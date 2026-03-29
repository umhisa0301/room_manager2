import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/room_url_extraction_coordinator.dart';

/// デバッグ時のみ `--dart-define=DEBUG_ROOM_EXTRACTION_WEBVIEW_VISIBLE=true` で有効化。
/// 抽出用 WebView を画面下に表示し、実際の表示・遷移を確認できる。
const bool kDebugRoomExtractionWebViewVisible = bool.fromEnvironment(
  'DEBUG_ROOM_EXTRACTION_WEBVIEW_VISIBLE',
  defaultValue: false,
);

/// 抽出用 WebView 向け User-Agent（モバイル表記なし）。
/// 楽天市場等が PC 版 HTML / セレクタを返すようにする。
const String _desktopChromeUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 RoomManager/1.0';

/// 画面外相当の極小 WebView で商品ページを読み XPath / CSS 評価を行うホスト。
/// [MaterialApp.builder] などルート付近に1つだけ置く。
class RoomUrlExtractionHost extends StatefulWidget {
  const RoomUrlExtractionHost({super.key, required this.child});

  final Widget child;

  @override
  State<RoomUrlExtractionHost> createState() => _RoomUrlExtractionHostState();
}

class _RoomUrlExtractionHostState extends State<RoomUrlExtractionHost> {
  static const String _logTag = '[RoomUrlExtraction]';

  WebViewController? _controller;
  final Queue<_QueuedExtraction> _queue = Queue<_QueuedExtraction>();
  bool _draining = false;
  Completer<void>? _loadCompleter;

  /// JS 側の [err] をログ用に補足説明付きへ。
  static String _explainJsErr(String? err) {
    switch (err) {
      case 'no node':
        return 'XPathがどのノードにも一致しません（ページ構造・セレクタ・遅延描画を確認）';
      case 'no element':
        return 'CSSセレクタに一致する要素がありません';
      case 'empty value':
        return '要素は一致しましたが href/テキストが空です';
      case 'null result':
        return 'JSの戻り値がnullです';
      default:
        if (err == null || err.isEmpty) return '理由コードなし';
        if (err.startsWith('parse error')) {
          return 'JS結果のJSON解析に失敗しました: $err';
        }
        return err;
    }
  }

  void _logFailure({
    required String phase,
    required String summary,
    required String pageUrl,
    required String selectorType,
    required String selectorValue,
    Object? cause,
  }) {
    final sel = selectorValue.length > 160
        ? '${selectorValue.substring(0, 160)}…'
        : selectorValue;
    final url = pageUrl.length > 200 ? '${pageUrl.substring(0, 200)}…' : pageUrl;
    debugPrint(
      '$_logTag 失敗 [$phase] $summary | type=$selectorType | selector=$sel | url=$url',
    );
    if (cause != null) {
      debugPrint('$_logTag 原因: $cause');
    }
  }

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
      ..setUserAgent(_desktopChromeUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            final comp = _loadCompleter;
            if (comp != null && !comp.isCompleted) {
              comp.complete();
            }
          },
          onWebResourceError: (WebResourceError err) {
            // 副リソース（画像・XHR 等）の ORB 等は本体表示と無関係なことが多い。
            // メイン以外のエラーで completeError すると、実際は描画できても抽出が失敗する。
            if (err.isForMainFrame == false) {
              debugPrint(
                '$_logTag 副リソース読込エラー(無視): ${err.description}',
              );
              return;
            }
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
    if (c == null) {
      debugPrint(
        '$_logTag 失敗 [WebView] controller が未初期化のため実行できません',
      );
      return null;
    }

    final trimmedUrl = url.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      debugPrint(
        '$_logTag 失敗 [URL検証] http(s) でない、または解析不能: $trimmedUrl',
      );
      throw Exception('商品URLが不正です');
    }

    debugPrint('$_logTag 読み込み開始: $trimmedUrl');

    _loadCompleter = Completer<void>();
    await c.loadRequest(uri);

    try {
      await _loadCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('ページの読み込みがタイムアウトしました'),
      );
    } on TimeoutException catch (e) {
      _logFailure(
        phase: 'ページ読み込み',
        summary: '30秒でタイムアウト（ネットワーク・リダイレクト過多など）',
        pageUrl: trimmedUrl,
        selectorType: selectorType,
        selectorValue: selectorValue,
        cause: e,
      );
      rethrow;
    } catch (e) {
      _logFailure(
        phase: 'ページ読み込み',
        summary: 'WebViewの読み込みエラー',
        pageUrl: trimmedUrl,
        selectorType: selectorType,
        selectorValue: selectorValue,
        cause: e,
      );
      rethrow;
    }

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

    Object? raw;
    try {
      raw = await c.runJavaScriptReturningResult(script).timeout(
        const Duration(seconds: 15),
      );
    } on TimeoutException catch (e) {
      _logFailure(
        phase: 'JS実行',
        summary: 'runJavaScript が15秒でタイムアウト',
        pageUrl: trimmedUrl,
        selectorType: selectorType,
        selectorValue: selectorValue,
        cause: e,
      );
      rethrow;
    } catch (e) {
      _logFailure(
        phase: 'JS実行',
        summary: 'runJavaScript 実行中に例外',
        pageUrl: trimmedUrl,
        selectorType: selectorType,
        selectorValue: selectorValue,
        cause: e,
      );
      rethrow;
    }

    final parsed = _parseJsPayload(raw);
    if (parsed.ok && (parsed.value ?? '').trim().isNotEmpty) {
      final extracted = parsed.value!.trim();
      debugPrint('$_logTag 取得結果: $extracted');
      return extracted;
    }

    final code = parsed.err;
    final human = _explainJsErr(code);
    _logFailure(
      phase: 'DOM抽出',
      summary: human,
      pageUrl: trimmedUrl,
      selectorType: selectorType,
      selectorValue: selectorValue,
      cause: code,
    );
    throw Exception(
      code != null && code.isNotEmpty ? '$human (code: $code)' : human,
    );
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
    final web = _controller != null
        ? WebViewWidget(controller: _controller!)
        : const SizedBox.shrink();

    if (kDebugRoomExtractionWebViewVisible) {
      final h = MediaQuery.sizeOf(context).height * 0.45;
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: h.clamp(120.0, 600.0),
            child: Material(
              elevation: 12,
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ColoredBox(
                    color: Colors.amber.shade100,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        'DEBUG: ROOM URL 抽出用 WebView\n'
                        'オフにする: DEBUG_ROOM_EXTRACTION_WEBVIEW_VISIBLE を外して再ビルド',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  Expanded(child: web),
                ],
              ),
            ),
          ),
        ],
      );
    }

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
              child: web,
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
