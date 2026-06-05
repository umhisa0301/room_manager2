import '../models/shop_discovery_summary.dart';
import '../models/shop_pool_candidate.dart';
import '../repository/product_catalog_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../services/shop_discovery_pool_api_compare.dart';
import '../services/shop_discovery_pool_comparator.dart';
import '../services/shop_discovery_pool_fallback.dart';
import '../services/shop_discovery_pool_quality_report.dart';
import '../services/shop_pool_keyword_relevance.dart';
import '../utils/product_safety_filter.dart';
import '../utils/shop_display_resolve.dart';

enum ShopDiscoveryPoolSupplementReason {
  highPoolScore,
  highHitItemCount,
  strongRelevance,
  apiMissingButPoolStrong,
  genreComplement,
  rejectedAlreadyInApi,
  rejectedWeakQuality,
  rejectedNoImage,
  rejectedSavedShop,
  rejectedWeakRelevance,
  rejectedHitItemCount,
  rejectedNoShopUrl,
  rejectedStale,
  rejectedUnsafe,
}

class ShopDiscoveryPoolSupplementCandidate {
  const ShopDiscoveryPoolSupplementCandidate({
    required this.rank,
    required this.shopCode,
    required this.shopName,
    required this.score,
    required this.relevance,
    required this.matchedBy,
    required this.hitItemCount,
    required this.avgReview,
    required this.maxReviewCount,
    required this.primaryGenreName,
    required this.hasImage,
    required this.hasShopUrl,
    required this.reason,
  });

  final int rank;
  final String shopCode;
  final String shopName;
  final double score;
  final ShopPoolKeywordMatchLevel relevance;
  final String matchedBy;
  final int hitItemCount;
  final double avgReview;
  final int maxReviewCount;
  final String primaryGenreName;
  final bool hasImage;
  final bool hasShopUrl;
  final ShopDiscoveryPoolSupplementReason reason;

  String toTopLogString() {
    return 'shopCode:$shopCode,shopName:$shopName,'
        'score:${score.toStringAsFixed(1)},hitItems:$hitItemCount,'
        'relevance:${relevance.name},reason:${reason.name}';
  }
}

class ShopDiscoveryPoolSupplementResult {
  const ShopDiscoveryPoolSupplementResult({
    required this.keyword,
    required this.comparison,
    required this.poolQuality,
    required this.apiQuality,
    required this.eligibleSupplementCount,
    required this.selectedSupplements,
    required this.zeroReason,
    required this.wouldShowSupplementIfEnabled,
    required this.apiWeakSignal,
    required this.apiWeakReason,
    required this.poolCouldCoverApiWeakness,
  });

  final String keyword;
  final ShopDiscoveryPoolComparisonResult comparison;
  final ShopPoolFallbackQualityReport? poolQuality;
  final ShopDiscoveryApiQualitySummary apiQuality;
  final int eligibleSupplementCount;
  final List<ShopDiscoveryPoolSupplementCandidate> selectedSupplements;
  final String zeroReason;
  final bool wouldShowSupplementIfEnabled;
  final bool apiWeakSignal;
  final String apiWeakReason;
  final bool poolCouldCoverApiWeakness;

  static final empty = ShopDiscoveryPoolSupplementResult(
    keyword: '',
    comparison: _emptyComparison,
    poolQuality: null,
    apiQuality: const ShopDiscoveryApiQualitySummary(
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
    ),
    eligibleSupplementCount: 0,
    selectedSupplements: const <ShopDiscoveryPoolSupplementCandidate>[],
    zeroReason: 'noApiSummaries',
    wouldShowSupplementIfEnabled: false,
    apiWeakSignal: false,
    apiWeakReason: '',
    poolCouldCoverApiWeakness: false,
  );

