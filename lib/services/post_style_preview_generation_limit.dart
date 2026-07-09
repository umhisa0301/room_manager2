import 'package:flutter/foundation.dart';

import '../config/ai_gateway_config.dart';
import '../config/monetization_config.dart';
import '../config/monetization_plan_config.dart';
import '../utils/app_debug_log.dart';
import 'post_style_preview_generation_count_store.dart';
import 'subscription_entitlement_store.dart';
import 'subscription_status.dart';

/// 投稿スタイル設定の生成イメージ更新の利用可否スナップショット。
class PostStylePreviewGenerationLimitState {
  const PostStylePreviewGenerationLimitState({
    required this.allowed,
    required this.usedCount,
    required this.limit,
    required this.plan,
    required this.remoteGenerationEnabled,
    required this.appliesDailyLimit,
    this.reasonCode,
  });

  final bool allowed;
  final int usedCount;

  /// 無制限時は [kPostStylePreviewGenerationDailyLimit] を表示用に保持。
  final int limit;
  final MonetizationPlan plan;

  /// Remote AI が有効（Stub ではない）か。
  final bool remoteGenerationEnabled;

  /// 無料ユーザー向け日次制限が適用されるか。
  final bool appliesDailyLimit;

  /// 制限到達時は `daily_limit_reached`。
  final String? reasonCode;

  /// 日次制限適用時の残り回数。無制限時は [limit] を返す。
  int get remainingCount => appliesDailyLimit
      ? (limit - usedCount).clamp(0, limit)
      : limit;
}

/// 無料ユーザー向けの1日あたり生成イメージ更新上限。
const int kPostStylePreviewGenerationDailyLimit = 3;

const String kPostStylePreviewDailyLimitReasonCode = 'daily_limit_reached';

/// Remote AI 利用時のみ生成イメージの日次制限を強制する。
bool isPostStylePreviewGenerationLimitEnforced() =>
    AiGatewayConfig.useRemotePostCommentGeneration &&
    AiGatewayConfig.appKey.trim().isNotEmpty;

/// 生成イメージが無制限か。
///
/// [MonetizationPlanContext.plan] が basic / pro のときのみ true。
/// 課金準備中・エンタイトルメント不明・Billing 未接続は [clampMonetizationPlan] により
/// free に落ちるため false（無料制限が適用される）。
bool isUnlimitedPreviewGeneration(MonetizationPlanContext planContext) =>
    planContext.plan != MonetizationPlan.free;

void _logPostStylePreviewGenerationLimit({
  required bool previewLimitEnforced,
  required MonetizationPlanContext planContext,
  required PurchaseEntitlement entitlement,
  required int usedCount,
  required PostStylePreviewGenerationLimitState state,
}) {
  if (!kDebugMode) return;
  importantDebugLog(
    '[POST_STYLE_PREVIEW_LIMIT] previewLimitEnforced=$previewLimitEnforced '
    'useRemotePostCommentGeneration=${AiGatewayConfig.useRemotePostCommentGeneration} '
    'currentPlan=${planContext.plan.name} '
    'entitlementState=${entitlement.status.name} '
    'isUnlimitedPreviewGeneration=${isUnlimitedPreviewGeneration(planContext)} '
    'usedCount=$usedCount '
    'remainingCount=${state.remainingCount} '
    'allowed=${state.allowed}',
  );
}

