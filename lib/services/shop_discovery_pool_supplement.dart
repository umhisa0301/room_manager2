import '../config/debug_log_flags.dart';
import '../constants/shop_pool_fallback_keyword_synonyms.dart';
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
    required this.matchedGenreName,
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
  final String matchedGenreName;
  final bool hasImage;
  final bool hasShopUrl;
  final ShopDiscoveryPoolSupplementReason reason;

  String toTopLogString() {
    return 'shopCode:$shopCode,shopName:$shopName,'
        'score:${score.toStringAsFixed(1)},hitItems:$hitItemCount,'
        'relevance:${relevance.name},reason:${reason.name}';
  }
}

/// 補助枠の候補ごと表示可否（ログ専用・UI未接続）。
class ShopDiscoveryPoolSupplementCandidateDecision {
  const ShopDiscoveryPoolSupplementCandidateDecision({
    required this.rank,
    required this.shopCode,
    required this.shopName,
    required this.showEligible,
    required this.reason,
    required this.candidateDecisionReason,
    required this.displayRank,
    required this.genericShop,
    required this.broadShop,
    required this.genreAligned,
    required this.genreAlignmentReason,
    required this.strongItemEvidence,
    required this.matchedBy,
    required this.hitItemCount,
    required this.primaryGenreName,
    required this.matchedGenreName,
  });

  final int rank;
  final String shopCode;
  final String shopName;
  final bool showEligible;
  final String reason;
  final String candidateDecisionReason;
  final int displayRank;
  final bool genericShop;
  final bool broadShop;
  final bool genreAligned;
  final String genreAlignmentReason;
  final bool strongItemEvidence;
  final String matchedBy;
  final int hitItemCount;
  final String primaryGenreName;
  final String matchedGenreName;

  String toCandidateLogString({bool extendedAudit = false}) {
    final base = 'shopCode:$shopCode,showEligible:$showEligible,'
        'reason:$reason,displayRank:${displayRank <= 0 ? '-' : displayRank},'
        'genericShop:$genericShop,broadShop:$broadShop,'
        'genreAligned:$genreAligned,genreAlignmentReason:$genreAlignmentReason';
    if (!extendedAudit) return base;
    return '$base,strongItemEvidence:$strongItemEvidence,'
        'matchedBy:${matchedBy.isEmpty ? '-' : matchedBy},'
        'hitItems:$hitItemCount,'
        'primaryGenreName:${primaryGenreName.isEmpty ? '-' : primaryGenreName},'
        'matchedGenreName:${matchedGenreName.isEmpty ? '-' : matchedGenreName},'
        'candidateDecisionReason:$candidateDecisionReason';
  }
}

/// 補助枠の表示推奨（ログ専用・UI未接続）。
class ShopDiscoveryPoolSupplementDisplayDecision {
  const ShopDiscoveryPoolSupplementDisplayDecision({
    required this.decision,
    required this.reason,
    required this.recommendedDisplayCount,
    required this.maxAllowedDisplayCount,
    required this.confidence,
    required this.eligibleAfterStrongEvidence,
    required this.candidateDecisions,
  });

  final String decision;
  final String reason;
  final int recommendedDisplayCount;
  final int maxAllowedDisplayCount;
  final String confidence;
  final int eligibleAfterStrongEvidence;
  final List<ShopDiscoveryPoolSupplementCandidateDecision> candidateDecisions;

  static const empty = ShopDiscoveryPoolSupplementDisplayDecision(
    decision: 'hide',
    reason: 'noApiSummaries',
    recommendedDisplayCount: 0,
    maxAllowedDisplayCount: 0,
    confidence: 'low',
    eligibleAfterStrongEvidence: 0,
    candidateDecisions: <ShopDiscoveryPoolSupplementCandidateDecision>[],
  );

