import '../config/debug_log_flags.dart';
import '../models/catalog_product.dart';
import '../models/shop_pool_candidate.dart';
import '../repository/product_catalog_repository.dart'
    show ProductCatalogRepository, ProductCatalogUpsertItemResult;
import '../services/product_catalog_shop_aggregator.dart';
import 'app_debug_log.dart';
import 'product_safety_filter.dart';

/// 詳細画面 upsert 後の商品単位トレース行（監査ログ用）。
class ShopDiscoveryDetailCatalogItemTraceLine {
  const ShopDiscoveryDetailCatalogItemTraceLine({
    required this.itemCode,
    required this.inputCanonicalId,
    required this.canonicalId,
    required this.shopCode,
    required this.itemName,
    required this.normalizedItemUrl,
    required this.saved,
    required this.reason,
    required this.getByCanonicalIdFound,
    required this.findByAliasFound,
    required this.resolvedCanonicalId,
    required this.resolvedShopCode,
    required this.sameShopCode,
    this.aliasMatchedBy = '',
  });

  final String itemCode;
  final String inputCanonicalId;
  final String canonicalId;
  final String shopCode;
  final String itemName;
  final String normalizedItemUrl;
  final bool saved;
  final String reason;
  final bool getByCanonicalIdFound;
  final bool findByAliasFound;
  final String resolvedCanonicalId;
  final String resolvedShopCode;
  final bool sameShopCode;
  final String aliasMatchedBy;
}

/// ProductCatalog upsert 1件ごとの merge 結果（最大5件・[CATALOG_AUDIT_LOGS] 時のみ）。
void logProductCatalogUpsertItemResults(
  List<ProductCatalogUpsertItemResult> results,
) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  for (final r in results.take(5)) {
    final urlRejectFields = r.urlIdentityRejected
        ? ' urlIdentityRejected=true '
            'urlIdentityRejectReason=${r.urlIdentityRejectReason.isEmpty ? '-' : r.urlIdentityRejectReason} '
            'inputProductId=${r.productId.isEmpty ? '-' : r.productId} '
            'matchedCanonicalId=${r.matchedCanonicalId.isEmpty ? '-' : r.matchedCanonicalId} '
            'matchedProductId=${r.matchedProductId.isEmpty ? '-' : r.matchedProductId}'
        : '';
    catalogAuditLog(
      '[PRODUCT_CATALOG_UPSERT_ITEM_RESULT] '
      'inputCanonicalId=${r.inputCanonicalId} '
      'resolvedCanonicalId=${r.resolvedCanonicalId} '
      'operation=${r.operation} mergeReason=${r.mergeReason} '
      'inputShopCode=${r.inputShopCode} savedShopCode=${r.savedShopCode} '
      'aliasMatchedBy=${r.aliasMatchedBy.isEmpty ? '-' : r.aliasMatchedBy} '
      'productId=${r.productId.isEmpty ? '-' : r.productId} '
      'normalizedItemUrl=${r.normalizedItemUrl.isEmpty ? '-' : r.normalizedItemUrl} '
      'saved=${r.saved}$urlRejectFields',
    );
  }
}

