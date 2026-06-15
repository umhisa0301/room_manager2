import 'package:flutter/foundation.dart';

import '../config/monetization_config.dart';
import '../config/monetization_plan_config.dart';
import '../models/today_recommendation.dart';
import '../utils/app_debug_log.dart';
import 'recommendation_generation_count_store.dart';
import 'recommendation_generation_limit.dart';

/// おすすめコレ手動再生成の利用可否スナップショット。
class RecommendationRefreshLimitState {
  const RecommendationRefreshLimitState({
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

  /// 制限到達時は `daily_refresh_limit_reached`。
  final String? reasonCode;
}

/// 手動再生成かどうか（初回生成は [dailyRecommendationLimit] 対象のため除外）。
bool isManualRecommendationRefresh({
  required bool manual,
  required TodayRecommendationBundle? bundleBefore,
  required String todayLocalDateKey,
}) =>
    manual &&
    !isPrimaryRecommendationGeneration(
      manual: manual,
      bundleBefore: bundleBefore,
      todayLocalDateKey: todayLocalDateKey,
    );

/// 利用回数とプランから手動再生成可否を解決する（純粋関数・テスト用）。
RecommendationRefreshLimitState resolveRecommendationRefreshAvailability({
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
  final limit = context.limits.dailyRecommendationRefreshLimit;

  if (!context.limitsEnforcementEnabled) {
    return RecommendationRefreshLimitState(
      allowed: true,
      usedCount: usedCount,
      limit: limit,
      plan: context.plan,
      limitsEnforcementEnabled: false,
    );
  }

  final allowed = usedCount < limit;
  return RecommendationRefreshLimitState(
    allowed: allowed,
    usedCount: usedCount,
    limit: limit,
    plan: context.plan,
    limitsEnforcementEnabled: true,
    reasonCode: allowed ? null : 'daily_refresh_limit_reached',
  );
}

/// 端末保存の今日の手動再生成回数から可否を解決する。
Future<RecommendationRefreshLimitState>
    resolveRecommendationRefreshAvailabilityForToday({
  DateTime? now,
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) async {
  final usedCount = await RecommendationGenerationCountStore.readTodayRefreshCount(
    now: now,
  );
  return resolveRecommendationRefreshAvailability(
    usedCount: usedCount,
    flags: flags,
    purchasedPlanOverride: purchasedPlanOverride,
  );
}

/// 手動再生成可否のエイリアス。
Future<bool> canRefreshTodayRecommendation({
  DateTime? now,
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) async {
  final state = await resolveRecommendationRefreshAvailabilityForToday(
    now: now,
    flags: flags,
    purchasedPlanOverride: purchasedPlanOverride,
  );
  if (kDebugMode) {
    importantDebugLog(
      '[MONETIZATION_LIMIT] recommendationRefresh used=${state.usedCount} '
      'limit=${state.limit} allowed=${state.allowed}',
    );
  }
  return state.allowed;
}

/// 手動再生成成功後に今日の回数を 1 増やす。
Future<int> recordSuccessfulRecommendationRefresh({DateTime? now}) =>
    RecommendationGenerationCountStore.incrementTodayRefreshCount(now: now);

/// 制限到達時のユーザー向けメッセージ本文。
String recommendationRefreshLimitBlockedMessage(MonetizationPlan plan) {
  switch (plan) {
    case MonetizationPlan.free:
      return '無料版では、おすすめコレの再生成は1日1回までです。'
          '明日またお試しください。';
    case MonetizationPlan.basic:
      return 'Basicプランでは、おすすめコレの再生成は1日'
          '${resolvePlanLimitsFor(plan).dailyRecommendationRefreshLimit}回までです。'
          '明日またお試しください。';
    case MonetizationPlan.pro:
      return 'Proプランでは、おすすめコレの再生成は1日'
          '${resolvePlanLimitsFor(plan).dailyRecommendationRefreshLimit}回までです。'
          '明日またお試しください。';
  }
}

/// 無料版向けの Basic 予定ヒント（購入導線なし）。
String recommendationRefreshLimitBasicHint() =>
    '今後のBasicプランでは、1日5回まで再生成できる予定です。';

/// 制限到達ダイアログ・スナックバー用の全文。
String buildRecommendationRefreshLimitBlockedBody(
  RecommendationRefreshLimitState state,
) {
  final base = recommendationRefreshLimitBlockedMessage(state.plan);
  if (state.plan == MonetizationPlan.free) {
    return '$base\n\n${recommendationRefreshLimitBasicHint()}';
  }
  return base;
}

/// 利用状況の短い表示（制限 ON 時のみ意味がある）。
String recommendationRefreshUsageLabel(RecommendationRefreshLimitState state) =>
    '今日の再生成: ${state.usedCount} / ${state.limit}回';
