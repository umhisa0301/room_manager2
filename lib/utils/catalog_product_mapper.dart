import 'package:flutter/foundation.dart';

import '../config/debug_log_flags.dart';
import '../config/product_catalog_config.dart';
import '../models/catalog_product.dart';
import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../repository/product_catalog_repository.dart';
import '../services/genre_master_service.dart';
import '../services/rakuten_item_url_parser.dart';
import 'app_debug_log.dart';
import 'catalog_product_keys.dart';
import 'product_catalog_audit.dart';
import 'product_catalog_upsert_timing.dart';

/// 保存前に genreId から genreName を補完（API が genreName を返さない場合向け）。
@visibleForTesting
String resolveCatalogGenreName({
  required String genreId,
  required String genreName,
}) {
  final existing = genreName.trim();
  if (existing.isNotEmpty && existing.toLowerCase() != 'unknown') {
    return existing;
  }
  final gid = genreId.trim();
  if (gid.isEmpty) return existing;
  final fromMaster = GenreMasterService.instance.getGenreNameById(gid);
  if (fromMaster == null) return existing;
  final resolved = fromMaster.trim();
  if (resolved.isEmpty || resolved == gid) return existing;
  return resolved;
}

/// [RakutenSearchItem] から [CatalogProduct] を生成。
CatalogProduct catalogProductFromSearchItem(
  RakutenSearchItem item, {
  CatalogProductSource source = CatalogProductSource.search,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.high,
  DateTime? now,
  String? roomPageUrl,
}) {
  final t = now ?? DateTime.now();
  final normalizedUrl = CatalogProductKeys.normalizeItemUrl(item.itemUrl);
  final parsed = RakutenItemUrlParser.tryParse(item.itemUrl);
  final canonicalId = CatalogProductKeys.resolveCanonicalId(
    productId: item.productId,
    itemUrl: item.itemUrl,
    normalizedItemUrl: normalizedUrl,
  );
  final aliases = CatalogProductKeys.buildAliases(
    canonicalId: canonicalId ?? '',
    productId: item.productId,
    itemUrl: item.itemUrl,
    normalizedItemUrl: normalizedUrl,
    shopCode: parsed?.shopCode ?? item.shopCode,
    itemPathSegment: parsed?.itemPathSegment,
    roomPageUrl: roomPageUrl,
  );

  final product = CatalogProduct(
    canonicalId: canonicalId ?? '',
    productId: item.productId,
    itemCode: item.productId,
    itemUrl: item.itemUrl,
    normalizedItemUrl: normalizedUrl,
    itemName: item.itemName,
    itemPrice: item.itemPrice,
    imageUrl: item.imageUrl,
    shopCode: item.shopCode,
    shopName: item.shopName,
    shopUrl: item.shopUrl,
    genreId: item.genreId,
    genreName: resolveCatalogGenreName(
      genreId: item.genreId,
      genreName: item.genreName,
    ),
    reviewAverage: item.reviewAverage,
    reviewCount: item.reviewCount,
    affiliateUrl: item.affiliateUrl,
    itemCaption: '',
    source: source,
    sourceTrust: sourceTrust,
    fetchedAt: t,
    lastValidatedAt: t,
    lastAccessedAt: t,
    qualityStatus: const CatalogProductQualityStatus(
      hasImage: false,
      hasPrice: false,
      hasValidUrl: false,
      safe: true,
    ),
    aliases: aliases,
    cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
  );
  return product.withRecomputedQuality();
}

