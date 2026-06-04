import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/debug_log_flags.dart';
import '../config/demo_mode.dart';
import '../config/product_catalog_config.dart';
import '../models/catalog_product.dart';
import '../utils/app_debug_log.dart';
import '../utils/catalog_product_keys.dart';

/// upsert 1件の監査結果（[CATALOG_AUDIT_LOGS] 時のみ収集）。
class ProductCatalogUpsertItemResult {
  const ProductCatalogUpsertItemResult({
    required this.inputCanonicalId,
    required this.resolvedCanonicalId,
    required this.operation,
    required this.mergeReason,
    required this.inputShopCode,
    required this.savedShopCode,
    required this.aliasMatchedBy,
    required this.saved,
    required this.normalizedItemUrl,
    required this.productId,
  });

  final String inputCanonicalId;
  final String resolvedCanonicalId;
  final String operation;
  final String mergeReason;
  final String inputShopCode;
  final String savedShopCode;
  final String aliasMatchedBy;
  final bool saved;
  final String normalizedItemUrl;
  final String productId;
}

/// upsert バッチ結果。
class ProductCatalogUpsertBatchResult {
  const ProductCatalogUpsertBatchResult({
    required this.inserted,
    required this.updated,
    required this.skipped,
    required this.evicted,
    this.updatedByCanonicalId = 0,
    this.updatedByAlias = 0,
    this.aliasConflictPrevented = 0,
    this.itemResults = const [],
  });

  final int inserted;
  final int updated;
  final int skipped;
  final int evicted;
  final int updatedByCanonicalId;
  final int updatedByAlias;

  /// 別 canonicalId への alias 誤マージを防ぎ、別商品として insert した件数。
  final int aliasConflictPrevented;
  final List<ProductCatalogUpsertItemResult> itemResults;
}

/// ローカル共通商品カタログ（SharedPreferences 永続化）。
///
/// 将来 Drift / サーバキャッシュへ移行しやすいよう、永続化詳細はこのクラス内に閉じる。
class ProductCatalogRepository {
  ProductCatalogRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _prefsKey = 'product_catalog_v1';

  Map<String, CatalogProduct> _products = {};
  Map<String, String> _aliasToCanonical = {};
  List<String> _lruOrder = [];
  bool _loaded = false;

  void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    if (kDemoModeEnabled) {
      _products = {};
      _aliasToCanonical = {};
      _lruOrder = [];
      return;
    }
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final productsRaw = decoded['products'];
      final lruRaw = decoded['lruOrder'];
      if (productsRaw is! List) return;

      final products = <String, CatalogProduct>{};
      for (final entry in productsRaw) {
        if (entry is! Map<String, dynamic>) continue;
        final product = CatalogProduct.fromJson(entry);
        if (product == null || !product.isSavable) continue;
        products[product.canonicalId] = product;
      }

      final lru = lruRaw is List
          ? lruRaw.map((e) => e.toString()).toList(growable: true)
          : <String>[];
      lru.removeWhere((id) => !products.containsKey(id));
      for (final id in products.keys) {
        if (!lru.contains(id)) lru.add(id);
      }