  static final _emptyComparison = ShopDiscoveryPoolComparisonResult(
    apiSummaryCount: 0,
    poolCandidateCount: 0,
    poolCandidateCountBeforeSavedExclude: 0,
    poolCandidateCountAfterSavedExclude: 0,
    catalogShopCount: 0,
    overlapByShopCodeCount: 0,
    apiOnlyCount: 0,
    poolOnlyCount: 0,
    catalogOnlyCount: 0,
    savedExcludedCount: 0,
    topApiShops: const <String>[],
    topPoolShops: const <String>[],
    topOverlapShops: const <String>[],
    missingReasonSummary: const <String, int>{},
    poolTopScoreMax: 0,
    poolTopScoreMin: 0,
    apiTopScoreMax: 0,
    catalogShopTotal: 0,
    poolHasEnoughCandidatesForDisplay: false,
    overlapRate: 0,
  );

  String buildSummaryLogLine() {
    final keywordForLog = keyword.isEmpty ? '-' : keyword;
    final pool = poolQuality;
    final base =
        '[SHOP_DISCOVERY_POOL_SUPPLEMENT_SUMMARY] keyword=$keywordForLog '
        'apiSummaryCount=${comparison.apiSummaryCount} '
        'poolCandidateCount=${comparison.poolCandidateCount} '
        'eligibleSupplementCount=$eligibleSupplementCount '
        'selectedSupplementCount=${selectedSupplements.length} '
        'apiOverlapCount=${comparison.overlapByShopCodeCount} '
        'apiOnly=${comparison.apiOnlyCount} '
        'poolOnly=${comparison.poolOnlyCount} '
        'poolQualityLevel=${pool?.qualityLevel.name ?? 'insufficient'} '
        'poolDepthQuality=${pool?.depthQuality.name ?? 'insufficient'} '
        'wouldShowSupplementIfEnabled=$wouldShowSupplementIfEnabled '
        'apiWeakSignal=$apiWeakSignal '
        'apiWeakReason=${apiWeakReason.isEmpty ? '-' : apiWeakReason} '
        'poolCouldCoverApiWeakness=$poolCouldCoverApiWeakness '
        'willUsePoolForUi=false willSkipApi=false';

    if (selectedSupplements.isEmpty) {
      return '$base reason=${zeroReason.isEmpty ? '-' : zeroReason}';
    }
    return base;
  }

  String buildTopLogLine() {
    final keywordForLog = keyword.isEmpty ? '-' : keyword;
    final s = selectedSupplements;
    return '[SHOP_DISCOVERY_POOL_SUPPLEMENT_TOP] keyword=$keywordForLog '
        'supplement1=${_slot(s, 0)} '
        'supplement2=${_slot(s, 1)} '
        'supplement3=${_slot(s, 2)}';
  }

  static String _slot(List<ShopDiscoveryPoolSupplementCandidate> entries, int i) {
    if (i >= entries.length) return '-';
    return entries[i].toTopLogString();
  }
}

abstract final class ShopDiscoveryPoolSupplement {
  static const int maxSelectedCount = 3;

