import '../models/shop_discovery_summary.dart';
import '../models/shop_pool_candidate.dart';
import '../services/shop_discovery_pool_fallback.dart';
import '../services/shop_pool_keyword_relevance.dart';

enum ShopPoolFallbackQualityLevel { excellent, good, weak, insufficient }

enum ShopPoolFallbackDepthQuality { excellent, good, weak, insufficient }

enum ShopPoolFallbackDisplayQuality { excellent, good, weak, insufficient }

class ShopPoolFallbackTopEntry {
  const ShopPoolFallbackTopEntry({
    required this.rank,
    required this.shopCode,
    required this.shopName,
    required this.score,
    required this.hitItemCount,
    required this.avgReview,
    required this.maxReviewCount,
    required this.relevanceLevel,
    required this.matchedBy,
  });

  final int rank;
  final String shopCode;
  final String shopName;
  final double score;
  final int hitItemCount;
  final double avgReview;
  final int maxReviewCount;
  final ShopPoolKeywordMatchLevel relevanceLevel;
  final String matchedBy;

  String toLogString() {
    return 'shopCode:$shopCode,shopName:$shopName,score:${score.toStringAsFixed(1)},'
        'relevance:${relevanceLevel.name},matchedBy:$matchedBy,'
        'hitItems:$hitItemCount,avgReview:${avgReview.toStringAsFixed(2)},'
        'maxReviewCount:$maxReviewCount';
  }
}

class ShopPoolFallbackQualityReport {
  const ShopPoolFallbackQualityReport({
    required this.keyword,
    required this.fallbackCount,
    required this.poolCandidateCount,
    required this.avgScore,
    required this.maxScore,
    required this.minScore,
    required this.avgReview,
    required this.maxReviewCount,
    required this.avgHitItemCount,
    required this.withImageCount,
    required this.withShopUrlCount,
    required this.genreCount,
    required this.topGenres,
    required this.duplicateShopCount,
    required this.savedExcluded,
    required this.invalidExcluded,
    required this.unsafeExcluded,
    required this.source,
    required this.qualityLevel,
    required this.topEntries,
    required this.keywordMatchStrong,
    required this.keywordMatchMedium,
    required this.keywordMatchWeak,
    required this.keywordNoMatch,
    required this.unknownGenreCount,
    required this.relevanceQuality,
    required this.excludedNoRelevance,
    required this.demotedWeak,
    required this.hitItemCount1,
    required this.hitItemCount2Plus,
    required this.unknownGenreRatio,
    required this.thinCandidateCount,
    required this.depthQuality,
    required this.displayQuality,
  });

  final String keyword;
  final int fallbackCount;
  final int poolCandidateCount;
  final double avgScore;
  final double maxScore;
  final double minScore;
  final double avgReview;
  final int maxReviewCount;
  final double avgHitItemCount;
  final int withImageCount;
  final int withShopUrlCount;
  final int genreCount;
  final List<String> topGenres;
  final int duplicateShopCount;
  final int savedExcluded;
  final int invalidExcluded;
  final int unsafeExcluded;
  final String source;
  final ShopPoolFallbackQualityLevel qualityLevel;
  final List<ShopPoolFallbackTopEntry> topEntries;
  final int keywordMatchStrong;
  final int keywordMatchMedium;
  final int keywordMatchWeak;
  final int keywordNoMatch;
  final int unknownGenreCount;
  final ShopPoolFallbackRelevanceQuality relevanceQuality;
  final int excludedNoRelevance;
  final int demotedWeak;
  final int hitItemCount1;
  final int hitItemCount2Plus;
  final double unknownGenreRatio;
  final int thinCandidateCount;
  final ShopPoolFallbackDepthQuality depthQuality;
  final ShopPoolFallbackDisplayQuality displayQuality;

