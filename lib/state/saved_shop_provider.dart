import 'package:flutter/foundation.dart';

import '../models/saved_shop.dart';
import '../repository/saved_shop_repository.dart';

class SavedShopProvider extends ChangeNotifier {
  SavedShopProvider({required SavedShopRepository repository})
    : _repository = repository,
      _shops = repository.loadAll();

  final SavedShopRepository _repository;
  List<SavedShop> _shops;

  /// ショップID単位の保存・解除処理中セット（候補登録の productId busy と同様）。
  final Set<String> _busyShopIds = {};

  List<SavedShop> get shops => List.unmodifiable(_shops);

  bool isSaved(String shopId) {
    final id = shopId.trim();
    if (id.isEmpty) return false;
    return _shops.any((e) => e.shopId == id);
  }

  /// 同一ショップの保存・解除が処理中かどうか。
  bool isShopBusy(String shopId) {
    final id = shopId.trim();
    if (id.isEmpty) return false;
    return _busyShopIds.contains(id);
  }

  SavedShop? findById(String shopId) {
    final id = shopId.trim();
    if (id.isEmpty) return null;
    for (final e in _shops) {
      if (e.shopId == id) return e;
    }
    return null;
  }

  /// ショップを保存する。処理中の同一IDはスキップして false を返す。
  Future<bool> upsertShop({
    required String shopId,
    required String shopName,
    required String shopUrl,
  }) async {
    final id = shopId.trim();
    final name = shopName.trim();
    if (id.isEmpty || name.isEmpty) return false;
    if (_busyShopIds.contains(id)) return false;
    _busyShopIds.add(id);
    notifyListeners();
    try {
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
      return true;
    } finally {
      _busyShopIds.remove(id);
      notifyListeners();
    }
  }

  /// ショップ保存を解除する。処理中の同一IDはスキップして false を返す。
  Future<bool> removeShop(String shopId) async {
    final id = shopId.trim();
    if (id.isEmpty) return false;
    if (_busyShopIds.contains(id)) return false;
    _busyShopIds.add(id);
    notifyListeners();
    try {
      _shops = _shops.where((e) => e.shopId != id).toList(growable: false);
      await _repository.saveAll(_shops);
      notifyListeners();
      return true;
    } finally {
      _busyShopIds.remove(id);
      notifyListeners();
    }
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
