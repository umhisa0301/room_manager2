import 'package:flutter/foundation.dart';

import '../config/monetization_config.dart';
import '../config/monetization_plan_config.dart';
import '../models/today_recommendation.dart';
import '../utils/app_debug_log.dart';
import 'recommendation_generation_count_store.dart';

/// おすすめコレ生成の利用可否スナップショット。
class RecommendationGenerationLimitState {
  const RecommendationGenerationLimitState({
    required this.allowed,
    required this.usedCount,
    required this.limit,
    required this.plan,
    required this.limitsEnforcementEnabled,
    this.reasonCode,
  });

  final bool allowed;
  final int usedCount;
  final int limit;
  final MonetizationPlan plan;
  final bool limitsEnforcementEnabled;

  /// 制限到達時は `daily_limit_reached`。
  final String? reasonCode;
}

/// 初回生成かどうか（手動再生成は [dailyRecommendationRefreshLimit] 対象のため除外）。
bool isPrimaryRecommendationGeneration({
  required bool manual,
  required TodayRecommendationBundle? bundleBefore,
  required String todayLocalDateKey,
}) {
  if (!manual) return true;
  if (bundleBefore == null) return true;
  if (bundleBefore.localDateKey != todayLocalDateKey) return true;
  return bundleBefore.entries.isEmpty;
}

/// 利用回数とプランから生成可否を解決する（純粋関数・テスト用）。
RecommendationGenerationLimitState resolveRecommendationGenerationAvailability({
  required int usedCount,
  MonetizationPlanContext? planContext,
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) {
  final context = planContext ??
      resolvePlanLimitsForCurrentUser(
        flags: flags,
        purchasedPlanOverride: purchasedPlanOverride,
      );
  final limit = context.limits.dailyRecommendationLimit;

  if (!context.limitsEnforcementEnabled) {
    return RecommendationGenerationLimitState(
      allowed: true,
      usedCount: usedCount,
      limit: limit,
      plan: context.plan,
      limitsEnforcementEnabled: false,
    );
  }

  final allowed = usedCount < limit;
  return RecommendationGenerationLimitState(
    allowed: allowed,
    usedCount: usedCount,
    limit: limit,
    plan: context.plan,
    limitsEnforcementEnabled: true,
    reasonCode: allowed ? null : 'daily_limit_reached',
  );
}

/// 端末保存の今日の回数から生成可否を解決する。
Future<RecommendationGenerationLimitState>
    resolveRecommendationGenerationAvailabilityForToday({
  DateTime? now,
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) async {
  final usedCount = await RecommendationGenerationCountStore.readTodayCount(
    now: now,
  );
  return resolveRecommendationGenerationAvailability(
    usedCount: usedCount,
    flags: flags,
    purchasedPlanOverride: purchasedPlanOverride,
  );
}

/// 生成可否のエイリアス。
Future<bool> canGenerateTodayRecommendation({
  DateTime? now,
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) async {
  final state = await resolveRecommendationGenerationAvailabilityForToday(
    now: now,
    flags: flags,
    purchasedPlanOverride: purchasedPlanOverride,
  );
  if (kDebugMode) {
    importantDebugLog(
      '[MONETIZATION_LIMIT] recommendation used=${state.usedCount} '
      'limit=${state.limit} allowed=${state.allowed}',
    );
  }
  return state.allowed;
}

/// 生成成功後に今日の回数を 1 増やす。
Future<int> recordSuccessfulRecommendationGeneration({DateTime? now}) =>
    RecommendationGenerationCountStore.incrementTodayCount(now: now);

/// 制限到達時のユーザー向けメッセージ本文。
String recommendationGenerationLimitBlockedMessage(MonetizationPlan plan) {
  switch (plan) {
    case MonetizationPlan.free:
      return '無料版では、おすすめコレ生成は1日1回までです。'
          '明日またお試しください。';
    case MonetizationPlan.basic:
      return 'Basicプランでは、おすすめコレ生成は1日'
          '${resolvePlanLimitsFor(plan).dailyRecommendationLimit}回までです。'
          '明日またお試しください。';
    case MonetizationPlan.pro:
      return 'Proプランでは、おすすめコレ生成は1日'
          '${resolvePlanLimitsFor(plan).dailyRecommendationLimit}回までです。'
          '明日またお試しください。';
  }
}

/// 無料版向けの Basic 予定ヒント（購入導線なし）。
String recommendationGenerationLimitBasicHint() =>
    '今後のBasicプランでは、1日5回まで生成できる予定です。';

/// 制限到達ダイアログ・スナックバー用の全文。
String buildRecommendationGenerationLimitBlockedBody(
  RecommendationGenerationLimitState state,
) {
  final base = recommendationGenerationLimitBlockedMessage(state.plan);
  if (state.plan == MonetizationPlan.free) {
    return '$base\n\n${recommendationGenerationLimitBasicHint()}';
  }
  return base;
}

/// 利用状況の短い表示（制限 ON 時のみ意味がある）。
String recommendationGenerationUsageLabel(
  RecommendationGenerationLimitState state,
) =>
    '今日のおすすめコレ生成: ${state.usedCount} / ${state.limit}回';
