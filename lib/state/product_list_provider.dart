import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/product_status.dart';

/// 商品一覧の状態を保持する ChangeNotifier。
/// 追加・編集・削除はここを経由し、永続化レイヤーは後から差し替え可能。
class ProductListProvider extends ChangeNotifier {
  final List<Product> _products = [];

  List<Product> get products => List.unmodifiable(_products);

  /// タブ用：指定ステータスの商品だけ返す
  List<Product> byStatus(ProductStatus status) {
    return _products.where((p) => p.status == status).toList();
  }

  void addProduct(Product product) {
    _products.add(product);
    notifyListeners();
  }

  /// 編集用（詳細・編集画面で利用）
  void updateProduct(Product product) {
    final i = _products.indexWhere((p) => p.id == product.id);
    if (i >= 0) {
      _products[i] = product;
      notifyListeners();
    }
  }

  /// id で取得（詳細画面で利用）
  Product? findById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