/// ProductCatalog 集計と ShopPool 候補の差分診断（[CATALOG_AUDIT_LOGS] 時のみ）。
void logShopPoolAggregationDiagnostics({
  required ProductCatalogRepository repository,
  Set<String> excludeSavedShopCodes = const {},
  DateTime? now,
  int maxShopsToLog = 5,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;

  final t = now ?? DateTime.now();
  final products = repository.getAll();
  final savedExclude = excludeSavedShopCodes
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();

  final byShop = <String, List<CatalogProduct>>{};
  for (final p in products) {
    final code = p.shopCode.trim();
    if (code.isEmpty) continue;
    byShop.putIfAbsent(code, () => []).add(p);
  }

  final aggregate = ProductCatalogShopAggregator.aggregate(
    repository: repository,
    excludeSavedShopCodes: savedExclude,
    now: t,
  );
  final poolByCode = {
    for (final c in aggregate.candidates) c.shopCode.trim(): c,
  };

  final multiShops = byShop.entries.where((e) => e.value.length >= 2).toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));

  var includedInPool = 0;
  var excludedStale = 0;
  var excludedLowTrust = 0;
  var excludedUnsafe = 0;
  var excludedNoValidProducts = 0;
  var excludedSavedShop = 0;
  final topEntries = <String>[];

  for (final entry in multiShops.take(maxShopsToLog)) {
    final shopCode = entry.key;
    final items = entry.value;
    final diag = _diagnoseShopProducts(
      shopCode: shopCode,
      products: items,
      repository: repository,
      now: t,
    );

    if (savedExclude.contains(shopCode)) {
      excludedSavedShop++;
    } else if (diag.poolEligibleCount == 0) {
      excludedNoValidProducts++;
    } else if (diag.staleCount > 0 &&
        diag.poolEligibleCount < items.length &&
        diag.poolEligibleCount <= 1) {
      excludedStale++;
    } else if (diag.lowTrustCount > 0 && diag.poolEligibleCount <= 1) {
      excludedLowTrust++;
    } else if (diag.unsafeCount > 0 && diag.poolEligibleCount <= 1) {
      excludedUnsafe++;
    }

    final pool = poolByCode[shopCode];
    final poolItemCount = pool?.itemCount ?? 0;
    final inPool = pool != null;
    if (inPool && poolItemCount >= 2) {
      includedInPool++;
    }

    final reason = savedExclude.contains(shopCode)
        ? 'savedShop'
        : poolItemCount >= 2
        ? 'ok'
        : diag.poolEligibleCount == 0
        ? 'noValidProducts'
        : diag.staleCount > 0 && diag.poolEligibleCount < items.length
        ? 'stale'
        : diag.lowTrustCount > 0
        ? 'lowTrust'
        : diag.unsafeCount > 0
        ? 'unsafe'
        : 'singleEligible';

    topEntries.add(
      '$shopCode:${items.length}/$poolItemCount/$reason/inPool:$inPool',
    );
  }

  catalogAuditLog(
    '[SHOP_POOL_MULTI_SHOP_TRACE] '
    'totalMultiProductShops=${multiShops.length} '
    'includedInPool=$includedInPool '
    'excludedStale=$excludedStale '
    'excludedLowTrust=$excludedLowTrust '
    'excludedUnsafe=$excludedUnsafe '
    'excludedMissingShopCode=0 '
    'excludedNoValidProducts=$excludedNoValidProducts '
    'excludedSavedShop=$excludedSavedShop '
    'topMultiShops=${topEntries.isEmpty ? '-' : topEntries.join(',')}',
  );

  if (byShop.isEmpty) return;

  String? maxShopCode;
  var maxCount = 0;
  for (final entry in byShop.entries) {
    if (entry.value.length > maxCount) {
      maxCount = entry.value.length;
      maxShopCode = entry.key;
    }
  }
  if (maxShopCode == null) return;

  final maxItems = byShop[maxShopCode]!;
  final maxDiag = _diagnoseShopProducts(
    shopCode: maxShopCode,
    products: maxItems,
    repository: repository,
    now: t,
  );
  final maxPool = poolByCode[maxShopCode];
  final maxPoolItemCount = maxPool?.itemCount ?? 0;
  final maxInPool = maxPool != null;
  final maxReason = savedExclude.contains(maxShopCode)
      ? 'savedShop'
      : maxPoolItemCount >= 2
      ? 'ok'
      : maxDiag.staleCount > 0 && maxDiag.poolEligibleCount < maxItems.length
      ? 'partialStale'
      : maxDiag.poolEligibleCount <= 1
      ? 'singleEligible'
      : '-';

  catalogAuditLog(
    '[PRODUCT_CATALOG_MAX_SHOP_TRACE] '
    'shopCode=$maxShopCode '
    'productCount=$maxCount '
    'sourceBreakdown=${_formatEnumCounts(maxDiag.sourceCounts)} '
    'trustBreakdown=${_formatTrustCounts(maxDiag.trustCounts)} '
    'freshCount=${maxDiag.freshCount} '
    'safeCount=${maxDiag.safeCount} '
    'staleCount=${maxDiag.staleCount} '
    'poolItemCount=$maxPoolItemCount '
    'inPool=$maxInPool '
    'excludedReason=$maxReason',
  );
}

class _ShopProductDiag {
  const _ShopProductDiag({
    required this.freshCount,
    required this.staleCount,
    required this.lowTrustCount,
    required this.unsafeCount,
    required this.safeCount,
    required this.poolEligibleCount,
    required this.sourceCounts,
    required this.trustCounts,
  });

  final int freshCount;
  final int staleCount;
  final int lowTrustCount;
  final int unsafeCount;
  final int safeCount;
  final int poolEligibleCount;
  final Map<CatalogProductSource, int> sourceCounts;
  final Map<CatalogProductSourceTrust, int> trustCounts;
}

