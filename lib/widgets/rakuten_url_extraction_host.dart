import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/rakuten_managed_product.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../services/rakuten_url_extraction_scheduler.dart';
import '../services/xpath_config_loader.dart';

class _ExtractionJob {
  _ExtractionJob(this.productId, this.pageUrl);
  final String productId;
  final String pageUrl;
}

/// 画面外の極小 WebView で商品 URL を開き、XPath 抽出を行う（ユーザーにはほぼ見えない）。
class RakutenUrlExtractionHost extends StatefulWidget {
  const RakutenUrlExtractionHost({
    super.key,
    required this.scheduler,
    required this.repository,
    required this.xpathLoader,
    required this.onPersisted,
  });

  final RakutenUrlExtractionSchedulerImpl scheduler;
  final RakutenManagedProductRepository repository;
  final XpathConfigLoader xpathLoader;
  final VoidCallback onPersisted;

  @override
  State<RakutenUrlExtractionHost> createState() =>
      _RakutenUrlExtractionHostState();
}

class _RakutenUrlExtractionHostState extends State<RakutenUrlExtractionHost> {
  WebViewController? _controller;
  final Queue<_ExtractionJob> _queue = Queue<_ExtractionJob>();
  bool _draining = false;
  Completer<void>? _pageReady;
  bool _awaitingPage = false;
  _ExtractionJob? _activeJob;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    widget.scheduler.registerHandler(_enqueue);
    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: _onPageFinished,
            onWebResourceError: (WebResourceError error) {
              final job = _activeJob;
              if (job == null || !_awaitingPage) return;
              _cancelTimeout();
              _awaitingPage = false;
              if (_pageReady != null && !_pageReady!.isCompleted) {
                _pageReady!.completeError(error.description);
              }
            },
          ),
        );
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _enqueue(String productId, String pageUrl) {
    if (kIsWeb) {
      unawaited(_failProduct(productId, 'WebではURL抽出に未対応です'));
      return;
    }
    if (_controller == null) {
      unawaited(_failProduct(productId, 'WebViewの初期化に失敗しました'));
      return;
    }
    _queue.addLast(_ExtractionJob(productId, pageUrl));
    unawaited(_drainQueue());
  }

  Future<void> _drainQueue() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty && _controller != null) {
        final job = _queue.removeFirst();
        await _runSingleJob(job);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _runSingleJob(_ExtractionJob job) async {
    _activeJob = job;
    _pageReady = Completer<void>();
    _awaitingPage = true;
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 45), () {
      if (!_awaitingPage) return;
      if (_pageReady != null && !_pageReady!.isCompleted) {
        _pageReady!.completeError(TimeoutException('page load'));
      }
    });
    try {
      await _controller!.loadRequest(Uri.parse(job.pageUrl));
      await _pageReady!.future;
    } on TimeoutException {
      await _failProduct(job.productId, 'ページ読み込みがタイムアウトしました');
      await _loadBlank();
      _activeJob = null;
      return;
    } on Object {
      await _failProduct(job.productId, 'ページを開けませんでした');
      await _loadBlank();
      _activeJob = null;
      return;
    } finally {
      _cancelTimeout();
      _awaitingPage = false;
    }

    try {
      final xpath = await widget.xpathLoader.loadPrimaryXpathValue();
      if (xpath == null || xpath.trim().isEmpty) {
        await _failProduct(job.productId, 'XPath設定を読み込めませんでした');
        await _loadBlank();
        _activeJob = null;
        return;
      }

      final js = _buildXPathEvaluationJs(xpath.trim());
      final raw = await _controller!.runJavaScriptReturningResult(js);
      final parsed = _parseJsJsonResult(raw);
      if (parsed == null) {
        await _failProduct(job.productId, '抽出結果の解析に失敗しました');
      } else if (parsed['ok'] == true) {
        final value = (parsed['value'] ?? '').toString().trim();
        if (value.isEmpty) {
          await _failProduct(job.productId, 'XPathに一致する値が空でした');
        } else {
          await _succeedProduct(job.productId, value);
        }
      } else {
        final err = (parsed['error'] ?? 'no_match').toString();
        await _failProduct(job.productId, 'XPath抽出: $err');
      }
    } catch (e) {
      await _failProduct(job.productId, '抽出処理エラー: $e');
    }

    await _loadBlank();
    _activeJob = null;
  }

  void _onPageFinished(String url) {
    if (!_awaitingPage || _pageReady == null) return;
    final c = _pageReady!;
    if (c.isCompleted) return;
    c.complete();
  }

  Future<void> _loadBlank() async {
    try {
      await _controller?.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  Future<void> _succeedProduct(String productId, String extractedUrl) async {
    final current = widget.repository.getByProductId(productId);
    if (current == null) return;
    final now = DateTime.now();
    await widget.repository.replaceProduct(
      current.copyWith(
        extractedUrl: extractedUrl,
        extractionStatus: RakutenUrlExtractionStatus.success,
        extractionErrorMessage: '',
        extractedAt: now,
        updatedAt: now,
      ),
    );
    widget.onPersisted();
  }

  Future<void> _failProduct(String productId, String message) async {
    final current = widget.repository.getByProductId(productId);
    if (current == null) return;
    final now = DateTime.now();
    await widget.repository.replaceProduct(
      current.copyWith(
        extractionStatus: RakutenUrlExtractionStatus.failed,
        extractionErrorMessage: message,
        updatedAt: now,
      ),
    );
    widget.onPersisted();
  }

  static String _buildXPathEvaluationJs(String xpath) {
    final enc = jsonEncode(xpath);
    return '''
(function() {
  try {
    var xpath = $enc;
    var result = document.evaluate(
      xpath,
      document,
      null,
      XPathResult.FIRST_ORDERED_NODE_TYPE,
      null
    );
    var node = result.singleNodeValue;
    if (!node) {
      return JSON.stringify({"ok":false,"error":"no_match"});
    }
    var text = "";
    if (node.nodeType === 2) {
      text = (node.value || "").trim();
    } else if (node.nodeType === 1) {
      var el = node;
      text = (el.getAttribute("href") || el.textContent || "").trim();
    } else {
      text = (node.textContent || "").trim();
    }
    if (text.indexOf("/") === 0 && window.location && window.location.origin) {
      text = window.location.origin + text;
    }
    return JSON.stringify({"ok":true,"value": text});
  } catch (e) {
    return JSON.stringify({"ok":false,"error": String(e)});
  }
})()
''';
  }

  static Map<String, dynamic>? _parseJsJsonResult(Object? raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw as Map);
    }
    String s;
    if (raw is String) {
      s = raw;
    } else {
      s = raw.toString();
    }
    try {
      if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
        final inner = jsonDecode(s);
        if (inner is String) s = inner;
      }
      final decoded = jsonDecode(s);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || _controller == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Opacity(
        opacity: 0.02,
        child: SizedBox(
          width: 360,
          height: 560,
          child: WebViewWidget(controller: _controller!),
        ),
      ),
    );
  }
}
