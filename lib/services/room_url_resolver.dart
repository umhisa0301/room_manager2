import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/room_rakuten_url_normalize.dart';
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
  Future<RoomUrlResolveOutcome> resolveRakutenItemUrlFromRoomPage(
    String roomPageUrl, {
    bool useWebViewFallback = false,
  }) async {
    final trimmed = roomPageUrl.trim();
    if (trimmed.isEmpty) {
      return const RoomUrlResolveFailure(RoomUrlResolveFailureKind.invalidInput);
    }
    if (!RoomRakutenUrlNormalize.isLikelyRoomProductPageUrl(trimmed)) {
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
    } on TimeoutException {
      return const RoomUrlResolveFailure(RoomUrlResolveFailureKind.timeout);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RoomUrlResolver] HTTP 失敗: $e\n$st');
      }
      return const RoomUrlResolveFailure(RoomUrlResolveFailureKind.networkError);
    }

    if (res.statusCode < 200 || res.statusCode >= 400) {
      return RoomUrlResolveFailure(
        RoomUrlResolveFailureKind.httpError,
        debugDetail: 'status=${res.statusCode}',
      );
    }

    final body = res.body;
    if (body.isEmpty) {
      return const RoomUrlResolveFailure(RoomUrlResolveFailureKind.emptyBody);
    }

    final decoded = _unescapeBasicXmlEntities(body);
    var parsed = RakutenItemUrlParser.findFirstInText(decoded);
    parsed ??= RakutenItemUrlParser.findFirstInText(body);

    if (parsed == null) {
      return const RoomUrlResolveFailure(
        RoomUrlResolveFailureKind.rakutenLinkNotFound,
      );
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
