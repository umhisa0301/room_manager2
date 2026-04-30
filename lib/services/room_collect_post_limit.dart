import 'package:flutter/material.dart';

import '../models/rakuten_managed_product.dart';
import '../models/room_activity_event.dart';

/// ROOM コレ投稿の1日・1時間上限表示・判定用スナップショット。
enum RoomCollectPostLimitBarState { normal, warning, reached }

class RoomCollectPostLimitSnapshot {
  const RoomCollectPostLimitSnapshot({
    required this.todayCount,
    required this.hourCount,
    required this.hasAnyCollectRecord,
    required this.hourRecoveryAt,
  });

  static const int dailyLimit = 200;
  static const int hourlyLimit = 100;
  static const int dailyWarningThreshold = 160;
  static const int hourlyWarningThreshold = 80;

  final int todayCount;
  final int hourCount;
  final bool hasAnyCollectRecord;

  /// 直近1時間ウィンドウが満杯のとき、最古のコレ時刻から1時間後（再開目安）。
  final DateTime? hourRecoveryAt;

  int get dailyRemaining => (dailyLimit - todayCount).clamp(0, dailyLimit);
  int get hourlyRemaining => (hourlyLimit - hourCount).clamp(0, hourlyLimit);

  bool get isDailyReached => todayCount >= dailyLimit;
  bool get isHourlyReached => hourCount >= hourlyLimit;
  bool get isAnyLimitReached => isDailyReached || isHourlyReached;

  bool get isDailyWarning =>
      !isDailyReached && todayCount >= dailyWarningThreshold;
  bool get isHourlyWarning =>
      !isHourlyReached && hourCount >= hourlyWarningThreshold;

  bool get canAcceptAnotherCollect =>
      todayCount < dailyLimit && hourCount < hourlyLimit;

  RoomCollectPostLimitBarState get dailyBarState {
    if (isDailyReached) return RoomCollectPostLimitBarState.reached;
    if (isDailyWarning) return RoomCollectPostLimitBarState.warning;
    return RoomCollectPostLimitBarState.normal;
  }

  RoomCollectPostLimitBarState get hourlyBarState {
    if (isHourlyReached) return RoomCollectPostLimitBarState.reached;
    if (isHourlyWarning) return RoomCollectPostLimitBarState.warning;
    return RoomCollectPostLimitBarState.normal;
  }

  /// 上限で投稿できない理由（到達時）。未到達は null。
  String get reachedBlockTitle {
    if (isDailyReached) return '本日の上限です';
    if (isHourlyReached) return 'この1時間は上限です';
    return '';
  }

  String get reachedBlockBodyLine {
    if (isDailyReached) return '明日また再開してください。';
    if (isHourlyReached) return '少し待ってから再開してください。';
    return '';
  }

  /// ユーザー向け短文（ダイアログ・ツールチップ）。未到達は null。
  String? get userBlockMessage {
    if (!isAnyLimitReached) return null;
    if (isDailyReached) {
      return '本日の上限です。明日また再開してください。';
    }
    if (isHourlyReached) {
      return 'この1時間は上限です。少し待ってから再開してください。';
    }
    return null;
  }

  String recoveryFootnote(DateTime now) {
    if (!isHourlyReached || hourRecoveryAt == null) {
      return '少し時間をおいて再開できます。';
    }
    return formatMinutesToRecoveryLine(hourRecoveryAt!, now);
  }

  static RoomCollectPostLimitSnapshot compute({
    required List<RakutenManagedProduct> items,
    required List<RoomActivityEvent> events,
    required DateTime now,
  }) {
    final timestamps = <DateTime>[];
    final productIdsWithDoneAt = <String>{};

    for (final item in items) {
      if (!RakutenManagedProduct.isMemberForStatusTab(
        item,
        RakutenManagedProductStatus.done,
      )) {
        continue;
      }
      final doneAt = item.doneAt;
      if (doneAt == null) continue;
      timestamps.add(doneAt);
      final id = item.productId.trim();
      if (id.isNotEmpty) productIdsWithDoneAt.add(id);
    }

    for (final event in events) {
      if (event.type != RoomActivityEventType.movedToCored) continue;
      if (productIdsWithDoneAt.contains(event.productId.trim())) continue;
      timestamps.add(event.createdAt);
    }

    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final hourStart = now.subtract(const Duration(minutes: 60));
    var todayCount = 0;
    final hourTimestamps = <DateTime>[];

    for (final at in timestamps) {
      if (!at.isBefore(todayStart) && at.isBefore(tomorrowStart)) {
        todayCount++;
      }
      if (!at.isBefore(hourStart) && !at.isAfter(now)) {
        hourTimestamps.add(at);
      }
    }
    hourTimestamps.sort();

    return RoomCollectPostLimitSnapshot(
      todayCount: todayCount,
      hourCount: hourTimestamps.length,
      hasAnyCollectRecord: timestamps.isNotEmpty,
      hourRecoveryAt: hourTimestamps.isEmpty
          ? null
          : hourTimestamps.first.add(const Duration(minutes: 60)),
    );
  }
}

/// 「あと○分で再開できます」（分は最低1、端数は切り上げ）。
String formatMinutesToRecoveryLine(DateTime recoveryAt, DateTime now) {
  var diff = recoveryAt.difference(now);
  if (diff.isNegative) {
    return 'まもなく再開できます。';
  }
  final minutes = (diff.inSeconds / 60).ceil().clamp(1, 24 * 60);
  return 'あと$minutes分で再開できます。';
}

Future<void> showCollectPostBlockedDialog(
  BuildContext context,
  RoomCollectPostLimitSnapshot snapshot,
) async {
  final now = DateTime.now();
  final headline = snapshot.userBlockMessage ?? '現在は投稿できません。';
  final detail = snapshot.isHourlyReached
      ? snapshot.recoveryFootnote(now)
      : snapshot.isDailyReached
          ? '本日のカウントは0時を過ぎるとリセットされます。'
          : '';

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(snapshot.isDailyReached ? '本日の上限' : '1時間の上限'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(headline),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  detail,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('閉じる'),
          ),
        ],
      );
    },
  );
}