/// [RakutenManagedProduct] から [CatalogProduct] を生成。
CatalogProduct catalogProductFromManagedProduct(
  RakutenManagedProduct row, {
  CatalogProductSource source = CatalogProductSource.roomImport,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.medium,
  DateTime? now,
}) {
  return catalogProductFromSearchItem(
    RakutenSearchItem(
      productId: row.productId,
      itemName: row.itemName,
      itemPrice: row.itemPrice,
      itemUrl: row.itemUrl,
      affiliateUrl: row.affiliateUrl ?? '',
      imageUrl: row.imageUrl,
      shopName: row.shopName,
      reviewCount: row.reviewCount,
      reviewAverage: row.reviewAverage,
      shopCode: row.shopCode,
      shopUrl: row.shopUrl,
      genreId: row.genreId,
      genreName: row.genreName,
    ),
    source: source,
    sourceTrust: sourceTrust,
    now: now,
    roomPageUrl: row.roomUrl,
  );
}

/// [CatalogProduct] を既存 UI 互換の [RakutenSearchItem] に変換。
RakutenSearchItem catalogProductToSearchItem(CatalogProduct product) {
  return RakutenSearchItem(
    productId: product.productId.isNotEmpty
        ? product.productId
        : product.canonicalId,
    itemName: product.itemName,
    itemPrice: product.itemPrice,
    itemUrl: product.itemUrl,
    affiliateUrl: product.affiliateUrl,
    imageUrl: product.imageUrl,
    shopName: product.shopName,
    reviewCount: product.reviewCount,
    reviewAverage: product.reviewAverage,
    shopCode: product.shopCode,
    shopUrl: product.shopUrl,
    genreId: product.genreId,
    genreName: product.genreName,
  );
}

/// upsert 結果サマリ。
class ProductCatalogUpsertSummary {
  const ProductCatalogUpsertSummary({
    required this.attempted,
    required this.upserted,
    required this.skipped,
    required this.merged,
    this.inserted = 0,
    this.updated = 0,
    this.qualityNg = 0,
  });

  const ProductCatalogUpsertSummary.skipped()
    : attempted = 0,
      upserted = 0,
      skipped = 0,
      merged = 0,
      inserted = 0,
      updated = 0,
      qualityNg = 0;

  final int attempted;

  /// [ProductCatalogRepository.upsertAll] の inserted + updated（操作件数。ユニーク商品数ではない）。
  final int upserted;
  final int skipped;

  /// upsertAll の updated 件数（同一 canonicalId への merge 含む）。
  final int merged;
  final int inserted;
  final int updated;

  /// 安全判定 NG のため保存しなかった件数。
  final int qualityNg;
}

/// 探すタブ検索モード向けの監査ログ用ラベル。
String catalogUpsertModeLabelForSearchModeTag(String modeTag) {
  switch (modeTag) {
    case 'genre':
      return 'genreSearch';
    case 'savedShop':
      return 'savedShopSearch';
    case 'product':
    default:
      return 'productSearch';
  }
}

/// 検索結果をカタログへ upsert（[ProductCatalogConfig.kProductCatalogEnabled] 時のみ）。
Future<ProductCatalogUpsertSummary> upsertCatalogFromSearchItems(
  ProductCatalogRepository repository,
  Iterable<RakutenSearchItem> items, {
  CatalogProductSource source = CatalogProductSource.search,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.high,
  DateTime? now,
  String? catalogMode,
}) async {
  if (!ProductCatalogConfig.kProductCatalogEnabled) {
    return const ProductCatalogUpsertSummary.skipped();
  }
  final list = items.toList(growable: false);
  if (list.isEmpty) {
    return const ProductCatalogUpsertSummary(
      attempted: 0,
      upserted: 0,
      skipped: 0,
      merged: 0,
    );
  }

  var qualityNg = 0;
  final products = <CatalogProduct>[];
  for (final item in list) {
    final product = catalogProductFromSearchItem(
      item,
      source: source,
      sourceTrust: sourceTrust,
      now: now,
    );
    if (!product.isSavable) continue;
    if (!product.qualityStatus.safe) {
      qualityNg++;
      continue;
    }
    products.add(product);
  }

  final skipped = list.length - products.length - qualityNg;
  final result = await repository.upsertAll(products);
  final summary = ProductCatalogUpsertSummary(
    attempted: list.length,
    upserted: result.inserted + result.updated,
    skipped: skipped + result.skipped,
    merged: result.updated,
    inserted: result.inserted,
    updated: result.updated,
    qualityNg: qualityNg,
  );
  if (catalogMode != null && catalogMode.isNotEmpty) {
    catalogAuditLog(
      '[PRODUCT_CATALOG_SEARCH_UPSERT_SUMMARY] mode=$catalogMode '
      'items=${summary.attempted} upserted=${summary.upserted} '
      'skipped=${summary.skipped} qualityNg=${summary.qualityNg} '
      'source=${source.name}',
    );
    _logProductCatalogSearchVerifySummary(
      repository,
      products,
      catalogMode,
    );
  }
  return summary;
}

