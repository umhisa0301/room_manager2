import 'package:flutter/foundation.dart';

import '../config/debug_log_flags.dart';
import '../config/product_catalog_config.dart';
import '../models/catalog_product.dart';
import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../repository/product_catalog_repository.dart';
import '../services/rakuten_item_url_parser.dart';
import '../services/room_import_metadata_enrichment.dart';
import 'app_debug_log.dart';
import 'catalog_product_keys.dart';
import 'room_import_product_image.dart';
import 'room_import_safe_merge.dart';

/// カタログ照合の一致種別（優先度順で最初の一致のみ採用）。
enum RoomCatalogMatchKind {
  none,
  productId,
  normalizedUrl,
  shopItem,
  roomPageKey,
}

/// 照合結果。
class RoomCatalogLookupResult {
  const RoomCatalogLookupResult({
    required this.product,
    required this.matchKind,
    required this.skippedStale,
    required this.skippedLowTrust,
    required this.skippedUnsafe,
  });

  const RoomCatalogLookupResult.miss({
    this.skippedStale = false,
    this.skippedLowTrust = false,
    this.skippedUnsafe = false,
  }) : product = null,
       matchKind = RoomCatalogMatchKind.none;

  final CatalogProduct? product;
  final RoomCatalogMatchKind matchKind;
  final bool skippedStale;
  final bool skippedLowTrust;
  final bool skippedUnsafe;

  bool get matched => product != null;
}

/// バッチ照合・補完の集計（監査サマリ用）。
class RoomCatalogLookupSummary {
  int checked = 0;
  int matchedByProductId = 0;
  int matchedByUrl = 0;
  int matchedByShopItem = 0;
  int matchedByRoomPageKey = 0;
  int unmatched = 0;
  int usedForPrice = 0;
  int usedForImage = 0;
  int usedForShop = 0;
  int usedForGenre = 0;
  int skippedStale = 0;
  int skippedLowTrust = 0;
  int skippedUnsafeImage = 0;

  void recordLookup(RoomCatalogLookupResult result) {
    checked++;
    if (!result.matched) {
      unmatched++;
      if (result.skippedStale) skippedStale++;
      if (result.skippedLowTrust) skippedLowTrust++;
      if (result.skippedUnsafe) skippedUnsafeImage++;
      return;
    }
    switch (result.matchKind) {
      case RoomCatalogMatchKind.productId:
        matchedByProductId++;
      case RoomCatalogMatchKind.normalizedUrl:
        matchedByUrl++;
      case RoomCatalogMatchKind.shopItem:
        matchedByShopItem++;
      case RoomCatalogMatchKind.roomPageKey:
        matchedByRoomPageKey++;
      case RoomCatalogMatchKind.none:
        unmatched++;
    }
  }

  /// バッチ開始時の入口ログ（lookup 実行有無の切り分け用）。
  static void logLookupEntry({
    required bool enabled,
    required bool repositoryPresent,
    required int targetCount,
    required String source,
  }) {
    if (!kDebugMode) return;
    if (!DebugLogFlags.kCatalogAuditLogsEnabled &&
        !DebugLogFlags.kRoomAuditLogsEnabled) {
      return;
    }
    final line =
        '[ROOM_CATALOG_LOOKUP_ENTRY] enabled=$enabled '
        'repositoryPresent=$repositoryPresent targetCount=$targetCount '
        'source=$source';
    if (DebugLogFlags.kCatalogAuditLogsEnabled) {
      catalogAuditLog(line);
    } else {
      roomAuditLog(line);
    }
  }

