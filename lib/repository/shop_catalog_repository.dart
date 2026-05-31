import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/demo_mode.dart';
import '../config/shop_catalog_config.dart';
import '../models/shop_catalog_entry.dart';
import '../utils/app_debug_log.dart';
import '../utils/shop_catalog_keys.dart';

/// upsert バッチ結果。
class ShopCatalogUpsertBatchResult {
  const ShopCatalogUpsertBatchResult({
    required this.inserted,
    required this.updated,
    required this.skipped,
    required this.evicted,
  });

  final int inserted;
  final int updated;
  final int skipped;
  final int evicted;
}

/// ローカル共通ショップカタログ（SharedPreferences 永続化）。
class ShopCatalogRepository {
  ShopCatalogRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _prefsKey = 'shop_catalog_v1';

  Map<String, ShopCatalogEntry> _shops = {};
  Map<String, String> _aliasToShopCode = {};
  List<String> _lruOrder = [];
  bool _loaded = false;

  bool get _enabled => ShopCatalogConfig.kShopCatalogEnabled;

  void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    if (!_enabled || kDemoModeEnabled) {
      _shops = {};
      _aliasToShopCode = {};
      _lruOrder = [];
      return;
    }
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final shopsRaw = decoded['shops'];
      final lruRaw = decoded['lruOrder'];
      if (shopsRaw is! List) return;

      final shops = <String, ShopCatalogEntry>{};
      for (final entry in shopsRaw) {
        if (entry is! Map<String, dynamic>) continue;
        final shop = ShopCatalogEntry.fromJson(entry);
        if (shop == null || !shop.isSavable) continue;
        shops[shop.shopCode] = shop;
      }

      final lru = lruRaw is List
          ? lruRaw.map((e) => e.toString()).toList(growable: true)
          : <String>[];
      lru.removeWhere((id) => !shops.containsKey(id));
      for (final id in shops.keys) {
        if (!lru.contains(id)) lru.add(id);
      }

