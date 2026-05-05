import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/room_rakuten_url_normalize.dart';
import '../utils/room_sync_log.dart';
import 'rakuten_item_url_parser.dart';

/// ROOM 商品ページから楽天市場の商品URLを推定する。
///
/// **Step 1（本実装）**: HTTP で HTML を取得し [RakutenItemUrlParser] で `item.rakuten.co.jp` を検索。
///
/// **WebView フォールバック**: ROOM 側が JS 必須でリンクが HTML に現れない場合、
/// 既存の [RoomUrlExtractionCoordinator] 経由でページを描画し DOM から href を拾う
/// 拡張が可能（本クラスは [resolveRakutenItemUrlFromRoomPage] の戻りで失敗理由を区別できる）。
class RoomUrlResolver {
  RoomUrlResolver({
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 18),
  }) : _client = httpClient ?? http.Client(),
       _timeout = timeout;

  final http.Client _client;
  final Duration _timeout;

  /// HTTP のみ。将来的に `useWebViewFallback: true` で Coordinator に委譲可能な拡張点。
  ///
  /// [traceRoomSync] が true のとき、[ROOM_SYNC] プレフィックス付きで詳細ログを出す（kDebugMode のみ）。
  Future<RoomUrlResolveOutcome> resolveRakutenItemUrlFromRoomPage(
    String roomPageUrl, {
    bool useWebViewFallback = false,
    bool traceRoomSync = false,
  }) async {
    final trimmed = roomPageUrl.trim();
    if (trimmed.isEmpty) {
      if (traceRoomSync) {
        roomSyncWarn('ROOM商品ページURLが空（invalidInput）');
      }
      return const RoomUrlResolveFailure(RoomUrlResolveFailureKind.invalidInput);
    }
    if (!RoomRakutenUrlNormalize.isLikelyRoomProductPageUrl(trimmed)) {
      if (traceRoomSync) {
        roomSyncWarn('ROOM商品ページURLとして不正（notRoomUrl）: $trimmed');
      }
      return const RoomUrlResolveFailure(RoomUrlResolveFailureKind.notRoomUrl);
    }
    if (useWebViewFallback) {
      if (kDebugMode) {
        debugPrint(
          '[RoomUrlResolver] WebView フォールバックは未実装です（ATS/非同期WebView制約のため HTTP を使用）。',
        );
      }
    }

    late http.Response res;
    try {
      if (traceRoomSync) {
        roomSyncLog('ROOM商品ページへ接続: $trimmed');
        roomSyncLog(
          'User-Agent: Mozilla/5.0 (compatible; RoomManagerApp/1.0; +https://example.invalid)',
        );
      }
      res = await _client
          .get(
            Uri.parse(trimmed),
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (compatible; RoomManagerApp/1.0; +https://example.invalid)',
              'Accept': 'text/html,application/xhtml+xml',
            },
          )
          .timeout(_timeout);
    } on TimeoutException catch (e, st) {
      if (traceRoomSync) {
        roomSyncError('ROOM商品ページ取得失敗: timeout', e, st);
      }
      return const RoomUrlResolveFailure(RoomUrlResolveFailureKind.timeout);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RoomUrlResolver] HTTP 失敗: $e\n$st');
      }
      if (traceRoomSync) {
        roomSyncError('ROOM商品ページ取得失敗: exception', e, st);
      }
      return const RoomUrlResolveFailure(RoomUrlResolveFailureKind.networkError);
    }

    if (traceRoomSync) {
      roomSyncLog('HTTP status: ${res.statusCode}');
      roomSyncPreview('ROOM商品ページ response body', res.body, maxLength: 500);
    }

    if (res.statusCode < 200 || res.statusCode >= 400) {
      if (traceRoomSync) {
        roomSyncError('ROOM商品ページ取得失敗 status=${res.statusCode}');
        roomSyncPreview('ROOM商品ページ error body', res.body, maxLength: 500);
      }
      return RoomUrlResolveFailure(
        RoomUrlResolveFailureKind.httpError,
        debugDetail: 'status=${res.statusCode}',
      );
    }

    final body = res.body;
    if (body.isEmpty) {
      if (traceRoomSync) {
        roomSyncWarn('ROOM商品ページ response body が空（emptyBody）');
      }
      return const RoomUrlResolveFailure(RoomUrlResolveFailureKind.emptyBody);
    }

    final decoded = _unescapeBasicXmlEntities(body);
    if (traceRoomSync) {
      roomSyncLog('楽天で見るURL抽出開始（item.rakuten.co.jp / 他）');
      final decList = RakutenItemUrlParser.findAllMatchesInText(decoded);
      final rawList = RakutenItemUrlParser.findAllMatchesInText(body);
      final merged = <String>[];
      final seenUrl = <String>{};
      void addAll(List<RakutenItemUrlParseResult> list) {
        for (final r in list) {
          final u = r.rakutenUrl.trim();
          if (u.isEmpty || seenUrl.contains(u)) continue;
          seenUrl.add(u);
          merged.add(u);
        }
      }

      addAll(decList);
      addAll(rawList);
      final aflRe = RegExp(
        r'https?://hb\.afl\.rakuten\.co\.jp/[^\s"<>]+',
        caseSensitive: false,
      );
      final aflUrls = <String>[];
      for (final m in aflRe.allMatches(decoded)) {
        final s = m.group(0);
        if (s != null && !aflUrls.contains(s)) aflUrls.add(s);
      }
      for (final m in aflRe.allMatches(body)) {
        final s = m.group(0);
        if (s != null && !aflUrls.contains(s)) aflUrls.add(s);
      }
      roomSyncLog('楽天URL候補数（item.rakuten ユニーク）: ${merged.length}');
      for (var i = 0; i < merged.length; i++) {
        roomSyncLog('楽天URL候補[${i + 1}] (item): ${merged[i]}');
      }
      roomSyncLog('楽天アフィリエイトURL候補数: ${aflUrls.length}');
      for (var i = 0; i < aflUrls.length; i++) {
        roomSyncLog('楽天URL候補[${i + 1}] (afl): ${aflUrls[i]}');
      }
    }

    var parsed = RakutenItemUrlParser.findFirstInText(decoded);
    parsed ??= RakutenItemUrlParser.findFirstInText(body);

    if (parsed == null) {
      if (traceRoomSync) {
        roomSyncWarn('楽天URLを取得できませんでした（item パターン不一致）');
        final sample = decoded.isNotEmpty ? decoded : body;
        final lower = sample.toLowerCase();
        roomSyncWarn(
          'HTML内に item.rakuten.co.jp を含むか: ${lower.contains('item.rakuten.co.jp')}',
        );
        roomSyncWarn(
          'HTML内に hb.afl.rakuten.co.jp を含むか: ${lower.contains('hb.afl.rakuten.co.jp')}',
        );
        roomSyncWarn(
          'HTML内に 「楽天市場で見る」を含むか: ${sample.contains('楽天市場で見る')}',
        );
        roomSyncWarn(
          'HTML内に 「楽天で見る」を含むか: ${sample.contains('楽天で見る')}',
        );
      }
      return const RoomUrlResolveFailure(
        RoomUrlResolveFailureKind.rakutenLinkNotFound,
      );
    }

    if (traceRoomSync) {
      roomSyncLog('採用した楽天URL: ${parsed.rakutenUrl}');
    }

    final meta = _readOpenGraphTitleAndImage(decoded.isNotEmpty ? decoded : body);
    return RoomUrlResolveSuccess(
      rakutenItem: parsed,
      roomPageTitle: meta.$1,
      roomPageImageUrl: meta.$2,
    );
  }

  /// `&amp;` 等を最低限戻し、href 内の item.rakuten を拾いやすくする。
  static String _unescapeBasicXmlEntities(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'");
  }

  /// ROOM ページ向け og:title / og:image（取得できた場合のみ）。
  static (String?, String?) _readOpenGraphTitleAndImage(String html) {
    String? title;
    final titleRe = RegExp(
      r'property="og:title"[^>]*content="([^"]+)"',
      caseSensitive: false,
    );
    final titleRe2 = RegExp(
      r'content="([^"]+)"[^>]*property="og:title"',
      caseSensitive: false,
    );
    final tm = titleRe.firstMatch(html) ?? titleRe2.firstMatch(html);
    if (tm != null) {
      title = tm.group(1)?.trim();
      if (title != null && title.isEmpty) title = null;
    }

    String? image;
    final imgRe = RegExp(
      r'property="og:image"[^>]*content="([^"]+)"',
      caseSensitive: false,
    );
    final imgRe2 = RegExp(
      r'content="([^"]+)"[^>]*property="og:image"',
      caseSensitive: false,
    );
    final im = imgRe.firstMatch(html) ?? imgRe2.firstMatch(html);
    if (im != null) {
      image = im.group(1)?.trim();
      if (image != null && image.isEmpty) image = null;
    }
    return (title, image);
  }
}

sealed class RoomUrlResolveOutcome {
  const RoomUrlResolveOutcome();
}

final class RoomUrlResolveSuccess extends RoomUrlResolveOutcome {
  const RoomUrlResolveSuccess({
    required this.rakutenItem,
    this.roomPageTitle,
    this.roomPageImageUrl,
  });

  final RakutenItemUrlParseResult rakutenItem;
  final String? roomPageTitle;
  final String? roomPageImageUrl;
}

final class RoomUrlResolveFailure extends RoomUrlResolveOutcome {
  const RoomUrlResolveFailure(this.kind, {this.debugDetail});

  final RoomUrlResolveFailureKind kind;
  final String? debugDetail;
}

enum RoomUrlResolveFailureKind {
  invalidInput,
  notRoomUrl,
  timeout,
  networkError,
  httpError,
  emptyBody,
  rakutenLinkNotFound,
}