      _products = products;
      _lruOrder = lru;
      _rebuildAliasIndex();
    } catch (e, st) {
      importantDebugLog('[PRODUCT_CATALOG] load failed: $e\n$st');
      _products = {};
      _aliasToCanonical = {};
      _lruOrder = [];
    }
  }

  void _rebuildAliasIndex() {
    final index = <String, String>{};
    for (final product in _products.values) {
      for (final alias in _allAliasesFor(product)) {
        index[alias] = product.canonicalId;
      }
    }
    _aliasToCanonical = index;
  }

  Iterable<String> _allAliasesFor(CatalogProduct product) {
    return CatalogProductKeys.mergeAliases(
      product.aliases,
      [product.canonicalId],
    );
  }

  Future<bool> _persist() async {
    if (kDemoModeEnabled) return true;
    try {
      final payload = {
        'v': 1,
        'products': _lruOrder
            .where(_products.containsKey)
            .map((id) => _products[id]!.toJson())
            .toList(growable: false),
        'lruOrder': _lruOrder,
      };
      return await _prefs.setString(_prefsKey, jsonEncode(payload));
    } catch (e, st) {
      importantDebugLog('[PRODUCT_CATALOG] persist failed: $e\n$st');
      return false;
    }
  }

  void _touchLru(String canonicalId) {
    _lruOrder.remove(canonicalId);
    _lruOrder.add(canonicalId);
  }

  void _registerAliases(CatalogProduct product) {
    for (final alias in _allAliasesFor(product)) {
      _aliasToCanonical[alias] = product.canonicalId;
    }
  }

  void _unregisterAliases(CatalogProduct product) {
    for (final alias in _allAliasesFor(product)) {
      final mapped = _aliasToCanonical[alias];
      if (mapped == product.canonicalId) {
        _aliasToCanonical.remove(alias);
      }
    }
  }

  int _evictIfNeeded() {
    var evicted = 0;
    while (_products.length > ProductCatalogConfig.maxCatalogProducts) {
      if (_lruOrder.isEmpty) break;
      final oldest = _lruOrder.first;
      final removed = _products.remove(oldest);
      _lruOrder.removeAt(0);
      if (removed != null) {
        _unregisterAliases(removed);
        evicted++;
      }
    }
    if (evicted > 0) {
      catalogAuditLog(
        '[PRODUCT_CATALOG_LRU_SUMMARY] evicted=$evicted '
        'remaining=${_products.length} max=${ProductCatalogConfig.maxCatalogProducts}',
      );
    }
    return evicted;
  }

  CatalogProduct? getByCanonicalId(String canonicalId, {bool touch = true}) {
    _ensureLoaded();
    final id = canonicalId.trim();
    if (id.isEmpty) return null;
    final product = _products[id];
    if (product == null) return null;
    if (touch) {
      final touched = product.copyWith(lastAccessedAt: DateTime.now());
      _products[id] = touched;
      _touchLru(id);
    }
    return _products[id];
  }

  CatalogProduct? findByAlias(String alias, {bool touch = true}) {
    _ensureLoaded();
    final key = alias.trim();
    if (key.isEmpty) return null;
    final canonicalId = _aliasToCanonical[key];
    if (canonicalId == null) {
      return null;
    }
    verboseItemLog(
      '[PRODUCT_CATALOG_ALIAS_MATCH] alias=$key canonicalId=$canonicalId',
    );
    return getByCanonicalId(canonicalId, touch: touch);
  }

  List<CatalogProduct> getByCanonicalIds(
    Iterable<String> canonicalIds, {
    bool touch = false,
  }) {
    _ensureLoaded();
    final out = <CatalogProduct>[];
    for (final raw in canonicalIds) {
      final p = getByCanonicalId(raw, touch: touch);
      if (p != null) out.add(p);
    }
    return out;
  }

  List<CatalogProduct> getAll() {
    _ensureLoaded();
    return _lruOrder
        .where(_products.containsKey)
        .map((id) => _products[id]!)
        .toList(growable: false);
  }

  int count() {
    _ensureLoaded();
    return _products.length;
  }

  bool isStale(CatalogProduct product, {DateTime? now}) {
    final ref = product.lastValidatedAt;
    final t = now ?? DateTime.now();
    final ageSeconds = t.difference(ref).inSeconds;
    return ageSeconds > product.cacheTtlSeconds;
  }

  Future<ProductCatalogUpsertBatchResult> upsert(CatalogProduct incoming) async {
    return upsertAll([incoming]);
  }

  Future<ProductCatalogUpsertBatchResult> upsertAll(
    Iterable<CatalogProduct> incomingProducts, {
    bool collectItemAuditResults = false,
  }) async {
    _ensureLoaded();
    if (kDemoModeEnabled) {
      return const ProductCatalogUpsertBatchResult(
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
    var updatedByCanonicalId = 0;
    var updatedByAlias = 0;
    var aliasConflictPrevented = 0;
    final itemResults = <ProductCatalogUpsertItemResult>[];
    final auditItems =
        collectItemAuditResults && DebugLogFlags.kCatalogAuditLogsEnabled;

    for (final raw in incomingProducts) {
      if (!raw.isSavable) {
        skipped++;
        if (auditItems && itemResults.length < 5) {
          itemResults.add(_auditSkipped(raw, mergeReason: 'notSavable'));
        }
        continue;
      }

      final incoming = raw.withRecomputedQuality();
      if (!incoming.qualityStatus.safe) {
        skipped++;
        if (auditItems && itemResults.length < 5) {
          itemResults.add(_auditSkipped(incoming, mergeReason: 'qualityNg'));
        }
        continue;
      }

      final existingByCanonical = _products[incoming.canonicalId];
      final aliasLookup = _findExistingForIncoming(incoming);
      final existingByAlias = aliasLookup?.product;

      if (existingByCanonical != null) {
        _unregisterAliases(existingByCanonical);
        final merged = existingByCanonical.mergeFrom(incoming).withRecomputedQuality();
        _products[incoming.canonicalId] = merged;
        _registerAliases(merged);
        _touchLru(incoming.canonicalId);
        updated++;
        updatedByCanonicalId++;
        if (auditItems && itemResults.length < 5) {
          itemResults.add(
            _auditResult(
              incoming: incoming,
              resolved: merged,
              operation: 'update',
              mergeReason: 'canonicalIdMatch',
              aliasMatchedBy: aliasLookup?.matchedAlias ?? '',
            ),
          );
        }
        continue;
      }

      if (existingByAlias != null &&
          existingByAlias.canonicalId != incoming.canonicalId) {
        final shareIdentity = CatalogProductKeys.catalogProductsShareIdentity(
          existingCanonicalId: existingByAlias.canonicalId,
          existingProductId: existingByAlias.productId,
          existingNormalizedItemUrl: existingByAlias.normalizedItemUrl,
          incomingCanonicalId: incoming.canonicalId,
          incomingProductId: incoming.productId,
          incomingNormalizedItemUrl: incoming.normalizedItemUrl,
        );
        if (shareIdentity) {
          _unregisterAliases(existingByAlias);
          final merged =
              existingByAlias.mergeFrom(incoming).withRecomputedQuality();
          _products[existingByAlias.canonicalId] = merged;
          _registerAliases(merged);
          _touchLru(existingByAlias.canonicalId);
          updated++;
          updatedByAlias++;
          if (auditItems && itemResults.length < 5) {
            itemResults.add(
              _auditResult(
                incoming: incoming,
                resolved: merged,
                operation: 'update',
                mergeReason: _aliasMergeReason(incoming, existingByAlias),
                aliasMatchedBy: aliasLookup?.matchedAlias ?? '',
              ),
            );
          }
          continue;
        }
        aliasConflictPrevented++;
        _products[incoming.canonicalId] = incoming;
        _registerAliases(incoming);
        _touchLru(incoming.canonicalId);
        inserted++;
        if (auditItems && itemResults.length < 5) {
          itemResults.add(
            _auditResult(
              incoming: incoming,
              resolved: incoming,
              operation: 'insert',
              mergeReason: 'aliasConflictPrevented',
              aliasMatchedBy: aliasLookup?.matchedAlias ?? '',
            ),
          );
        }
        continue;
      }

      _products[incoming.canonicalId] = incoming;
      _registerAliases(incoming);
      _touchLru(incoming.canonicalId);
      inserted++;
      if (auditItems && itemResults.length < 5) {
        itemResults.add(
          _auditResult(
            incoming: incoming,
            resolved: incoming,
            operation: 'insert',
            mergeReason: 'insert',
            aliasMatchedBy: '',
          ),
        );
      }
    }

    evicted = _evictIfNeeded();
    await _persist();

    catalogAuditLog(
      '[PRODUCT_CATALOG_UPSERT_SUMMARY] inserted=$inserted updated=$updated '
      'updatedByCanonicalId=$updatedByCanonicalId updatedByAlias=$updatedByAlias '
      'aliasConflictPrevented=$aliasConflictPrevented '
      'skipped=$skipped evicted=$evicted total=${_products.length}',
    );

    return ProductCatalogUpsertBatchResult(
      inserted: inserted,
      updated: updated,
      skipped: skipped,
      evicted: evicted,
      updatedByCanonicalId: updatedByCanonicalId,
      updatedByAlias: updatedByAlias,
      aliasConflictPrevented: aliasConflictPrevented,
      itemResults: itemResults,
    );
  }

  ({CatalogProduct? product, String? matchedAlias})? _findExistingForIncoming(
    CatalogProduct incoming,
  ) {
    for (final alias in _allAliasesFor(incoming)) {
      final canonicalId = _aliasToCanonical[alias];
      if (canonicalId == null) continue;
      final existing = _products[canonicalId];
      if (existing != null) {
        return (product: existing, matchedAlias: alias);
      }
    }
    return null;
  }

  String _aliasMergeReason(CatalogProduct incoming, CatalogProduct existing) {
    final inUrl = incoming.normalizedItemUrl.trim();
    final exUrl = existing.normalizedItemUrl.trim();
    if (inUrl.isNotEmpty && exUrl.isNotEmpty && inUrl == exUrl) {
      return 'urlMatch';
    }
    final inPid = CatalogProductKeys.normalizeProductId(incoming.productId);
    final exPid = CatalogProductKeys.normalizeProductId(existing.productId);
    if (inPid != null && exPid != null && inPid == exPid) {
      return 'aliasMatch';
    }
    return 'aliasMatch';
  }

  ProductCatalogUpsertItemResult _auditResult({
    required CatalogProduct incoming,
    required CatalogProduct resolved,
    required String operation,
    required String mergeReason,
    required String aliasMatchedBy,
  }) {
    return ProductCatalogUpsertItemResult(
      inputCanonicalId: incoming.canonicalId,
      resolvedCanonicalId: resolved.canonicalId,
      operation: operation,
      mergeReason: mergeReason,
      inputShopCode: incoming.shopCode,
      savedShopCode: resolved.shopCode,
      aliasMatchedBy: aliasMatchedBy,
      saved: true,
      normalizedItemUrl: incoming.normalizedItemUrl,
      productId: incoming.productId,
    );
  }

  ProductCatalogUpsertItemResult _auditSkipped(
    CatalogProduct incoming, {
    required String mergeReason,
  }) {
    return ProductCatalogUpsertItemResult(
      inputCanonicalId: incoming.canonicalId,
      resolvedCanonicalId: '-',
      operation: 'skip',
      mergeReason: mergeReason,
      inputShopCode: incoming.shopCode,
      savedShopCode: '-',
      aliasMatchedBy: '',
      saved: false,
      normalizedItemUrl: incoming.normalizedItemUrl,
      productId: incoming.productId,
    );
  }

  Future<void> clear() async {
    _ensureLoaded();
    _products = {};
    _aliasToCanonical = {};
    _lruOrder = [];
    if (!kDemoModeEnabled) {
      await _prefs.remove(_prefsKey);
    }
  }
}
