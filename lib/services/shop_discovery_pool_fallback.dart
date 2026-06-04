import '../config/product_catalog_config.dart';
import '../constants/shop_pool_fallback_keyword_synonyms.dart';
import '../models/catalog_product.dart';
import '../models/shop_discovery_summary.dart';
import '../models/shop_pool_candidate.dart';
import '../repository/product_catalog_repository.dart';
import '../services/product_catalog_shop_aggregator.dart';
import '../services/shop_pool_keyword_relevance.dart';
import '../utils/room_import_product_image.dart';
import '../utils/shop_display_resolve.dart';
import '../utils/shop_pool_fallback_audit.dart';

class ShopPoolFallbackRelevanceStats {
  const ShopPoolFallbackRelevanceStats({
    required this.strongCount,
    required this.mediumCount,
    required this.weakCount,
    required this.noMatchCount,
    required this.unknownGenreCount,
    required this.excludedNoRelevance,
    required this.demotedWeak,
    required this.relevanceQuality,
  });

  final int strongCount;
  final int mediumCount;
  final int weakCount;
  final int noMatchCount;
  final int unknownGenreCount;
  final int excludedNoRelevance;
  final int demotedWeak;
  final ShopPoolFallbackRelevanceQuality relevanceQuality;

  static const empty = ShopPoolFallbackRelevanceStats(
    strongCount: 0,
    mediumCount: 0,
    weakCount: 0,
    noMatchCount: 0,
    unknownGenreCount: 0,
    excludedNoRelevance: 0,
    demotedWeak: 0,
    relevanceQuality: ShopPoolFallbackRelevanceQuality.insufficient,
  );
}

class ShopDiscoveryPoolFallbackResult {
  const ShopDiscoveryPoolFallbackResult({
    required this.summaries,
    required this.usedFallback,
    required this.reason,
    required this.poolCandidateCount,
    required this.convertedCount,
    required this.savedExcludedCount,
    required this.skippedInvalidCount,
    required this.unsafeExcludedCount,
    required this.keyword,
    required this.fallbackRankByShopCode,
    required this.displayedCandidates,
    required this.relevanceByShopCode,
    required this.relevanceStats,
    this.source = 'shopPoolFallback',
  });

  final List<ShopDiscoverySummary> summaries;
  final bool usedFallback;
  final String reason;
  final int poolCandidateCount;
  final int convertedCount;
  final int savedExcludedCount;
  final int skippedInvalidCount;
  final int unsafeExcludedCount;
  final String keyword;
  final Map<String, int> fallbackRankByShopCode;
  final List<ShopPoolCandidate> displayedCandidates;
  final Map<String, ShopPoolKeywordRelevanceResult> relevanceByShopCode;
  final ShopPoolFallbackRelevanceStats relevanceStats;
  final String source;

  bool get canFallback => convertedCount >= 3;
  bool get isPartialFallback => convertedCount >= 3 && convertedCount < 10;
}

class _RankedPoolCandidate {
  const _RankedPoolCandidate({
    required this.candidate,
    required this.relevance,
  });

  final ShopPoolCandidate candidate;
  final ShopPoolKeywordRelevanceResult relevance;
}

