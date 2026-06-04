import '../services/rakuten_item_url_parser.dart';
import 'room_rakuten_url_normalize.dart';

/// 共通商品カタログの ID・alias 生成。
abstract final class CatalogProductKeys {
  /// productId / itemCode（`shop:item`）の正規化。無効なら null。
  static String? normalizeProductId(String? raw) {
    return normalizeItemCode(raw);
  }

  /// itemCode の正規化（[normalizeProductId] と同一）。
  static String? normalizeItemCode(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return null;
    final colon = t.indexOf(':');
    if (colon <= 0 || colon >= t.length - 1) return null;
    final shop = t.substring(0, colon).trim();
    final item = t.substring(colon + 1).trim();
    if (shop.isEmpty || item.isEmpty) return null;
    return '$shop:$item';
  }

  /// 商品ページ URL の正規化（item.rakuten.co.jp は parser 優先）。
  static String normalizeItemUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final parsed = RakutenItemUrlParser.tryParse(t);
    if (parsed != null) return parsed.rakutenUrl;
    final u = Uri.tryParse(t);
    if (u == null || !u.hasAuthority) return '';
    var path = u.path;
    if (!path.endsWith('/') && path.isNotEmpty) {
      path = '$path/';
    }
    return '${u.scheme}://${u.host.toLowerCase()}$path';
  }

  /// alias / synthetic key 用の normalized item URL。
  static String normalizedItemUrlKey(String rawUrl) {
    return normalizeItemUrl(rawUrl);
  }

  /// `shopCode:itemPathSegment` 形式の alias。
  static String? shopItemAlias(String shopCode, String itemPathSegment) {
    final shop = shopCode.trim();
    final seg = itemPathSegment.trim();
    if (shop.isEmpty || seg.isEmpty) return null;
    return '$shop:$seg';
  }

  /// ROOM 商品ページ URL の alias（クエリ除去・ホスト小文字）。
  static String roomPageKey(String rawRoomUrl) {
    return RoomRakutenUrlNormalize.normalizeRoomProductPageKey(rawRoomUrl);
  }

  /// canonicalId の決定。
  ///
  /// 1. 有効な productId / itemCode
  /// 2. normalizedItemUrl から `url:<url>`
  /// 3. 決定不可なら null
  static String? resolveCanonicalId({
    String? productId,
    String? itemCode,
    String? itemUrl,
    String? normalizedItemUrl,
  }) {
    final id = normalizeProductId(productId) ?? normalizeItemCode(itemCode);
    if (id != null) return id;

    final normUrl = (normalizedItemUrl ?? '').trim().isNotEmpty
        ? normalizedItemUrl!.trim()
        : normalizeItemUrl(itemUrl ?? '');
    if (normUrl.isNotEmpty) return 'url:$normUrl';
    return null;
  }

  /// productId / URL 由来の alias が [canonicalId] と矛盾しないか。
  static bool aliasConsistentWithCanonicalId({
    required String alias,
    required String canonicalId,
    String? productId,
    String? itemCode,
  }) {
    final cid = canonicalId.trim();
    final a = alias.trim();
    if (a.isEmpty) return false;
    if (cid.isNotEmpty && a == cid) return true;
    final pid = normalizeProductId(productId) ?? normalizeItemCode(itemCode);
    if (pid != null && a == pid) return true;
    if (cid.isEmpty && pid == null) return true;
    return false;
  }

  /// 別 canonicalId 同士が同一商品としてマージ可能か（URL / productId 一致のみ）。
  static bool catalogProductsShareIdentity({
    required String existingCanonicalId,
    required String existingProductId,
    required String existingNormalizedItemUrl,
    required String incomingCanonicalId,
    required String incomingProductId,
    required String incomingNormalizedItemUrl,
  }) {
    final inCid = incomingCanonicalId.trim();
    final exCid = existingCanonicalId.trim();
    if (inCid.isNotEmpty && inCid == exCid) return true;

    final inPid = normalizeProductId(incomingProductId);
    final exPid = normalizeProductId(existingProductId);
    if (inPid != null && exPid != null) {
      if (inPid == exPid) return true;
      final inUrl = incomingNormalizedItemUrl.trim();
      final exUrl = existingNormalizedItemUrl.trim();
      if (inUrl.isNotEmpty && exUrl.isNotEmpty && inUrl == exUrl) {
        return true;
      }
      return false;
    }

    final inUrl = incomingNormalizedItemUrl.trim();
    final exUrl = existingNormalizedItemUrl.trim();
    if (inUrl.isNotEmpty && exUrl.isNotEmpty && inUrl == exUrl) {
      return true;
    }
    return false;
  }

  /// ルックアップ用 alias 一覧（canonicalId 自身も含む）。
  ///
  /// URL パース由来の `shop:segment` は productId / canonicalId と一致するときだけ登録する
  /// （別 itemCode への誤マージ防止）。
  static List<String> buildAliases({
    required String canonicalId,
    String? productId,
    String? itemCode,
    String? itemUrl,
    String? normalizedItemUrl,
    String? shopCode,
    String? itemPathSegment,
    String? roomPageUrl,
  }) {
    final cid = canonicalId.trim();
    final out = <String>{};
    if (cid.isNotEmpty) out.add(cid);

    final normUrl = (normalizedItemUrl ?? '').trim().isNotEmpty
        ? normalizedItemUrl!.trim()
        : normalizeItemUrl(itemUrl ?? '');
    if (normUrl.isNotEmpty) out.add(normUrl);

    final pid =
        normalizeProductId(productId) ?? normalizeItemCode(itemCode);
    if (pid != null) out.add(pid);

    if (shopCode != null && itemPathSegment != null) {
      final alias = shopItemAlias(shopCode, itemPathSegment);
      if (alias != null &&
          aliasConsistentWithCanonicalId(
            alias: alias,
            canonicalId: cid,
            productId: productId,
            itemCode: itemCode,
          )) {
        out.add(alias);
      }
    }

    final parsed = RakutenItemUrlParser.tryParse(itemUrl ?? '');
    if (parsed != null) {
      final composite = parsed.compositeProductId;
      if (aliasConsistentWithCanonicalId(
        alias: composite,
        canonicalId: cid,
        productId: productId,
        itemCode: itemCode,
      )) {
        out.add(composite);
      }
    }

    if (roomPageUrl != null &&
        RoomRakutenUrlNormalize.isLikelyRoomProductPageUrl(roomPageUrl)) {
      final key = roomPageKey(roomPageUrl);
      if (key.isNotEmpty) out.add(key);
    }

    return out.toList(growable: false);
  }

  static List<String> mergeAliases(List<String> a, List<String> b) {
    return {...a, ...b}.toList(growable: false);
  }
}
