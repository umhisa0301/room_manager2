/// 楽天APIのレスポンスをアプリ側で扱いやすくした商品モデル。
class RakutenSearchItem {
  const RakutenSearchItem({
    required this.productId,
    required this.itemName,
    required this.itemPrice,
    required this.itemUrl,
    required this.affiliateUrl,
    required this.imageUrl,
    required this.shopName,
  });

  final String productId;
  final String itemName;
  final int itemPrice;

  /// 通常の商品ページURL（常に保持）。
  final String itemUrl;

  /// リクエストに `affiliateId` があるときAPIが返すアフィリエイト用URL。無い場合は空。
  final String affiliateUrl;

  final String imageUrl;
  final String shopName;

  /// 「楽天で見る」で開くURL（アフィリエイトURLを優先）。
  String get browserLaunchUrl =>
      affiliateUrl.trim().isNotEmpty ? affiliateUrl.trim() : itemUrl;

  /// API が `affiliateUrl` を返したか（リクエストの affiliateId が有効なときに付く）。
  bool get hasAffiliateUrlInResponse => affiliateUrl.trim().isNotEmpty;
}