  String buildDecisionLogLine({
    required String keyword,
    required double overlapRate,
    required bool apiWeakSignal,
    required int selectedSupplementCount,
    bool extendedAudit = false,
  }) {
    final keywordForLog = keyword.isEmpty ? '-' : keyword;
    final base = '[SHOP_DISCOVERY_POOL_SUPPLEMENT_DECISION] keyword=$keywordForLog '
        'decision=$decision reason=$reason '
        'overlapRate=${overlapRate.toStringAsFixed(3)} '
        'apiWeakSignal=$apiWeakSignal '
        'selectedSupplementCount=$selectedSupplementCount '
        'recommendedDisplayCount=$recommendedDisplayCount '
        'maxAllowedDisplayCount=$maxAllowedDisplayCount '
        'confidence=$confidence ';
    final tail = 'willUsePoolForUi=false willSkipApi=false';
    if (!extendedAudit) return '$base$tail';
    return '$base'
        'eligibleAfterStrongEvidence=$eligibleAfterStrongEvidence '
        '$tail';
  }

  String buildCandidateDecisionLogLine({
    required String keyword,
    bool extendedAudit = false,
  }) {
    final keywordForLog = keyword.isEmpty ? '-' : keyword;
    final c = candidateDecisions;
    return '[SHOP_DISCOVERY_POOL_SUPPLEMENT_CANDIDATE_DECISION] '
        'keyword=$keywordForLog '
        'candidate1=${_candidateSlot(c, 0, extendedAudit)} '
        'candidate2=${_candidateSlot(c, 1, extendedAudit)} '
        'candidate3=${_candidateSlot(c, 2, extendedAudit)}';
  }

  static String _candidateSlot(
    List<ShopDiscoveryPoolSupplementCandidateDecision> entries,
    int index,
    bool extendedAudit,
  ) {
    if (index >= entries.length) return '-';
    return entries[index].toCandidateLogString(extendedAudit: extendedAudit);
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
    required this.displayDecision,
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
  final ShopDiscoveryPoolSupplementDisplayDecision displayDecision;

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
    displayDecision: ShopDiscoveryPoolSupplementDisplayDecision.empty,
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

  String buildDecisionLogLine() {
    final extended = DebugLogFlags.kCatalogAuditLogsEnabled;
    return displayDecision.buildDecisionLogLine(
      keyword: keyword,
      overlapRate: comparison.overlapRate,
      apiWeakSignal: apiWeakSignal,
      selectedSupplementCount: selectedSupplements.length,
      extendedAudit: extended,
    );
  }

  String buildCandidateDecisionLogLine() {
    return displayDecision.buildCandidateDecisionLogLine(
      keyword: keyword,
      extendedAudit: DebugLogFlags.kCatalogAuditLogsEnabled,
    );
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
          matchedGenreName: resolveMatchedGenreName(
            keyword: keyword,
            candidate: e.candidate,
            repository: repository,
          ),
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

    final displayDecision = buildDisplayDecision(
      keyword: keyword,
      comparison: comparison,
      poolQuality: poolQuality,
      selected: selected,
      wouldShow: wouldShow,
      apiWeakSignal: weak.signal,
      zeroReason: zeroReason,
      apiGenreNames: apiGenreNames.isNotEmpty
          ? apiGenreNames
          : apiQuality.topGenres.toSet(),
    );

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
      displayDecision: displayDecision,
    );
  }