/// おすすめコレ API 取得結果をカタログへ upsert。
Future<ProductCatalogUpsertSummary> upsertCatalogFromRecommendItems(
  ProductCatalogRepository repository,
  Iterable<RakutenSearchItem> items, {
  DateTime? now,
}) async {
  final summary = await upsertCatalogFromSearchItems(
    repository,
    items,
    source: CatalogProductSource.todayRecommendation,
    sourceTrust: CatalogProductSourceTrust.high,
    now: now,
  );
  if (!ProductCatalogConfig.kProductCatalogEnabled) {
    return summary;
  }
  catalogAuditLog(
    '[PRODUCT_CATALOG_RECOMMEND_UPSERT_SUMMARY] items=${summary.attempted} '
    'upserted=${summary.upserted} skipped=${summary.skipped} '
    'qualityNg=${summary.qualityNg} source=todayRecommendation',
  );
  return summary;
}

/// ショップ発掘で **既に取得済み** の商品を ProductCatalog に蓄積する。
///
/// - 追加 API 呼び出しは行わない（[RakutenSearchProvider] の検索結果を渡す）
/// - [upsertCatalogFromSearchItems] と同様の isSavable / qualityStatus.safe で除外
/// - source: [CatalogProductSource.shopDiscovery]、sourceTrust: medium
Future<ProductCatalogUpsertSummary> upsertCatalogFromShopDiscoveryItems(
  ProductCatalogRepository repository,
  Iterable<RakutenSearchItem> items, {
  DateTime? now,
  String keyword = '',
}) async {
  final summary = await upsertCatalogFromSearchItems(
    repository,
    items,
    source: CatalogProductSource.shopDiscovery,
    sourceTrust: CatalogProductSourceTrust.medium,
    now: now,
  );
  if (!ProductCatalogConfig.kProductCatalogEnabled) {
    return summary;
  }
  ProductCatalogUpsertTimingRegistry.markShopDiscoveryCompleted(
    catalogCountAfter: repository.count(),
  );
  if (DebugLogFlags.kCatalogAuditLogsEnabled) {
    final kw = keyword.trim();
    catalogAuditLog(
      '[PRODUCT_CATALOG_SHOP_DISCOVERY_UPSERT_SUMMARY] '
      'keyword=${kw.isEmpty ? '-' : kw} '
      'items=${summary.attempted} upserted=${summary.upserted} '
      'skipped=${summary.skipped} qualityNg=${summary.qualityNg} '
      'source=shopDiscovery sourceTrust=medium',
    );
    logProductCatalogDistributionSummary(repository);
    ProductCatalogUpsertTimingRegistry.logUpsertTimingIfEnabled();
  }
  return summary;
}

