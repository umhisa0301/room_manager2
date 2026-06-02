import '../config/debug_log_flags.dart';
import '../models/shop_pool_candidate.dart';
import '../repository/product_catalog_repository.dart';
import '../services/shop_discovery_pool_fallback.dart';
import '../services/shop_pool_keyword_relevance.dart';
import 'app_debug_log.dart';
import 'product_catalog_audit.dart';

/// ShopPool 候補の厚み・ジャンル分布（[CATALOG_AUDIT_LOGS] 時のみ）。
void logShopPoolDepthSummary({
  required String source,
  required List<ShopPoolCandidate> candidates,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;

  final count = candidates.length;
  if (count == 0) {
    catalogAuditLog(
      '[SHOP_POOL_DEPTH_SUMMARY] source=$source candidateCount=0 '
      'avgItemCount=0 itemCount1=0 itemCount2Plus=0 '
      'withPrimaryGenre=0 unknownPrimaryGenre=0 '
      'withSourceProductIds=0 avgSourceProductIds=0 '
      'withSampleProductIds=0 avgSampleProductIds=0',
    );
    return;
  }

  var itemCount1 = 0;
  var itemCount2Plus = 0;
  var itemSum = 0;
  var withPrimaryGenre = 0;
  var unknownPrimaryGenre = 0;
  var withSourceProductIds = 0;
  var sourceIdSum = 0;
  var withSampleProductIds = 0;
  var sampleIdSum = 0;

  for (final c in candidates) {
    itemSum += c.itemCount;
    if (c.itemCount <= 1) {
      itemCount1++;
    } else {
      itemCount2Plus++;
    }
    if (c.primaryGenreId.trim().isNotEmpty ||
        c.primaryGenreName.trim().isNotEmpty) {
      withPrimaryGenre++;
    }
    if (ShopPoolKeywordRelevance.isUnknownGenre(c)) {
      unknownPrimaryGenre++;
    }
    if (c.sourceProductIds.isNotEmpty) {
      withSourceProductIds++;
      sourceIdSum += c.sourceProductIds.length;
    }
    if (c.sampleProductIds.isNotEmpty) {
      withSampleProductIds++;
      sampleIdSum += c.sampleProductIds.length;
    }
  }

  final avgItem = itemSum / count;
  final avgSourceIds = withSourceProductIds == 0
      ? 0.0
      : sourceIdSum / withSourceProductIds;
  final avgSampleIds = withSampleProductIds == 0
      ? 0.0
      : sampleIdSum / withSampleProductIds;

  catalogAuditLog(
    '[SHOP_POOL_DEPTH_SUMMARY] '
    'source=$source candidateCount=$count '
    'avgItemCount=${avgItem.toStringAsFixed(1)} '
    'itemCount1=$itemCount1 itemCount2Plus=$itemCount2Plus '
    'withPrimaryGenre=$withPrimaryGenre '
    'unknownPrimaryGenre=$unknownPrimaryGenre '
    'withSourceProductIds=$withSourceProductIds '
    'avgSourceProductIds=${avgSourceIds.toStringAsFixed(1)} '
    'withSampleProductIds=$withSampleProductIds '
    'avgSampleProductIds=${avgSampleIds.toStringAsFixed(1)}',
  );
}

/// fallback 適用時の keyword / catalog 参照診断（[CATALOG_AUDIT_LOGS] 時のみ）。
void logShopPoolFallbackDiag({
  required ProductCatalogRepository repository,
  required String keyword,
  required ShopDiscoveryPoolFallbackResult fallback,
}) {
  if (!DebugLogFlags.kCatalogAuditLogsEnabled) return;
  if (!fallback.usedFallback) return;

  logProductCatalogDistributionSummary(repository);

  var matchedByItemName = 0;
  var matchedByGenre = 0;
  var matchedByShopName = 0;
  var missingCatalogProductRefs = 0;
  var unknownGenreInFallback = 0;
  var hitItemCount1 = 0;
  var hitItemCount2Plus = 0;
  var catalogRefChecks = 0;

  final displayedByCode = <String, ShopPoolCandidate>{
    for (final c in fallback.displayedCandidates) c.shopCode.trim(): c,
  };

  for (final summary in fallback.summaries) {
    if (summary.hitItemCount <= 1) {
      hitItemCount1++;
    } else {
      hitItemCount2Plus++;
    }
    final relevance =
        fallback.relevanceByShopCode[summary.shopKey] ??
        ShopPoolKeywordRelevanceResult.none;
    switch (relevance.matchedBy) {
      case 'itemName':
        matchedByItemName++;
      case 'genreName':
        matchedByGenre++;
      case 'shopName':
        matchedByShopName++;
      default:
        break;
    }
    final candidate = displayedByCode[summary.shopKey];
    if (candidate != null &&
        ShopPoolKeywordRelevance.isUnknownGenre(candidate)) {
      unknownGenreInFallback++;
    }
    if (candidate != null) {
      for (final id in <String>{
        ...candidate.sourceProductIds,
        ...candidate.sampleProductIds,
      }) {
        if (id.trim().isEmpty) continue;
        catalogRefChecks++;
        if (repository.getByCanonicalId(id, touch: false) == null) {
          missingCatalogProductRefs++;
        }
      }
    }
  }

  catalogAuditLog(
    '[SHOP_POOL_FALLBACK_DIAG] '
    'keyword=${keyword.isEmpty ? '-' : keyword} '
    'fallbackCount=${fallback.summaries.length} '
    'matchedByItemName=$matchedByItemName '
    'matchedByGenre=$matchedByGenre '
    'matchedByShopName=$matchedByShopName '
    'missingCatalogProductRefs=$missingCatalogProductRefs '
    'catalogRefChecks=$catalogRefChecks '
    'unknownGenreInFallback=$unknownGenreInFallback '
    'hitItemCount1=$hitItemCount1 '
    'hitItemCount2Plus=$hitItemCount2Plus',
  );
}
