import '../config/monetization_plan_config.dart';

/// 購入状態の種別。
///
/// NOTE: Google Play Billing 未接続（Phase 9B 時点）。
/// 通常の本番起動では [none] が返る。
/// テスト・将来の Billing 接続時に [basicActive] / [proActive] を注入できる。
enum SubscriptionStatus {
  /// 未購入または Billing 未接続。
  none,

  /// Basic プラン有効。
  basicActive,

  /// Pro プラン有効。
  proActive,
}

/// 購入エンタイトルメント（権限）モデル。
///
/// 将来 Google Play Billing 接続時に、この型に実購入情報を詰めて渡す。
/// 現時点では [SubscriptionStatus.none] をデフォルトとして使う。
class PurchaseEntitlement {
  const PurchaseEntitlement({
    required this.status,
    this.expiresAt,
    this.source,
  });

  /// デフォルト（未購入 / Billing 未接続）。
  const PurchaseEntitlement.none()
      : status = SubscriptionStatus.none,
        expiresAt = null,
        source = null;

  final SubscriptionStatus status;

  /// サブスクの有効期限（null = 期限情報なし）。
  /// 将来 Billing 接続時に Play Store からの有効期限を格納する。
  final DateTime? expiresAt;

  /// 購入ソース（例: 'play_store'）。将来拡張用。
  final String? source;

  /// サブスクが有効かどうか。
  ///
  /// [expiresAt] が設定されている場合は現在時刻との比較も行う。
  bool get isActive {
    if (status == SubscriptionStatus.none) return false;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) return false;
    return true;
  }

  bool get isBasicActive =>
      isActive && status == SubscriptionStatus.basicActive;

  bool get isProActive => isActive && status == SubscriptionStatus.proActive;

  /// 広告非表示権限（basic / pro は true）。
  /// NOTE: Phase 9B 時点では広告表示制御には未接続。Phase 9D 以降で連動予定。
  bool get adsRemoved => isBasicActive || isProActive;

  /// この権限が示す [MonetizationPlan]。
  /// フラグクランプは呼び出し元 ([resolveMonetizationPlanFromEntitlement]) が行う。
  MonetizationPlan get resolvedPlan {
    if (isProActive) return MonetizationPlan.pro;
    if (isBasicActive) return MonetizationPlan.basic;
    return MonetizationPlan.free;
  }
}

/// [PurchaseEntitlement] から [MonetizationPlan] を解決する純粋関数。
///
/// - [SubscriptionStatus.none] または期限切れ → [MonetizationPlan.free]
/// - [SubscriptionStatus.basicActive] → [MonetizationPlan.basic]
/// - [SubscriptionStatus.proActive] → [MonetizationPlan.pro]
///
/// フラグクランプ（SUBSCRIPTION_ENABLED 等）はこの関数では行わない。
/// [resolveCurrentMonetizationPlan] 経由で [clampMonetizationPlan] が適用される。
MonetizationPlan resolveMonetizationPlanFromEntitlement(
  PurchaseEntitlement entitlement,
) {
  return entitlement.resolvedPlan;
}
