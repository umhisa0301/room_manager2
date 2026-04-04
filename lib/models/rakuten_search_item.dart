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
    this.reviewCount = 0,
    this.reviewAverage = 0,
    this.shopCode = '',
    this.shopUrl = '',
    this.genreId = '',
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
  final int reviewCount;
  final double reviewAverage;

  /// 店舗コード（楽天API `shopCode`）。
  final String shopCode;

  /// 店舗URL（楽天API `shopUrl`）。
  final String shopUrl;

  /// ジャンルID（楽天API `genreId`。数値でも文字列として保持）。
  final String genreId;

  /// 「楽天で見る」で開くURL（アフィリエイトURLを優先）。
  String get browserLaunchUrl =>
      affiliateUrl.trim().isNotEmpty ? affiliateUrl.trim() : itemUrl;

  /// API が `affiliateUrl` を返したか（リクエストの affiliateId が有効なときに付く）。
  bool get hasAffiliateUrlInResponse => affiliateUrl.trim().isNotEmpty;
}