  static ShopDiscoveryPoolSupplementDisplayDecision buildDisplayDecision({
    required String keyword,
    required ShopDiscoveryPoolComparisonResult comparison,
    required ShopPoolFallbackQualityReport? poolQuality,
    required List<ShopDiscoveryPoolSupplementCandidate> selected,
    required bool wouldShow,
    required bool apiWeakSignal,
    required String zeroReason,
    Set<String> apiGenreNames = const <String>{},
  }) {
    final overlapRate = comparison.overlapRate;
    final poolTopGenres = poolQuality?.topGenres ?? const <String>[];

    final recommended = evaluateRecommendedDisplayCount(
      selectedCount: selected.length,
      overlapRate: overlapRate,
      apiWeakSignal: apiWeakSignal,
      wouldShow: wouldShow,
      poolQuality: poolQuality,
      selected: selected,
      keyword: keyword,
      poolTopGenres: poolTopGenres,
    );

    final maxAllowed = evaluateMaxAllowedDisplayCount(
      overlapRate: overlapRate,
      apiWeakSignal: apiWeakSignal,
    );

    final candidateDecisions = evaluateCandidateDecisions(
      keyword: keyword,
      selected: selected,
      recommendedDisplayCount: recommended,
      apiWeakSignal: apiWeakSignal,
      poolTopGenres: poolTopGenres,
      apiGenreNames: apiGenreNames,
      poolQuality: poolQuality,
      overlapRate: overlapRate,
    );

    final decisionPair = evaluateSupplementDecision(
      wouldShow: wouldShow,
      recommendedDisplayCount: recommended,
      overlapRate: overlapRate,
      apiWeakSignal: apiWeakSignal,
      selectedCount: selected.length,
      zeroReason: zeroReason,
      keyword: keyword,
      candidateDecisions: candidateDecisions,
      comparison: comparison,
    );

    final confidence = evaluateDisplayConfidence(
      decision: decisionPair.decision,
      recommendedDisplayCount: recommended,
      poolQuality: poolQuality,
      overlapRate: overlapRate,
      candidateDecisions: candidateDecisions,
    );

    final eligibleAfterStrongEvidence = candidateDecisions
        .where((e) => e.showEligible && e.strongItemEvidence)
        .length;

    return ShopDiscoveryPoolSupplementDisplayDecision(
      decision: decisionPair.decision,
      reason: decisionPair.reason,
      recommendedDisplayCount: recommended,
      maxAllowedDisplayCount: maxAllowed,
      confidence: confidence,
      eligibleAfterStrongEvidence: eligibleAfterStrongEvidence,
      candidateDecisions: candidateDecisions,
    );
  }

  static int evaluateRecommendedDisplayCount({
    required int selectedCount,
    required double overlapRate,
    required bool apiWeakSignal,
    required bool wouldShow,
    required ShopPoolFallbackQualityReport? poolQuality,
    required List<ShopDiscoveryPoolSupplementCandidate> selected,
    required String keyword,
    required List<String> poolTopGenres,
  }) {
    if (selectedCount <= 0 || !wouldShow) return 0;
    if (overlapRate >= 1.0) return 0;
    if (_keywordBlocksSupplementDisplay(keyword, selected, poolTopGenres)) {
      return 0;
    }
    if (apiWeakSignal) {
      if (overlapRate >= 0.85) return 2;
      return 3;
    }
    if (overlapRate >= 0.9) return 1;
    if (poolQuality?.qualityLevel == ShopPoolFallbackQualityLevel.excellent &&
        _hasApiMissingStrongCandidate(selected)) {
      return 1;
    }
    return wouldShow ? 1 : 0;
  }

  static int evaluateMaxAllowedDisplayCount({
    required double overlapRate,
    required bool apiWeakSignal,
  }) {
    if (overlapRate >= 1.0) return 0;
    if (apiWeakSignal) return 3;
    if (overlapRate >= 0.9) return 2;
    return 2;
  }

