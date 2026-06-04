import '../models/shop_catalog_entry.dart';
import '../models/shop_discovery_summary.dart';
import '../models/shop_pool_candidate.dart';
import '../repository/product_catalog_repository.dart';
import '../services/shop_discovery_pool_comparator.dart';
import '../services/shop_discovery_pool_fallback.dart';
import '../services/shop_discovery_pool_quality_report.dart';
import '../services/shop_pool_keyword_relevance.dart';

class ShopDiscoveryApiQualitySummary {
  const ShopDiscoveryApiQualitySummary({
    required this.count,
    required this.avgScore,
    required this.avgReview,
    required this.maxReviewCount,
    required this.avgHitItemCount,
    required this.withImageCount,
    required this.withShopUrlCount,
    required this.genreCount,
    required this.topGenres,
    required this.duplicateShopCount,
  });

  final int count;
  final double avgScore;
  final double avgReview;
  final int maxReviewCount;
  final double avgHitItemCount;
  final int withImageCount;
  final int withShopUrlCount;
  final int genreCount;
  final List<String> topGenres;
  final int duplicateShopCount;

  static ShopDiscoveryApiQualitySummary fromSummaries(
    List<ShopDiscoverySummary> summaries,
  ) {
    if (summaries.isEmpty) {
      return const ShopDiscoveryApiQualitySummary(
        count: 0,
        avgScore: 0,
        avgReview: 0,
        maxReviewCount: 0,
        avgHitItemCount: 0,
        withImageCount: 0,
        withShopUrlCount: 0,
        genreCount: 0,
        topGenres: <String>[],
        duplicateShopCount: 0,
      );
    }

    var scoreSum = 0.0;
    var reviewSum = 0.0;
    var hitItemSum = 0;
    var maxReviewCount = 0;
    var withImageCount = 0;
    var withShopUrlCount = 0;
    final seen = <String>{};
    var duplicateShopCount = 0;

    for (final summary in summaries) {
      scoreSum += summary.discoveryScore;
      reviewSum += summary.avgReviewAverage;
      hitItemSum += summary.hitItemCount;
      if (summary.maxReviewCount > maxReviewCount) {
        maxReviewCount = summary.maxReviewCount;
      }
      if (summary.shopUrl.trim().isNotEmpty) withShopUrlCount++;
      if (summary.representativeItems.any(
        (e) => ShopDiscoveryPoolFallback.hasDisplayableImageUrl(e.imageUrl),
      )) {
        withImageCount++;
      }
      if (!seen.add(summary.shopKey)) duplicateShopCount++;
    }

    return ShopDiscoveryApiQualitySummary(
      count: summaries.length,
      avgScore: scoreSum / summaries.length,
      avgReview: reviewSum / summaries.length,
      maxReviewCount: maxReviewCount,
      avgHitItemCount: hitItemSum / summaries.length,
      withImageCount: withImageCount,
      withShopUrlCount: withShopUrlCount,
      genreCount: 0,
      topGenres: const <String>[],
      duplicateShopCount: duplicateShopCount,
    );
  }
}

class ShopDiscoveryApiCompareTopEntry {
  const ShopDiscoveryApiCompareTopEntry({
    required this.shopCode,
    required this.shopName,
    required this.score,
    required this.hitItemCount,
  });

  final String shopCode;
  final String shopName;
  final double score;
  final int hitItemCount;

  String toLogString() {
    return 'shopCode:$shopCode,shopName:$shopName,'
        'score:${score.toStringAsFixed(1)},hitItems:$hitItemCount';
  }
}

class ShopDiscoveryPoolApiCompareTopEntry {
  const ShopDiscoveryPoolApiCompareTopEntry({
    required this.shopCode,
    required this.shopName,
    required this.score,
    required this.hitItemCount,
    required this.relevanceLevel,
  });

  final String shopCode;
  final String shopName;
  final double score;
  final int hitItemCount;
  final ShopPoolKeywordMatchLevel relevanceLevel;

  String toLogString() {
    return 'shopCode:$shopCode,shopName:$shopName,'
        'score:${score.toStringAsFixed(1)},hitItems:$hitItemCount,'
        'relevance:${relevanceLevel.name}';
  }
}

class ShopDiscoveryPoolApiCompareResult {
  const ShopDiscoveryPoolApiCompareResult({
    required this.keyword,
    required this.comparison,
    required this.apiQuality,
    required this.poolQuality,
    required this.apiTopEntries,
    required this.poolTopEntries,
    required this.overlapTopShopCodes,
    required this.wouldBeUsableAsSupplement,
    required this.wouldBeUsableAsReplacement,
    required this.poolTopCount,
  });

  final String keyword;
  final ShopDiscoveryPoolComparisonResult comparison;
  final ShopDiscoveryApiQualitySummary apiQuality;
  final ShopPoolFallbackQualityReport? poolQuality;
  final List<ShopDiscoveryApiCompareTopEntry> apiTopEntries;
  final List<ShopDiscoveryPoolApiCompareTopEntry> poolTopEntries;
  final List<String> overlapTopShopCodes;
  final bool wouldBeUsableAsSupplement;
  final bool wouldBeUsableAsReplacement;
  final int poolTopCount;

