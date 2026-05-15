import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rakuten_managed_product.dart';
import '../../models/room_activity_event.dart';
import '../../navigation/app_shell_controller.dart';
import '../../state/rakuten_managed_product_provider.dart';

/// 活動画面用：`yyyy-MM-dd` 形式のキー（[ActivityLog] と同一ルール）。
String activityLogDateKey(DateTime local) {
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '${local.year}-$mm-$dd';
}

RakutenManagedProduct? activityFindProduct(
  List<RakutenManagedProduct> items,
  String productId,
) {
  final id = productId.trim();
  if (id.isEmpty) return null;
  for (final e in items) {
    if (e.productId == id) return e;
  }
  return null;
}

/// 活動ログの1行タップ時：ROOMコレの適切なタブを開く。
void activityNavigateForProductId(
  BuildContext context, {
  required String productId,
}) {
  final shell = context.read<AppShellController>();
  final room = context.read<RakutenManagedProductProvider>();
  final found = activityFindProduct(room.items, productId);
  if (found == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('商品が見つかりません（削除済みの可能性があります）'),
      ),
    );
    shell.openRoomCollect(initialTabIndex: 0);
    return;
  }
  switch (found.status) {
    case RakutenManagedProductStatus.done:
      shell.openRoomCollect(initialTabIndex: 1);
      return;
    case RakutenManagedProductStatus.candidate:
      shell.openRoomCollect(
        initialTabIndex: 0,
        focusCandidateProductId: found.productId,
      );
      return;
    case RakutenManagedProductStatus.none:
      shell.openRoomCollect(initialTabIndex: 0);
      return;
  }
}

int activityCountEventsOnLocalDay(
  List<RoomActivityEvent> events,
  DateTime localDay,
  Set<RoomActivityEventType> types,
) {
  final start = DateTime(localDay.year, localDay.month, localDay.day);
  final end = start.add(const Duration(days: 1));
  var n = 0;
  for (final e in events) {
    if (!types.contains(e.type)) continue;
    if (e.createdAt.isBefore(start) || !e.createdAt.isBefore(end)) continue;
    n++;
  }
  return n;
}

/// ローカル暦日ごとの「候補へ追加」（`addedAt` ベース）。イベント欠損時のフォールバック用。
///
/// **ROOM 取り込み**でコレ済に入った商品（`status == done` かつ `addedAt` が今日）は
/// カウントしない。[RakutenManagedProductStatus.candidate] のみ。
int activityCountCandidatesAddedOnLocalCalendarDay(
  List<RakutenManagedProduct> items,
  DateTime localDay,
) {
  final start = DateTime(localDay.year, localDay.month, localDay.day);
  final end = start.add(const Duration(days: 1));
  var n = 0;
  for (final e in items) {
    if (!RakutenManagedProduct.isMemberForStatusTab(
      e,
      RakutenManagedProductStatus.candidate,
    )) {
      continue;
    }
    final a = e.addedAt;
    if (a.isBefore(start) || !a.isBefore(end)) continue;
    n++;
  }
  return n;
}
