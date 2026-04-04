import 'product.dart';

/// 商品検索結果の1件。
/// どの項目で一致したかを保持し、UIで一致種別を表示しやすくする。
class ProductSearchHit {
  const ProductSearchHit({required this.product, required this.matchKinds});

  final Product product;
  final List<ProductMatchKind> matchKinds;
}

enum ProductMatchKind {
  productName,
  productUrl,
  urlExact,
  memo,
  tags,
  quickComment,
}

extension ProductMatchKindLabel on ProductMatchKind {
  String get label {
    switch (this) {
      case ProductMatchKind.productName:
        return '商品名一致';
      case ProductMatchKind.productUrl:
        return 'URL部分一致';
      case ProductMatchKind.urlExact:
        return 'URL一致';
      case ProductMatchKind.memo:
        return 'メモ一致';
      case ProductMatchKind.tags:
        return 'タグ一致';
      case ProductMatchKind.quickComment:
        return 'コメント一致';
    }
  }
}
