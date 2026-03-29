import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/room_url_extraction_coordinator.dart';

/// 画面外相当の極小 WebView で商品ページを読み XPath / CSS 評価を行うホスト。
/// [MaterialApp.builder] などルート付近に1つだけ置く。
class RoomUrlExtractionHost extends StatefulWidget {
  const RoomUrlExtractionHost({super.key, required this.child});

  final Widget child;

  @override
  State<RoomUrlExtractionHost> createState() => _RoomUrlExtractionHostState();
}

class _RoomUrlExtractionHostState extends State<RoomUrlExtractionHost> {
  WebViewController? _controller;
  final Queue<_QueuedExtraction> _queue = Queue<_QueuedExtraction>();
  bool _draining = false;
  Completer<void>? _loadCompleter;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void dispose() {
    RoomUrlExtractionCoordinator.instance.detach();
    super.dispose();
  }

  Future<void> _initController() async {
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 RoomManager/1.0',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            final comp = _loadCompleter;
            if (comp != null && !comp.isCompleted) {
              comp.complete();
            }
          },
          onWebResourceError: (WebResourceError err) {
            final comp = _loadCompleter;
            if (comp != null && !comp.isCompleted) {
              comp.completeError(Exception(err.description));
            }
          },
        ),
      );

    if (!mounted) return;
    setState(() => _controller = c);
    RoomUrlExtractionCoordinator.instance.attach(_enqueueAndRun);
  }

  Future<String?> _enqueueAndRun(
    String url,
    String selectorType,
    String selectorValue,
    int postLoadDelayMs,
  ) async {
    final job = _QueuedExtraction(
      url,
      selectorType,
      selectorValue,
      postLoadDelayMs,
      Completer<String?>(),
    );
    _queue.add(job);
    unawaited(_drainQueue());
    return job.completer.future;
  }

  Future<void> _drainQueue() async {
    if (_draining || _queue.isEmpty || _controller == null) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty && mounted) {
        final job = _queue.removeFirst();
        try {
          final result = await _runOne(
            job.url,
            job.selectorType,
            job.selectorValue,
            job.postLoadDelayMs,
          );
          if (!job.completer.isCompleted) {
            job.completer.complete(result);
          }
        } catch (e, st) {
          if (!job.completer.isCompleted) {
            job.completer.completeError(e, st);
          }
        }
      }
    } finally {
      _draining = false;
      if (_queue.isNotEmpty && mounted) {
        unawaited(_drainQueue());
      }
    }
  }

  Future<String?> _runOne(
    String url,
    String selectorType,
    String selectorValue,
    int postLoadDelayMs,
  ) async {
    final c = _controller;
    if (c == null) return null;

    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw Exception('商品URLが不正です');
    }

    _loadCompleter = Completer<void>();
    await c.loadRequest(uri);

    await _loadCompleter!.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('ページの読み込みがタイムアウトしました'),
    );

    if (postLoadDelayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: postLoadDelayMs));
    }

    final t = selectorType.toLowerCase().trim();
    final String script;
    if (t == 'css') {
      script = _buildCssScript(selectorValue);
    } else {
      script = _buildXPathScript(selectorValue);
    }

    final raw = await c.runJavaScriptReturningResult(script).timeout(
      const Duration(seconds: 15),
    );

    final parsed = _parseJsPayload(raw);
    if (parsed.ok && (parsed.value ?? '').trim().isNotEmpty) {
      return parsed.value!.trim();
    }
    throw Exception(parsed.err ?? '抽出結果が空です');
  }

  static String _buildXPathScript(String xpath) {
    final xpLit = jsonEncode(xpath);
    return '''
(function() {
  try {
    var xp = $xpLit;
    var r = document.evaluate(xp, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
    var n = r.singleNodeValue;
    if (!n) {
      return JSON.stringify({ ok: false, err: 'no node' });
    }
    var v = null;
    if (n.nodeType === 2) {
      v = n.nodeValue;
    } else if (n.nodeType === 1 && n.tagName === 'A' && n.href) {
      v = n.href;
    } else if (n.nodeValue) {
      v = n.nodeValue;
    } else {
      v = (n.textContent || '').trim();
    }
    if (!v) {
      return JSON.stringify({ ok: false, err: 'empty value' });
    }
    return JSON.stringify({ ok: true, value: v });
  } catch (e) {
    return JSON.stringify({ ok: false, err: String(e) });
  }
})()
''';
  }

  /// [document.querySelector](css) で要素を取り、リンクなら絶対 URL を優先。
  static String _buildCssScript(String cssSelector) {
    final lit = jsonEncode(cssSelector);
    return '''
(function() {
  try {
    var sel = $lit;
    var el = document.querySelector(sel);
    if (!el) {
      return JSON.stringify({ ok: false, err: 'no element' });
    }
    var v = '';
    if (el.tagName === 'A' && el.href) {
      v = el.href;
    } else {
      v = (el.getAttribute('href') || el.textContent || '').trim();
    }
    if (!v) {
      return JSON.stringify({ ok: false, err: 'empty value' });
    }
    return JSON.stringify({ ok: true, value: v });
  } catch (e) {
    return JSON.stringify({ ok: false, err: String(e) });
  }
})()
''';
  }

  static _JsParsed _parseJsPayload(Object? raw) {
    if (raw == null) {
      return _JsParsed(ok: false, err: 'null result');
    }
    var s = raw.toString();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      try {
        final d = jsonDecode(s);
        if (d is String) s = d;
      } catch (_) {}
    }
    try {
      final map = jsonDecode(s);
      if (map is Map<String, dynamic>) {
        final ok = map['ok'] == true;
        final value = map['value']?.toString();
        final err = map['err']?.toString();
        return _JsParsed(ok: ok, value: value, err: err);
      }
    } catch (_) {}
    return _JsParsed(ok: false, err: 'parse error: $s');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          right: 0,
          bottom: 0,
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0.01,
            child: IgnorePointer(
              ignoring: true,
              child: _controller != null
                  ? WebViewWidget(controller: _controller!)
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class _QueuedExtraction {
  _QueuedExtraction(
    this.url,
    this.selectorType,
    this.selectorValue,
    this.postLoadDelayMs,
    this.completer,
  );

  final String url;
  final String selectorType;
  final String selectorValue;
  final int postLoadDelayMs;
  final Completer<String?> completer;
}

class _JsParsed {
  _JsParsed({required this.ok, this.value, this.err});

  final bool ok;
  final String? value;
  final String? err;
}
