import 'dart:convert';

import 'rakuten_ichiba_url_parse.dart';
import '../services/rakuten_item_url_parser.dart';
import 'room_sync_log.dart';

/// ROOM `rat` / `relay` / `rat-redirect` から得た、永続化・補完用のヒント。
///
/// 用語:
/// - [urlShopCode] / [urlProductCode]: 楽天市場URLパス上の店舗コードと商品パス（API itemCode ではない）。
/// - [eventShopUrl]: `event.shopurl`（API composite の左側に使う）。
/// - [apiItemCode] / [apiCompositeItemCode]: 楽天API direct itemCode 用。
final class RoomRatRedirectArtifacts {
  const RoomRatRedirectArtifacts({
    required this.roomRedirectUrl,
    required this.eventShopUrl,
    required this.eventItemIdRaw,
    required this.apiItemCode,
    required this.apiCompositeItemCode,
    required this.genreId,
    required this.rakutenItemUrl,
    required this.urlShopCode,
    required this.urlProductCode,
    required this.decodedDest,
    required this.decodedPcUrl,
  });

  final String roomRedirectUrl;

  /// `event.shopurl`（`apiCompositeItemCode` の左側）。
  final String eventShopUrl;

  final String eventItemIdRaw;
  final String apiItemCode;

  /// `eventShopUrl:apiItemCode`（楽天 Item Search の direct 向け）。
  final String apiCompositeItemCode;
  final String genreId;
  final String rakutenItemUrl;

  /// `item.rakuten.co.jp/{urlShopCode}/{urlProductCode}/` の第1パスセグメント。
  final String urlShopCode;

  /// 市場URLパス上の商品コード（JAN・スラッグ等。API itemCode ではない）。
  final String urlProductCode;

  /// `dest` クエリを1段デコードした文字列（ログ用）。
  final String decodedDest;

  /// `pc=` 内をフルデコードした item.rakuten URL 相当（ログ用）。
  final String decodedPcUrl;

  /// 互換: [urlProductCode] と同義（旧 `roomProductSlug`）。
  String get roomProductSlug => urlProductCode;

  /// 互換: [eventShopUrl]。
  String get shopurl => eventShopUrl;

  bool get hasApiComposite =>
      apiCompositeItemCode.trim().isNotEmpty &&
      rakutenIchibaUrlLooksLikeApiItemCode(apiCompositeItemCode.trim());
}

/// ROOM HTML 内の `rat` / `relay` / `rat-redirect` URL を解析する。
abstract final class RoomRatRedirectParse {
  static final RegExp _ratUrlPattern = RegExp(
    r'https?://[^\s"<>]*room\.rakuten\.co\.jp[^\s"<>]*'
    r'(?:/rat-redirect[^\s"<>]*|/rat/[^\s"<>]*|relay/click\.html[^\s"<>]*)',
    caseSensitive: false,
  );

  /// HTML から最初の有効な rat 系リンクを拾い、解析する（失敗時 null）。
  static RoomRatRedirectArtifacts? mergeBestFromHtml(
    String decodedHtml,
    String rawHtml, {
    required String roomPageUrl,
  }) {
    final seen = <String>{};
    RoomRatRedirectArtifacts? best;
    void consider(String url) {
      final u = url.trim();
      if (u.isEmpty || !seen.add(u)) return;
      final parsed = tryParseRedirectUrl(u, roomPageUrl: roomPageUrl);
      if (parsed == null) return;
      if (parsed.hasApiComposite) {
        if (best == null || !best!.hasApiComposite) best = parsed;
      } else {
        best ??= parsed;
      }
    }

    for (final m in _ratUrlPattern.allMatches(decodedHtml)) {
      consider(m.group(0) ?? '');
    }
    for (final m in _ratUrlPattern.allMatches(rawHtml)) {
      consider(m.group(0) ?? '');
    }
    if (best != null) {
      final b = best!;
      roomRedirectParseLog(
        'roomUrl=$roomPageUrl eventShopUrl=${b.eventShopUrl} eventItemIdRaw=${b.eventItemIdRaw} '
        'apiItemCode=${b.apiItemCode} apiCompositeItemCode=${b.apiCompositeItemCode} '
        'genreId=${b.genreId} rakutenItemUrl=${b.rakutenItemUrl} '
        'urlShopCode=${b.urlShopCode} urlProductCode=${b.urlProductCode}',
      );
    }
    return best;
  }