/// 利用回数とプランから生成可否を解決する（純粋関数・テスト用）。
PostStylePreviewGenerationLimitState resolvePostStylePreviewGenerationAvailability({
  required int usedCount,
  MonetizationPlanContext? planContext,
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
  bool? enforcementEnabled,
}) {
  final remoteEnabled = enforcementEnabled ?? isPostStylePreviewGenerationLimitEnforced();
  final context = planContext ??
      resolvePlanLimitsForCurrentUser(
        flags: flags,
        purchasedPlanOverride: purchasedPlanOverride,
      );

  if (!remoteEnabled) {
    final state = PostStylePreviewGenerationLimitState(
      allowed: true,
      usedCount: usedCount,
      limit: kPostStylePreviewGenerationDailyLimit,
      plan: context.plan,
      remoteGenerationEnabled: false,
      appliesDailyLimit: false,
    );
    _logPostStylePreviewGenerationLimit(
      previewLimitEnforced: remoteEnabled,
      planContext: context,
      entitlement: readStoredPurchaseEntitlement(),
      usedCount: usedCount,
      state: state,
    );
    return state;
  }

  final unlimited = isUnlimitedPreviewGeneration(context);
  final appliesDailyLimit = !unlimited;

  if (!appliesDailyLimit) {
    final state = PostStylePreviewGenerationLimitState(
      allowed: true,
      usedCount: usedCount,
      limit: kPostStylePreviewGenerationDailyLimit,
      plan: context.plan,
      remoteGenerationEnabled: true,
      appliesDailyLimit: false,
    );
    _logPostStylePreviewGenerationLimit(
      previewLimitEnforced: remoteEnabled,
      planContext: context,
      entitlement: readStoredPurchaseEntitlement(),
      usedCount: usedCount,
      state: state,
    );
    return state;
  }

  final allowed = usedCount < kPostStylePreviewGenerationDailyLimit;
  final state = PostStylePreviewGenerationLimitState(
    allowed: allowed,
    usedCount: usedCount,
    limit: kPostStylePreviewGenerationDailyLimit,
    plan: context.plan,
    remoteGenerationEnabled: true,
    appliesDailyLimit: true,
    reasonCode: allowed ? null : kPostStylePreviewDailyLimitReasonCode,
  );
  _logPostStylePreviewGenerationLimit(
    previewLimitEnforced: remoteEnabled,
    planContext: context,
    entitlement: readStoredPurchaseEntitlement(),
    usedCount: usedCount,
    state: state,
  );
  return state;
}

/// 端末保存の今日の回数から生成可否を解決する。
Future<PostStylePreviewGenerationLimitState>
    resolvePostStylePreviewGenerationAvailabilityForToday({
  DateTime? now,
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
  bool? enforcementEnabled,
}) async {
  final usedCount = await PostStylePreviewGenerationCountStore.readTodayCount(
    now: now,
  );
  return resolvePostStylePreviewGenerationAvailability(
    usedCount: usedCount,
    flags: flags,
    purchasedPlanOverride: purchasedPlanOverride,
    enforcementEnabled: enforcementEnabled,
  );
}

/// 生成成功後に今日の回数を 1 増やす。
Future<int> recordSuccessfulPostStylePreviewGeneration({DateTime? now}) =>
    PostStylePreviewGenerationCountStore.incrementTodayCount(now: now);

/// 制限到達時のユーザー向けメッセージ。
String buildPostStylePreviewGenerationLimitBlockedMessage() =>
    '本日の生成イメージ作成回数の上限に達しました。保存済みの文例は編集できます。';

/// 利用状況の短い表示。
String postStylePreviewGenerationUsageLabel(
  PostStylePreviewGenerationLimitState state,
) {
  if (!state.appliesDailyLimit) {
    return '生成イメージ: 無制限';
  }
  if (!state.allowed) {
    return buildPostStylePreviewGenerationLimitBlockedMessage();
  }
  return '本日の生成イメージ: あと${state.remainingCount}回';
}

/// 成功時にカウントを記録すべきか。
bool shouldRecordPostStylePreviewGeneration({
  required PostStylePreviewGenerationLimitState state,
  bool? enforcementEnabled,
}) {
  final remoteEnabled = enforcementEnabled ?? isPostStylePreviewGenerationLimitEnforced();
  if (!remoteEnabled) return false;
  if (!state.appliesDailyLimit) return false;
  if (kDebugMode) {
    importantDebugLog(
      '[POST_STYLE_PREVIEW_LIMIT] record used=${state.usedCount} '
      'limit=${state.limit}',
    );
  }
  return true;
}