  String buildQualityLogLine() {
    final pool = poolQuality;
    final keywordForLog = keyword.isEmpty ? '-' : keyword;
    return '[SHOP_DISCOVERY_POOL_API_COMPARE_QUALITY] '
        'keyword=$keywordForLog '
        'apiSummaryCount=${comparison.apiSummaryCount} '
        'poolCandidateCount=${comparison.poolCandidateCount} '
        'poolTopCount=$poolTopCount '
        'overlapByShopCode=${comparison.overlapByShopCodeCount} '
        'overlapRate=${comparison.overlapRate.toStringAsFixed(3)} '
        'apiOnly=${comparison.apiOnlyCount} '
        'poolOnly=${comparison.poolOnlyCount} '
        'apiAvgScore=${apiQuality.avgScore.toStringAsFixed(1)} '
        'poolAvgScore=${pool?.avgScore.toStringAsFixed(1) ?? '0.0'} '
        'apiAvgReview=${apiQuality.avgReview.toStringAsFixed(2)} '
        'poolAvgReview=${pool?.avgReview.toStringAsFixed(2) ?? '0.00'} '
        'apiAvgHitItemCount=${apiQuality.avgHitItemCount.toStringAsFixed(1)} '
        'poolAvgHitItemCount=${pool?.avgHitItemCount.toStringAsFixed(1) ?? '0.0'} '
        'apiWithImageCount=${apiQuality.withImageCount} '
        'poolWithImageCount=${pool?.withImageCount ?? 0} '
        'apiGenreCount=${apiQuality.genreCount} '
        'poolGenreCount=${pool?.genreCount ?? 0} '
        'apiTopGenres=${apiQuality.topGenres.isEmpty ? '-' : apiQuality.topGenres.join(',')} '
        'poolTopGenres=${pool == null || pool.topGenres.isEmpty ? '-' : pool.topGenres.join(',')} '
        'poolQualityLevel=${pool?.qualityLevel.name ?? 'insufficient'} '
        'poolDepthQuality=${pool?.depthQuality.name ?? 'insufficient'} '
        'poolDisplayQuality=${pool?.displayQuality.name ?? 'insufficient'} '
        'poolRelevanceQuality=${pool?.relevanceQuality.name ?? 'insufficient'} '
        'wouldBeUsableAsSupplement=$wouldBeUsableAsSupplement '
        'wouldBeUsableAsReplacement=$wouldBeUsableAsReplacement '
        'willUsePoolForUi=false willSkipApi=false';
  }

  String buildTopLogLine() {
    final keywordForLog = keyword.isEmpty ? '-' : keyword;
    return '[SHOP_DISCOVERY_POOL_API_COMPARE_TOP] '
        'keyword=$keywordForLog '
        'apiTop1=${_slot(apiTopEntries, 0)} '
        'apiTop2=${_slot(apiTopEntries, 1)} '
        'apiTop3=${_slot(apiTopEntries, 2)} '
        'poolTop1=${_poolSlot(poolTopEntries, 0)} '
        'poolTop2=${_poolSlot(poolTopEntries, 1)} '
        'poolTop3=${_poolSlot(poolTopEntries, 2)} '
        'overlapTop=${overlapTopShopCodes.isEmpty ? '-' : overlapTopShopCodes.join(',')}';
  }

  static String _slot(List<ShopDiscoveryApiCompareTopEntry> entries, int index) {
    if (index >= entries.length) return '-';
    return entries[index].toLogString();
  }

  static String _poolSlot(
    List<ShopDiscoveryPoolApiCompareTopEntry> entries,
    int index,
  ) {
    if (index >= entries.length) return '-';
    return entries[index].toLogString();
  }
}