  static ShopPoolFallbackQualityReport? fromFallback(
    ShopDiscoveryPoolFallbackResult fallback,
  ) {
    if (!fallback.usedFallback) return null;
    final summaries = fallback.summaries;
    final stats = fallback.relevanceStats;
    if (summaries.isEmpty) {
      return _emptyReport(fallback, stats);
    }

    var scoreSum = 0.0;
    var reviewSum = 0.0;
    var hitItemSum = 0;
    var maxScore = double.negativeInfinity;
    var minScore = double.infinity;
    var maxReviewCount = 0;
    var withImageCount = 0;
    var withShopUrlCount = 0;
    var hitItemCount1 = 0;
    var hitItemCount2Plus = 0;
    var thinCandidateCount = 0;
    final seen = <String>{};
    var duplicateShopCount = 0;
    final genreCounts = <String, int>{};
    final displayedByCode = <String, ShopPoolCandidate>{
      for (final c in fallback.displayedCandidates) c.shopCode.trim(): c,
    };

    for (final summary in summaries) {
      scoreSum += summary.discoveryScore;
      reviewSum += summary.avgReviewAverage;
      hitItemSum += summary.hitItemCount;
      if (summary.hitItemCount <= 1) {
        hitItemCount1++;
      } else {
        hitItemCount2Plus++;
      }
      if (summary.discoveryScore > maxScore) maxScore = summary.discoveryScore;
      if (summary.discoveryScore < minScore) minScore = summary.discoveryScore;
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
      final candidate = displayedByCode[summary.shopKey];
      final relevance =
          fallback.relevanceByShopCode[summary.shopKey] ??
          ShopPoolKeywordRelevanceResult.none;
      if (_isThinCandidate(summary, candidate, relevance)) {
        thinCandidateCount++;
      }
      final genre = (candidate?.primaryGenreName.trim().isNotEmpty ?? false)
          ? candidate!.primaryGenreName.trim()
          : 'unknown';
      genreCounts.update(genre, (v) => v + 1, ifAbsent: () => 1);
    }

    final sortedGenres = genreCounts.entries.toList(growable: false)
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    final topGenres = sortedGenres
        .take(3)
        .map((e) => '${e.key}:${e.value}')
        .toList(growable: false);

    final avgHitItemCount = hitItemSum / summaries.length;
    final unknownGenreRatio = stats.unknownGenreCount / summaries.length;
    final relevanceQuality = stats.relevanceQuality;
    final depthQuality = evaluateDepthQuality(
      fallbackCount: summaries.length,
      avgHitItemCount: avgHitItemCount,
      hitItemCount2Plus: hitItemCount2Plus,
      unknownGenreRatio: unknownGenreRatio,
      thinCandidateCount: thinCandidateCount,
    );
    final displayQuality = evaluateDisplayQuality(
      fallbackCount: summaries.length,
      avgReview: reviewSum / summaries.length,
      withImageCount: withImageCount,
      withShopUrlCount: withShopUrlCount,
    );
    final qualityLevel = evaluateOverallQualityLevel(
      relevanceQuality: relevanceQuality,
      depthQuality: depthQuality,
      displayQuality: displayQuality,
      unknownGenreRatio: unknownGenreRatio,
      avgHitItemCount: avgHitItemCount,
    );

    final topEntries = summaries
        .take(3)
        .map((summary) {
          final relevance =
              fallback.relevanceByShopCode[summary.shopKey] ??
              ShopPoolKeywordRelevanceResult.none;
          return ShopPoolFallbackTopEntry(
            rank: summary.discoveryRank ?? 0,
            shopCode: summary.shopKey,
            shopName: truncateShopName(summary.shopName),
            score: summary.discoveryScore,
            hitItemCount: summary.hitItemCount,
            avgReview: summary.avgReviewAverage,
            maxReviewCount: summary.maxReviewCount,
            relevanceLevel: relevance.level,
            matchedBy: relevance.matchedBy,
          );
        })
        .toList(growable: false);

    return ShopPoolFallbackQualityReport(
      keyword: fallback.keyword,
      fallbackCount: summaries.length,
      poolCandidateCount: fallback.poolCandidateCount,
      avgScore: scoreSum / summaries.length,
      maxScore: maxScore,
      minScore: minScore,
      avgReview: reviewSum / summaries.length,
      maxReviewCount: maxReviewCount,
      avgHitItemCount: avgHitItemCount,
      withImageCount: withImageCount,
      withShopUrlCount: withShopUrlCount,
      genreCount: genreCounts.length,
      topGenres: topGenres,
      duplicateShopCount: duplicateShopCount,
      savedExcluded: fallback.savedExcludedCount,
      invalidExcluded: fallback.skippedInvalidCount,
      unsafeExcluded: fallback.unsafeExcludedCount,
      source: fallback.source,
      qualityLevel: qualityLevel,
      topEntries: topEntries,
      keywordMatchStrong: stats.strongCount,
      keywordMatchMedium: stats.mediumCount,
      keywordMatchWeak: stats.weakCount,
      keywordNoMatch: stats.noMatchCount,
      unknownGenreCount: stats.unknownGenreCount,
      relevanceQuality: relevanceQuality,
      excludedNoRelevance: stats.excludedNoRelevance,
      demotedWeak: stats.demotedWeak,
      hitItemCount1: hitItemCount1,
      hitItemCount2Plus: hitItemCount2Plus,
      unknownGenreRatio: unknownGenreRatio,
      thinCandidateCount: thinCandidateCount,
      depthQuality: depthQuality,
      displayQuality: displayQuality,
    );
  }

