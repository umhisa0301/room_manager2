import 'package:flutter/foundation.dart';

import '../config/monetization_config.dart';
import '../config/monetization_plan_config.dart';
import '../models/rakuten_managed_product.dart';
import '../utils/app_debug_log.dart';
import '../utils/managed_product_diag_log.dart';
import 'room_import_limit_policy.dart';

/// ROOMデータ更新（取り込み）の利用可否スナップショット。
class RoomImportAvailabilityState {
  const RoomImportAvailabilityState({
    required this.allowed,
    required this.currentImportedCount,
    required this.limit,
    required this.unlimited,
    required this.plan,
    required this.limitsEnforcementEnabled,
    this.reasonCode,
  });

  final bool allowed;

  /// コレ候補＋コレ済みの管理商品合計。
  final int currentImportedCount;

  /// null は無制限（basic / pro）。
  final int? limit;
  final bool unlimited;
  final MonetizationPlan plan;
  final bool limitsEnforcementEnabled;

  /// 上限到達時は `room_import_limit_reached`。
  final String? reasonCode;
}

/// 無料版制限のカウント対象：コレ候補＋コレ済みの合計。
int countManagedProductsForRoomImportLimit(
  Iterable<RakutenManagedProduct> items,
) {
  final (pending, done) = ManagedProductDiagLog.pendingAndDoneCounts(items);
  return pending + done;
}

/// 利用件数とプランから ROOM データ更新可否を解決（純粋関数・テスト用）。
RoomImportAvailabilityState resolveRoomImportAvailability({
  required int currentImportedCount,
  MonetizationPlanContext? planContext,
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) {
  final context = planContext ??
      resolvePlanLimitsForCurrentUser(
        flags: flags,
        purchasedPlanOverride: purchasedPlanOverride,
      );
  final planLimit = context.limits.roomImportLimitPerRun;
  final unlimited = planLimit == null;

  if (!context.limitsEnforcementEnabled) {
    return RoomImportAvailabilityState(
      allowed: true,
      currentImportedCount: currentImportedCount,
      limit: planLimit,
      unlimited: true,
      plan: context.plan,
      limitsEnforcementEnabled: false,
    );
  }

  if (unlimited) {
    return RoomImportAvailabilityState(
      allowed: true,
      currentImportedCount: currentImportedCount,
      limit: null,
      unlimited: true,
      plan: context.plan,
      limitsEnforcementEnabled: true,
    );
  }

  final limit = planLimit;
  final allowed = currentImportedCount < limit;
  return RoomImportAvailabilityState(
    allowed: allowed,
    currentImportedCount: currentImportedCount,
    limit: limit,
    unlimited: false,
    plan: context.plan,
    limitsEnforcementEnabled: true,
    reasonCode: allowed ? null : 'room_import_limit_reached',
  );
}

/// 商品一覧から ROOM データ更新可否を解決。
RoomImportAvailabilityState resolveRoomImportAvailabilityFromItems({
  required Iterable<RakutenManagedProduct> items,
  MonetizationPlanContext? planContext,
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) =>
    resolveRoomImportAvailability(
      currentImportedCount: countManagedProductsForRoomImportLimit(items),
      planContext: planContext,
      flags: flags,
      purchasedPlanOverride: purchasedPlanOverride,
    );

/// 生成可否のエイリアス。
bool canRefreshRoomData(RoomImportAvailabilityState state) => state.allowed;

/// 管理商品一覧から ROOM データ更新可否を解決し debug ログを出す。
bool canRefreshRoomDataForManagedItems({
  required Iterable<RakutenManagedProduct> items,
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) {
  final state = resolveRoomImportAvailabilityFromItems(
    items: items,
    flags: flags,
    purchasedPlanOverride: purchasedPlanOverride,
  );
  if (kDebugMode) {
    importantDebugLog(
      '[MONETIZATION_LIMIT] roomImport allowed=${state.allowed} '
      'plan=${state.plan.name} current=${state.currentImportedCount} '
      'limit=${state.limit ?? 'unlimited'}',
    );
  }
  return state.allowed;
}

/// 1回の取り込みバッチで処理する最大件数（0 = 実行不可）。
int resolveRoomImportBatchSize(RoomImportAvailabilityState state) {
  if (!state.allowed) return 0;
  if (state.unlimited) {
    return RoomImportLimitPolicy.proBatchLimit;
  }
  final limit = state.limit!;
  final remaining = limit - state.currentImportedCount;
  if (remaining <= 0) return 0;
  return remaining;
}

/// 取り込み後自動補完の上限。
int resolveRoomImportPostBatchEnrichLimit(RoomImportAvailabilityState state) {
  final batch = resolveRoomImportBatchSize(state);
  if (batch <= 0) return 0;
  if (state.unlimited) {
    return RoomImportLimitPolicy.postBatchAutoEnrichMaxApiCalls;
  }
  return batch.clamp(0, RoomImportLimitPolicy.postBatchAutoEnrichMaxApiCalls);
}

/// 無料版向けの体験版ヒント。
String roomImportLimitTrialHint() =>
    '無料版では投稿・反応の更新は10件までお試しできます。';

/// 上限到達時のユーザー向けメッセージ。
String roomImportLimitBlockedMessage() =>
    '無料版では投稿・反応の更新は10件までです。'
    'Basicプランでは上限なく同期できる予定です。';

/// SnackBar 等用の全文。
String buildRoomImportLimitBlockedBody(RoomImportAvailabilityState state) =>
    roomImportLimitBlockedMessage();

/// 制限 ON 時の短い表示（ボタン付近）。
String? roomImportLimitUsageHint(RoomImportAvailabilityState state) {
  if (!state.limitsEnforcementEnabled || state.unlimited) return null;
  if (state.plan != MonetizationPlan.free) return null;
  if (!state.allowed) return null;
  final limit = state.limit ?? kFreeMonetizationPlanLimits.roomImportLimitPerRun!;
  return '${roomImportLimitTrialHint()}（${state.currentImportedCount} / $limit件）';
}