  static ({String decision, String reason}) evaluateSupplementDecision({
    required bool wouldShow,
    required int recommendedDisplayCount,
    required double overlapRate,
    required bool apiWeakSignal,
    required int selectedCount,
    required String zeroReason,
    required String keyword,
    required List<ShopDiscoveryPoolSupplementCandidateDecision> candidateDecisions,
    required ShopDiscoveryPoolComparisonResult comparison,
  }) {
    if (selectedCount <= 0) {
      return (
        decision: 'hide',
        reason: zeroReason.isEmpty ? 'noEligibleSupplementCandidates' : zeroReason,
      );
    }
    if (overlapRate >= 1.0 && comparison.apiOnlyCount == 0) {
      return (decision: 'hide', reason: 'apiAlreadyCoversPoolTop');
    }
    if (recommendedDisplayCount <= 0 &&
        zeroReason == 'apiAlreadyCoversPoolTop') {
      return (decision: 'hide', reason: 'apiAlreadyCoversPoolTop');
    }
    if (recommendedDisplayCount <= 0 &&
        candidateDecisions.isNotEmpty &&
        candidateDecisions.every((e) => !e.genreAligned)) {
      return (decision: 'hide', reason: 'genreMismatchForKeyword');
    }
    if (recommendedDisplayCount > 0 &&
        candidateDecisions.any((e) => e.showEligible)) {
      return (
        decision: 'showCandidate',
        reason: apiWeakSignal
            ? 'apiWeakNeedsPoolSupplement'
            : 'apiMissingStrongPoolCandidate',
      );
    }
    if (!wouldShow) {
      return (decision: 'hide', reason: 'apiStrongEnoughNoSupplement');
    }
    if (recommendedDisplayCount > 0) {
      return (decision: 'hide', reason: 'supplementCandidatesFiltered');
    }
    return (decision: 'hide', reason: 'supplementNotRecommended');
  }

  static String evaluateDisplayConfidence({
    required String decision,
    required int recommendedDisplayCount,
    required ShopPoolFallbackQualityReport? poolQuality,
    required double overlapRate,
    required List<ShopDiscoveryPoolSupplementCandidateDecision> candidateDecisions,
  }) {
    if (decision == 'hide' && overlapRate >= 1.0) return 'high';
    if (decision == 'showCandidate' && recommendedDisplayCount > 0) {
      ShopDiscoveryPoolSupplementCandidateDecision? topEligible;
      for (final e in candidateDecisions) {
        if (e.showEligible) {
          topEligible = e;
          break;
        }
      }
      if (topEligible != null &&
          !topEligible.genericShop &&
          !topEligible.broadShop) {
        if (topEligible.strongItemEvidence && !topEligible.genreAligned) {
          return 'medium';
        }
        if (poolQuality?.qualityLevel ==
            ShopPoolFallbackQualityLevel.excellent) {
          return 'high';
        }
      }
    }
    if (poolQuality?.qualityLevel == ShopPoolFallbackQualityLevel.good) {
      return 'medium';
    }
    if (recommendedDisplayCount == 0 && decision == 'hide') return 'high';
    return 'low';
  }

