/// ProductCatalog 集計由来のショップ候補（UI 未接続・読み取り専用）。
class ShopPoolCandidate {
  const ShopPoolCandidate({
    required this.shopCode,
    required this.shopName,
    required this.shopUrl,
    required this.representativeImageUrl,
    required this.primaryGenreId,
    required this.primaryGenreName,
    required this.itemCount,
    required this.safeItemCount,
    required this.itemsWithImage,
    required this.itemsWithPrice,
    required this.averageReviewAverage,
    required this.maxReviewCount,
    required this.averagePrice,
    required this.minPrice,
    required this.maxPrice,
    required this.score,
    required this.sampleProductIds,
    required this.sourceGenres,
    required this.sourceProductIds,
  });

  final String shopCode;
  final String shopName;
  final String shopUrl;
  final String representativeImageUrl;
  final String primaryGenreId;
  final String primaryGenreName;
  final int itemCount;
  final int safeItemCount;
  final int itemsWithImage;
  final int itemsWithPrice;
  final double averageReviewAverage;
  final int maxReviewCount;
  final double averagePrice;
  final int minPrice;
  final int maxPrice;
  final double score;
  final List<String> sampleProductIds;
  final List<String> sourceGenres;
  final List<String> sourceProductIds;
}

/// [ProductCatalogShopAggregator.aggregate] の除外・集計サマリ。
class ShopPoolAggregateStats {
  const ShopPoolAggregateStats({
    required this.catalogProducts,
    required this.catalogShops,
    required this.poolCandidates,
    required this.savedExcluded,
    required this.staleExcluded,
    required this.lowTrustExcluded,
    required this.unsafeExcluded,
    required this.emptyShopCodeExcluded,
  });

  final int catalogProducts;
  final int catalogShops;
  final int poolCandidates;
  final int savedExcluded;
  final int staleExcluded;
  final int lowTrustExcluded;
  final int unsafeExcluded;
  final int emptyShopCodeExcluded;

  static const empty = ShopPoolAggregateStats(
    catalogProducts: 0,
    catalogShops: 0,
    poolCandidates: 0,
    savedExcluded: 0,
    staleExcluded: 0,
    lowTrustExcluded: 0,
    unsafeExcluded: 0,
    emptyShopCodeExcluded: 0,
  );
}

/// ProductCatalog 集計結果。
class ShopPoolAggregateResult {
  const ShopPoolAggregateResult({
    required this.candidates,
    required this.stats,
  });

  final List<ShopPoolCandidate> candidates;
  final ShopPoolAggregateStats stats;
}