_ShopProductDiag _diagnoseShopProducts({
  required String shopCode,
  required List<CatalogProduct> products,
  required ProductCatalogRepository repository,
  required DateTime now,
}) {
  var freshCount = 0;
  var staleCount = 0;
  var lowTrustCount = 0;
  var unsafeCount = 0;
  var safeCount = 0;
  var poolEligibleCount = 0;
  final sourceCounts = <CatalogProductSource, int>{};
  final trustCounts = <CatalogProductSourceTrust, int>{};

  for (final p in products) {
    sourceCounts.update(p.source, (v) => v + 1, ifAbsent: () => 1);
    trustCounts.update(p.sourceTrust, (v) => v + 1, ifAbsent: () => 1);

    if (repository.isStale(p, now: now)) {
      staleCount++;
      continue;
    }
    freshCount++;

    if (p.sourceTrust == CatalogProductSourceTrust.low) {
      lowTrustCount++;
      continue;
    }
    if (!p.qualityStatus.safe ||
        ProductSafetyFilter.isBlockedProduct(
          itemName: p.itemName,
          itemCaption: p.itemCaption,
          shopName: p.shopName,
          genreName: p.genreName,
          itemUrl: p.itemUrl,
          affiliateUrl: p.affiliateUrl,
        )) {
      unsafeCount++;
      continue;
    }
    safeCount++;
    poolEligibleCount++;
  }

  return _ShopProductDiag(
    freshCount: freshCount,
    staleCount: staleCount,
    lowTrustCount: lowTrustCount,
    unsafeCount: unsafeCount,
    safeCount: safeCount,
    poolEligibleCount: poolEligibleCount,
    sourceCounts: sourceCounts,
    trustCounts: trustCounts,
  );
}

/// ProductCatalog 全体のフィールド分布（[CATALOG_AUDIT_LOGS] 時のみ）。
void logProductCatalogDistributionSummary(ProductCatalogRepository repository) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;

  final products = repository.getAll();
  final total = products.length;
  if (total == 0) {
    catalogAuditLog(
      '[PRODUCT_CATALOG_DISTRIBUTION_SUMMARY] total=0 '
      'withGenreId=0 withGenreName=0 withShopCode=0 withShopName=0 '
      'withItemName=0 unknownGenreName=0 '
      'sourceBreakdown=- trustBreakdown=-',
    );
    return;
  }

  var withGenreId = 0;
  var withGenreName = 0;
  var withShopCode = 0;
  var withShopName = 0;
  var withItemName = 0;
  var unknownGenreName = 0;
  final sourceCounts = <CatalogProductSource, int>{};
  final trustCounts = <CatalogProductSourceTrust, int>{};

  for (final p in products) {
    if (p.genreId.trim().isNotEmpty) withGenreId++;
    final gn = p.genreName.trim();
    if (gn.isNotEmpty && gn.toLowerCase() != 'unknown') {
      withGenreName++;
    } else {
      unknownGenreName++;
    }
    if (p.shopCode.trim().isNotEmpty) withShopCode++;
    if (p.shopName.trim().isNotEmpty) withShopName++;
    if (p.itemName.trim().isNotEmpty) withItemName++;
    sourceCounts.update(p.source, (v) => v + 1, ifAbsent: () => 1);
    trustCounts.update(p.sourceTrust, (v) => v + 1, ifAbsent: () => 1);
  }

  catalogAuditLog(
    '[PRODUCT_CATALOG_DISTRIBUTION_SUMMARY] '
    'total=$total '
    'withGenreId=$withGenreId '
    'withGenreName=$withGenreName '
    'withShopCode=$withShopCode '
    'withShopName=$withShopName '
    'withItemName=$withItemName '
    'unknownGenreName=$unknownGenreName '
    'sourceBreakdown=${_formatEnumCounts(sourceCounts)} '
    'trustBreakdown=${_formatTrustCounts(trustCounts)}',
  );
  _logProductCatalogShopAccumulationSummary(products);
}

/// shopCode 単位の商品蓄積厚み（ShopPool itemCount 診断用）。
void _logProductCatalogShopAccumulationSummary(List<CatalogProduct> products) {
  final byShop = <String, int>{};
  for (final p in products) {
    final code = p.shopCode.trim();
    if (code.isEmpty) continue;
    byShop[code] = (byShop[code] ?? 0) + 1;
  }
  if (byShop.isEmpty) {
    catalogAuditLog(
      '[PRODUCT_CATALOG_SHOP_ACCUMULATION_SUMMARY] '
      'uniqueShops=0 productCount1Shop=0 productCount2PlusShops=0 '
      'maxProductsPerShop=0 avgProductsPerShop=0',
    );
    return;
  }

  var shopsWith1 = 0;
  var shopsWith2Plus = 0;
  var maxPerShop = 0;
  var productSum = 0;
  for (final count in byShop.values) {
    productSum += count;
    if (count > maxPerShop) maxPerShop = count;
    if (count <= 1) {
      shopsWith1++;
    } else {
      shopsWith2Plus++;
    }
  }
  final avg = productSum / byShop.length;
  catalogAuditLog(
    '[PRODUCT_CATALOG_SHOP_ACCUMULATION_SUMMARY] '
    'uniqueShops=${byShop.length} '
    'productCount1Shop=$shopsWith1 '
    'productCount2PlusShops=$shopsWith2Plus '
    'maxProductsPerShop=$maxPerShop '
    'avgProductsPerShop=${avg.toStringAsFixed(2)}',
  );
}