  static ShopDiscoveryPoolSupplementResult build({
    required String keyword,
    required List<ShopDiscoverySummary> apiSummaries,
    required List<ShopPoolCandidate> poolCandidates,
    required ShopDiscoveryPoolComparisonResult comparison,
    required ShopPoolFallbackQualityReport? poolQuality,
    ProductCatalogRepository? repository,
    Set<String> savedShopCodes = const <String>{},
    Set<String> apiReferenceGenreNames = const <String>{},
    RakutenKeywordSearchStopReason? apiStopReason,
    int apiPagesFailed = 0,
    DateTime? now,
  }) {
    if (apiSummaries.isEmpty || poolCandidates.isEmpty) {
      return ShopDiscoveryPoolSupplementResult.empty;
    }

    final apiQuality = ShopDiscoveryApiQualitySummary.fromSummaries(apiSummaries);
    final apiShopCodes = apiSummaries
        .map((e) => e.shopKey.trim())
        .where((e) => e.isNotEmpty && e != 'unknown')
        .toSet();
    final saved = savedShopCodes
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final t = now ?? DateTime.now();

    final apiGenreNames = apiReferenceGenreNames;
    final poolAvgScore = _poolAverageScore(poolCandidates);
    final poolQualityGood = poolQuality != null &&
        _qualityAtLeastGood(poolQuality.qualityLevel);

    final eligible = <_EligibleEntry>[];

    for (final candidate in poolCandidates) {
      final code = candidate.shopCode.trim();
      if (code.isEmpty || code == 'unknown') continue;

      if (apiShopCodes.contains(code)) continue;
      if (saved.contains(code)) continue;

      final relevance = ShopPoolKeywordRelevance.evaluate(
        repository: repository,
        keyword: keyword,
        candidate: candidate,
      );
      if (relevance.level != ShopPoolKeywordMatchLevel.strong &&
          relevance.level != ShopPoolKeywordMatchLevel.medium) {
        continue;
      }

      if (candidate.itemCount < 2) continue;

      final shopUrl = candidate.shopUrl.trim();
      if (shopUrl.isEmpty ||
          !RegExp(r'^https?://', caseSensitive: false).hasMatch(shopUrl)) {
        continue;
      }

      if (!ShopDiscoveryPoolFallback.hasDisplayableImageUrl(
        candidate.representativeImageUrl,
      )) {
        continue;
      }

      if (repository != null) {
        if (_shopHasUnsafeProducts(repository, code)) continue;
        if (!_shopHasFreshProducts(repository, code, t)) continue;
      } else if (candidate.safeItemCount <= 0) {
        continue;
      }

      if (!poolQualityGood &&
          !_candidateIndividuallyHighQuality(candidate, poolAvgScore)) {
        continue;
      }

      final resolvedName = ShopDisplayResolve.resolveDisplayShopName(
        shopName: candidate.shopName,
        shopCode: code,
      );
      if (resolvedName == ShopDisplayResolve.unknownShopLabel) continue;

      final reason = _pickSelectionReason(
        candidate: candidate,
        relevance: relevance,
        apiGenreNames: apiGenreNames,
        poolAvgScore: poolAvgScore,
      );

      eligible.add(
        _EligibleEntry(
          candidate: candidate,
          relevance: relevance,
          shopName: ShopPoolFallbackQualityReport.truncateShopName(resolvedName),
          reason: reason,
        ),
      );
    }

    eligible.sort((a, b) => b.candidate.score.compareTo(a.candidate.score));

    final selected = <ShopDiscoveryPoolSupplementCandidate>[];
    for (var i = 0; i < eligible.length && i < maxSelectedCount; i++) {
      final e = eligible[i];
      selected.add(
        ShopDiscoveryPoolSupplementCandidate(
          rank: i + 1,
          shopCode: e.candidate.shopCode,
          shopName: e.shopName,
          score: e.candidate.score,
          relevance: e.relevance.level,
          matchedBy: e.relevance.matchedBy,
          hitItemCount: e.candidate.itemCount,
          avgReview: e.candidate.averageReviewAverage,
          maxReviewCount: e.candidate.maxReviewCount,
          primaryGenreName: e.candidate.primaryGenreName,
          hasImage: ShopDiscoveryPoolFallback.hasDisplayableImageUrl(
            e.candidate.representativeImageUrl,
          ),
          hasShopUrl: e.candidate.shopUrl.trim().isNotEmpty,
          reason: e.reason,
        ),
      );
    }

    final poolShopCodes = poolCandidates
        .map((e) => e.shopCode.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final weak = evaluateApiWeakSignal(
      apiSummaries: apiSummaries,
      apiQuality: apiQuality,
      comparison: comparison,
      poolShopCodes: poolShopCodes,
      apiStopReason: apiStopReason,
      apiPagesFailed: apiPagesFailed,
    );

    final poolCouldCover = evaluatePoolCouldCoverApiWeakness(
      poolQuality: poolQuality,
      comparison: comparison,
      apiWeakSignal: weak.signal,
    );

    final wouldShow = evaluateWouldShowSupplementIfEnabled(
      selectedCount: selected.length,
      poolQuality: poolQuality,
      comparison: comparison,
    );

    final zeroReason = selected.isEmpty
        ? _zeroReason(
            comparison: comparison,
            poolQuality: poolQuality,
            eligibleCount: eligible.length,
          )
        : '';

    return ShopDiscoveryPoolSupplementResult(
      keyword: keyword,
      comparison: comparison,
      poolQuality: poolQuality,
      apiQuality: apiQuality,
      eligibleSupplementCount: eligible.length,
      selectedSupplements: selected,
      zeroReason: zeroReason,
      wouldShowSupplementIfEnabled: wouldShow,
      apiWeakSignal: weak.signal,
      apiWeakReason: weak.reason,
      poolCouldCoverApiWeakness: poolCouldCover,
    );
  }

  static ApiWeakEvaluation evaluateApiWeakSignal({
    required List<ShopDiscoverySummary> apiSummaries,
    required ShopDiscoveryApiQualitySummary apiQuality,
    required ShopDiscoveryPoolComparisonResult comparison,
    Set<String> poolShopCodes = const <String>{},
    RakutenKeywordSearchStopReason? apiStopReason,
    int apiPagesFailed = 0,
  }) {
    final reasons = <String>[];

    if (apiSummaries.length < 10) {
      reasons.add('apiSummaryCountLow');
    }
    if (apiQuality.avgHitItemCount < 2) {
      reasons.add('apiAvgHitItemCountLow');
    }
    if (apiQuality.withImageCount < apiQuality.count) {
      reasons.add('apiMissingImages');
    }
    if (apiStopReason == RakutenKeywordSearchStopReason.partialFetchFailure ||
        apiPagesFailed > 0) {
      reasons.add('partialApiPagesFailed');
    }

    if (comparison.apiOnlyCount >= 1 && poolShopCodes.isNotEmpty) {
      final apiOnlySummaries = apiSummaries
          .where((s) {
            final code = s.shopKey.trim();
            return code.isNotEmpty && !poolShopCodes.contains(code);
          })
          .toList(growable: false);
      if (apiOnlySummaries.isNotEmpty) {
        final avgOnlyScore = apiOnlySummaries
                .map((e) => e.discoveryScore)
                .reduce((a, b) => a + b) /
            apiOnlySummaries.length;
        if (avgOnlyScore < 200) {
          reasons.add('apiOnlyLowScore');
        }
      }
    }

    return ApiWeakEvaluation(
      signal: reasons.isNotEmpty,
      reason: reasons.join(','),
    );
  }

  static bool evaluatePoolCouldCoverApiWeakness({
    required ShopPoolFallbackQualityReport? poolQuality,
    required ShopDiscoveryPoolComparisonResult comparison,
    required bool apiWeakSignal,
  }) {
    if (!apiWeakSignal) return false;
    final pool = poolQuality;
    if (pool == null) return false;
    if (!_qualityAtLeastGood(pool.qualityLevel)) return false;
    if (!_depthAtLeastGood(pool.depthQuality)) return false;
    if (comparison.poolCandidateCount < 10) return false;
    return comparison.overlapRate >= 0.5 ||
        pool.avgHitItemCount >= 3.0 ||
        pool.hitItemCount2Plus >= 5;
  }

  static bool evaluateWouldShowSupplementIfEnabled({
    required int selectedCount,
    required ShopPoolFallbackQualityReport? poolQuality,
    required ShopDiscoveryPoolComparisonResult comparison,
  }) {
    if (selectedCount <= 0) return false;
    final pool = poolQuality;
    if (pool == null) return false;
    if (!ShopDiscoveryPoolApiCompare.evaluateWouldBeUsableAsSupplement(
      comparison: comparison,
      poolQuality: pool,
    )) {
      return false;
    }
    return comparison.apiOnlyCount > 0 || comparison.overlapRate < 1.0;
  }

  static String _zeroReason({
    required ShopDiscoveryPoolComparisonResult comparison,
    required ShopPoolFallbackQualityReport? poolQuality,
    required int eligibleCount,
  }) {
    if (comparison.poolCandidateCount <= 0) return 'noPoolCandidates';
    if (poolQuality == null) return 'poolQualityUnavailable';
    if (comparison.overlapRate >= 1.0 && comparison.apiOnlyCount == 0) {
      return 'apiAlreadyCoversPoolTop';
    }
    if (eligibleCount <= 0) return 'noEligibleSupplementCandidates';
    return 'supplementNotSelected';
  }

  static ShopDiscoveryPoolSupplementReason _pickSelectionReason({
    required ShopPoolCandidate candidate,
    required ShopPoolKeywordRelevanceResult relevance,
    required Set<String> apiGenreNames,
    required double poolAvgScore,
  }) {
    if (relevance.level == ShopPoolKeywordMatchLevel.strong) {
      return ShopDiscoveryPoolSupplementReason.strongRelevance;
    }
    if (candidate.itemCount >= 5) {
      return ShopDiscoveryPoolSupplementReason.highHitItemCount;
    }
    final genre = candidate.primaryGenreName.trim();
    if (genre.isNotEmpty &&
        apiGenreNames.isNotEmpty &&
        !apiGenreNames.contains(genre)) {
      return ShopDiscoveryPoolSupplementReason.genreComplement;
    }
    if (poolAvgScore > 0 && candidate.score >= poolAvgScore * 1.05) {
      return ShopDiscoveryPoolSupplementReason.highPoolScore;
    }
    return ShopDiscoveryPoolSupplementReason.apiMissingButPoolStrong;
  }

  static bool _candidateIndividuallyHighQuality(
    ShopPoolCandidate candidate,
    double poolAvgScore,
  ) {
    if (candidate.itemCount < 2) return false;
    if (candidate.safeItemCount <= 0) return false;
    if (!ShopDiscoveryPoolFallback.hasDisplayableImageUrl(
      candidate.representativeImageUrl,
    )) {
      return false;
    }
    if (candidate.shopUrl.trim().isEmpty) return false;
    if (candidate.score >= 280) return true;
    if (candidate.itemCount >= 4 &&
        candidate.averageReviewAverage >= 4.3 &&
        (poolAvgScore <= 0 || candidate.score >= poolAvgScore)) {
      return true;
    }
    return false;
  }

  static double _poolAverageScore(List<ShopPoolCandidate> candidates) {
    if (candidates.isEmpty) return 0;
    var sum = 0.0;
    for (final c in candidates) {
      sum += c.score;
    }
    return sum / candidates.length;
  }

  static bool _shopHasFreshProducts(
    ProductCatalogRepository repository,
    String shopCode,
    DateTime now,
  ) {
    var found = false;
    for (final p in repository.getAll()) {
      if (p.shopCode.trim() != shopCode) continue;
      found = true;
      if (!repository.isStale(p, now: now)) return true;
    }
    return !found;
  }

  static bool _shopHasUnsafeProducts(
    ProductCatalogRepository repository,
    String shopCode,
  ) {
    for (final p in repository.getAll()) {
      if (p.shopCode.trim() != shopCode) continue;
      if (!p.qualityStatus.safe ||
          ProductSafetyFilter.isBlockedProduct(
            itemName: p.itemName,
            itemCaption: p.itemCaption,
            shopName: p.shopName,
            genreName: p.genreName,
            itemUrl: p.itemUrl,
            affiliateUrl: p.affiliateUrl,
          )) {
        return true;
      }
    }
    return false;
  }

  static bool _qualityAtLeastGood(ShopPoolFallbackQualityLevel level) {
    return level == ShopPoolFallbackQualityLevel.excellent ||
        level == ShopPoolFallbackQualityLevel.good;
  }

  static bool _depthAtLeastGood(ShopPoolFallbackDepthQuality depth) {
    return depth == ShopPoolFallbackDepthQuality.excellent ||
        depth == ShopPoolFallbackDepthQuality.good;
  }
}

class ApiWeakEvaluation {
  const ApiWeakEvaluation({required this.signal, required this.reason});

  final bool signal;
  final String reason;
}

class _EligibleEntry {
  const _EligibleEntry({
    required this.candidate,
    required this.relevance,
    required this.shopName,
    required this.reason,
  });

  final ShopPoolCandidate candidate;
  final ShopPoolKeywordRelevanceResult relevance;
  final String shopName;
  final ShopDiscoveryPoolSupplementReason reason;
}
