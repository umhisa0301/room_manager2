import '../models/rakuten_managed_product.dart';
import '../services/rakuten_item_url_parser.dart';
import 'catalog_product_keys.dart';
import 'rakuten_ichiba_url_parse.dart';
import 'room_rakuten_url_normalize.dart';

/// ROOM 取り込み upsert 用の同一商品照合結果。
final class RoomImportProductIdentityMatch {
  const RoomImportProductIdentityMatch({
    required this.matchType,
    required this.matchedKey,
  });

  /// ヒットした照合種別（ログ・テスト用）。
  final String matchType;

  /// 交差した identity key（先頭1件）。
  final String matchedKey;
}

/// ROOM 取り込み時の同一商品判定（単一キーに依存しない）。
abstract final class RoomImportProductIdentity {
  static String _norm(String raw) => raw.trim().toLowerCase();

  static void _add(Set<String> out, String? raw) {
    final t = _norm(raw ?? '');
    if (t.isNotEmpty) out.add(t);
  }

  static void _addProductIdKeys(Set<String> out, String raw, {String shopCode = ''}) {
    final t = raw.trim();
    if (t.isEmpty) return;
    _add(out, t);
    final normalized = CatalogProductKeys.normalizeProductId(t);
    if (normalized != null) {
      _add(out, normalized);
    }
    final colon = t.indexOf(':');
    if (colon < 0) {
      final shop = shopCode.trim();
      if (shop.isNotEmpty) {
        _add(out, '$shop:$t');
      }
    }
  }

  static void _addParsedUrlKeys(Set<String> out, String rawUrl) {
    final canonical = RoomRakutenUrlNormalize.resolveToCanonicalItemRakutenUrl(rawUrl);
    if (canonical != null) {
      _add(out, CatalogProductKeys.normalizeItemUrl(canonical));
      final parsed = RakutenItemUrlParser.tryParse(canonical);
      if (parsed != null) {
        _add(out, parsed.compositeProductId);
        _add(out, CatalogProductKeys.shopItemAlias(
          parsed.shopCode,
          parsed.itemPathSegment,
        ));
      }
    }
    final norm = CatalogProductKeys.normalizeItemUrl(rawUrl);
    if (norm.isNotEmpty &&
        CatalogProductKeys.canUseUrlForProductIdentity(norm)) {
      _add(out, norm);
    }
    final affiliateTarget =
        RoomRakutenUrlNormalize.decodeAffiliatePcTargetUrl(rawUrl);
    if (affiliateTarget != null) {
      _addParsedUrlKeys(out, affiliateTarget);
    }
  }

  static void _addRoomPageKeys(Set<String> out, String rawRoomUrl) {
    final t = rawRoomUrl.trim();
    if (t.isEmpty) return;
    _add(out, RoomRakutenUrlNormalize.normalizeRoomProductPageKey(t));
    final hints = parseRakutenIchibaUrlHints(t);
    if (hints.itemCode != null) {
      _addProductIdKeys(out, hints.itemCode!);
    }
    if (hints.shopCode != null &&
        hints.itemPath != null &&
        hints.shopCode!.isNotEmpty &&
        hints.itemPath!.isNotEmpty) {
      _add(out, CatalogProductKeys.shopItemAlias(
        hints.shopCode!,
        hints.itemPath!,
      ));
    }
  }

  /// 保存済み [RakutenManagedProduct] の identity key 集合。
  static Set<String> keysForManagedProduct(RakutenManagedProduct row) {
    final out = <String>{};
    final shop = row.shopCode.trim();

    _addProductIdKeys(out, row.productId, shopCode: shop);
    _addProductIdKeys(out, row.roomApiCompositeItemCode, shopCode: shop);

    if (shop.isNotEmpty) {
      final slug = row.roomProductSlug.trim();
      if (slug.isNotEmpty) {
        _add(out, CatalogProductKeys.shopItemAlias(shop, slug));
      }
      final redirectItem = row.roomRedirectItemCode.trim();
      if (redirectItem.isNotEmpty) {
        _add(out, CatalogProductKeys.shopItemAlias(shop, redirectItem));
      }
    }

    _addParsedUrlKeys(out, row.itemUrl);
    _addParsedUrlKeys(out, row.rakutenUrl ?? '');
    _addParsedUrlKeys(out, row.affiliateUrl ?? '');
    _addParsedUrlKeys(out, row.extractedUrl);
    _addRoomPageKeys(out, row.roomUrl);

    final canonicalId = CatalogProductKeys.resolveCanonicalId(
      productId: row.productId,
      itemUrl: row.itemUrl,
    );
    if (canonicalId != null) {
      _add(out, canonicalId);
    }

    return out;
  }

