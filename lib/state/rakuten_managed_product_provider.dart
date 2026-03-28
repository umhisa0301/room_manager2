import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../repository/rakuten_managed_product_repository.dart';

/// 楽天検索由来のローカル管理商品の状態（UI向け）。
class RakutenManagedProductProvider extends ChangeNotifier {
  RakutenManagedProductProvider({required RakutenManagedProductRepository repository})
      : _repository = repository {
    _reloadFromStorage();
  }

  final RakutenManagedProductRepository _repository;

  List<RakutenManagedProduct> _items = const [];
  final Set<String> _registeringProductIds = {};

  List<RakutenManagedProduct> get items => List.unmodifiable(_items);

  /// 永続化一覧に無い場合は [RakutenManagedProductStatus.none]。
  RakutenManagedProductStatus statusForProduct(String productId) {
    final id = productId.trim();
    if (id.isEmpty) return RakutenManagedProductStatus.none;
    for (final e in _items) {
      if (e.productId == id) return e.status;
    }
    return RakutenManagedProductStatus.none;
  }

  bool isRegistering(String productId) =>
      _registeringProductIds.contains(productId.trim());

  void _reloadFromStorage() {
    _items = _repository.loadAll();
  }

  /// コレ候補として登録。成功時は null、失敗時はエラーメッセージ。
  /// 既に候補・コレ済の場合は重複せず成功扱い（null）。
  Future<String?> registerCandidate(RakutenSearchItem item) async {
    final id = item.productId.trim();
    if (id.isEmpty) {
      return '商品IDが空のため登録できません';
    }
    if (_registeringProductIds.contains(id)) {
      return null;
    }
    _registeringProductIds.add(id);
    notifyListeners();
    try {
      await _repository.registerCandidateFromSearchItem(item);
      _reloadFromStorage();
      return null;
    } on Exception catch (e) {
      return e.toString();
    } catch (e) {
      return '登録に失敗しました: $e';
    } finally {
      _registeringProductIds.remove(id);
      notifyListeners();
    }
  }
}
