/// ショップ発掘結果の1件（1ショップ分）。
class ShopDiscoverySummary {
  const ShopDiscoverySummary({
    required this.shopKey,
    required this.shopName,
    required this.shopUrl,
    required this.hitItemCount,
    required this.maxReviewCount,
    required this.avgReviewAverage,
    required this.discoveryScore,
    required this.representativeItems,
    this.origin,
    this.discoveryKeyword,
    this.discoveryRank,
  });

  final String shopKey;
  final String shopName;
  final String shopUrl;
  final int hitItemCount;
  final int maxReviewCount;
  final double avgReviewAverage;
  final double discoveryScore;
  final List<ShopRepresentativeItem> representativeItems;
  final String? origin;
  final String? discoveryKeyword;
  final int? discoveryRank;
}

/// ショップを代表する商品（サムネ・タイトル・URL）。
class ShopRepresentativeItem {
  const ShopRepresentativeItem({
    required this.itemName,
    required this.imageUrl,
    required this.itemUrl,
  });

  final String itemName;
  final String imageUrl;
  final String itemUrl;
}
