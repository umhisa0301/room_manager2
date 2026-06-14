/// 収益化（広告・課金・無料版制限）のビルド時フラグ。
///
/// すべての define は未指定時 **false**（広告なし・課金なし・制限なし）。
///
/// Phase 1（収益化なし）:
/// `flutter build appbundle --release`
///
/// Phase 2（広告ON）:
/// `--dart-define=MONETIZATION_ENABLED=true --dart-define=ADS_ENABLED=true`
///
/// Phase 3（有料プランON）:
/// 上記に加え
/// `--dart-define=SUBSCRIPTION_ENABLED=true --dart-define=FREE_PLAN_LIMITS_ENABLED=true`
///
/// Phase 4（プロプランON）:
/// 上記に加え `--dart-define=PRO_PLAN_ENABLED=true`
///
/// Google Play 申請用 release では [MonetizationConfig.kMonetizationDartDefineEnabled] を
/// 意図せず true にしないこと（デフォルト false で安全）。
abstract final class MonetizationConfig {
  static const bool kMonetizationDartDefineEnabled = bool.fromEnvironment(
    'MONETIZATION_ENABLED',
    defaultValue: false,
  );

  static const bool kAdsDartDefineEnabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: false,
  );

  static const bool kSubscriptionDartDefineEnabled = bool.fromEnvironment(
    'SUBSCRIPTION_ENABLED',
    defaultValue: false,
  );

  static const bool kFreePlanLimitsDartDefineEnabled = bool.fromEnvironment(
    'FREE_PLAN_LIMITS_ENABLED',
    defaultValue: false,
  );

  static const bool kProPlanDartDefineEnabled = bool.fromEnvironment(
    'PRO_PLAN_ENABLED',
    defaultValue: false,
  );
}

/// 収益化機能の実効フラグ（マスター [isMonetizationEnabled] が false なら子はすべて false）。
abstract final class MonetizationFlags {
  static const bool isMonetizationEnabled =
      MonetizationConfig.kMonetizationDartDefineEnabled;

  static const bool isAdsEnabled =
      MonetizationConfig.kMonetizationDartDefineEnabled &&
      MonetizationConfig.kAdsDartDefineEnabled;

  static const bool isSubscriptionEnabled =
      MonetizationConfig.kMonetizationDartDefineEnabled &&
      MonetizationConfig.kSubscriptionDartDefineEnabled;

  static const bool isFreePlanLimitsEnabled =
      MonetizationConfig.kMonetizationDartDefineEnabled &&
      MonetizationConfig.kFreePlanLimitsDartDefineEnabled;

  static const bool isProPlanEnabled =
      MonetizationConfig.kMonetizationDartDefineEnabled &&
      MonetizationConfig.kSubscriptionDartDefineEnabled &&
      MonetizationConfig.kProPlanDartDefineEnabled;

  /// debug 起動時の1行サマリ（秘匿情報なし）。
  static String get debugLogLine =>
      '[MONETIZATION_FLAGS] monetization=$isMonetizationEnabled '
      'ads=$isAdsEnabled subscription=$isSubscriptionEnabled '
      'freeLimits=$isFreePlanLimitsEnabled pro=$isProPlanEnabled';
}

/// 派生フラグのスナップショット（テスト・将来のランタイム判定用）。
class MonetizationFlagSnapshot {
  const MonetizationFlagSnapshot({
    required this.isMonetizationEnabled,
    required this.isAdsEnabled,
    required this.isSubscriptionEnabled,
    required this.isFreePlanLimitsEnabled,
    required this.isProPlanEnabled,
  });

  final bool isMonetizationEnabled;
  final bool isAdsEnabled;
  final bool isSubscriptionEnabled;
  final bool isFreePlanLimitsEnabled;
  final bool isProPlanEnabled;

  /// コンパイル時 [MonetizationFlags] と同値のスナップショット。
  static MonetizationFlagSnapshot fromCompileTime() => MonetizationFlagSnapshot(
        isMonetizationEnabled: MonetizationFlags.isMonetizationEnabled,
        isAdsEnabled: MonetizationFlags.isAdsEnabled,
        isSubscriptionEnabled: MonetizationFlags.isSubscriptionEnabled,
        isFreePlanLimitsEnabled: MonetizationFlags.isFreePlanLimitsEnabled,
        isProPlanEnabled: MonetizationFlags.isProPlanEnabled,
      );
}

/// dart-define 生値から派生フラグを算出する純粋関数（単体テスト用）。
///
/// 本番の [MonetizationFlags] と同じ依存関係:
/// - [monetizationEnabled] が false なら子フラグはすべて false
/// - [proPlanEnabled] は [subscriptionEnabled] も true のときのみ有効
MonetizationFlagSnapshot resolveMonetizationFlags({
  required bool monetizationEnabled,
  required bool adsEnabled,
  required bool subscriptionEnabled,
  required bool freePlanLimitsEnabled,
  required bool proPlanEnabled,
}) {
  return MonetizationFlagSnapshot(
    isMonetizationEnabled: monetizationEnabled,
    isAdsEnabled: monetizationEnabled && adsEnabled,
    isSubscriptionEnabled: monetizationEnabled && subscriptionEnabled,
    isFreePlanLimitsEnabled: monetizationEnabled && freePlanLimitsEnabled,
    isProPlanEnabled:
        monetizationEnabled && subscriptionEnabled && proPlanEnabled,
  );
}