      _shops = shops;
      _lruOrder = lru;
      _rebuildAliasIndex();
    } catch (e, st) {
      importantDebugLog('[SHOP_CATALOG] load failed: $e\n$st');
      _shops = {};
      _aliasToShopCode = {};
      _lruOrder = [];
    }
  }

  void _rebuildAliasIndex() {
    final index = <String, String>{};
    for (final shop in _shops.values) {
      for (final alias in _allAliasesFor(shop)) {
        index[alias] = shop.shopCode;
      }
    }
    _aliasToShopCode = index;
  }

  Iterable<String> _allAliasesFor(ShopCatalogEntry shop) {
    return ShopCatalogKeys.mergeAliases(
      shop.aliases,
      ShopCatalogKeys.buildAliases(
        shopCode: shop.shopCode,
        shopUrl: shop.shopUrl,
      ),
    );
  }

  Future<bool> _persist() async {
    if (!_enabled || kDemoModeEnabled) return true;
    try {
      final payload = {
        'v': 1,
        'shops': _lruOrder
            .where(_shops.containsKey)
            .map((id) => _shops[id]!.toJson())
            .toList(growable: false),
        'lruOrder': _lruOrder,
      };
      return await _prefs.setString(_prefsKey, jsonEncode(payload));
    } catch (e, st) {
      importantDebugLog('[SHOP_CATALOG] persist failed: $e\n$st');
      return false;
    }
  }

  void _touchLru(String shopCode) {
    _lruOrder.remove(shopCode);
    _lruOrder.add(shopCode);
  }

  void _registerAliases(ShopCatalogEntry shop) {
    for (final alias in _allAliasesFor(shop)) {
      _aliasToShopCode[alias] = shop.shopCode;
    }
  }

  void _unregisterAliases(ShopCatalogEntry shop) {
    for (final alias in _allAliasesFor(shop)) {
      final mapped = _aliasToShopCode[alias];
      if (mapped == shop.shopCode) {
        _aliasToShopCode.remove(alias);
      }
    }
  }

  int _evictIfNeeded() {
    var evicted = 0;
    while (_shops.length > ShopCatalogConfig.maxShopCatalogEntries) {
      if (_lruOrder.isEmpty) break;
      final oldest = _lruOrder.first;
      final removed = _shops.remove(oldest);
      _lruOrder.removeAt(0);
      if (removed != null) {
        _unregisterAliases(removed);
        evicted++;
      }
    }
    if (evicted > 0) {
      shopCatalogAuditLog(
        '[SHOP_CATALOG_LRU_SUMMARY] evicted=$evicted '
        'remaining=${_shops.length} max=${ShopCatalogConfig.maxShopCatalogEntries}',
      );
    }
    return evicted;
  }

  ShopCatalogEntry? getByShopCode(String shopCode, {bool touch = true}) {
    if (!_enabled) return null;
    _ensureLoaded();
    final id = ShopCatalogKeys.normalizeShopCode(shopCode);
    if (id == null) return null;
    final shop = _shops[id];
    if (shop == null) return null;
    if (touch) {
      final touched = shop.copyWith(lastAccessedAt: DateTime.now());
      _shops[id] = touched;
      _touchLru(id);
    }
    return _shops[id];
  }

  ShopCatalogEntry? findByAlias(String alias, {bool touch = true}) {
    if (!_enabled) return null;
    _ensureLoaded();
    final key = alias.trim();
    if (key.isEmpty) return null;
    final shopCode = _aliasToShopCode[key];
    if (shopCode == null) return null;
    return getByShopCode(shopCode, touch: touch);
  }

  List<ShopCatalogEntry> getAll() {
    if (!_enabled) return const [];
    _ensureLoaded();
    return _lruOrder
        .where(_shops.containsKey)
        .map((id) => _shops[id]!)
        .toList(growable: false);
  }

  int count() {
    if (!_enabled) return 0;
    _ensureLoaded();
    return _shops.length;
  }

  bool isStale(ShopCatalogEntry shop, {DateTime? now}) {
    final ref = shop.lastValidatedAt;
    final t = now ?? DateTime.now();
    final ageSeconds = t.difference(ref).inSeconds;
    return ageSeconds > shop.cacheTtlSeconds;
  }

  Future<ShopCatalogUpsertBatchResult> upsert(ShopCatalogEntry incoming) async {
    return upsertAll([incoming]);
  }

  Future<ShopCatalogUpsertBatchResult> upsertAll(
    Iterable<ShopCatalogEntry> incomingShops,
  ) async {
    if (!_enabled) {
      return const ShopCatalogUpsertBatchResult(
        inserted: 0,
        updated: 0,
        skipped: 0,
        evicted: 0,
      );
    }
    _ensureLoaded();
    if (kDemoModeEnabled) {
      return const ShopCatalogUpsertBatchResult(
        inserted: 0,
        updated: 0,
        skipped: 0,
        evicted: 0,
      );
    }

    var inserted = 0;
    var updated = 0;
    var skipped = 0;
    var evicted = 0;

    for (final raw in incomingShops) {
      if (!raw.isSavable) {
        skipped++;
        continue;
      }

      final incoming = raw;
      final code = incoming.shopCode;
      final existingByCode = _shops[code];
      final existingByAlias = _findExistingForIncoming(incoming);

      if (existingByCode != null) {
        _unregisterAliases(existingByCode);
        final merged = existingByCode.mergeFrom(incoming);
        _shops[code] = merged;
        _registerAliases(merged);
        _touchLru(code);
        updated++;
        continue;
      }

      if (existingByAlias != null && existingByAlias.shopCode != code) {
        _unregisterAliases(existingByAlias);
        final merged = existingByAlias.mergeFrom(incoming);
        _shops[existingByAlias.shopCode] = merged;
        _registerAliases(merged);
        _touchLru(existingByAlias.shopCode);
        updated++;
        continue;
      }

      _shops[code] = incoming;
      _registerAliases(incoming);
      _touchLru(code);
      inserted++;
    }

    evicted = _evictIfNeeded();
    try {
      await _persist();
    } catch (e, st) {
      importantDebugLog('[SHOP_CATALOG] upsert persist failed: $e\n$st');
    }

    shopCatalogAuditLog(
      '[SHOP_CATALOG_UPSERT_SUMMARY] inserted=$inserted updated=$updated '
      'skipped=$skipped evicted=$evicted total=${_shops.length}',
    );

    return ShopCatalogUpsertBatchResult(
      inserted: inserted,
      updated: updated,
      skipped: skipped,
      evicted: evicted,
    );
  }

  ShopCatalogEntry? _findExistingForIncoming(ShopCatalogEntry incoming) {
    for (final alias in _allAliasesFor(incoming)) {
      final shopCode = _aliasToShopCode[alias];
      if (shopCode == null) continue;
      final existing = _shops[shopCode];
      if (existing != null) return existing;
    }
    return null;
  }

  Future<void> clear() async {
    if (!_enabled) return;
    _ensureLoaded();
    _shops = {};
    _aliasToShopCode = {};
    _lruOrder = [];
    if (!kDemoModeEnabled) {
      try {
        await _prefs.remove(_prefsKey);
      } catch (e, st) {
        importantDebugLog('[SHOP_CATALOG] clear failed: $e\n$st');
      }
    }
  }
}