  static ShopPoolFallbackQualityReport _emptyReport(
    ShopDiscoveryPoolFallbackResult fallback,
    ShopPoolFallbackRelevanceStats stats,
  ) {
    return ShopPoolFallbackQualityReport(
      keyword: fallback.keyword,
      fallbackCount: 0,
      poolCandidateCount: fallback.poolCandidateCount,
      avgScore: 0,
      maxScore: 0,
      minScore: 0,
      avgReview: 0,
      maxReviewCount: 0,
      avgHitItemCount: 0,
      withImageCount: 0,
      withShopUrlCount: 0,
      genreCount: 0,
      topGenres: const <String>[],
      duplicateShopCount: 0,
      savedExcluded: fallback.savedExcludedCount,
      invalidExcluded: fallback.skippedInvalidCount,
      unsafeExcluded: fallback.unsafeExcludedCount,
      source: fallback.source,
      qualityLevel: ShopPoolFallbackQualityLevel.insufficient,
      topEntries: const <ShopPoolFallbackTopEntry>[],
      keywordMatchStrong: stats.strongCount,
      keywordMatchMedium: stats.mediumCount,
      keywordMatchWeak: stats.weakCount,
      keywordNoMatch: stats.noMatchCount,
      unknownGenreCount: stats.unknownGenreCount,
      relevanceQuality: stats.relevanceQuality,
      excludedNoRelevance: stats.excludedNoRelevance,
      demotedWeak: stats.demotedWeak,
      hitItemCount1: 0,
      hitItemCount2Plus: 0,
      unknownGenreRatio: 0,
      thinCandidateCount: 0,
      depthQuality: ShopPoolFallbackDepthQuality.insufficient,
      displayQuality: ShopPoolFallbackDisplayQuality.insufficient,
    );
  }

  static bool _isThinCandidate(
    ShopDiscoverySummary summary,
    ShopPoolCandidate? candidate,
    ShopPoolKeywordRelevanceResult relevance,
  ) {
    if (summary.hitItemCount != 1) return false;
    if (relevance.level != ShopPoolKeywordMatchLevel.strong) return false;
    if (candidate == null) return true;
    final genreName = candidate.primaryGenreName.trim();
    if (genreName.isEmpty) return true;
    final lower = genreName.toLowerCase();
    return lower == 'unknown' || lower == '不明';
  }