  /// 単一の rat / relay / rat-redirect URL を解析する。
  static RoomRatRedirectArtifacts? tryParseRedirectUrl(
    String rawRedirect, {
    required String roomPageUrl,
  }) {
    final trimmed = rawRedirect.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    final eventEnc = uri.queryParameters['event'] ?? uri.queryParameters['Event'];
    final destEnc = uri.queryParameters['dest'] ?? uri.queryParameters['Dest'];
    if (eventEnc == null || eventEnc.trim().isEmpty) {
      return null;
    }

    String eventShopUrl = '';
    String eventItemIdRaw = '';
    String apiItemCode = '';
    String genreId = '';
    try {
      final eventJson =
          jsonDecode(Uri.decodeFull(eventEnc.trim())) as Map<String, dynamic>?;
      if (eventJson == null) return null;
      eventShopUrl = _readStringKey(
        eventJson,
        const ['shopurl', 'shopUrl', 'shop_id', 'shopId'],
      );
      eventItemIdRaw = _readItemIdRaw(eventJson['itemid'] ?? eventJson['itemId']);
      apiItemCode = _apiItemCodeFromEventItemId(eventItemIdRaw);
      genreId = _readGenreId(eventJson);
    } catch (_) {
      return null;
    }

    final peeled = _peelDestToItemRakuten(destEnc);
    if (peeled == null) {
      roomRatRedirectExtractLog(
        'rawUrl=${_trimLogUrl(trimmed)} decodedDest= decodedPcUrl= '
        'shopCode= urlProductCode= rakutenItemUrl= '
        'eventShopUrl=$eventShopUrl eventItemIdRaw=$eventItemIdRaw '
        'apiItemCode=$apiItemCode apiCompositeItemCode= genreId=$genreId '
        'reason=destPeelFailed',
      );
      return null;
    }

    final urlShopCode = peeled.urlShopCode;
    final urlProductCode = peeled.urlProductCode;
    var rakutenItemUrl = peeled.itemRakutenUrl.trim();
    if (rakutenItemUrl.isNotEmpty) {
      rakutenItemUrl = _normalizeHttpsItemRakutenUrl(rakutenItemUrl);
    }

    var composite = '';
    if (eventShopUrl.isNotEmpty && apiItemCode.isNotEmpty) {
      composite = '${eventShopUrl.trim()}:${apiItemCode.trim()}';
    }

    final art = RoomRatRedirectArtifacts(
      roomRedirectUrl: trimmed,
      eventShopUrl: eventShopUrl.trim(),
      eventItemIdRaw: eventItemIdRaw,
      apiItemCode: apiItemCode.trim(),
      apiCompositeItemCode: composite,
      genreId: genreId.trim(),
      rakutenItemUrl: rakutenItemUrl,
      urlShopCode: urlShopCode.trim(),
      urlProductCode: urlProductCode.trim(),
      decodedDest: peeled.decodedDest,
      decodedPcUrl: peeled.decodedPcUrl,
    );

    roomRatRedirectExtractLog(
      'rawUrl=${_trimLogUrl(trimmed)} '
      'decodedDest=${_trimLogUrl(peeled.decodedDest)} '
      'decodedPcUrl=${_trimLogUrl(peeled.decodedPcUrl)} '
      'shopCode=${art.urlShopCode} urlProductCode=${art.urlProductCode} '
      'rakutenItemUrl=${_trimLogUrl(art.rakutenItemUrl)} '
      'eventShopUrl=${art.eventShopUrl} eventItemIdRaw=${art.eventItemIdRaw} '
      'apiItemCode=${art.apiItemCode} apiCompositeItemCode=${art.apiCompositeItemCode.isEmpty ? '(empty)' : art.apiCompositeItemCode} '
      'genreId=${art.genreId.isEmpty ? '(empty)' : art.genreId}',
    );

    return art;
  }