/// ショップ発掘詳細画面で **既に取得済み** の商品を ProductCatalog に蓄積する。
///
/// - 追加 API 呼び出しは行わない（詳細画面の initial items / shopCode 検索結果を渡す）
/// - source: [CatalogProductSource.shopDiscovery]
/// - [upsertSource]: `initialItems` / `loadedByShopCode`（監査ログ用）
Future<ProductCatalogUpsertSummary> upsertCatalogFromShopDiscoveryDetailItems(
  ProductCatalogRepository repository,
  Iterable<RakutenSearchItem> items, {
  required String shopCode,
  required String upsertSource,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.medium,
  DateTime? now,
}) async {
  final summary = await upsertCatalogFromSearchItems(
    repository,
    items,
    source: CatalogProductSource.shopDiscovery,
    sourceTrust: sourceTrust,
    now: now,
  );
  if (!ProductCatalogConfig.kProductCatalogEnabled) {
    return summary;
  }
  if (DebugLogFlags.kCatalogAuditLogsEnabled) {
    final code = shopCode.trim();
    catalogAuditLog(
      '[SHOP_DISCOVERY_DETAIL_CATALOG_UPSERT_SUMMARY] '
      'shopCode=${code.isEmpty ? '-' : code} '
      'source=$upsertSource '
      'items=${summary.attempted} upserted=${summary.upserted} '
      'inserted=${summary.inserted} updated=${summary.updated} '
      'skipped=${summary.skipped} qualityNg=${summary.qualityNg} '
      'catalogSource=shopDiscoveryDetail catalogTrust=${sourceTrust.name}',
    );
    final itemTraces = buildShopDiscoveryDetailCatalogItemTraces(
      items: items,
      shopCode: code,
      repository: repository,
      source: CatalogProductSource.shopDiscovery,
      sourceTrust: sourceTrust,
      now: now,
    );
    final savedForShop = repository
        .getAll()
        .where((p) => p.shopCode.trim() == code)
        .length;
    logShopDiscoveryDetailCatalogItemTrace(
      shopCode: code,
      inputItems: summary.attempted,
      savedForShop: savedForShop,
      traces: itemTraces,
    );
    logShopDiscoveryDetailDepthTrace(
      repository: repository,
      shopCode: code,
      now: now,
    );
    logShopDiscoveryDetailPoolTrace(
      repository: repository,
      shopCode: code,
      now: now,
    );
    logSavedOrDiscoveryShopDepthAfterUpsert(
      repository: repository,
      shopCode: code,
      now: now,
    );
  }
  return summary;
}

/// 詳細画面 initialItems の保存結果を商品単位で診断（最大 [maxItems] 件）。
@visibleForTesting
List<ShopDiscoveryDetailCatalogItemTraceLine>
    buildShopDiscoveryDetailCatalogItemTraces({
  required Iterable<RakutenSearchItem> items,
  required String shopCode,
  required ProductCatalogRepository repository,
  CatalogProductSource source = CatalogProductSource.shopDiscovery,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.medium,
  DateTime? now,
  int maxItems = 5,
}) {
  final code = shopCode.trim();
  final seenCanonical = <String>{};
  final lines = <ShopDiscoveryDetailCatalogItemTraceLine>[];

  for (final item in items.take(maxItems)) {
    final product = catalogProductFromSearchItem(
      item,
      source: source,
      sourceTrust: sourceTrust,
      now: now,
    );
    final canonicalId = product.canonicalId.trim();
    final itemCode = item.productId.trim();
    final itemShopCode = item.shopCode.trim();

    var saved = false;
    var reason = '-';

    if (!product.isSavable) {
      reason = 'notSavable';
    } else if (!product.qualityStatus.safe) {
      reason = 'qualityUnsafe';
    } else if (canonicalId.isNotEmpty && seenCanonical.contains(canonicalId)) {
      reason = 'canonicalDuplicate';
    } else {
      if (canonicalId.isNotEmpty) seenCanonical.add(canonicalId);
      final stored = repository.getByCanonicalId(canonicalId);
      if (stored == null) {
        reason = 'notInCatalog';
      } else if (code.isNotEmpty && stored.shopCode.trim() != code) {
        reason = 'wrongShopCode';
      } else {
        saved = true;
      }
    }

    lines.add(
      ShopDiscoveryDetailCatalogItemTraceLine(
        itemCode: itemCode.isEmpty ? '-' : itemCode,
        canonicalId: canonicalId.isEmpty ? '-' : canonicalId,
        shopCode: itemShopCode.isEmpty ? '-' : itemShopCode,
        itemName: item.itemName.trim().isEmpty ? '-' : item.itemName.trim(),
        saved: saved,
        reason: reason,
      ),
    );
  }

  return lines;
}

