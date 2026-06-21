import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_status.dart';

/// SharedPreferences に保存する購入エンタイトルメントの簡易永続化。
///
/// purchaseToken やレシートは保存しない。
/// 将来 restorePurchases / サーバー検証に置き換え可能な設計。
class SubscriptionEntitlementStore {
  SubscriptionEntitlementStore(this._prefs);

  static const String _keyStatus = 'subscription_entitlement_status';
  static const String _keySource = 'subscription_entitlement_source';
  static const String _keyLastUpdatedAt = 'subscription_entitlement_last_updated_at';
  static const String _keyProductKind = 'subscription_entitlement_product_kind';

  static const String productKindBasic = 'basic';

  final SharedPreferences _prefs;
  PurchaseEntitlement _cache = const PurchaseEntitlement.none();

  /// メモリ上の最新エンタイトルメント（load / save 後に更新）。
  PurchaseEntitlement get entitlement => _cache;

  /// 永続化データを読み込み、[_cache] を更新する。
  Future<void> load() async {
    _cache = _readFromPrefs();
  }

  /// エンタイトルメントを永続化し、[_cache] を更新する。
  Future<void> save(PurchaseEntitlement entitlement) async {
    _cache = entitlement;
    if (entitlement.status == SubscriptionStatus.none) {
      await clear();
      return;
    }

    await _prefs.setString(_keyStatus, entitlement.status.name);
    if (entitlement.source != null) {
      await _prefs.setString(_keySource, entitlement.source!);
    } else {
      await _prefs.remove(_keySource);
    }
    final updatedAt = DateTime.now().toUtc();
    await _prefs.setString(_keyLastUpdatedAt, updatedAt.toIso8601String());

    final productKind = switch (entitlement.status) {
      SubscriptionStatus.basicActive => productKindBasic,
      SubscriptionStatus.proActive => 'pro',
      SubscriptionStatus.none => '',
    };
    if (productKind.isEmpty) {
      await _prefs.remove(_keyProductKind);
    } else {
      await _prefs.setString(_keyProductKind, productKind);
    }
  }

  /// 永続化データを削除し、[_cache] を none に戻す。
  Future<void> clear() async {
    _cache = const PurchaseEntitlement.none();
    await _prefs.remove(_keyStatus);
    await _prefs.remove(_keySource);
    await _prefs.remove(_keyLastUpdatedAt);
    await _prefs.remove(_keyProductKind);
  }

  PurchaseEntitlement _readFromPrefs() {
    final statusName = _prefs.getString(_keyStatus);
    if (statusName == null) {
      return const PurchaseEntitlement.none();
    }

    SubscriptionStatus? status;
    for (final value in SubscriptionStatus.values) {
      if (value.name == statusName) {
        status = value;
        break;
      }
    }
    if (status == null || status == SubscriptionStatus.none) {
      return const PurchaseEntitlement.none();
    }

    final source = _prefs.getString(_keySource);

    return PurchaseEntitlement(
      status: status,
      source: source,
      expiresAt: null,
    );
  }
}

SubscriptionEntitlementStore? _globalSubscriptionEntitlementStore;

/// アプリ起動時に登録するグローバルストア。
void registerGlobalSubscriptionEntitlementStore(SubscriptionEntitlementStore store) {
  _globalSubscriptionEntitlementStore = store;
}

/// テスト用: グローバルストア登録を解除する。
void unregisterGlobalSubscriptionEntitlementStore() {
  _globalSubscriptionEntitlementStore = null;
}

/// 登録済みストアからエンタイトルメントを読む（未登録時は none）。
PurchaseEntitlement readStoredPurchaseEntitlement() {
  return _globalSubscriptionEntitlementStore?.entitlement ??
      const PurchaseEntitlement.none();
}