  void logSummary({String reason = 'completed'}) {
    if (!kDebugMode) return;
    if (!DebugLogFlags.kCatalogAuditLogsEnabled &&
        !DebugLogFlags.kRoomAuditLogsEnabled) {
      return;
    }
    final line =
        '[ROOM_CATALOG_LOOKUP_SUMMARY] checked=$checked '
        'matchedByProductId=$matchedByProductId '
        'matchedByUrl=$matchedByUrl '
        'matchedByShopItem=$matchedByShopItem '
        'matchedByRoomPageKey=$matchedByRoomPageKey '
        'unmatched=$unmatched '
        'usedForPrice=$usedForPrice usedForImage=$usedForImage '
        'usedForShop=$usedForShop usedForGenre=$usedForGenre '
        'skippedStale=$skippedStale skippedLowTrust=$skippedLowTrust '
        'skippedUnsafeImage=$skippedUnsafeImage reason=$reason';
    if (DebugLogFlags.kCatalogAuditLogsEnabled) {
      catalogAuditLog(line);
    } else {
      roomAuditLog(line);
    }
  }
}

/// ROOM 同期・メタ補完向けの ProductCatalog 参照（読み取り補助）。
abstract final class RoomCatalogEnrichment {
  static bool get enabled => ProductCatalogConfig.kProductCatalogEnabled;

  /// ROOM 同期ループ向け（最小キーのみ。商品名照合はしない）。
  static RoomCatalogLookupResult lookupKeys({
    required ProductCatalogRepository repository,
    String productId = '',
    String roomApiCompositeItemCode = '',
    String itemUrl = '',
    String affiliateUrl = '',
    String rakutenUrl = '',
    String roomPageUrl = '',
    String shopCode = '',
    String itemPathSegment = '',
    DateTime? now,
  }) {
    return lookupProduct(
      repository: repository,
      row: _syntheticManagedRow(
        productId: productId,
        roomApiCompositeItemCode: roomApiCompositeItemCode,
        itemUrl: itemUrl,
        affiliateUrl: affiliateUrl,
        rakutenUrl: rakutenUrl,
        roomPageUrl: roomPageUrl,
        shopCode: shopCode,
      ),
      shopCodeHint: shopCode,
      itemPathSegmentHint: itemPathSegment,
      now: now,
    );
  }

  /// 厳密照合のみ（商品名類似は使わない）。
  static RoomCatalogLookupResult lookupProduct({
    required ProductCatalogRepository repository,
    required RakutenManagedProduct row,
    String? shopCodeHint,
    String? itemPathSegmentHint,
    DateTime? now,
  }) {
    final candidates = <_LookupCandidate>[];

    final composite = CatalogProductKeys.normalizeProductId(row.productId) ??
        CatalogProductKeys.normalizeProductId(row.roomApiCompositeItemCode);
    if (composite != null) {
      candidates.add(
        _LookupCandidate(RoomCatalogMatchKind.productId, composite),
      );
    }

    final urlKeys = <String>{};
    for (final raw in <String>[
      row.itemUrl,
      row.affiliateUrl ?? '',
      row.rakutenUrl ?? '',
    ]) {
      final norm = CatalogProductKeys.normalizeItemUrl(raw);
      if (norm.isNotEmpty) urlKeys.add(norm);
    }
    for (final norm in urlKeys) {
      candidates.add(
        _LookupCandidate(RoomCatalogMatchKind.normalizedUrl, norm),
      );
    }

    final shop = (shopCodeHint ?? row.shopCode.trim()).trim();
    var seg = (itemPathSegmentHint ?? '').trim();
    if (seg.isEmpty) {
      final parsed = RakutenItemUrlParser.tryParse(row.itemUrl);
      seg = parsed?.itemPathSegment.trim() ?? '';
    }
    if (seg.isEmpty) {
      seg = row.roomRedirectItemCode.trim();
    }
    final shopItem = CatalogProductKeys.shopItemAlias(shop, seg);
    if (shopItem != null) {
      candidates.add(
        _LookupCandidate(RoomCatalogMatchKind.shopItem, shopItem),
      );
    }

    final roomUrl = row.roomUrl.trim();
    if (roomUrl.isNotEmpty) {
      final roomKey = CatalogProductKeys.roomPageKey(roomUrl);
      if (roomKey.isNotEmpty) {
        candidates.add(
          _LookupCandidate(RoomCatalogMatchKind.roomPageKey, roomKey),
        );
      }
    }

    var sawStale = false;
    var sawLowTrust = false;
    var sawUnsafe = false;

    for (final c in candidates) {
      final product = repository.findByAlias(c.alias, touch: false);
      if (product == null) continue;

      if (repository.isStale(product, now: now)) {
        sawStale = true;
        verboseItemLog(
          '[ROOM_CATALOG_LOOKUP] productId=${row.productId} match=${c.kind.name} '
          'skipped=stale canonicalId=${product.canonicalId}',
        );
        continue;
      }
      if (product.sourceTrust == CatalogProductSourceTrust.low) {
        sawLowTrust = true;
        verboseItemLog(
          '[ROOM_CATALOG_LOOKUP] productId=${row.productId} match=${c.kind.name} '
          'skipped=lowTrust canonicalId=${product.canonicalId}',
        );
        continue;
      }
      if (!product.qualityStatus.safe) {
        sawUnsafe = true;
        verboseItemLog(
          '[ROOM_CATALOG_LOOKUP] productId=${row.productId} match=${c.kind.name} '
          'skipped=unsafe canonicalId=${product.canonicalId}',
        );
        continue;
      }

      verboseItemLog(
        '[ROOM_CATALOG_LOOKUP] productId=${row.productId} match=${c.kind.name} '
        'canonicalId=${product.canonicalId} trust=${product.sourceTrust.name}',
      );
      return RoomCatalogLookupResult(
        product: product,
        matchKind: c.kind,
        skippedStale: sawStale,
        skippedLowTrust: sawLowTrust,
        skippedUnsafe: sawUnsafe,
      );
    }

    return RoomCatalogLookupResult.miss(
      skippedStale: sawStale,
      skippedLowTrust: sawLowTrust,
      skippedUnsafe: sawUnsafe,
    );
  }