abstract final class ShopDiscoveryPoolFallback {
  static ShopDiscoveryPoolFallbackResult buildFallbackSummaries({
    required ProductCatalogRepository? repository,
    required String keyword,
    required List<ShopDiscoverySummary> apiSummaries,
    required bool apiSearchSucceeded,
    required Set<String> savedShopCodes,
    int maxDisplayCount = 10,
  }) {
    if (!ProductCatalogConfig.kProductCatalogEnabled) {
      return _emptyResult(keyword: keyword, reason: 'productCatalogDisabled');
    }
    if (repository == null) {
      return _emptyResult(
        keyword: keyword,
        reason: 'productCatalogRepositoryUnavailable',
      );
    }
    if (apiSummaries.isNotEmpty) {
      return ShopDiscoveryPoolFallbackResult(
        summaries: apiSummaries,
        usedFallback: false,
        reason: 'apiResultAvailable',
        poolCandidateCount: 0,
        convertedCount: 0,
        savedExcludedCount: 0,
        skippedInvalidCount: 0,
        unsafeExcludedCount: 0,
        keyword: keyword,
        fallbackRankByShopCode: const <String, int>{},
        displayedCandidates: const <ShopPoolCandidate>[],
        relevanceByShopCode: const <String, ShopPoolKeywordRelevanceResult>{},
        relevanceStats: ShopPoolFallbackRelevanceStats.empty,
      );
    }

    final aggregate = ProductCatalogShopAggregator.aggregate(
      repository: repository,
      excludeSavedShopCodes: savedShopCodes,
    );
    final candidates = aggregate.candidates;
    final ranked = _rankForKeyword(
      repository: repository,
      keyword: keyword,
      candidates: candidates,
    );

    final selection = _selectForDisplay(
      ranked: ranked,
      maxDisplayCount: maxDisplayCount,
    );

    var skippedInvalidCount = 0;
    final converted = <ShopDiscoverySummary>[];
    final displayedCandidates = <ShopPoolCandidate>[];
    final rankByShopCode = <String, int>{};
    final relevanceByShopCode = <String, ShopPoolKeywordRelevanceResult>{};

    for (var i = 0; i < selection.selected.length; i++) {
      final entry = selection.selected[i];
      final rank = i + 1;
      final summary = _toSummary(
        repository: repository,
        candidate: entry.candidate,
        keyword: keyword,
        rank: rank,
        relevance: entry.relevance,
      );
      if (summary == null) {
        skippedInvalidCount++;
        continue;
      }
      converted.add(summary);
      displayedCandidates.add(entry.candidate);
      rankByShopCode[summary.shopKey] = rank;
      relevanceByShopCode[summary.shopKey] = entry.relevance;
    }

    final poolCandidateCount = candidates.length;
    final convertedCount = converted.length;
    final canFallback = convertedCount >= 3;
    final reason = !apiSearchSucceeded
        ? (canFallback ? 'apiFailed' : 'apiFailed_notEnoughPoolCandidates')
        : (canFallback ? 'apiEmpty' : 'notEnoughPoolCandidates');

    final relevanceStats = _buildRelevanceStats(
      relevanceByShopCode: relevanceByShopCode,
      fallbackCount: convertedCount,
      excludedNoRelevance: selection.excludedNoRelevance,
      demotedWeak: selection.demotedWeak,
    );

    logShopPoolDepthSummaryWithDiagnostics(
      source: 'shopDiscovery',
      candidates: candidates,
      repository: repository,
      excludeSavedShopCodes: savedShopCodes,
    );

    final result = ShopDiscoveryPoolFallbackResult(
      summaries: canFallback ? converted : const <ShopDiscoverySummary>[],
      usedFallback: canFallback,
      reason: reason,
      poolCandidateCount: poolCandidateCount,
      convertedCount: convertedCount,
      savedExcludedCount: aggregate.stats.savedExcluded,
      skippedInvalidCount: skippedInvalidCount,
      unsafeExcludedCount: aggregate.stats.unsafeExcluded,
      keyword: keyword,
      fallbackRankByShopCode: rankByShopCode,
      displayedCandidates: displayedCandidates,
      relevanceByShopCode: relevanceByShopCode,
      relevanceStats: relevanceStats,
    );

    if (canFallback) {
      logShopPoolFallbackDiag(
        repository: repository,
        keyword: keyword,
        fallback: result,
      );
    }

    return result;
  }