  static List<ShopDiscoveryPoolSupplementCandidateDecision>
      evaluateCandidateDecisions({
    required String keyword,
    required List<ShopDiscoveryPoolSupplementCandidate> selected,
    required int recommendedDisplayCount,
    required bool apiWeakSignal,
    required List<String> poolTopGenres,
    required ShopPoolFallbackQualityReport? poolQuality,
    required double overlapRate,
    Set<String> apiGenreNames = const <String>{},
  }) {
    final drafts = <_CandidateDecisionDraft>[];

    for (var i = 0; i < selected.length && i < maxSelectedCount; i++) {
      final c = selected[i];
      final genericShop = evaluateGenericShop(c.shopCode, c.shopName);
      final broadShop = evaluateBroadShop(
        shopCode: c.shopCode,
        shopName: c.shopName,
        genre: c.primaryGenreName,
      );
      final genreAlign = evaluateGenreAlignment(
        keyword: keyword,
        genre: c.primaryGenreName,
        poolTopGenres: poolTopGenres,
        apiGenreNames: apiGenreNames,
      );
      final strongItemEvidence = evaluateStrongItemEvidence(
        keyword: keyword,
        candidate: c,
        poolQuality: poolQuality,
        overlapRate: overlapRate,
        genericShop: genericShop,
        broadShop: broadShop,
      );

      drafts.add(
        _CandidateDecisionDraft(
          candidate: c,
          genericShop: genericShop,
          broadShop: broadShop,
          genreAligned: genreAlign.aligned,
          genreAlignmentReason: genreAlign.reason,
          strongItemEvidence: strongItemEvidence,
        ),
      );
    }

    final decisions = <ShopDiscoveryPoolSupplementCandidateDecision>[];
    var assignedDisplayRank = 0;
    String? firstEligibleShopCode;

    for (final draft in drafts) {
      final c = draft.candidate;
      var showEligible = false;
      var reason = 'notSelectedForDisplay';
      var displayRank = 0;

      if (draft.genericShop) {
        reason = 'similarToCandidate1OrTooGeneric';
      } else if (draft.broadShop) {
        reason = 'broadShopOrFurusato';
      } else if (c.hitItemCount <= 2) {
        reason = 'lowHitItemCountOrBroadShop';
      } else if (!draft.genreAligned && !draft.strongItemEvidence) {
        reason = 'genreMismatchForKeyword';
      } else if (firstEligibleShopCode != null &&
          _isSimilarToPriorEligible(
            currentCode: c.shopCode,
            currentName: c.shopName,
            priorCode: firstEligibleShopCode,
          )) {
        reason = 'similarToCandidate1OrTooGeneric';
      } else if (recommendedDisplayCount <= 0) {
        reason = 'apiStrongEnoughNoSupplement';
      } else if (assignedDisplayRank >= recommendedDisplayCount) {
        reason = 'exceedsRecommendedDisplayCount';
      } else {
        showEligible = true;
        assignedDisplayRank++;
        displayRank = assignedDisplayRank;
        firstEligibleShopCode ??= c.shopCode;
        if (draft.strongItemEvidence && !draft.genreAligned) {
          reason = 'strongItemEvidenceDespiteUnknownGenre';
        } else if (apiWeakSignal && assignedDisplayRank > 1) {
          reason = 'apiWeakNeedsPoolSupplement';
        } else {
          reason = 'apiMissingStrongPoolCandidate';
        }
      }

      decisions.add(
        ShopDiscoveryPoolSupplementCandidateDecision(
          rank: c.rank,
          shopCode: c.shopCode,
          shopName: c.shopName,
          showEligible: showEligible,
          reason: reason,
          candidateDecisionReason: reason,
          displayRank: displayRank,
          genericShop: draft.genericShop,
          broadShop: draft.broadShop,
          genreAligned: draft.genreAligned,
          genreAlignmentReason: draft.genreAlignmentReason,
          strongItemEvidence: draft.strongItemEvidence,
          matchedBy: c.matchedBy,
          hitItemCount: c.hitItemCount,
          primaryGenreName: c.primaryGenreName,
          matchedGenreName: c.matchedGenreName,
        ),
      );
    }
    return decisions;
  }

  static bool evaluateStrongItemEvidence({
    required String keyword,
    required ShopDiscoveryPoolSupplementCandidate candidate,
    required ShopPoolFallbackQualityReport? poolQuality,
    required double overlapRate,
    required bool genericShop,
    required bool broadShop,
  }) {
    if (genericShop || broadShop) return false;
    if (overlapRate >= 1.0) return false;
    if (candidate.relevance != ShopPoolKeywordMatchLevel.strong) return false;
    if (candidate.matchedBy.trim().toLowerCase() != 'itemname') return false;
    if (candidate.hitItemCount < 5) return false;

    final pool = poolQuality;
    if (pool == null) return false;
    if (!_depthAtLeastGood(pool.depthQuality)) return false;
    if (!_displayAtLeastGood(pool.displayQuality)) return false;

    final keywordNorm = keyword.trim().toLowerCase();
    if (keywordNorm == 'ベビー' &&
        _isBottleGenreMismatchForBaby(candidate.primaryGenreName)) {
      return false;
    }
    return true;
  }