  /// 即時画像取得 API の代替候補（安全な imageUrl のみ）。
  static RakutenSearchItem? buildImmediateImagePatch({
    required RakutenManagedProduct row,
    required CatalogProduct catalog,
  }) {
    if (!_canUseCatalogImage(row: row, catalog: catalog)) return null;
    return _basePatch(row).copyWithImage(catalog.imageUrl);
  }

  /// ROOM 同期の新規取り込み向け（既存画像なし前提）。
  static RakutenSearchItem? buildImmediateImagePatchForNewImport({
    required CatalogProduct catalog,
    required String productId,
  }) {
    if (catalog.sourceTrust == CatalogProductSourceTrust.low) return null;
    if (!catalog.qualityStatus.hasImage) return null;
    if (!RoomImportProductImage.isSafeProductImageUrl(catalog.imageUrl)) {
      return null;
    }
    final pid = productId.trim();
    if (pid.isEmpty) return null;
    return RakutenSearchItem(
      productId: pid,
      itemName: '',
      itemPrice: catalog.itemPrice > 0 ? catalog.itemPrice : 0,
      itemUrl: catalog.itemUrl,
      affiliateUrl: catalog.affiliateUrl,
      imageUrl: catalog.imageUrl,
      shopName: '',
      reviewCount: 0,
      reviewAverage: 0,
      shopCode: catalog.shopCode,
      shopUrl: '',
      genreId: '',
      genreName: '',
    );
  }

  /// メタ補完 API の代替候補（空欄のみ。商品名は補完しない）。
  static RakutenSearchItem? buildMetadataEnrichmentPatch({
    required RakutenManagedProduct row,
    required CatalogProduct catalog,
    RoomCatalogLookupSummary? summary,
  }) {
    final flags = RoomImportMetadataEnrichmentService.needFlagsForProduct(row);
    var any = false;
    var patch = _basePatch(row);

    if (flags.needsPrice && _canUseCatalogPrice(row: row, catalog: catalog)) {
      patch = patch.copyWithPrice(catalog.itemPrice);
      any = true;
      summary?.usedForPrice++;
    }
    if (flags.needsImage && _canUseCatalogImage(row: row, catalog: catalog)) {
      patch = patch.copyWithImage(catalog.imageUrl);
      any = true;
      summary?.usedForImage++;
    }
    if (flags.needsShopName &&
        _canUseCatalogShopName(row: row, catalog: catalog)) {
      patch = patch.copyWithShop(
        shopName: catalog.shopName,
        shopCode: catalog.shopCode,
        shopUrl: catalog.shopUrl,
      );
      any = true;
      summary?.usedForShop++;
    }
    if (flags.needsGenre && _canUseCatalogGenre(row: row, catalog: catalog)) {
      patch = patch.copyWithGenre(
        genreId: catalog.genreId,
        genreName: catalog.genreName,
      );
      any = true;
      summary?.usedForGenre++;
    }

    if (!_patchMeetsApiEnrichmentNeeds(flags, patch)) {
      return null;
    }
    if (!any) return null;
    return patch;
  }

