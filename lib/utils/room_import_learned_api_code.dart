import '../models/rakuten_search_item.dart';
import 'rakuten_ichiba_url_parse.dart';

/// keyword 補完などで API 応答から `shop:数字` 形式を逆学習する。
abstract final class RoomImportLearnedApiCode {
  /// 戻り値: `(composite, source)`。取れなければ null。
  static (String composite, String source)? tryParseFromSearchItem(
    RakutenSearchItem api,
  ) {
    final pid = api.productId.trim();
    if (pid.isNotEmpty && rakutenIchibaUrlLooksLikeApiItemCode(pid)) {
      return (pid, 'apiItemCode');
    }

    for (final raw in [api.affiliateUrl, api.itemUrl]) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      final hints = parseRakutenIchibaUrlHints(t);
      final ic = hints.itemCode?.trim() ?? '';
      if (ic.isNotEmpty && rakutenIchibaUrlLooksLikeApiItemCode(ic)) {
        return (ic, 'affiliateUrl');
      }
    }

    final m = _tryMobilePathComposite(api.affiliateUrl);
    if (m != null) return m;
    final m2 = _tryMobilePathComposite(api.itemUrl);
    if (m2 != null) return m2;

    final fromQueryM = _tryCompositeFromAffiliateMParam(api.affiliateUrl);
    if (fromQueryM != null) return fromQueryM;

    return null;
  }

  static (String, String)? _tryMobilePathComposite(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    try {
      final u = Uri.parse(t);
      final host = u.host.toLowerCase();
      if (!host.contains('m.rakuten.co.jp')) return null;
      final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.length < 3) return null;
      final shop = segs[0].trim();
      if (shop.isEmpty) return null;
      var i = 1;
      if (segs[i].toLowerCase() == 'i') i++;
      if (i >= segs.length) return null;
      final item = segs[i].trim();
      if (item.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(item)) return null;
      final c = '$shop:$item';
      if (!rakutenIchibaUrlLooksLikeApiItemCode(c)) return null;
      return (c, 'affiliateMobileUrl');
    } catch (_) {
      return null;
    }
  }

  static (String, String)? _tryCompositeFromAffiliateMParam(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    try {
      final u = Uri.parse(t);
      final mRaw = u.queryParameters['m'] ?? u.queryParameters['M'];
      if (mRaw == null || mRaw.trim().isEmpty) return null;
      final decoded = Uri.decodeComponent(mRaw.trim());
      final inner = _tryMobilePathComposite(decoded);
      if (inner != null) {
        return (inner.$1, 'affiliateUrlMParam');
      }
      final hints = parseRakutenIchibaUrlHints(decoded);
      final ic = hints.itemCode?.trim() ?? '';
      if (ic.isNotEmpty && rakutenIchibaUrlLooksLikeApiItemCode(ic)) {
        return (ic, 'affiliateUrlMParam');
      }
    } catch (_) {}
    return null;
  }
}
