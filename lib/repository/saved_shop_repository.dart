import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/demo_mode.dart';
import '../data/demo_mode_data.dart';
import '../models/saved_shop.dart';

class SavedShopRepository {
  SavedShopRepository(this._prefs);

  final SharedPreferences _prefs;
  static const String _key = 'saved_shops_v1';

  List<SavedShop> loadAll() {
    if (kDemoModeEnabled) {
      return DemoModeData.savedShops();
    }
    final raw = _prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <SavedShop>[];
      for (final e in decoded) {
        if (e is Map<String, dynamic>) {
          final shop = SavedShop.fromJson(e);
          if (shop != null) out.add(shop);
        }
      }
      out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<SavedShop> shops) async {
    if (kDemoModeEnabled) {
      return;
    }
    final data = shops.map((e) => e.toJson()).toList(growable: false);
    await _prefs.setString(_key, jsonEncode(data));
  }
}