  /// ROOM 取り込み 1 件分の identity key 集合。
  static Set<String> keysForIncomingImport({
    required RakutenItemUrlParseResult parsedItem,
    required String normalizedRoomUrlKey,
    String roomPageUrl = '',
    String? roomPageAffiliateUrl,
    String roomApiCompositeItemCode = '',
    String roomProductSlug = '',
    String roomRedirectShopCode = '',
    String roomRedirectItemCode = '',
  }) {
    final out = <String>{};
    final shop = parsedItem.shopCode.trim().isNotEmpty
        ? parsedItem.shopCode.trim()
        : roomRedirectShopCode.trim();

    _add(out, parsedItem.compositeProductId);
    _addProductIdKeys(out, roomApiCompositeItemCode, shopCode: shop);
    _addParsedUrlKeys(out, parsedItem.rakutenUrl);

    final slug = roomProductSlug.trim().isNotEmpty
        ? roomProductSlug.trim()
        : parsedItem.itemPathSegment.trim();
    if (shop.isNotEmpty && slug.isNotEmpty) {
      _add(out, CatalogProductKeys.shopItemAlias(shop, slug));
    }
    if (shop.isNotEmpty) {
      final redirectItem = roomRedirectItemCode.trim();
      if (redirectItem.isNotEmpty) {
        _add(out, CatalogProductKeys.shopItemAlias(shop, redirectItem));
      }
    }

    _addRoomPageKeys(out, roomPageUrl);
    final roomKey = normalizedRoomUrlKey.trim();
    if (roomKey.isNotEmpty) {
      _add(out, RoomRakutenUrlNormalize.normalizeRoomProductPageKey(roomKey));
    }

    _addParsedUrlKeys(out, roomPageAffiliateUrl ?? '');

    final canonicalId = CatalogProductKeys.resolveCanonicalId(
      productId: roomApiCompositeItemCode.isNotEmpty
          ? roomApiCompositeItemCode
          : parsedItem.compositeProductId,
      itemUrl: parsedItem.rakutenUrl,
    );
    if (canonicalId != null) {
      _add(out, canonicalId);
    }

    return out;
  }

  static String? _shopFromProductId(String raw) {
    final normalized = CatalogProductKeys.normalizeProductId(raw);
    if (normalized == null) return null;
    final idx = normalized.indexOf(':');
    if (idx <= 0) return null;
    return normalized.substring(0, idx);
  }

  static String? shopCodeForManagedProduct(RakutenManagedProduct row) {
    final shop = row.shopCode.trim();
    if (shop.isNotEmpty) return shop;
    return _shopFromProductId(row.productId) ??
        _shopFromProductId(row.roomApiCompositeItemCode);
  }

  static String? shopCodeForIncomingImport({
    required RakutenItemUrlParseResult parsedItem,
    String roomRedirectShopCode = '',
    String roomApiCompositeItemCode = '',
  }) {
    final shop = parsedItem.shopCode.trim();
    if (shop.isNotEmpty) return shop;
    final redirectShop = roomRedirectShopCode.trim();
    if (redirectShop.isNotEmpty) return redirectShop;
    return _shopFromProductId(roomApiCompositeItemCode);
  }

  static bool _shopsCompatible(String? a, String? b) {
    final left = (a ?? '').trim().toLowerCase();
    final right = (b ?? '').trim().toLowerCase();
    if (left.isEmpty || right.isEmpty) return true;
    return left == right;
  }

  static String _matchTypeForKey(String key) {
    if (key.startsWith('http')) return 'normalizedItemUrl';
    if (key.startsWith('url:')) return 'canonicalUrl';
    if (key.contains('room.rakuten.co.jp')) return 'normalizedRoomUrl';
    if (key.contains(':')) return 'shopItemOrProductId';
    return 'identityKey';
  }

  /// 2 つの key 集合が同一商品か（shop 不一致時は false）。
  static RoomImportProductIdentityMatch? intersectMatch({
    required Set<String> incomingKeys,
    required Set<String> existingKeys,
    String? incomingShop,
    String? existingShop,
  }) {
    if (incomingKeys.isEmpty || existingKeys.isEmpty) return null;
    if (!_shopsCompatible(incomingShop, existingShop)) return null;

    for (final key in incomingKeys) {
      if (existingKeys.contains(key)) {
        return RoomImportProductIdentityMatch(
          matchType: _matchTypeForKey(key),
          matchedKey: key,
        );
      }
    }
    return null;
  }

  /// [list] から incoming と同一商品の行を探す（見つかれば index 付きで返す）。
  static ({RakutenManagedProduct row, int index, RoomImportProductIdentityMatch match})?
  findExistingRow({
    required List<RakutenManagedProduct> list,
    required Set<String> incomingKeys,
    String? incomingShop,
  }) {
    for (var i = 0; i < list.length; i++) {
      final row = list[i];
      final existingKeys = keysForManagedProduct(row);
      final hit = intersectMatch(
        incomingKeys: incomingKeys,
        existingKeys: existingKeys,
        incomingShop: incomingShop,
        existingShop: shopCodeForManagedProduct(row),
      );
      if (hit != null) {
        return (row: row, index: i, match: hit);
      }
    }
    return null;
  }
}