/// 詳細画面 upsert の重複実行防止用 signature（shopCode + productId 昇順）。
@visibleForTesting
String shopDiscoveryDetailCatalogItemSignature(
  Iterable<RakutenSearchItem> items,
) {
  final ids = items
      .map((e) => e.productId.trim())
      .where((e) => e.isNotEmpty)
      .toList()
    ..sort();
  return ids.join('|');
}

/// 詳細画面 upsert の重複実行防止（initial / loaded を別管理）。
class ShopDiscoveryDetailCatalogUpsertGuard {
  String? _initialSignature;
  String? _loadedSignature;

  bool shouldUpsertInitial(List<RakutenSearchItem> items) {
    if (items.isEmpty) return false;
    final sig = shopDiscoveryDetailCatalogItemSignature(items);
    if (sig.isEmpty) return false;
    return _initialSignature != sig;
  }

  bool shouldUpsertLoaded(List<RakutenSearchItem> items) {
    if (items.isEmpty) return false;
    final sig = shopDiscoveryDetailCatalogItemSignature(items);
    if (sig.isEmpty) return false;
    return _loadedSignature != sig;
  }

  void markInitialUpserted(List<RakutenSearchItem> items) {
    _initialSignature = shopDiscoveryDetailCatalogItemSignature(items);
  }

  void markLoadedUpserted(List<RakutenSearchItem> items) {
    _loadedSignature = shopDiscoveryDetailCatalogItemSignature(items);
  }
}

/// ROOM 取り込み・補完結果をカタログへ upsert（失敗しても呼び出し元は継続）。
Future<ProductCatalogUpsertSummary> upsertCatalogFromRoomManagedProducts(
  ProductCatalogRepository? repository,
  Iterable<RakutenManagedProduct> items, {
  CatalogProductSource source = CatalogProductSource.roomImport,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.medium,
  DateTime? now,
}) async {
  if (repository == null || !ProductCatalogConfig.kProductCatalogEnabled) {
    return const ProductCatalogUpsertSummary.skipped();
  }
  final list = items.toList(growable: false);
  if (list.isEmpty) {
    return const ProductCatalogUpsertSummary(
      attempted: 0,
      upserted: 0,
      skipped: 0,
      merged: 0,
    );
  }

  var qualityNg = 0;
  var trustHigh = 0;
  var trustMedium = 0;
  var trustLow = 0;
  final products = <CatalogProduct>[];
  for (final row in list) {
    final product = catalogProductFromManagedProduct(
      row,
      source: source,
      sourceTrust: sourceTrust,
      now: now,
    );
    switch (product.sourceTrust) {
      case CatalogProductSourceTrust.high:
        trustHigh++;
      case CatalogProductSourceTrust.medium:
        trustMedium++;
      case CatalogProductSourceTrust.low:
        trustLow++;
    }
    if (!product.isSavable) continue;
    if (!product.qualityStatus.safe) {
      qualityNg++;
      continue;
    }
    products.add(product);
  }

  try {
    final skipped = list.length - products.length - qualityNg;
    final result = await repository.upsertAll(products);
    final summary = ProductCatalogUpsertSummary(
      attempted: list.length,
      upserted: result.inserted + result.updated,
      skipped: skipped + result.skipped,
      merged: result.updated,
      inserted: result.inserted,
      updated: result.updated,
      qualityNg: qualityNg,
    );
    _logRoomCatalogUpsertSummary(
      source: source,
      summary: summary,
      trustHigh: trustHigh,
      trustMedium: trustMedium,
      trustLow: trustLow,
    );
    return summary;
  } catch (e) {
    importantDebugLog('[ROOM_CATALOG_UPSERT] failed: $e');
    return ProductCatalogUpsertSummary(
      attempted: list.length,
      upserted: 0,
      skipped: list.length,
      merged: 0,
      qualityNg: qualityNg,
    );
  }
}

