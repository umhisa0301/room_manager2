import '../config/product_catalog_config.dart';
import '../models/shop_discovery_summary.dart';
import '../models/shop_pool_candidate.dart';
import '../repository/product_catalog_repository.dart';
import '../services/product_catalog_shop_aggregator.dart';
import '../utils/room_import_product_image.dart';
import '../utils/shop_display_resolve.dart';

class ShopDiscoveryPoolFallbackResult {
  const ShopDiscoveryPoolFallbackResult({
    required this.summaries,
    required this.usedFallback,
    required this.reason,
    required this.poolCandidateCount,
    required this.convertedCount,
    required this.savedExcludedCount,
    required this.skippedInvalidCount,
    required this.keyword,
    this.source = 'shopPoolFallback',
  });

  final List<ShopDiscoverySummary> summaries;
  final bool usedFallback;
  final String reason;
  final int poolCandidateCount;
  final int convertedCount;
  final int savedExcludedCount;
  final int skippedInvalidCount;
  final String keyword;
  final String source;

  bool get canFallback => convertedCount >= 3;
  bool get isPartialFallback => convertedCount >= 3 && convertedCount < 10;
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
      return ShopDiscoveryPoolFallbackResult(
        summaries: const <ShopDiscoverySummary>[],
        usedFallback: false,
        reason: 'productCatalogDisabled',
        poolCandidateCount: 0,
        convertedCount: 0,
        savedExcludedCount: 0,
        skippedInvalidCount: 0,
        keyword: keyword,
      );
    }
    if (repository == null) {
      return ShopDiscoveryPoolFallbackResult(
        summaries: const <ShopDiscoverySummary>[],
        usedFallback: false,
        reason: 'productCatalogRepositoryUnavailable',
        poolCandidateCount: 0,
        convertedCount: 0,
        savedExcludedCount: 0,
        skippedInvalidCount: 0,
        keyword: keyword,
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
        keyword: keyword,
      );
    }

    final aggregate = ProductCatalogShopAggregator.aggregate(
      repository: repository,
      excludeSavedShopCodes: savedShopCodes,
    );
    final candidates = aggregate.candidates;
    var skippedInvalidCount = 0;
    final converted = <ShopDiscoverySummary>[];
    for (final candidate in candidates) {
      final summary = _toSummary(candidate);
      if (summary == null) {
        skippedInvalidCount++;
        continue;
      }
      converted.add(summary);
      if (converted.length >= maxDisplayCount) break;
    }

    final poolCandidateCount = candidates.length;
    final convertedCount = converted.length;
    final canFallback = convertedCount >= 3;
    final reason = !apiSearchSucceeded
        ? (canFallback ? 'apiFailed' : 'apiFailed_notEnoughPoolCandidates')
        : (canFallback ? 'apiEmpty' : 'notEnoughPoolCandidates');

    return ShopDiscoveryPoolFallbackResult(
      summaries: canFallback ? converted : const <ShopDiscoverySummary>[],
      usedFallback: canFallback,
      reason: reason,
      poolCandidateCount: poolCandidateCount,
      convertedCount: convertedCount,
      savedExcludedCount: aggregate.stats.savedExcluded,
      skippedInvalidCount: skippedInvalidCount,
      keyword: keyword,
    );
  }

  static ShopDiscoverySummary? _toSummary(ShopPoolCandidate candidate) {
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

    final imageUrl = _safeImageUrl(candidate.representativeImageUrl);
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
    );
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