  static String _trimLogUrl(String s, {int max = 220}) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  static String _readStringKey(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return v.toString();
    }
    return '';
  }

  static String _readGenreId(Map<String, dynamic> m) {
    for (final k in const ['igenre', 'iGenre']) {
      final v = m[k];
      if (v is List && v.isNotEmpty) {
        return v.first.toString().trim();
      }
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return v.toString();
    }
    return _readStringKey(m, const ['genreId', 'genre_id']);
  }

  static String _readItemIdRaw(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    if (v is List) {
      for (final e in v) {
        final s = e?.toString().trim() ?? '';
        if (s.isNotEmpty) return s;
      }
      return '';
    }
    return v.toString().trim();
  }

  /// `"306273/10002596"` → `10002596`
  static String _apiItemCodeFromEventItemId(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final noBracket = t.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
    final slash = noBracket.indexOf('/');
    if (slash >= 0 && slash < noBracket.length - 1) {
      return noBracket.substring(slash + 1).trim();
    }
    return noBracket.trim();
  }

  static _DestPeelResult? _peelDestToItemRakuten(String? destEnc) {
    if (destEnc == null || destEnc.trim().isEmpty) return null;
    var cur = destEnc.trim();
    String? decodedDestOut;
    for (var hop = 0; hop < 8; hop++) {
      String decoded;
      try {
        decoded = Uri.decodeFull(cur);
      } catch (_) {
        return null;
      }
      decoded = decoded.trim();
      if (decoded.isEmpty) return null;
      decodedDestOut ??= decoded;

      final lower = decoded.toLowerCase();
      if (lower.contains('item.rakuten.co.jp')) {
        final parsed = RakutenItemUrlParser.tryParse(decoded);
        final url = parsed?.rakutenUrl.trim() ?? '';
        if (url.isEmpty) {
          final segs = _pathSegmentsForItemRakuten(decoded);
          if (segs.length >= 2) {
            final norm = _normalizeHttpsItemRakutenUrl(decoded);
            return _DestPeelResult(
              itemRakutenUrl: norm,
              decodedDest: decodedDestOut,
              decodedPcUrl: norm,
              urlShopCode: segs[0],
              urlProductCode: segs[1],
            );
          }
          return null;
        }
        final segs = _pathSegmentsForItemRakuten(parsed!.rakutenUrl);
        if (segs.length < 2) return null;
        final norm = _normalizeHttpsItemRakutenUrl(parsed.rakutenUrl);
        return _DestPeelResult(
          itemRakutenUrl: norm,
          decodedDest: decodedDestOut,
          decodedPcUrl: norm,
          urlShopCode: segs[0],
          urlProductCode: segs[1],
        );
      }

      final u = Uri.tryParse(decoded);
      if (u == null) return null;
      if (u.host.toLowerCase().contains('hb.afl.rakuten.co.jp')) {
        final pc = u.queryParameters['pc'] ?? u.queryParameters['PC'];
        if (pc == null || pc.trim().isEmpty) return null;
        cur = _fullyUrlDecodeChain(pc.trim());
        continue;
      }
      return null;
    }
    return null;
  }

  /// `%25` などが残っているとき、安定するまで decode を繰り返す。
  static String _fullyUrlDecodeChain(String raw) {
    var s = raw;
    for (var i = 0; i < 8; i++) {
      String next;
      try {
        next = Uri.decodeFull(s);
      } catch (_) {
        break;
      }
      if (next == s) break;
      s = next;
    }
    return s;
  }

  static List<String> _pathSegmentsForItemRakuten(String rawUrl) {
    var u = Uri.tryParse(rawUrl.trim());
    if (u == null) return const [];
    if (!u.host.toLowerCase().contains('item.rakuten.co.jp')) {
      return const [];
    }
    return u.pathSegments.where((s) => s.isNotEmpty).toList();
  }

  static String _normalizeHttpsItemRakutenUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    var u = Uri.tryParse(t);
    if (u == null) return t;
    if (!u.hasScheme) {
      u = Uri.tryParse('https://$t');
    }
    if (u == null) return t;
    var path = u.path;
    if (path.isEmpty) path = '/';
    if (!path.endsWith('/')) path = '$path/';
    return Uri(
      scheme: 'https',
      host: u.host.toLowerCase(),
      path: path,
    ).toString();
  }
}

final class _DestPeelResult {
  const _DestPeelResult({
    required this.itemRakutenUrl,
    required this.decodedDest,
    required this.decodedPcUrl,
    required this.urlShopCode,
    required this.urlProductCode,
  });

  final String itemRakutenUrl;
  final String decodedDest;
  final String decodedPcUrl;
  final String urlShopCode;
  final String urlProductCode;
}

/// URL スラッグ由来のセグメントを楽天API direct itemCode として使わないか。
bool roomImportEnrichSlugShouldSkipDirectItemCode(String segment) {
  final t = segment.trim();
  if (t.isEmpty) return true;
  if (rakutenIchibaUrlLooksLikeApiItemCode(t)) return false;
  if (t.contains('-')) return true;
  if (RegExp(r'[A-Za-z_]').hasMatch(t)) return true;
  if (RegExp(r'^[0-9]+$').hasMatch(t) && t.length >= 11) return true;
  return false;
}