void _logRoomCatalogUpsertSummary({
  required CatalogProductSource source,
  required ProductCatalogUpsertSummary summary,
  required int trustHigh,
  required int trustMedium,
  required int trustLow,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled &&
      !DebugLogFlags.kRoomAuditLogsEnabled) {
    return;
  }
  final line =
      '[ROOM_CATALOG_UPSERT_SUMMARY] source=${source.name} '
      'items=${summary.attempted} upserted=${summary.upserted} '
      'skipped=${summary.skipped} qualityNg=${summary.qualityNg} '
      'trustHigh=$trustHigh trustMedium=$trustMedium trustLow=$trustLow';
  if (DebugLogFlags.kCatalogAuditLogsEnabled) {
    catalogAuditLog(line);
  } else {
    roomAuditLog(line);
  }
}

/// 実機確認用: 保存直後のカタログ状態サマリ（[DebugLogFlags.kCatalogAuditLogsEnabled] 時のみ）。
void _logProductCatalogSearchVerifySummary(
  ProductCatalogRepository repository,
  List<CatalogProduct> products,
  String catalogMode,
) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  final count = repository.count();
  if (products.isEmpty) {
    catalogAuditLog(
      '[PRODUCT_CATALOG_SEARCH_VERIFY_SUMMARY] mode=$catalogMode '
      'count=$count savedBatch=0',
    );
    return;
  }
  final sample = products.first;
  final stored = repository.getByCanonicalId(sample.canonicalId, touch: false);
  final byProductId = sample.productId.trim().isNotEmpty
      ? repository.findByAlias(sample.productId, touch: false)
      : null;
  final byNormUrl = sample.normalizedItemUrl.trim().isNotEmpty
      ? repository.findByAlias(sample.normalizedItemUrl, touch: false)
      : null;
  final parsed = RakutenItemUrlParser.tryParse(sample.itemUrl);
  final shopItemAlias = parsed != null
      ? CatalogProductKeys.shopItemAlias(parsed.shopCode, parsed.itemPathSegment)
      : null;
  final byShopItem = shopItemAlias != null
      ? repository.findByAlias(shopItemAlias, touch: false)
      : null;
  var batchWithGenreId = 0;
  var batchWithGenreName = 0;
  for (final p in products) {
    if (p.genreId.trim().isNotEmpty) batchWithGenreId++;
    if (p.genreName.trim().isNotEmpty) batchWithGenreName++;
  }
  catalogAuditLog(
    '[PRODUCT_CATALOG_SEARCH_VERIFY_SUMMARY] mode=$catalogMode count=$count '
    'savedBatch=${products.length} batchWithGenreId=$batchWithGenreId '
    'batchWithGenreName=$batchWithGenreName '
    'canonicalId=${sample.canonicalId} '
    'getByCanonicalId=${stored != null} findByProductId=${byProductId != null} '
    'findByNormalizedUrl=${byNormUrl != null} findByShopItem=${byShopItem != null} '
    'sampleGenreId=${sample.genreId.isEmpty ? '-' : sample.genreId} '
    'sampleGenreName=${sample.genreName.isEmpty ? '-' : sample.genreName} '
    'storedGenreId=${stored == null || stored.genreId.isEmpty ? '-' : stored.genreId} '
    'storedGenreName=${stored == null || stored.genreName.isEmpty ? '-' : stored.genreName} '
    'source=${stored?.source.name} sourceTrust=${stored?.sourceTrust.name} '
    'qualitySafe=${stored?.qualityStatus.safe} '
    'hasImage=${stored?.qualityStatus.hasImage} hasPrice=${stored?.qualityStatus.hasPrice}',
  );
}
