import 'package:flutter/foundation.dart';

import '../models/activity_log.dart';
import '../repository/activity_log_repository.dart';

/// 活動ログの状態管理。
class ActivityLogProvider extends ChangeNotifier {
  ActivityLogProvider({required ActivityLogRepository repository})
    : _repository = repository,
      _logs = List.from(repository.loadLogs());

  final ActivityLogRepository _repository;
  final List<ActivityLog> _logs;

  List<ActivityLog> get logs {
    final copy = List<ActivityLog>.from(_logs);
    copy.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return copy;
  }

  String todayKey() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  ActivityLog? getTodayLog() => findByDateKey(todayKey());

  ActivityLog? findByDateKey(String dateKey) {
    try {
      return _logs.firstWhere((e) => e.dateKey == dateKey);
    } catch (_) {
      return null;
    }
  }

  void upsertToday({
    required int collectedCount,
    required int commentCount,
    String? memo,
  }) {
    final key = todayKey();
    final now = DateTime.now();
    final existing = findByDateKey(key);
    if (existing == null) {
      _logs.add(
        ActivityLog(
          dateKey: key,
          collectedCount: collectedCount,
          commentCount: commentCount,
          memo: memo,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      final i = _logs.indexWhere((e) => e.dateKey == key);
      _logs[i] = existing.copyWith(
        collectedCount: collectedCount,
        commentCount: commentCount,
        memo: memo,
        updatedAt: now,
      );
    }
    _persist();
    notifyListeners();
  }

  void _persist() {
    _repository.saveLogs(_logs);
  }
}