  /// カタログパッチで API 補完キュー（shopName/genre）が不要になるか。
  static bool patchCoversApiEnrichmentNeeds(
    RakutenManagedProduct row,
    RakutenSearchItem patch,
  ) {
    final flags = RoomImportMetadataEnrichmentService.needFlagsForProduct(row);
    return _patchMeetsApiEnrichmentNeeds(flags, patch);
  }

  static bool _patchMeetsApiEnrichmentNeeds(
    RoomImportEnrichmentNeedFlags flags,
    RakutenSearchItem patch,
  ) {
    if (flags.needsShopName) {
      final s = patch.shopName.trim();
      if (s.isEmpty || s == 'ショップ名不明' || s == 'ショップ未設定') {
        return false;
      }
    }
    if (flags.needsGenre) {
      final gn = patch.genreName.trim();
      final gid = patch.genreId.trim();
      if (gn.isEmpty || gn == 'ジャンル未設定') {
        if (gid.isEmpty) return false;
      }
    }
    return true;
  }

  static bool _canUseCatalogPrice({
    required RakutenManagedProduct row,
    required CatalogProduct catalog,
  }) {
    if (catalog.sourceTrust == CatalogProductSourceTrust.low) return false;
    if (catalog.itemPrice <= 0) return false;
    return row.itemPrice <= 0;
  }

  static bool _canUseCatalogImage({
    required RakutenManagedProduct row,
    required CatalogProduct catalog,
  }) {
    if (catalog.sourceTrust == CatalogProductSourceTrust.low) return false;
    if (!catalog.qualityStatus.hasImage) return false;
    if (!RoomImportProductImage.isSafeProductImageUrl(catalog.imageUrl)) {
      return false;
    }
    final existing = row.imageUrl.trim();
    if (existing.isNotEmpty &&
        RoomImportProductImage.isSafeProductImageUrl(existing) &&
        !RoomImportProductImage.isSuspiciousStoredProductImage(existing)) {
      return false;
    }
    return RoomImportMetadataEnrichmentService.needFlagsForProduct(row)
        .needsImage;
  }

  static bool _canUseCatalogShopName({
    required RakutenManagedProduct row,
    required CatalogProduct catalog,
  }) {
    if (catalog.sourceTrust == CatalogProductSourceTrust.low) return false;
    final name = catalog.shopName.trim();
    if (!RoomImportSafeMerge.isPresentString(name)) return false;
    if (name == 'ショップ名不明' || name == 'ショップ未設定') return false;
    if (row.shopCode.trim().isNotEmpty && name == row.shopCode.trim()) {
      return false;
    }
    return RoomImportMetadataEnrichmentService.needFlagsForProduct(row)
        .needsShopName;
  }

  static bool _canUseCatalogGenre({
    required RakutenManagedProduct row,
    required CatalogProduct catalog,
  }) {
    if (catalog.sourceTrust == CatalogProductSourceTrust.low) return false;
    final gn = catalog.genreName.trim();
    final gid = catalog.genreId.trim();
    if (gn.isEmpty && gid.isEmpty) return false;
    if (gn == 'ジャンル未設定') return false;
    return RoomImportMetadataEnrichmentService.needFlagsForProduct(row)
        .needsGenre;
  }

