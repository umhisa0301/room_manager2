/// 楽天APIのレスポンスをアプリ側で扱いやすくした商品モデル。
class RakutenSearchItem {
  const RakutenSearchItem({
    required this.productId,
    required this.itemName,
    required this.itemPrice,
    required this.itemUrl,
    required this.imageUrl,
    required this.shopName,
  });

  final String productId;
  final String itemName;
  final int itemPrice;
  final String itemUrl;
  final String imageUrl;
  final String shopName;
}