  static ShopPoolFallbackDepthQuality evaluateDepthQuality({
    required int fallbackCount,
    required double avgHitItemCount,
    required int hitItemCount2Plus,
    required double unknownGenreRatio,
    required int thinCandidateCount,
  }) {
    if (fallbackCount <= 2) return ShopPoolFallbackDepthQuality.insufficient;

    if (unknownGenreRatio >= 0.8 && avgHitItemCount < 2.0) {
      return ShopPoolFallbackDepthQuality.weak;
    }

    if (thinCandidateCount >= fallbackCount && avgHitItemCount < 2.0) {
      return ShopPoolFallbackDepthQuality.weak;
    }

    if (fallbackCount >= 10 &&
        avgHitItemCount >= 2.0 &&
        hitItemCount2Plus >= 5 &&
        unknownGenreRatio < 0.5) {
      return ShopPoolFallbackDepthQuality.excellent;
    }

    if (fallbackCount >= 5 &&
        hitItemCount2Plus >= 2 &&
        avgHitItemCount >= 1.5 &&
        unknownGenreRatio < 0.8) {
      return ShopPoolFallbackDepthQuality.good;
    }

    if (fallbackCount >= 3) return ShopPoolFallbackDepthQuality.weak;
    return ShopPoolFallbackDepthQuality.insufficient;
  }

  static ShopPoolFallbackDisplayQuality evaluateDisplayQuality({
    required int fallbackCount,
    required double avgReview,
    required int withImageCount,
    required int withShopUrlCount,
  }) {
    if (fallbackCount <= 2) return ShopPoolFallbackDisplayQuality.insufficient;

    if (fallbackCount >= 5 &&
        withImageCount == fallbackCount &&
        withShopUrlCount == fallbackCount &&
        avgReview >= 4.4) {
      return ShopPoolFallbackDisplayQuality.excellent;
    }

    if (fallbackCount >= 3 &&
        withImageCount >= (fallbackCount * 0.8).ceil() &&
        withShopUrlCount == fallbackCount &&
        avgReview >= 4.0) {
      return ShopPoolFallbackDisplayQuality.good;
    }

    if (fallbackCount >= 3) return ShopPoolFallbackDisplayQuality.weak;
    return ShopPoolFallbackDisplayQuality.insufficient;
  }

  static ShopPoolFallbackQualityLevel evaluateOverallQualityLevel({
    required ShopPoolFallbackRelevanceQuality relevanceQuality,
    required ShopPoolFallbackDepthQuality depthQuality,
    required ShopPoolFallbackDisplayQuality displayQuality,
    required double unknownGenreRatio,
    required double avgHitItemCount,
  }) {
    if (unknownGenreRatio >= 0.8 && avgHitItemCount < 2.0) {
      return ShopPoolFallbackQualityLevel.weak;
    }

    final rank = _minQualityRank(<int>[
      _relevanceRank(relevanceQuality),
      _depthRank(depthQuality),
      _displayRank(displayQuality),
    ]);

    return switch (rank) {
      3 => ShopPoolFallbackQualityLevel.excellent,
      2 => ShopPoolFallbackQualityLevel.good,
      1 => ShopPoolFallbackQualityLevel.weak,
      _ => ShopPoolFallbackQualityLevel.insufficient,
    };
  }

  static int _minQualityRank(List<int> ranks) {
    var min = ranks.first;
    for (final r in ranks.skip(1)) {
      if (r < min) min = r;
    }
    return min;
  }

  static int _relevanceRank(ShopPoolFallbackRelevanceQuality q) => switch (q) {
    ShopPoolFallbackRelevanceQuality.excellent => 3,
    ShopPoolFallbackRelevanceQuality.good => 2,
    ShopPoolFallbackRelevanceQuality.weak => 1,
    ShopPoolFallbackRelevanceQuality.insufficient => 0,
  };

  static int _depthRank(ShopPoolFallbackDepthQuality q) => switch (q) {
    ShopPoolFallbackDepthQuality.excellent => 3,
    ShopPoolFallbackDepthQuality.good => 2,
    ShopPoolFallbackDepthQuality.weak => 1,
    ShopPoolFallbackDepthQuality.insufficient => 0,
  };

  static int _displayRank(ShopPoolFallbackDisplayQuality q) => switch (q) {
    ShopPoolFallbackDisplayQuality.excellent => 3,
    ShopPoolFallbackDisplayQuality.good => 2,
    ShopPoolFallbackDisplayQuality.weak => 1,
    ShopPoolFallbackDisplayQuality.insufficient => 0,
  };

  static String truncateShopName(String value, {int max = 24}) {
    final t = value.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}...';
  }
}