  static String resolveMatchedGenreName({
    required String keyword,
    required ShopPoolCandidate candidate,
    ProductCatalogRepository? repository,
  }) {
    final keywordNorm = keyword.trim().toLowerCase();
    final tokens = ShopPoolFallbackKeywordSynonyms.tokensFor(keyword)
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (tokens.isEmpty) return '-';

    if (repository != null) {
      final genreCounts = <String, int>{};
      for (final p in repository.getAll()) {
        if (p.shopCode.trim() != candidate.shopCode.trim()) continue;
        final name = p.itemName.trim().toLowerCase();
        if (name.isEmpty) continue;
        var hit = false;
        for (final t in tokens) {
          if (name.contains(t)) {
            hit = true;
            break;
          }
        }
        if (!hit) continue;
        final genre = p.genreName.trim();
        if (genre.isEmpty) continue;
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }
      if (genreCounts.isNotEmpty) {
        var topGenre = '';
        var topCount = 0;
        for (final entry in genreCounts.entries) {
          if (entry.value > topCount) {
            topCount = entry.value;
            topGenre = entry.key;
          }
        }
        if (topGenre.isNotEmpty) return topGenre;
      }
    }

    for (final genre in candidate.sourceGenres) {
      final g = genre.trim();
      if (g.isEmpty) continue;
      if (_genreMatchesKeywordIntent(keywordNorm, g)) return g;
    }

    final primary = candidate.primaryGenreName.trim();
    return primary.isEmpty ? '-' : primary;
  }

  static bool evaluateGenericShop(String shopCode, String shopName) {
    const genericCodes = <String>{'rakuten24'};
    final code = shopCode.trim().toLowerCase();
    if (genericCodes.contains(code)) return true;

    final name = shopName.trim();
    if (name.isEmpty) return false;
    final isRakuten24Brand =
        name.contains('楽天24') || name.contains('楽天２４');
    if (!isRakuten24Brand) return false;
    if (name.contains('ドリンク') ||
        name.toLowerCase().contains('drink') ||
        name.contains('専門')) {
      return false;
    }
    return true;
  }

  static bool evaluateBroadShop({
    required String shopCode,
    required String shopName,
    required String genre,
  }) {
    final code = shopCode.trim();
    final name = shopName.trim();
    final genreText = genre.trim();

    if (name.contains('ふるさと納税') || name.contains('自治体')) return true;
    if (RegExp(r'^f\d{6}-').hasMatch(code)) return true;
    if (RegExp(r'[都道府県市区町村]$').hasMatch(name) && name.length <= 12) {
      return true;
    }
    if (genreText.contains('総合') ||
        name.contains('総合') ||
        name.contains('雑貨')) {
      return true;
    }
    return false;
  }

  static ({bool aligned, String reason}) evaluateGenreAlignment({
    required String keyword,
    required String genre,
    required List<String> poolTopGenres,
    Set<String> apiGenreNames = const <String>{},
  }) {
    final genreText = genre.trim();
    final keywordNorm = keyword.trim().toLowerCase();

    if (genreText.isEmpty) {
      return (aligned: false, reason: 'unknown');
    }

    if (keywordNorm == 'ベビー' && _isBottleGenreMismatchForBaby(genreText)) {
      return (aligned: false, reason: 'genreMismatchForKeyword');
    }

    if (_genreMatchesKeywordIntent(keywordNorm, genreText)) {
      return (aligned: true, reason: 'matchesKeywordGenre');
    }

    if (poolTopGenres.contains(genreText)) {
      return (aligned: true, reason: 'matchesPoolTopGenre');
    }

    for (final apiGenre in apiGenreNames) {
      if (apiGenre.trim() == genreText) {
        return (aligned: true, reason: 'matchesApiTopGenre');
      }
    }

    if (_genreLooselyMatchesKeyword(keywordNorm, genreText)) {
      return (aligned: true, reason: 'matchesKeywordGenre');
    }

    return (aligned: false, reason: 'unknown');
  }

