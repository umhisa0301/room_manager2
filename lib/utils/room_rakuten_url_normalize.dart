import '../services/rakuten_item_url_parser.dart';
import 'catalog_product_keys.dart';

/// ROOM 商品ページURLの照合用キー（ホスト小文字・末尾スラッシュ除去・クエリ除去）。
abstract final class RoomRakutenUrlNormalize {
  const RoomRakutenUrlNormalize._();

  static String normalizeRoomProductPageKey(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final u = Uri.tryParse(t);
    if (u == null || !u.hasAuthority) return '';
    var path = u.path;
    if (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }
    return '${u.scheme}://${u.host.toLowerCase()}$path';
  }

  static bool isLikelyRoomProductPageUrl(String raw) {
    final u = Uri.tryParse(raw.trim());
    if (u == null || !u.hasScheme) return false;
    final h = u.host.toLowerCase();
    return h == 'room.rakuten.co.jp' || h.endsWith('.room.rakuten.co.jp');
  }

  /// 楽天商品ページの安定URL（末尾スラッシュ付き）。
  static String canonicalItemRakutenUrl({
    required String shopCode,
    required String itemPathSegment,
  }) {
    final s = shopCode.trim();
    final i = itemPathSegment.trim();
    return 'https://item.rakuten.co.jp/$s/$i/';
  }

  /// `hb.afl.rakuten.co.jp` 等の `pc=` クエリから item.rakuten URL を取り出す。
  static String? decodeAffiliatePcTargetUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final u = Uri.tryParse(t);
    if (u == null || !u.hasAuthority) return null;
    if (!CatalogProductKeys.isAffiliateRedirectUrl(t)) return null;
    final pc = u.queryParameters['pc'] ?? u.queryParameters['PC'];
    if (pc == null || pc.trim().isEmpty) return null;
    try {
      return _fullyUrlDecodeChain(pc.trim());
    } catch (_) {
      return null;
    }
  }

  /// 入力 URL を `item.rakuten.co.jp/{shop}/{item}/` 形式へ正規化する（affiliate 対応）。
  static String? resolveToCanonicalItemRakutenUrl(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return null;
    final affiliateTarget = decodeAffiliatePcTargetUrl(t);
    if (affiliateTarget != null && affiliateTarget.trim().isNotEmpty) {
      t = affiliateTarget.trim();
    }
    final parsed = RakutenItemUrlParser.tryParse(t);
    if (parsed != null) return parsed.rakutenUrl;
    final u = Uri.tryParse(t);
    if (u == null || !u.hasAuthority) return null;
    if (!u.host.toLowerCase().contains('item.rakuten.co.jp')) return null;
    final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length < 2) return null;
    return canonicalItemRakutenUrl(
      shopCode: segs[0],
      itemPathSegment: segs[1],
    );
  }

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
}
