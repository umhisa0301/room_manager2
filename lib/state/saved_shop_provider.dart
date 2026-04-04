import 'package:flutter/foundation.dart';

import '../models/saved_shop.dart';
import '../repository/saved_shop_repository.dart';

class SavedShopProvider extends ChangeNotifier {
  SavedShopProvider({required SavedShopRepository repository})
    : _repository = repository,
      _shops = repository.loadAll();

  final SavedShopRepository _repository;
  List<SavedShop> _shops;

  List<SavedShop> get shops => List.unmodifiable(_shops);

  bool isSaved(String shopId) {
    final id = shopId.trim();
    if (id.isEmpty) return false;
    return _shops.any((e) => e.shopId == id);
  }

  SavedShop? findById(String shopId) {
    final id = shopId.trim();
    if (id.isEmpty) return null;
    for (final e in _shops) {
      if (e.shopId == id) return e;
    }
    return null;
  }

  Future<void> upsertShop({
    required String shopId,
    required String shopName,
    required String shopUrl,
  }) async {
    final id = shopId.trim();
    final name = shopName.trim();
    if (id.isEmpty || name.isEmpty) return;
    final now = DateTime.now();
    final next = <SavedShop>[];
    var updated = false;
    for (final e in _shops) {
      if (e.shopId == id) {
        next.add(
          e.copyWith(
            shopName: name,
            shopUrl: shopUrl.trim(),
            savedAt: e.savedAt,
          ),
        );
        updated = true;
      } else {
        next.add(e);
      }
    }
    if (!updated) {
      next.add(
        SavedShop(
          shopId: id,
          shopName: name,
          shopUrl: shopUrl.trim(),
          savedAt: now,
        ),
      );
    }
    next.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    _shops = next;
    await _repository.saveAll(_shops);
    notifyListeners();
  }

  Future<void> removeShop(String shopId) async {
    final id = shopId.trim();
    if (id.isEmpty) return;
    _shops = _shops.where((e) => e.shopId != id).toList(growable: false);
    await _repository.saveAll(_shops);
    notifyListeners();
  }

  Future<void> markViewed(String shopId) async {
    final id = shopId.trim();
    if (id.isEmpty) return;
    var changed = false;
    final now = DateTime.now();
    _shops = _shops
        .map((e) {
          if (e.shopId != id) return e;
          changed = true;
          return e.copyWith(lastViewedAt: now);
        })
        .toList(growable: false);
    if (!changed) return;
    await _repository.saveAll(_shops);
    notifyListeners();
  }
}
