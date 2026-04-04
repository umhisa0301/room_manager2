import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_log.dart';

/// 活動ログの永続化を担当するリポジトリ。
class ActivityLogRepository {
  ActivityLogRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyActivityLogs = 'activity_logs';

  List<ActivityLog> loadLogs() {
    try {
      final raw = _prefs.getString(_keyActivityLogs);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final result = <ActivityLog>[];
      for (final item in decoded) {
        final log = ActivityLog.fromJson(
          item is Map<String, dynamic> ? item : null,
        );
        if (log != null) result.add(log);
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  void saveLogs(List<ActivityLog> logs) {
    try {
      final raw = jsonEncode(logs.map((e) => e.toJson()).toList());
      _prefs.setString(_keyActivityLogs, raw);
    } catch (_) {
      // 失敗時もクラッシュさせない
    }
  }
}