  /// 通常 API 成功時の API vs ShopPool 比較監査用（fallback と同系の選定）。
  static ShopDiscoveryPoolCompareAuditData? buildCompareAuditData({
    required ProductCatalogRepository? repository,
    required String keyword,
    required List<ShopPoolCandidate> candidates,
    int maxCount = 10,
  }) {
    if (repository == null) return null;

    final ranked = _rankForKeyword(
      repository: repository,
      keyword: keyword,
      candidates: candidates,
    );
    final selection = _selectForDisplay(
      ranked: ranked,
      maxDisplayCount: maxCount,
    );

    var skippedInvalidCount = 0;
    final summaries = <ShopDiscoverySummary>[];
    final displayedCandidates = <ShopPoolCandidate>[];
    final relevanceByShopCode = <String, ShopPoolKeywordRelevanceResult>{};

    for (var i = 0; i < selection.selected.length; i++) {
      final entry = selection.selected[i];
      final rank = i + 1;
      final summary = _toSummary(
        repository: repository,
        candidate: entry.candidate,
        keyword: keyword,
        rank: rank,
        relevance: entry.relevance,
      );
      if (summary == null) {
        skippedInvalidCount++;
        continue;
      }
      summaries.add(summary);
      displayedCandidates.add(entry.candidate);
      relevanceByShopCode[summary.shopKey] = entry.relevance;
    }

    final relevanceStats = _buildRelevanceStats(
      relevanceByShopCode: relevanceByShopCode,
      fallbackCount: summaries.length,
      excludedNoRelevance: selection.excludedNoRelevance,
      demotedWeak: selection.demotedWeak,
    );

    return ShopDiscoveryPoolCompareAuditData(
      keyword: keyword,
      poolTopSummaries: summaries,
      displayedCandidates: displayedCandidates,
      relevanceByShopCode: relevanceByShopCode,
      relevanceStats: relevanceStats,
      poolCandidateCount: candidates.length,
      skippedInvalidCount: skippedInvalidCount,
    );
  }

  static ShopDiscoveryPoolFallbackResult _emptyResult({
    required String keyword,
    required String reason,
  }) {
    return ShopDiscoveryPoolFallbackResult(
      summaries: const <ShopDiscoverySummary>[],
      usedFallback: false,
      reason: reason,
      poolCandidateCount: 0,
      convertedCount: 0,
      savedExcludedCount: 0,
      skippedInvalidCount: 0,
      unsafeExcludedCount: 0,
      keyword: keyword,
      fallbackRankByShopCode: const <String, int>{},
      displayedCandidates: const <ShopPoolCandidate>[],
      relevanceByShopCode: const <String, ShopPoolKeywordRelevanceResult>{},
      relevanceStats: ShopPoolFallbackRelevanceStats.empty,
    );
  }

  static List<_RankedPoolCandidate> _rankForKeyword({
    required ProductCatalogRepository repository,
    required String keyword,
    required List<ShopPoolCandidate> candidates,
  }) {
    final ranked = candidates
        .map(
          (candidate) => _RankedPoolCandidate(
            candidate: candidate,
            relevance: ShopPoolKeywordRelevance.evaluate(
              repository: repository,
              keyword: keyword,
              candidate: candidate,
            ),
          ),
        )
        .toList(growable: false);
    ranked.sort(_compareRanked);
    return ranked;
  }

  static int _compareRanked(_RankedPoolCandidate a, _RankedPoolCandidate b) {
    final tierA = _relevanceTier(a);
    final tierB = _relevanceTier(b);
    if (tierA != tierB) return tierA.compareTo(tierB);

    final depthA = _depthSortKey(a);
    final depthB = _depthSortKey(b);
    if (depthA != depthB) return depthA.compareTo(depthB);

    return b.candidate.score.compareTo(a.candidate.score);
  }

  /// fallback 表示順: 厚み・ジャンル・画像をスコアより軽く優先。
  static int _depthSortKey(_RankedPoolCandidate entry) {
    var key = 0;
    if (entry.candidate.itemCount < 2) key += 20;
    if (ShopPoolKeywordRelevance.isUnknownGenre(entry.candidate)) {
      key += 10;
    }
    if (!hasDisplayableImageUrl(entry.candidate.representativeImageUrl)) {
      key += 5;
    }
    return key;
  }

  static int _relevanceTier(_RankedPoolCandidate entry) {
    var tier = switch (entry.relevance.level) {
      ShopPoolKeywordMatchLevel.strong => 0,
      ShopPoolKeywordMatchLevel.medium => 1,
      ShopPoolKeywordMatchLevel.weak => 2,
      ShopPoolKeywordMatchLevel.none => 4,
    };
    if (ShopPoolKeywordRelevance.isUnknownGenre(entry.candidate)) {
      tier += entry.relevance.level == ShopPoolKeywordMatchLevel.strong ? 1 : 2;
    }
    if (entry.candidate.itemCount == 1) {
      if (entry.relevance.level == ShopPoolKeywordMatchLevel.strong) {
        tier += 1;
      } else {
        tier += 3;
      }
    } else if (entry.candidate.itemCount < 2) {
      tier += 2;
    }
    return tier;
  }

