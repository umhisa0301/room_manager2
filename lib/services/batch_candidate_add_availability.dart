import 'package:flutter/foundation.dart';

import '../config/monetization_config.dart';
import '../config/monetization_plan_config.dart';
import '../utils/app_debug_log.dart';

/// 一括候補追加の利用可否スナップショット。
class BatchCandidateAddAvailabilityState {
  const BatchCandidateAddAvailabilityState({
    required this.allowed,
    required this.plan,
    required this.limitsEnforcementEnabled,
    this.reasonCode,
  });

  final bool allowed;
  final MonetizationPlan plan;
  final bool limitsEnforcementEnabled;

  /// 利用不可時は `plan_locked`。
  final String? reasonCode;
}

/// 現在プランから一括候補追加の可否を解決する（純粋関数・テスト用）。
BatchCandidateAddAvailabilityState resolveBatchCandidateAddAvailability({
  MonetizationPlanContext? planContext,
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) {
  final context = planContext ??
      resolvePlanLimitsForCurrentUser(
        flags: flags,
        purchasedPlanOverride: purchasedPlanOverride,
      );

  if (!context.limitsEnforcementEnabled) {
    return BatchCandidateAddAvailabilityState(
      allowed: true,
      plan: context.plan,
      limitsEnforcementEnabled: false,
    );
  }

  final allowed = context.limits.batchCandidateAddEnabled;
  return BatchCandidateAddAvailabilityState(
    allowed: allowed,
    plan: context.plan,
    limitsEnforcementEnabled: true,
    reasonCode: allowed ? null : 'plan_locked',
  );
}

/// 一括候補追加可否のエイリアス。
bool canUseBatchCandidateAdd({
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) {
  final state = resolveBatchCandidateAddAvailability(
    flags: flags,
    purchasedPlanOverride: purchasedPlanOverride,
  );
  if (kDebugMode) {
    importantDebugLog(
      '[MONETIZATION_LIMIT] batchCandidateAdd allowed=${state.allowed} '
      'plan=${state.plan.name}',
    );
  }
  return state.allowed;
}

/// ロック時のユーザー向けメッセージ本文。
String batchCandidateAddLockedMessage() =>
    '一括追加はBasicプラン向けの機能です。無料版では1件ずつ追加できます。';

/// 無料版向けの Basic 予定ヒント（購入導線なし）。
String batchCandidateAddLockedBasicHint() =>
    '今後のBasicプランでは、複数の商品をまとめて候補に追加できる予定です。';

/// SnackBar 等用の全文。
String buildBatchCandidateAddLockedBody(BatchCandidateAddAvailabilityState state) {
  final base = batchCandidateAddLockedMessage();
  if (state.plan == MonetizationPlan.free) {
    return '$base\n\n${batchCandidateAddLockedBasicHint()}';
  }
  return base;
}
