import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// ホームお知らせカードの「当日閉じた」状態（端末ローカル・UI専用）。
abstract final class HomeInAppNoticeDismissStore {
  static const String _key = 'home_in_app_notice_dismissed_v1';

  /// ローカル暦日のキー（yyyy-MM-dd）。
  static String todayDateKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// 今日閉じた [noticeKey] の集合を読み込む。
  static Future<Set<String>> loadDismissedKeysForToday({
    DateTime? now,
  }) async {
    final today = todayDateKey(now);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final date = decoded['date']?.toString();
      if (date != today) return {};
      final keys = decoded['keys'];
      if (keys is! List) return {};
      return keys.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  /// 今日の閉じた通知として [noticeKey] を保存する。
  static Future<void> dismissForToday(
    String noticeKey, {
    DateTime? now,
  }) async {
    final key = noticeKey.trim();
    if (key.isEmpty) return;
    final today = todayDateKey(now);
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadDismissedKeysForToday(now: now);
    existing.add(key);
    await prefs.setString(
      _key,
      jsonEncode({'date': today, 'keys': existing.toList()..sort()}),
    );
  }
}