  static bool _eligibleForPrimaryPool(_RankedPoolCandidate entry) {
    if (entry.relevance.level == ShopPoolKeywordMatchLevel.none) {
      return false;
    }
    if (entry.candidate.itemCount == 1 &&
        entry.relevance.level != ShopPoolKeywordMatchLevel.strong) {
      return false;
    }
    return true;
  }

  static _SelectionResult _selectForDisplay({
    required List<_RankedPoolCandidate> ranked,
    required int maxDisplayCount,
  }) {
    final primary = ranked.where(_eligibleForPrimaryPool).toList(growable: false);
    final backupNoMatch = ranked
        .where((e) => e.relevance.level == ShopPoolKeywordMatchLevel.none)
        .toList(growable: false);

    final selected = <_RankedPoolCandidate>[];
    var excludedNoRelevance = 0;
    var demotedWeak = 0;

    void addFrom(Iterable<_RankedPoolCandidate> source) {
      for (final entry in source) {
        if (selected.length >= maxDisplayCount) return;
        if (selected.any((e) => e.candidate.shopCode == entry.candidate.shopCode)) {
          continue;
        }
        selected.add(entry);
      }
    }

    addFrom(primary);

    if (selected.length < 3) {
      final backup = backupNoMatch
          .where((e) => e.candidate.itemCount >= 2)
          .followedBy(
            backupNoMatch.where((e) => e.candidate.itemCount == 1),
          );
      addFrom(backup);
    }

    for (final entry in ranked) {
      if (selected.any((e) => e.candidate.shopCode == entry.candidate.shopCode)) {
        continue;
      }
      if (entry.relevance.level == ShopPoolKeywordMatchLevel.none) {
        excludedNoRelevance++;
      } else if (entry.relevance.level == ShopPoolKeywordMatchLevel.weak) {
        demotedWeak++;
      }
    }

    return _SelectionResult(
      selected: selected,
      excludedNoRelevance: excludedNoRelevance,
      demotedWeak: demotedWeak,
    );
  }

  static ShopPoolFallbackRelevanceStats _buildRelevanceStats({
    required Map<String, ShopPoolKeywordRelevanceResult> relevanceByShopCode,
    required int fallbackCount,
    required int excludedNoRelevance,
    required int demotedWeak,
  }) {
    var strong = 0;
    var medium = 0;
    var weak = 0;
    var noMatch = 0;
    var unknownGenre = 0;
    for (final r in relevanceByShopCode.values) {
      switch (r.level) {
        case ShopPoolKeywordMatchLevel.strong:
          strong++;
        case ShopPoolKeywordMatchLevel.medium:
          medium++;
        case ShopPoolKeywordMatchLevel.weak:
          weak++;
        case ShopPoolKeywordMatchLevel.none:
          noMatch++;
      }
      if (r.isUnknownGenre) unknownGenre++;
    }
    return ShopPoolFallbackRelevanceStats(
      strongCount: strong,
      mediumCount: medium,
      weakCount: weak,
      noMatchCount: noMatch,
      unknownGenreCount: unknownGenre,
      excludedNoRelevance: excludedNoRelevance,
      demotedWeak: demotedWeak,
      relevanceQuality: ShopPoolKeywordRelevance.evaluateRelevanceQuality(
        fallbackCount: fallbackCount,
        strongCount: strong,
        mediumCount: medium,
        weakCount: weak,
        noMatchCount: noMatch,
      ),
    );
  }

