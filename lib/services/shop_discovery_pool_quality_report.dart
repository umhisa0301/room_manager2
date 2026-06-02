import '../models/shop_pool_candidate.dart';
import '../services/shop_discovery_pool_fallback.dart';
import '../services/shop_pool_keyword_relevance.dart';

enum ShopPoolFallbackQualityLevel { excellent, good, weak, insufficient }

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

  static ShopPoolFallbackQualityReport? fromFallback(
    ShopDiscoveryPoolFallbackResult fallback,
  ) {
    if (!fallback.usedFallback) return null;
    final summaries = fallback.summaries;
    final stats = fallback.relevanceStats;
    if (summaries.isEmpty) {
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
      );
    }

    var scoreSum = 0.0;
    var reviewSum = 0.0;
    var hitItemSum = 0;
    var maxScore = double.negativeInfinity;
    var minScore = double.infinity;
    var maxReviewCount = 0;
    var withImageCount = 0;
    var withShopUrlCount = 0;
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

    final strongMedium = stats.strongCount + stats.mediumCount;
    final unknownGenreRatio = summaries.isEmpty
        ? 1.0
        : stats.unknownGenreCount / summaries.length;

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
      avgHitItemCount: hitItemSum / summaries.length,
      withImageCount: withImageCount,
      withShopUrlCount: withShopUrlCount,
      genreCount: genreCounts.length,
      topGenres: topGenres,
      duplicateShopCount: duplicateShopCount,
      savedExcluded: fallback.savedExcludedCount,
      invalidExcluded: fallback.skippedInvalidCount,
      unsafeExcluded: fallback.unsafeExcludedCount,
      source: fallback.source,
      qualityLevel: evaluateQualityLevel(
        fallbackCount: summaries.length,
        avgReview: reviewSum / summaries.length,
        withImageCount: withImageCount,
        keywordStrongOrMediumMatchCount: strongMedium,
        unknownGenreRatio: unknownGenreRatio,
        topGenres: topGenres,
      ),
      topEntries: topEntries,
      keywordMatchStrong: stats.strongCount,
      keywordMatchMedium: stats.mediumCount,
      keywordMatchWeak: stats.weakCount,
      keywordNoMatch: stats.noMatchCount,
      unknownGenreCount: stats.unknownGenreCount,
      relevanceQuality: stats.relevanceQuality,
      excludedNoRelevance: stats.excludedNoRelevance,
      demotedWeak: stats.demotedWeak,
    );
  }

  static ShopPoolFallbackQualityLevel evaluateQualityLevel({
    required int fallbackCount,
    required double avgReview,
    required int withImageCount,
    required int keywordStrongOrMediumMatchCount,
    required double unknownGenreRatio,
    List<String> topGenres = const <String>[],
  }) {
    final allUnknownGenres = topGenres.length == 1 &&
        topGenres.first.startsWith('unknown:') &&
        topGenres.first.endsWith(':$fallbackCount');

    if (fallbackCount >= 10 &&
        avgReview >= 4.4 &&
        withImageCount == fallbackCount &&
        keywordStrongOrMediumMatchCount >= 7 &&
        unknownGenreRatio < 0.5 &&
        !allUnknownGenres) {
      return ShopPoolFallbackQualityLevel.excellent;
    }
    if (fallbackCount >= 5 &&
        avgReview >= 4.0 &&
        keywordStrongOrMediumMatchCount >= 3) {
      return ShopPoolFallbackQualityLevel.good;
    }
    if (fallbackCount >= 3) return ShopPoolFallbackQualityLevel.weak;
    return ShopPoolFallbackQualityLevel.insufficient;
  }

  static String truncateShopName(String value, {int max = 24}) {
    final t = value.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}...';
  }
}
