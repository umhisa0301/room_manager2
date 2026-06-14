import 'monetization_config.dart';

/// サブスクリプションプラン種別（free / basic / pro）。
enum MonetizationPlan {
  free,
  basic,
  pro,
}

/// プラン別の利用制限・権限定義。
class MonetizationPlanLimits {
  const MonetizationPlanLimits({
    required this.adsRemoved,
    required this.dailyRecommendationLimit,
    required this.dailyRecommendationRefreshLimit,
    required this.batchCandidateAddEnabled,
    required this.roomImportLimitPerRun,
    required this.reactionAnalyticsDetailEnabled,
    required this.advancedRakutenSearchSortEnabled,
    required this.aiCommentGenerationEnabled,
    required this.aiImprovementSuggestionEnabled,
    required this.conditionalBatchProcessingEnabled,
  });

  /// true のとき広告非表示（将来のサブスク連動用。現行広告 ON/OFF は [MonetizationFlags.isAdsEnabled]）。
  final bool adsRemoved;

  final int dailyRecommendationLimit;
  final int dailyRecommendationRefreshLimit;
  final bool batchCandidateAddEnabled;
  final int roomImportLimitPerRun;
  final bool reactionAnalyticsDetailEnabled;
  final bool advancedRakutenSearchSortEnabled;

  /// 将来対応（Pro）。
  final bool aiCommentGenerationEnabled;

  /// 将来対応（Pro）。
  final bool aiImprovementSuggestionEnabled;

  /// 将来対応（Pro）。
  final bool conditionalBatchProcessingEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonetizationPlanLimits &&
          runtimeType == other.runtimeType &&
          adsRemoved == other.adsRemoved &&
          dailyRecommendationLimit == other.dailyRecommendationLimit &&
          dailyRecommendationRefreshLimit ==
              other.dailyRecommendationRefreshLimit &&
          batchCandidateAddEnabled == other.batchCandidateAddEnabled &&
          roomImportLimitPerRun == other.roomImportLimitPerRun &&
          reactionAnalyticsDetailEnabled ==
              other.reactionAnalyticsDetailEnabled &&
          advancedRakutenSearchSortEnabled ==
              other.advancedRakutenSearchSortEnabled &&
          aiCommentGenerationEnabled == other.aiCommentGenerationEnabled &&
          aiImprovementSuggestionEnabled ==
              other.aiImprovementSuggestionEnabled &&
          conditionalBatchProcessingEnabled ==
              other.conditionalBatchProcessingEnabled;

  @override
  int get hashCode => Object.hash(
        adsRemoved,
        dailyRecommendationLimit,
        dailyRecommendationRefreshLimit,
        batchCandidateAddEnabled,
        roomImportLimitPerRun,
        reactionAnalyticsDetailEnabled,
        advancedRakutenSearchSortEnabled,
        aiCommentGenerationEnabled,
        aiImprovementSuggestionEnabled,
        conditionalBatchProcessingEnabled,
      );
}

/// プラン解決結果（制限値 + 強制適用フラグ）。
class MonetizationPlanContext {
  const MonetizationPlanContext({
    required this.plan,
    required this.limits,
    required this.limitsEnforcementEnabled,
  });

  final MonetizationPlan plan;
  final MonetizationPlanLimits limits;

  /// [MonetizationFlags.isFreePlanLimitsEnabled] が true のときのみ制限を強制する。
  final bool limitsEnforcementEnabled;
}

/// free プランの静的制限定義。
const MonetizationPlanLimits kFreeMonetizationPlanLimits = MonetizationPlanLimits(
  adsRemoved: false,
  dailyRecommendationLimit: 1,
  dailyRecommendationRefreshLimit: 1,
  batchCandidateAddEnabled: false,
  roomImportLimitPerRun: 10,
  reactionAnalyticsDetailEnabled: false,
  advancedRakutenSearchSortEnabled: false,
  aiCommentGenerationEnabled: false,
  aiImprovementSuggestionEnabled: false,
  conditionalBatchProcessingEnabled: false,
);