  static ShopDiscoverySummary? _toSummary({
    required ProductCatalogRepository repository,
    required ShopPoolCandidate candidate,
    required String keyword,
    required int rank,
    required ShopPoolKeywordRelevanceResult relevance,
  }) {
    final shopCode = candidate.shopCode.trim();
    if (shopCode.isEmpty || shopCode == 'unknown') return null;

    final resolvedName = ShopDisplayResolve.resolveDisplayShopName(
      shopName: candidate.shopName,
      shopCode: shopCode,
      screen: 'shopDiscoveryPoolFallback',
    );
    if (resolvedName == ShopDisplayResolve.unknownShopLabel) return null;
    if (ShopDisplayResolve.looksLikeShopCode(resolvedName)) return null;

    final shopUrl = _safeHttpUrl(candidate.shopUrl);
    if (shopUrl.isEmpty) return null;
    if (candidate.safeItemCount <= 0) return null;

    final imageUrl = _resolveDisplayImageUrl(
      repository: repository,
      candidate: candidate,
      keyword: keyword,
      relevance: relevance,
    );
    final representativeItems = <ShopRepresentativeItem>[
      ShopRepresentativeItem(
        itemName: '$resolvedName の候補',
        imageUrl: imageUrl,
        itemUrl: shopUrl,
      ),
    ];

    return ShopDiscoverySummary(
      shopKey: shopCode,
      shopName: resolvedName,
      shopUrl: shopUrl,
      hitItemCount: candidate.itemCount,
      maxReviewCount: candidate.maxReviewCount,
      avgReviewAverage: candidate.averageReviewAverage,
      discoveryScore: candidate.score,
      representativeItems: representativeItems,
      origin: 'shopPoolFallback',
      discoveryKeyword: keyword,
      discoveryRank: rank,
    );
  }

  static String _resolveDisplayImageUrl({
    required ProductCatalogRepository repository,
    required ShopPoolCandidate candidate,
    required String keyword,
    required ShopPoolKeywordRelevanceResult relevance,
  }) {
    final ids = <String>{
      ...candidate.sourceProductIds,
      ...candidate.sampleProductIds,
    };
    final products = repository.getByCanonicalIds(ids, touch: false);
    final tokens = ShopPoolFallbackKeywordSynonyms.tokensFor(keyword)
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    String? keywordMatchedImage;
    String? anySafeImage;
    for (final product in products) {
      final url = _safeImageUrl(product.imageUrl);
      if (url.isEmpty) continue;
      anySafeImage ??= url;
      if (relevance.level == ShopPoolKeywordMatchLevel.strong ||
          _productNameMatchesTokens(product, tokens)) {
        keywordMatchedImage ??= url;
      }
    }

    if (keywordMatchedImage != null && keywordMatchedImage.isNotEmpty) {
      return keywordMatchedImage;
    }
    if (anySafeImage != null && anySafeImage.isNotEmpty) {
      return anySafeImage;
    }
    return _safeImageUrl(candidate.representativeImageUrl);
  }

  static bool _productNameMatchesTokens(
    CatalogProduct product,
    Set<String> tokens,
  ) {
    final name = product.itemName.trim().toLowerCase();
    if (name.isEmpty) return false;
    for (final token in tokens) {
      if (name.contains(token)) return true;
    }
    return false;
  }

  /// カード表示に使える画像 URL か（noimage / placeholder 除外済み）。
  static bool hasDisplayableImageUrl(String raw) {
    return _safeImageUrl(raw).isNotEmpty;
  }

  static String _safeHttpUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final uri = Uri.tryParse(t);
    if (uri == null || !uri.hasAuthority) return '';
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return '';
    return t;
  }

  static String _safeImageUrl(String raw) {
    final t = _safeHttpUrl(raw);
    if (t.isEmpty) return '';
    if (RoomImportProductImage.isRejectedProductImageUrl(t)) return '';
    return t;
  }
}

/// 通常 API 成功時の監査用（UI 非表示）。keyword 適用後の上位候補。
class ShopDiscoveryPoolCompareAuditData {
  const ShopDiscoveryPoolCompareAuditData({
    required this.keyword,
    required this.poolTopSummaries,
    required this.displayedCandidates,
    required this.relevanceByShopCode,
    required this.relevanceStats,
    required this.poolCandidateCount,
    required this.skippedInvalidCount,
  });

  final String keyword;
  final List<ShopDiscoverySummary> poolTopSummaries;
  final List<ShopPoolCandidate> displayedCandidates;
  final Map<String, ShopPoolKeywordRelevanceResult> relevanceByShopCode;
  final ShopPoolFallbackRelevanceStats relevanceStats;
  final int poolCandidateCount;
  final int skippedInvalidCount;
}

class _SelectionResult {
  const _SelectionResult({
    required this.selected,
    required this.excludedNoRelevance,
    required this.demotedWeak,
  });

  final List<_RankedPoolCandidate> selected;
  final int excludedNoRelevance;
  final int demotedWeak;
}
