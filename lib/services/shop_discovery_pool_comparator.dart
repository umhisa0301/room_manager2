import '../models/shop_catalog_entry.dart';
import '../models/shop_discovery_summary.dart';
import '../models/shop_pool_candidate.dart';

class ShopDiscoveryPoolComparisonResult {
  const ShopDiscoveryPoolComparisonResult({
    required this.apiSummaryCount,
    required this.poolCandidateCount,
    required this.poolCandidateCountBeforeSavedExclude,
    required this.poolCandidateCountAfterSavedExclude,
    required this.catalogShopCount,
    required this.overlapByShopCodeCount,
    required this.apiOnlyCount,
    required this.poolOnlyCount,
    required this.catalogOnlyCount,
    required this.savedExcludedCount,
    required this.topApiShops,
    required this.topPoolShops,
    required this.topOverlapShops,
    required this.missingReasonSummary,
    required this.poolTopScoreMax,
    required this.poolTopScoreMin,
    required this.apiTopScoreMax,
    required this.catalogShopTotal,
    required this.poolHasEnoughCandidatesForDisplay,
    required this.overlapRate,
  });

  final int apiSummaryCount;
  final int poolCandidateCount;
  final int poolCandidateCountBeforeSavedExclude;
  final int poolCandidateCountAfterSavedExclude;
  final int catalogShopCount;
  final int overlapByShopCodeCount;
  final int apiOnlyCount;
  final int poolOnlyCount;
  final int catalogOnlyCount;
  final int savedExcludedCount;
  final List<String> topApiShops;
  final List<String> topPoolShops;
  final List<String> topOverlapShops;
  final Map<String, int> missingReasonSummary;
  final double poolTopScoreMax;
  final double poolTopScoreMin;
  final double apiTopScoreMax;
  final int catalogShopTotal;
  final bool poolHasEnoughCandidatesForDisplay;
  final double overlapRate;
}

abstract final class ShopDiscoveryPoolComparator {
  static String buildDedupeSignature({
    required String mode,
    required String keyword,
    required List<ShopDiscoverySummary> apiSummaries,
    required int poolCandidateCount,
    required int catalogShopCount,
    int apiTopLimit = 10,
  }) {
    final apiTopCodes = <String>[];
    for (final s in apiSummaries) {
      final code = s.shopKey.trim();
      if (code.isEmpty || code == 'unknown') continue;
      apiTopCodes.add(code);
      if (apiTopCodes.length >= apiTopLimit) break;
    }
    return 'mode=$mode|keyword=${keyword.trim()}|apiTop=${apiTopCodes.join(",")}|'
        'pool=$poolCandidateCount|catalog=$catalogShopCount';
  }

  static ShopDiscoveryPoolComparisonResult compare({
    required List<ShopDiscoverySummary> apiSummaries,
    required List<ShopPoolCandidate> poolCandidates,
    required List<ShopCatalogEntry> catalogEntries,
    Set<String> savedShopCodes = const <String>{},
    int topLimit = 3,
  }) {
    final normalizedSaved = savedShopCodes
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    final apiCodes = <String>{};
    final topApi = <String>[];
    for (final s in apiSummaries) {
      final code = s.shopKey.trim();
      if (code.isEmpty || code == 'unknown') continue;
      apiCodes.add(code);
      if (topApi.length < topLimit) topApi.add(code);
    }

    final poolCodesBeforeSavedExclude = <String>{};
    final poolCodesAfterSavedExclude = <String>{};
    final topPool = <String>[];
    var savedExcludedCount = 0;
    var poolTopScoreMax = 0.0;
    var poolTopScoreMin = 0.0;
    var poolHasScore = false;
    for (final p in poolCandidates) {
      final code = p.shopCode.trim();
      if (code.isEmpty) continue;
      poolCodesBeforeSavedExclude.add(code);
      if (normalizedSaved.contains(code)) {
        savedExcludedCount++;
        continue;
      }
      poolCodesAfterSavedExclude.add(code);
      if (topPool.length < topLimit) topPool.add(code);
      if (!poolHasScore) {
        poolTopScoreMax = p.score;
        poolTopScoreMin = p.score;
        poolHasScore = true;
      } else {
        if (p.score > poolTopScoreMax) poolTopScoreMax = p.score;
        if (p.score < poolTopScoreMin) poolTopScoreMin = p.score;
      }
    }

    final catalogCodes = <String>{};
    for (final c in catalogEntries) {
      final code = c.shopCode.trim();
      if (code.isEmpty) continue;
      catalogCodes.add(code);
    }

    final overlap = apiCodes.intersection(poolCodesAfterSavedExclude);
    final topOverlap = <String>[];
    for (final code in topApi) {
      if (overlap.contains(code) && topOverlap.length < topLimit) {
        topOverlap.add(code);
      }
    }

    var apiTopScoreMax = 0.0;
    for (final s in apiSummaries) {
      if (s.discoveryScore > apiTopScoreMax) {
        apiTopScoreMax = s.discoveryScore;
      }
    }

    final apiOnly = apiCodes.difference(poolCodesAfterSavedExclude);
    final poolOnly = poolCodesAfterSavedExclude.difference(apiCodes);
    final catalogOnly = catalogCodes
        .difference(apiCodes)
        .difference(poolCodesAfterSavedExclude);

    final baseForRate = apiCodes.length;
    final overlapRate = baseForRate <= 0
        ? 0.0
        : overlap.length / baseForRate;

    return ShopDiscoveryPoolComparisonResult(
      apiSummaryCount: apiCodes.length,
      poolCandidateCount: poolCodesAfterSavedExclude.length,
      poolCandidateCountBeforeSavedExclude: poolCodesBeforeSavedExclude.length,
      poolCandidateCountAfterSavedExclude: poolCodesAfterSavedExclude.length,
      catalogShopCount: catalogCodes.length,
      overlapByShopCodeCount: overlap.length,
      apiOnlyCount: apiOnly.length,
      poolOnlyCount: poolOnly.length,
      catalogOnlyCount: catalogOnly.length,
      savedExcludedCount: savedExcludedCount,
      topApiShops: topApi.take(topLimit).toList(growable: false),
      topPoolShops: topPool.take(topLimit).toList(growable: false),
      topOverlapShops: topOverlap.take(topLimit).toList(growable: false),
      missingReasonSummary: <String, int>{
        'apiOnly': apiOnly.length,
        'poolOnly': poolOnly.length,
        'catalogOnly': catalogOnly.length,
      },
      poolTopScoreMax: poolHasScore ? poolTopScoreMax : 0,
      poolTopScoreMin: poolHasScore ? poolTopScoreMin : 0,
      apiTopScoreMax: apiTopScoreMax,
      catalogShopTotal: catalogEntries.length,
      poolHasEnoughCandidatesForDisplay: poolCodesAfterSavedExclude.length >= 10,
      overlapRate: overlapRate,
    );
  }
}