  static RakutenManagedProduct _syntheticManagedRow({
    String productId = '',
    String roomApiCompositeItemCode = '',
    String itemUrl = '',
    String affiliateUrl = '',
    String rakutenUrl = '',
    String roomPageUrl = '',
    String shopCode = '',
    int itemPrice = 0,
    String imageUrl = '',
  }) {
    final pid = productId.trim().isNotEmpty
        ? productId.trim()
        : (roomApiCompositeItemCode.trim().isNotEmpty
            ? roomApiCompositeItemCode.trim()
            : '');
    final t = DateTime(2000);
    return RakutenManagedProduct(
      productId: pid,
      itemName: '',
      itemPrice: itemPrice,
      itemUrl: itemUrl,
      affiliateUrl: affiliateUrl.isEmpty ? null : affiliateUrl,
      rakutenUrl: rakutenUrl.isEmpty ? null : rakutenUrl,
      imageUrl: imageUrl,
      shopName: '',
      shopCode: shopCode,
      shopUrl: '',
      genreId: '',
      status: RakutenManagedProductStatus.done,
      createdAt: t,
      updatedAt: t,
      addedAt: t,
      extractedUrl: '',
      extractionStatus: RakutenUrlExtractionStatus.notStarted,
      extractionErrorMessage: '',
      roomUrl: roomPageUrl,
      coredActivitySource: RakutenCoredActivitySource.roomImport,
      roomApiCompositeItemCode: roomApiCompositeItemCode,
    );
  }

  static RakutenSearchItem _basePatch(RakutenManagedProduct row) {
    return RakutenSearchItem(
      productId: row.productId,
      itemName: '',
      itemPrice: 0,
      itemUrl: '',
      affiliateUrl: '',
      imageUrl: '',
      shopName: '',
      reviewCount: 0,
      reviewAverage: 0,
      shopCode: '',
      shopUrl: '',
      genreId: '',
      genreName: '',
    );
  }
}

class _LookupCandidate {
  const _LookupCandidate(this.kind, this.alias);
  final RoomCatalogMatchKind kind;
  final String alias;
}

extension on RakutenSearchItem {
  RakutenSearchItem copyWithImage(String imageUrl) {
    return RakutenSearchItem(
      productId: productId,
      itemName: itemName,
      itemPrice: itemPrice,
      itemUrl: itemUrl,
      affiliateUrl: affiliateUrl,
      imageUrl: imageUrl,
      shopName: shopName,
      reviewCount: reviewCount,
      reviewAverage: reviewAverage,
      shopCode: shopCode,
      shopUrl: shopUrl,
      genreId: genreId,
      genreName: genreName,
    );
  }

  RakutenSearchItem copyWithPrice(int itemPrice) {
    return RakutenSearchItem(
      productId: productId,
      itemName: itemName,
      itemPrice: itemPrice,
      itemUrl: itemUrl,
      affiliateUrl: affiliateUrl,
      imageUrl: imageUrl,
      shopName: shopName,
      reviewCount: reviewCount,
      reviewAverage: reviewAverage,
      shopCode: shopCode,
      shopUrl: shopUrl,
      genreId: genreId,
      genreName: genreName,
    );
  }

  RakutenSearchItem copyWithShop({
    required String shopName,
    required String shopCode,
    required String shopUrl,
  }) {
    return RakutenSearchItem(
      productId: productId,
      itemName: itemName,
      itemPrice: itemPrice,
      itemUrl: itemUrl,
      affiliateUrl: affiliateUrl,
      imageUrl: imageUrl,
      shopName: shopName,
      reviewCount: reviewCount,
      reviewAverage: reviewAverage,
      shopCode: shopCode,
      shopUrl: shopUrl,
      genreId: genreId,
      genreName: genreName,
    );
  }

  RakutenSearchItem copyWithGenre({
    required String genreId,
    required String genreName,
  }) {
    return RakutenSearchItem(
      productId: productId,
      itemName: itemName,
      itemPrice: itemPrice,
      itemUrl: itemUrl,
      affiliateUrl: affiliateUrl,
      imageUrl: imageUrl,
      shopName: shopName,
      reviewCount: reviewCount,
      reviewAverage: reviewAverage,
      shopCode: shopCode,
      shopUrl: shopUrl,
      genreId: genreId,
      genreName: genreName,
    );
  }
}
