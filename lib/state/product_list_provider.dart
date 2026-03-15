import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/product_status.dart';
import '../repository/product_repository.dart';

/// 商品一覧の状態を保持する ChangeNotifier。
/// 追加・編集・削除はここを経由し、永続化は ProductRepository に委譲する。
class ProductListProvider extends ChangeNotifier {
  ProductListProvider({required ProductRepository repository})
      : _repository = repository,
        _products = List.from(repository.loadProducts());

  final ProductRepository _repository;
  final List<Product> _products;

  List<Product> get products => List.unmodifiable(_products);

  /// タブ用：指定ステータスの商品だけ返す
  List<Product> byStatus(ProductStatus status) {
    return _products.where((p) => p.status == status).toList();
  }

  void _persist() {
    _repository.saveProducts(_products);
  }

  void addProduct(Product product) {
    _products.add(product);
    _persist();
    notifyListeners();
  }

  /// 編集用（詳細・編集画面で利用）
  void updateProduct(Product product) {
    final i = _products.indexWhere((p) => p.id == product.id);
    if (i >= 0) {
      _products[i] = product;
      _persist();
      notifyListeners();
    }
  }

  /// 削除用（詳細・一覧から削除する際に利用）
  void deleteProduct(Product product) {
    final had = _products.any((p) => p.id == product.id);
    if (had) {
      _products.removeWhere((p) => p.id == product.id);
      _persist();
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
