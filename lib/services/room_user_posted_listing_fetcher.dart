import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/room_rakuten_url_normalize.dart';

/// ユーザーの ROOM プロフィールURL起点で、投稿済み ROOM **商品ページ** URL を HTML から収集する。
///
/// - HTTP のみ（WebView なし）。ROOM 側のマークアップ変更に弱い拡張点として正規表現・パス判定を局所化。
/// - 将来: ページング・同期オフセット引数を足せる構造。
class RoomUserPostedListingFetcher {
  RoomUserPostedListingFetcher({
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 22),
  }) : _client = httpClient ?? http.Client(),
       _timeout = timeout;

  final http.Client _client;
  final Duration _timeout;

  /// 投稿の古い→新しいなど **一覧上の出現順** を可能な限り保持した URL リスト（重複キーは除外）。
  Future<List<String>> fetchPostedRoomProductPageUrls(String userRoomProfileUrl) async {
    final trimmed = userRoomProfileUrl.trim();
    if (trimmed.isEmpty) return [];
    Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      return [];
    }
    if (!uri.hasScheme || !_isRoomHost(uri.host)) {
      return [];
    }

    final userSeg = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';

    late http.Response res;
    try {
      res = await _client
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (compatible; RoomManagerApp/1.0; +https://example.invalid)',
              'Accept': 'text/html,application/xhtml+xml',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[RoomUserPostedListingFetcher] timeout url=$trimmed');
      }
      return [];
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RoomUserPostedListingFetcher] network error: $e\n$st');
      }
      return [];
    }

    if (res.statusCode < 200 || res.statusCode >= 400 || res.body.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[RoomUserPostedListingFetcher] bad response status=${res.statusCode}',
        );
      }
      return [];
    }

    final html = res.body;
    final decoded = RoomUrlResolverStyleUnescape.unescapeBasicXmlEntities(html);
    final candidates = _collectFromHtml(html: html, decodedHtml: decoded, baseUri: uri);

    final seen = <String>{};
    final out = <String>[];

    for (final raw in candidates) {
      final abs = raw.startsWith('http') ? raw : uri.resolve(raw).toString();
      if (!RoomRakutenUrlNormalize.isLikelyRoomProductPageUrl(abs)) continue;
      final u = Uri.tryParse(abs);
      if (u == null || !_isRoomHost(u.host)) continue;
      if (userSeg.isNotEmpty && !_belongsToRoomUser(u, userSeg)) continue;
      if (!_isLikelyRoomPostPath(u)) continue;
      final key = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(abs);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(key);
    }
    return out;
  }

  static bool _isRoomHost(String host) {
    final h = host.toLowerCase();
    return h == 'room.rakuten.co.jp' || h.endsWith('.room.rakuten.co.jp');
  }

  static bool _belongsToRoomUser(Uri productUri, String userSegment) {
    final segs = productUri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.isEmpty) return false;
    return segs.first == userSegment;
  }

  /// パスが `{user}/{投稿ID}` 形式かどうかの軽量判定（投稿IDは数字想定・将来の形式差はここで調整）。
  static bool _isLikelyRoomPostPath(Uri u) {
    final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length < 2) return false;
    final last = segs.last;
    return RegExp(r'^\d{8,}$').hasMatch(last);
  }

  static List<String> _collectFromHtml({
    required String html,
    required String decodedHtml,
    required Uri baseUri,
  }) {
    final out = <String>[];
    final reAbs = RegExp(
      r'https?://(?:www\.)?room\.rakuten\.co\.jp/[^\s"<>]+',
      caseSensitive: false,
    );
    for (final m in reAbs.allMatches(html)) {
      final s = m.group(0);
      if (s != null) out.add(s);
    }
    for (final m in reAbs.allMatches(decodedHtml)) {
      final s = m.group(0);
      if (s != null) out.add(s);
    }

    final reHref = RegExp(
      r'''href\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    for (final m in reHref.allMatches(html)) {
      final ref = (m.group(1) ?? '').trim();
      if (ref.isEmpty || ref.startsWith('#')) continue;
      out.add(ref);
    }
    for (final m in reHref.allMatches(decodedHtml)) {
      final ref = (m.group(1) ?? '').trim();
      if (ref.isEmpty || ref.startsWith('#')) continue;
      out.add(ref);
    }
    return out;
  }
}

/// [RoomUrlResolver] と同等の最低限エスケープ解除（クラス共有せず局所で保持し、既存ファイル名を増やさない）。
abstract final class RoomUrlResolverStyleUnescape {
  static String unescapeBasicXmlEntities(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'");
  }
}