/// basic プランの静的制限定義。
const MonetizationPlanLimits kBasicMonetizationPlanLimits = MonetizationPlanLimits(
  adsRemoved: true,
  dailyRecommendationLimit: 5,
  dailyRecommendationRefreshLimit: 5,
  batchCandidateAddEnabled: true,
  roomImportLimitPerRun: 30,
  reactionAnalyticsDetailEnabled: true,
  advancedRakutenSearchSortEnabled: true,
  aiCommentGenerationEnabled: false,
  aiImprovementSuggestionEnabled: false,
  conditionalBatchProcessingEnabled: false,
);

/// pro プランの静的制限定義。
const MonetizationPlanLimits kProMonetizationPlanLimits = MonetizationPlanLimits(
  adsRemoved: true,
  dailyRecommendationLimit: 10,
  dailyRecommendationRefreshLimit: 10,
  batchCandidateAddEnabled: true,
  roomImportLimitPerRun: 50,
  reactionAnalyticsDetailEnabled: true,
  advancedRakutenSearchSortEnabled: true,
  aiCommentGenerationEnabled: false,
  aiImprovementSuggestionEnabled: false,
  conditionalBatchProcessingEnabled: false,
);

/// プラン種別に対応する静的制限値（純粋関数・テスト用）。
MonetizationPlanLimits resolvePlanLimitsFor(MonetizationPlan plan) {
  switch (plan) {
    case MonetizationPlan.free:
      return kFreeMonetizationPlanLimits;
    case MonetizationPlan.basic:
      return kBasicMonetizationPlanLimits;
    case MonetizationPlan.pro:
      return kProMonetizationPlanLimits;
  }
}

/// 制限強制の有効判定（[FREE_PLAN_LIMITS_ENABLED] 連動）。
bool resolveLimitsEnforcementEnabled(MonetizationFlagSnapshot flags) =>
    flags.isFreePlanLimitsEnabled;

/// フラグに基づきプランをクランプする。
///
/// - 収益化 OFF / サブスク OFF → [MonetizationPlan.free]
/// - Pro 無効時に pro 指定 → [MonetizationPlan.basic] に降格
MonetizationPlan clampMonetizationPlan(
  MonetizationPlan plan,
  MonetizationFlagSnapshot flags,
) {
  if (!flags.isMonetizationEnabled || !flags.isSubscriptionEnabled) {
    return MonetizationPlan.free;
  }
  if (plan == MonetizationPlan.pro && !flags.isProPlanEnabled) {
    return MonetizationPlan.basic;
  }
  return plan;
}

/// 将来の Billing 実装差し替え口。現時点では常に free。
MonetizationPlan resolvePurchasedMonetizationPlan() => MonetizationPlan.free;

/// 現在の実効プランを解決する。
MonetizationPlan resolveCurrentMonetizationPlan({
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) {
  final snapshot = flags ?? MonetizationFlagSnapshot.fromCompileTime();
  final purchased = purchasedPlanOverride ?? resolvePurchasedMonetizationPlan();
  return clampMonetizationPlan(purchased, snapshot);
}

/// 指定プランとフラグから制限コンテキストを解決する（純粋関数・テスト用）。
MonetizationPlanContext resolvePlanLimits(
  MonetizationPlan plan,
  MonetizationFlagSnapshot flags,
) {
  final effectivePlan = clampMonetizationPlan(plan, flags);
  return MonetizationPlanContext(
    plan: effectivePlan,
    limits: resolvePlanLimitsFor(effectivePlan),
    limitsEnforcementEnabled: resolveLimitsEnforcementEnabled(flags),
  );
}

/// 現在ユーザー向けの制限コンテキストを解決する。
MonetizationPlanContext resolvePlanLimitsForCurrentUser({
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) {
  final snapshot = flags ?? MonetizationFlagSnapshot.fromCompileTime();
  final plan = resolveCurrentMonetizationPlan(
    flags: snapshot,
    purchasedPlanOverride: purchasedPlanOverride,
  );
  return MonetizationPlanContext(
    plan: plan,
    limits: resolvePlanLimitsFor(plan),
    limitsEnforcementEnabled: resolveLimitsEnforcementEnabled(snapshot),
  );
}

/// debug 起動時の1行サマリ（秘匿情報なし）。
String monetizationPlanDebugLogLine(MonetizationPlanContext context) =>
    '[MONETIZATION_PLAN] plan=${context.plan.name} '
    'limitsEnabled=${context.limitsEnforcementEnabled}';