String _formatEnumCounts(Map<CatalogProductSource, int> counts) {
  if (counts.isEmpty) return '-';
  final parts = CatalogProductSource.values
      .where(counts.containsKey)
      .map((e) => '${e.name}:${counts[e]}')
      .toList(growable: false);
  return parts.isEmpty ? '-' : parts.join(',');
}

String _formatTrustCounts(Map<CatalogProductSourceTrust, int> counts) {
  if (counts.isEmpty) return '-';
  final parts = CatalogProductSourceTrust.values
      .where(counts.containsKey)
      .map((e) => '${e.name}:${counts[e]}')
      .toList(growable: false);
  return parts.isEmpty ? '-' : parts.join(',');
}

/// stale 商品が深さ評価のみに使えるか（shopCode + itemName + genreId）。
bool isStaleUsableForDepthOnly(CatalogProduct product) {
  if (product.sourceTrust == CatalogProductSourceTrust.low) return false;
  if (product.shopCode.trim().isEmpty) return false;
  if (product.itemName.trim().isEmpty) return false;
  if (product.genreId.trim().isEmpty) return false;
  return true;
}

bool _isPoolEligibleFreshProduct(
  CatalogProduct product,
  ProductCatalogRepository repository, {
  required DateTime now,
}) {
  if (repository.isStale(product, now: now)) return false;
  if (product.sourceTrust == CatalogProductSourceTrust.low) return false;
  if (!product.qualityStatus.safe ||
      ProductSafetyFilter.isBlockedProduct(
        itemName: product.itemName,
        itemCaption: product.itemCaption,
        shopName: product.shopName,
        genreName: product.genreName,
        itemUrl: product.itemUrl,
        affiliateUrl: product.affiliateUrl,
      )) {
    return false;
  }
  return true;
}

/// ShopPool 厚みと stale 参考値の診断（テスト可能な純粋集計）。
class ShopPoolStaleDepthProjection {
  const ShopPoolStaleDepthProjection({
    required this.candidateCount,
    required this.freshItemCount,
    required this.staleItemCount,
    required this.staleUsableForDepth,
    required this.currentItemCount2Plus,
    required this.wouldItemCount2PlusIfStaleDepthAllowed,
  });

  final int candidateCount;
  final int freshItemCount;
  final int staleItemCount;
  final int staleUsableForDepth;
  final int currentItemCount2Plus;
  final int wouldItemCount2PlusIfStaleDepthAllowed;
}