  static bool _genreMatchesKeywordIntent(String keywordNorm, String genre) {
    if (keywordNorm == '水筒') {
      return _containsAny(genre, <String>[
        '水筒',
        'マグボトル',
        'ボトル',
        'タンブラー',
        '保温',
        '保冷',
        '魔法瓶',
      ]);
    }
    if (keywordNorm == 'コーヒー') {
      return _containsAny(genre, <String>['コーヒー', '珈琲', 'ドリップ', '焙煎', 'カフェ']);
    }
    if (keywordNorm == 'ベビー') {
      return _containsAny(genre, <String>[
        'ベビー',
        '赤ちゃん',
        '新生児',
        'マタニティ',
        '授乳',
        'おむつ',
        'ベビー向け',
      ]);
    }
    return false;
  }

  static bool _genreLooselyMatchesKeyword(String keywordNorm, String genre) {
    if (keywordNorm == '水筒') {
      return genre.contains('子供') && genre.contains('ボトル');
    }
    return false;
  }

  static bool _isBottleGenreMismatchForBaby(String genre) {
    final isBottle = genre.contains('水筒') ||
        genre.contains('マグボトル') ||
        (genre.contains('ボトル') && !genre.contains('哺乳'));
    if (!isBottle) return false;
    return !_containsAny(genre, <String>[
      'ベビー',
      '赤ちゃん',
      'キッズ',
      '子供',
      '子ども',
      'マタニティ',
    ]);
  }

  static bool _keywordBlocksSupplementDisplay(
    String keyword,
    List<ShopDiscoveryPoolSupplementCandidate> selected,
    List<String> poolTopGenres,
  ) {
    final keywordNorm = keyword.trim().toLowerCase();
    if (keywordNorm != 'ベビー' || selected.isEmpty) return false;

    final poolBottleOnly = poolTopGenres.isNotEmpty &&
        poolTopGenres.every(
          (g) =>
              g.contains('水筒') ||
              g.contains('マグボトル') ||
              (g.contains('ボトル') && !g.contains('ベビー')),
        );
    if (!poolBottleOnly) return false;

    return selected.every(
      (c) => !evaluateGenreAlignment(
        keyword: keyword,
        genre: c.primaryGenreName,
        poolTopGenres: poolTopGenres,
      ).aligned,
    );
  }

  static bool _hasApiMissingStrongCandidate(
    List<ShopDiscoveryPoolSupplementCandidate> selected,
  ) {
    return selected.any(
      (c) =>
          c.relevance == ShopPoolKeywordMatchLevel.strong &&
          c.hitItemCount >= 4 &&
          !evaluateGenericShop(c.shopCode, c.shopName) &&
          !evaluateBroadShop(
            shopCode: c.shopCode,
            shopName: c.shopName,
            genre: c.primaryGenreName,
          ),
    );
  }

  static bool _isSimilarToPriorEligible({
    required String currentCode,
    required String currentName,
    required String priorCode,
  }) {
    const drinkFamily = <String>{'rakuten24', 'soukaidrink'};
    final cur = currentCode.trim().toLowerCase();
    final prior = priorCode.trim().toLowerCase();
    if (drinkFamily.contains(cur) && drinkFamily.contains(prior)) return true;
    if (evaluateGenericShop(currentCode, currentName)) return true;
    return false;
  }

  static bool _containsAny(String text, Iterable<String> needles) {
    for (final n in needles) {
      if (text.contains(n)) return true;
    }
    return false;
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

  static bool _displayAtLeastGood(ShopPoolFallbackDisplayQuality display) {
    return display == ShopPoolFallbackDisplayQuality.excellent ||
        display == ShopPoolFallbackDisplayQuality.good;
  }
}

class _CandidateDecisionDraft {
  const _CandidateDecisionDraft({
    required this.candidate,
    required this.genericShop,
    required this.broadShop,
    required this.genreAligned,
    required this.genreAlignmentReason,
    required this.strongItemEvidence,
  });

  final ShopDiscoveryPoolSupplementCandidate candidate;
  final bool genericShop;
  final bool broadShop;
  final bool genreAligned;
  final String genreAlignmentReason;
  final bool strongItemEvidence;
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
