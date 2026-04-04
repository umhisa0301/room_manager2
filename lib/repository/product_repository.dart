import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';

/// 商品一覧の永続化を担当するリポジトリ。
/// 保存・読込はここに集約し、将来 Hive / Isar / Firebase に差し替えやすいようにする。
class ProductRepository {
  ProductRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyProductList = 'product_list';

  /// 保存済みの商品一覧を読み込む。データなし・不正時は空リストを返す。
  List<Product> loadProducts() {
    try {
      final jsonStr = _prefs.getString(_keyProductList);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final list = jsonDecode(jsonStr);
      if (list is! List) return [];

      final products = <Product>[];
      for (final item in list) {
        final product = Product.fromJson(
          item is Map<String, dynamic> ? item : null,
        );
        if (product != null) products.add(product);
      }
      return products;
    } catch (_) {
      return [];
    }
  }

  /// 商品一覧を上書き保存する。
  void saveProducts(List<Product> products) {
    try {
      final list = products.map((p) => p.toJson()).toList();
      _prefs.setString(_keyProductList, jsonEncode(list));
    } catch (_) {
      // 保存失敗時はクラッシュさせない（必要ならログやエラー通知を検討）
    }
  }
}