ShopPoolStaleDepthProjection computeShopPoolStaleDepthProjection({
  required ProductCatalogRepository repository,
  Set<String> excludeSavedShopCodes = const {},
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final products = repository.getAll();
  final savedExclude = excludeSavedShopCodes
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();

  final aggregate = ProductCatalogShopAggregator.aggregate(
    repository: repository,
    excludeSavedShopCodes: savedExclude,
    now: t,
  );

  var freshItemCount = 0;
  var currentItemCount2Plus = 0;
  for (final c in aggregate.candidates) {
    freshItemCount += c.itemCount;
    if (c.itemCount >= 2) currentItemCount2Plus++;
  }

  var staleItemCount = 0;
  var staleUsableForDepth = 0;
  final byShop = <String, List<CatalogProduct>>{};
  for (final p in products) {
    final code = p.shopCode.trim();
    if (code.isEmpty) continue;
    byShop.putIfAbsent(code, () => []).add(p);
    if (!repository.isStale(p, now: t)) continue;
    staleItemCount++;
    if (isStaleUsableForDepthOnly(p)) staleUsableForDepth++;
  }

  var wouldItemCount2Plus = 0;
  for (final entry in byShop.entries) {
    if (savedExclude.contains(entry.key)) continue;
    var depthCount = 0;
    for (final p in entry.value) {
      if (_isPoolEligibleFreshProduct(p, repository, now: t)) {
        depthCount++;
      } else if (repository.isStale(p, now: t) &&
          isStaleUsableForDepthOnly(p)) {
        depthCount++;
      }
    }
    if (depthCount >= 2) wouldItemCount2Plus++;
  }

  return ShopPoolStaleDepthProjection(
    candidateCount: aggregate.candidates.length,
    freshItemCount: freshItemCount,
    staleItemCount: staleItemCount,
    staleUsableForDepth: staleUsableForDepth,
    currentItemCount2Plus: currentItemCount2Plus,
    wouldItemCount2PlusIfStaleDepthAllowed: wouldItemCount2Plus,
  );
}

/// ShopPool stale 参考値サマリ（[CATALOG_AUDIT_LOGS] 時のみ）。
void logShopPoolStaleReferenceSummary({
  required ProductCatalogRepository repository,
  Set<String> excludeSavedShopCodes = const {},
  DateTime? now,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  final projection = computeShopPoolStaleDepthProjection(
    repository: repository,
    excludeSavedShopCodes: excludeSavedShopCodes,
    now: now,
  );
  catalogAuditLog(
    '[SHOP_POOL_STALE_REFERENCE_SUMMARY] '
    'candidateCount=${projection.candidateCount} '
    'freshItemCount=${projection.freshItemCount} '
    'staleItemCount=${projection.staleItemCount} '
    'staleUsableForDepth=${projection.staleUsableForDepth} '
    'currentItemCount2Plus=${projection.currentItemCount2Plus} '
    'wouldItemCount2PlusIfStaleDepthAllowed='
    '${projection.wouldItemCount2PlusIfStaleDepthAllowed}',
  );
}

/// 保存ショップ検索後の同一 shopCode 蓄積診断（[CATALOG_AUDIT_LOGS] 時のみ）。
void logSavedShopCatalogDepthSummary({
  required String shopCode,
  required int items,
  required int upserted,
  required ProductCatalogRepository repository,
  DateTime? now,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  final code = shopCode.trim();
  if (code.isEmpty) return;

  final t = now ?? DateTime.now();
  final shopProducts = repository
      .getAll()
      .where((p) => p.shopCode.trim() == code)
      .toList(growable: false);
  var freshCount = 0;
  for (final p in shopProducts) {
    if (!repository.isStale(p, now: t)) freshCount++;
  }

  catalogAuditLog(
    '[SAVED_SHOP_CATALOG_DEPTH_SUMMARY] '
    'shopCode=$code items=$items upserted=$upserted '
    'productCountForShop=${shopProducts.length} '
    'freshCountForShop=$freshCount '
    'source=savedShopSearch catalogSource=search catalogTrust=high',
  );
}

/// ショップ発掘結果から手動補強候補を数える（API は呼ばない）。
class ShopDiscoveryEnrichmentOpportunity {
  const ShopDiscoveryEnrichmentOpportunity({
    required this.keyword,
    required this.displayedShopCount,
    required this.shopsWithOnlyOneFreshProduct,
    required this.shopsEligibleForManualEnrich,
    required this.estimatedApiCallsIfEnrichTop3,
  });

  final String keyword;
  final int displayedShopCount;
  final int shopsWithOnlyOneFreshProduct;
  final int shopsEligibleForManualEnrich;
  final int estimatedApiCallsIfEnrichTop3;
}

ShopDiscoveryEnrichmentOpportunity computeShopDiscoveryEnrichmentOpportunity({
  required ProductCatalogRepository repository,
  required Iterable<String> displayedShopCodes,
  required String keyword,
  Set<String> excludeSavedShopCodes = const {},
  DateTime? now,
}) {
  final savedExclude = excludeSavedShopCodes
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();
  final aggregate = ProductCatalogShopAggregator.aggregate(
    repository: repository,
    excludeSavedShopCodes: savedExclude,
    now: now,
  );
  final poolByCode = {
    for (final c in aggregate.candidates) c.shopCode.trim(): c.itemCount,
  };

  final codes = displayedShopCodes
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  var oneFresh = 0;
  var eligible = 0;
  for (final code in codes) {
    if (savedExclude.contains(code)) continue;
    final poolCount = poolByCode[code] ?? 0;
    if (poolCount <= 1) oneFresh++;
    if (poolCount <= 1) eligible++;
  }

  return ShopDiscoveryEnrichmentOpportunity(
    keyword: keyword,
    displayedShopCount: codes.length,
    shopsWithOnlyOneFreshProduct: oneFresh,
    shopsEligibleForManualEnrich: eligible,
    estimatedApiCallsIfEnrichTop3: eligible >= 3 ? 3 : eligible,
  );
}

void logShopDiscoveryEnrichmentOpportunity({
  required ProductCatalogRepository repository,
  required Iterable<String> displayedShopCodes,
  required String keyword,
  Set<String> excludeSavedShopCodes = const {},
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  final opp = computeShopDiscoveryEnrichmentOpportunity(
    repository: repository,
    displayedShopCodes: displayedShopCodes,
    keyword: keyword,
    excludeSavedShopCodes: excludeSavedShopCodes,
  );
  final kw = opp.keyword.trim();
  catalogAuditLog(
    '[SHOP_DISCOVERY_ENRICHMENT_OPPORTUNITY] '
    'keyword=${kw.isEmpty ? '-' : kw} '
    'displayedShopCount=${opp.displayedShopCount} '
    'shopsWithOnlyOneFreshProduct=${opp.shopsWithOnlyOneFreshProduct} '
    'shopsEligibleForManualEnrich=${opp.shopsEligibleForManualEnrich} '
    'estimatedApiCallsIfEnrichTop3=${opp.estimatedApiCallsIfEnrichTop3}',
  );
}

/// ショップ発掘詳細を開いたときの既存カタログ状態（[CATALOG_AUDIT_LOGS] 時のみ）。
void logShopDiscoveryDetailCatalogAudit({
  required ProductCatalogRepository? repository,
  required String shopCode,
  required int itemsFromSearch,
  required bool wouldFetchFromApiIfEmpty,
  bool catalogUpsertOnOpen = false,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  final code = shopCode.trim();
  final repo = repository;
  if (repo == null || code.isEmpty) {
    catalogAuditLog(
      '[SHOP_DISCOVERY_DETAIL_CATALOG_AUDIT] shopCode=${code.isEmpty ? '-' : code} '
      'itemsFromSearch=$itemsFromSearch wouldFetchFromApiIfEmpty=$wouldFetchFromApiIfEmpty '
      'catalogEnabled=false catalogProductsForShop=0 freshInPool=0 '
      'catalogUpsertOnOpen=$catalogUpsertOnOpen',
    );
    return;
  }

  final shopProducts = repo
      .getAll()
      .where((p) => p.shopCode.trim() == code)
      .length;
  final pool = ProductCatalogShopAggregator.aggregate(repository: repo);
  final poolItemCount =
      pool.candidates
          .where((c) => c.shopCode.trim() == code)
          .map((c) => c.itemCount)
          .firstOrNull ??
      0;

  catalogAuditLog(
    '[SHOP_DISCOVERY_DETAIL_CATALOG_AUDIT] shopCode=$code '
    'itemsFromSearch=$itemsFromSearch '
    'wouldFetchFromApiIfEmpty=$wouldFetchFromApiIfEmpty '
    'catalogProductsForShop=$shopProducts freshInPool=$poolItemCount '
    'catalogUpsertOnOpen=$catalogUpsertOnOpen',
  );
}

/// 詳細画面 upsert 後の商品単位トレース（最大5件・[CATALOG_AUDIT_LOGS] 時のみ）。
void logShopDiscoveryDetailCatalogItemTrace({
  required String shopCode,
  required int inputItems,
  required int savedForShop,
  required List<ShopDiscoveryDetailCatalogItemTraceLine> traces,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  final code = shopCode.trim();
  if (code.isEmpty) return;

  final buf = StringBuffer()
    ..write('[SHOP_DISCOVERY_DETAIL_CATALOG_ITEM_TRACE] ')
    ..write('shopCode=$code ')
    ..write('inputItems=$inputItems ')
    ..write('savedForShop=$savedForShop');
  for (var i = 0; i < traces.length; i++) {
    final t = traces[i];
    buf
      ..write(' item${i + 1}=itemCode=${t.itemCode},')
      ..write('inputCanonicalId=${t.inputCanonicalId},canonicalId=${t.canonicalId},')
      ..write('normalizedItemUrl=${t.normalizedItemUrl},')
      ..write('shopCode=${t.shopCode},itemName=${t.itemName},')
      ..write('getByCanonicalIdFound=${t.getByCanonicalIdFound},')
      ..write('findByAliasFound=${t.findByAliasFound},')
      ..write('resolvedCanonicalId=${t.resolvedCanonicalId},')
      ..write('resolvedShopCode=${t.resolvedShopCode},')
      ..write('sameShopCode=${t.sameShopCode},')
      ..write('aliasMatchedBy=${t.aliasMatchedBy.isEmpty ? '-' : t.aliasMatchedBy},')
      ..write('saved=${t.saved},reason=${t.reason}');
  }
  catalogAuditLog(buf.toString());
}

/// 詳細画面 upsert 後の shopCode 単位深さ内訳（[CATALOG_AUDIT_LOGS] 時のみ）。
void logShopDiscoveryDetailDepthTrace({
  required ProductCatalogRepository repository,
  required String shopCode,
  DateTime? now,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  final code = shopCode.trim();
  if (code.isEmpty) return;

  final t = now ?? DateTime.now();
  final shopProducts = repository
      .getAll()
      .where((p) => p.shopCode.trim() == code)
      .toList(growable: false);

  var freshForShop = 0;
  var safeForShop = 0;
  var staleForShop = 0;
  var unsafeForShop = 0;
  final canonicalIds = <String>[];

  for (final p in shopProducts) {
    if (repository.isStale(p, now: t)) {
      staleForShop++;
    } else {
      freshForShop++;
    }
    if (p.qualityStatus.safe &&
        !ProductSafetyFilter.isBlockedProduct(
          itemName: p.itemName,
          itemCaption: p.itemCaption,
          shopName: p.shopName,
          genreName: p.genreName,
          itemUrl: p.itemUrl,
          affiliateUrl: p.affiliateUrl,
        )) {
      safeForShop++;
    } else {
      unsafeForShop++;
    }
    final cid = p.canonicalId.trim();
    if (cid.isNotEmpty && canonicalIds.length < 5) {
      canonicalIds.add(cid);
    }
  }

  catalogAuditLog(
    '[SHOP_DISCOVERY_DETAIL_DEPTH_TRACE] '
    'shopCode=$code '
    'allForShop=${shopProducts.length} '
    'freshForShop=$freshForShop '
    'safeForShop=$safeForShop '
    'staleForShop=$staleForShop '
    'unsafeForShop=$unsafeForShop '
    'canonicalIds=${canonicalIds.isEmpty ? '-' : canonicalIds.join('|')}',
  );
}

/// 詳細画面 upsert 直後の ShopPool 反映診断（[CATALOG_AUDIT_LOGS] 時のみ）。
void logShopDiscoveryDetailPoolTrace({
  required ProductCatalogRepository repository,
  required String shopCode,
  DateTime? now,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  final code = shopCode.trim();
  if (code.isEmpty) return;

  final t = now ?? DateTime.now();
  final catalogProductsForShop = repository
      .getAll()
      .where((p) => p.shopCode.trim() == code)
      .length;

  final pool = ProductCatalogShopAggregator.aggregate(
    repository: repository,
    now: t,
  );
  final candidate = pool.candidates
      .where((c) => c.shopCode.trim() == code)
      .firstOrNull;

  final excludedReason = _shopDiscoveryDetailPoolExcludedReason(
    repository: repository,
    shopCode: code,
    candidate: candidate,
    now: t,
  );

  catalogAuditLog(
    '[SHOP_DISCOVERY_DETAIL_POOL_TRACE] '
    'shopCode=$code '
    'catalogProductsForShop=$catalogProductsForShop '
    'poolCandidateExists=${candidate != null} '
    'poolItemCount=${candidate?.itemCount ?? 0} '
    'poolSourceProductIds=${candidate?.sourceProductIds.length ?? 0} '
    'poolSampleProductIds=${candidate?.sampleProductIds.length ?? 0} '
    'excludedReason=$excludedReason',
  );
}

String _shopDiscoveryDetailPoolExcludedReason({
  required ProductCatalogRepository repository,
  required String shopCode,
  required ShopPoolCandidate? candidate,
  DateTime? now,
}) {
  if (candidate != null) {
    final poolCount = candidate.itemCount;
    final all = repository
        .getAll()
        .where((p) => p.shopCode.trim() == shopCode)
        .length;
    if (poolCount >= all) return '-';
    return 'partialExcluded';
  }

  final t = now ?? DateTime.now();
  var fresh = 0;
  var stale = 0;
  for (final p in repository.getAll()) {
    if (p.shopCode.trim() != shopCode) continue;
    if (repository.isStale(p, now: t)) {
      stale++;
    } else {
      fresh++;
    }
  }
  if (fresh == 0 && stale > 0) return 'allStale';
  if (fresh == 0) return 'noFreshProducts';
  return 'notInPool';
}

/// 詳細/保存ショップ upsert 後の shopCode 単位厚み（[CATALOG_AUDIT_LOGS] 時のみ）。
void logSavedOrDiscoveryShopDepthAfterUpsert({
  required ProductCatalogRepository repository,
  required String shopCode,
  DateTime? now,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  final code = shopCode.trim();
  if (code.isEmpty) return;

  final t = now ?? DateTime.now();
  final shopProducts = repository
      .getAll()
      .where((p) => p.shopCode.trim() == code)
      .toList(growable: false);
  var freshCount = 0;
  for (final p in shopProducts) {
    if (!repository.isStale(p, now: t)) freshCount++;
  }

  final pool = ProductCatalogShopAggregator.aggregate(
    repository: repository,
    now: t,
  );
  final candidate = pool.candidates
      .where((c) => c.shopCode.trim() == code)
      .firstOrNull;

  catalogAuditLog(
    '[SAVED_OR_DISCOVERY_SHOP_DEPTH_AFTER_UPSERT] '
    'shopCode=$code productCountForShop=${shopProducts.length} '
    'freshCountForShop=$freshCount '
    'sourceProductIds=${candidate?.sourceProductIds.length ?? 0} '
    'sampleProductIds=${candidate?.sampleProductIds.length ?? 0}',
  );
}

/// Phase 3-I 施策別の想定効果（読み取りのみ・[CATALOG_AUDIT_LOGS] 時のみ）。
void logPhase3IStrategyAuditEstimate({
  required ProductCatalogRepository repository,
  Set<String> excludeSavedShopCodes = const {},
  DateTime? now,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  final t = now ?? DateTime.now();
  final products = repository.getAll();
  final staleProjection = computeShopPoolStaleDepthProjection(
    repository: repository,
    excludeSavedShopCodes: excludeSavedShopCodes,
    now: t,
  );
  final aggregate = ProductCatalogShopAggregator.aggregate(
    repository: repository,
    excludeSavedShopCodes: excludeSavedShopCodes,
    now: t,
  );

  var avgItemCount = 0.0;
  if (aggregate.candidates.isNotEmpty) {
    var sum = 0;
    for (final c in aggregate.candidates) {
      sum += c.itemCount;
    }
    avgItemCount = sum / aggregate.candidates.length;
  }

  // 施策A: search/high 由来で同一 shop に複数商品
  final searchByShop = <String, int>{};
  for (final p in products) {
    if (p.source != CatalogProductSource.search) continue;
    if (p.sourceTrust != CatalogProductSourceTrust.high) continue;
    final code = p.shopCode.trim();
    if (code.isEmpty) continue;
    searchByShop[code] = (searchByShop[code] ?? 0) + 1;
  }
  var searchMultiShops = 0;
  var searchProductSum = 0;
  for (final count in searchByShop.values) {
    searchProductSum += count;
    if (count >= 2) searchMultiShops++;
  }
  final searchAvgPerShop = searchByShop.isEmpty
      ? 0.0
      : searchProductSum / searchByShop.length;

  final poolByCode = {
    for (final c in aggregate.candidates) c.shopCode.trim(): c.itemCount,
  };

  // 施策C: shopDiscovery 由来ショップのうち pool itemCount<=1
  var shopDiscoverySingleInPool = 0;
  final shopDiscoveryShops = <String>{};
  for (final p in products) {
    if (p.source != CatalogProductSource.shopDiscovery) continue;
    final code = p.shopCode.trim();
    if (code.isEmpty) continue;
    shopDiscoveryShops.add(code);
  }
  for (final code in shopDiscoveryShops) {
    if ((poolByCode[code] ?? 0) <= 1) shopDiscoverySingleInPool++;
  }

  // 施策E: stale だが shopCode/itemName/genreId は保持
  var staleLongLivedFields = 0;
  for (final p in products) {
    if (!repository.isStale(p, now: t)) continue;
    if (isStaleUsableForDepthOnly(p)) staleLongLivedFields++;
  }

  catalogAuditLog(
    '[PHASE3I_STRATEGY_AUDIT] '
    'current_poolCandidates=${aggregate.candidates.length} '
    'current_avgItemCount=${avgItemCount.toStringAsFixed(2)} '
    'current_itemCount2Plus=${staleProjection.currentItemCount2Plus} '
    'strategyA_searchMultiProductShops=$searchMultiShops '
    'strategyA_searchAvgProductsPerShop=${searchAvgPerShop.toStringAsFixed(2)} '
    'strategyB_note=see_SHOP_DISCOVERY_ENRICHMENT_OPPORTUNITY '
    'strategyC_shopDiscoveryProductsInSinglePool=$shopDiscoverySingleInPool '
    'strategyD_staleUsableForDepth=${staleProjection.staleUsableForDepth} '
    'strategyD_wouldItemCount2Plus=${staleProjection.wouldItemCount2PlusIfStaleDepthAllowed} '
    'strategyE_staleLongLivedFields=$staleLongLivedFields',
  );
}