abstract final class ShopDiscoveryPoolApiCompare {
  static ShopDiscoveryPoolApiCompareResult build({
    required String keyword,
    required List<ShopDiscoverySummary> apiSummaries,
    required List<ShopPoolCandidate> poolCandidates,
    required List<ShopCatalogEntry> catalogEntries,
    required ProductCatalogRepository? repository,
    Set<String> savedShopCodes = const <String>{},
    int poolTopLimit = 10,
    int topLogLimit = 3,
    int aggregateStatsSavedExcluded = 0,
    int aggregateStatsUnsafeExcluded = 0,
  }) {
    final comparison = ShopDiscoveryPoolComparator.compare(
      apiSummaries: apiSummaries,
      poolCandidates: poolCandidates,
      catalogEntries: catalogEntries,
      savedShopCodes: savedShopCodes,
      topLimit: topLogLimit,
    );

    final auditData = ShopDiscoveryPoolFallback.buildCompareAuditData(
      repository: repository,
      keyword: keyword,
      candidates: poolCandidates,
      maxCount: poolTopLimit,
    );

    final poolQuality = auditData == null
        ? null
        : ShopPoolFallbackQualityReport.fromCompareAudit(
            auditData,
            savedExcluded: aggregateStatsSavedExcluded,
            invalidExcluded: auditData.skippedInvalidCount,
            unsafeExcluded: aggregateStatsUnsafeExcluded,
          );

    final apiQuality = ShopDiscoveryApiQualitySummary.fromSummaries(
      apiSummaries,
    );

    final apiTopEntries = apiSummaries
        .take(topLogLimit)
        .map(
          (s) => ShopDiscoveryApiCompareTopEntry(
            shopCode: s.shopKey,
            shopName: ShopPoolFallbackQualityReport.truncateShopName(s.shopName),
            score: s.discoveryScore,
            hitItemCount: s.hitItemCount,
          ),
        )
        .toList(growable: false);

    final poolTopEntries = <ShopDiscoveryPoolApiCompareTopEntry>[];
    if (auditData != null) {
      for (final summary in auditData.poolTopSummaries.take(topLogLimit)) {
        final relevance =
            auditData.relevanceByShopCode[summary.shopKey] ??
            ShopPoolKeywordRelevanceResult.none;
        poolTopEntries.add(
          ShopDiscoveryPoolApiCompareTopEntry(
            shopCode: summary.shopKey,
            shopName: ShopPoolFallbackQualityReport.truncateShopName(
              summary.shopName,
            ),
            score: summary.discoveryScore,
            hitItemCount: summary.hitItemCount,
            relevanceLevel: relevance.level,
          ),
        );
      }
    }

    final overlapTop = <String>[];
    for (final code in comparison.topApiShops) {
      if (comparison.topOverlapShops.contains(code) &&
          overlapTop.length < topLogLimit) {
        overlapTop.add(code);
      }
    }

    final wouldBeUsableAsSupplement = evaluateWouldBeUsableAsSupplement(
      comparison: comparison,
      poolQuality: poolQuality,
    );
    final wouldBeUsableAsReplacement = evaluateWouldBeUsableAsReplacement(
      comparison: comparison,
      poolQuality: poolQuality,
      apiTopGenres: apiQuality.topGenres,
    );

    return ShopDiscoveryPoolApiCompareResult(
      keyword: keyword,
      comparison: comparison,
      apiQuality: apiQuality,
      poolQuality: poolQuality,
      apiTopEntries: apiTopEntries,
      poolTopEntries: poolTopEntries,
      overlapTopShopCodes: overlapTop,
      wouldBeUsableAsSupplement: wouldBeUsableAsSupplement,
      wouldBeUsableAsReplacement: wouldBeUsableAsReplacement,
      poolTopCount: auditData?.poolTopSummaries.length ?? 0,
    );
  }

  static bool evaluateWouldBeUsableAsSupplement({
    required ShopDiscoveryPoolComparisonResult comparison,
    required ShopPoolFallbackQualityReport? poolQuality,
  }) {
    final pool = poolQuality;
    if (pool == null) return false;
    if (comparison.poolCandidateCount < 10) return false;
    if (!_qualityAtLeastGood(pool.qualityLevel)) return false;
    if (!_depthAtLeastGood(pool.depthQuality)) return false;
    if (pool.withImageCount < 8) return false;

    final overlapOk = comparison.overlapRate >= 0.3;
    final depthOk =
        pool.avgHitItemCount >= 3.0 || pool.hitItemCount2Plus >= 5;
    return overlapOk || depthOk;
  }

  static bool evaluateWouldBeUsableAsReplacement({
    required ShopDiscoveryPoolComparisonResult comparison,
    required ShopPoolFallbackQualityReport? poolQuality,
    required List<String> apiTopGenres,
  }) {
    final pool = poolQuality;
    if (pool == null) return false;
    if (comparison.poolCandidateCount < 10) return false;
    if (!_qualityAtLeastGood(pool.qualityLevel)) return false;
    if (comparison.overlapRate < 0.6) return false;
    if (pool.avgHitItemCount < 3.0) return false;
    if (pool.withImageCount < 9) return false;
    if (!_genresAlignWell(apiTopGenres, pool.topGenres)) return false;
    return true;
  }

  static bool _qualityAtLeastGood(ShopPoolFallbackQualityLevel level) {
    return level == ShopPoolFallbackQualityLevel.excellent ||
        level == ShopPoolFallbackQualityLevel.good;
  }

  static bool _depthAtLeastGood(ShopPoolFallbackDepthQuality depth) {
    return depth == ShopPoolFallbackDepthQuality.excellent ||
        depth == ShopPoolFallbackDepthQuality.good;
  }

  static bool _genresAlignWell(
    List<String> apiTopGenres,
    List<String> poolTopGenres,
  ) {
    final apiNames = _genreNames(apiTopGenres);
    final poolNames = _genreNames(poolTopGenres);
    if (apiNames.isEmpty || poolNames.isEmpty) return true;
    return apiNames.intersection(poolNames).isNotEmpty;
  }

  static Set<String> _genreNames(List<String> topGenres) {
    final names = <String>{};
    for (final entry in topGenres) {
      final name = entry.split(':').first.trim();
      if (name.isEmpty || name == 'unknown' || name == '-') continue;
      names.add(name);
    }
    return names;
  }
}
