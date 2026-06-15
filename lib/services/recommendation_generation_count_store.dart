import 'package:shared_preferences/shared_preferences.dart';

/// おすすめコレの1日あたり実行回数を端末ローカルに保持する。
///
/// 初回生成（[dateKey]/[countKey]）と手動再生成（[refreshDateKey]/[refreshCountKey]）は別管理。
abstract final class RecommendationGenerationCountStore {
  static const String dateKey = 'recommendation_generation_date';
  static const String countKey = 'recommendation_generation_count';
  static const String refreshDateKey = 'recommendation_refresh_date';
  static const String refreshCountKey = 'recommendation_refresh_count';

  /// ローカル暦日のキー（yyyy-MM-dd）。
  static String localDateKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// 今日の生成成功回数（日付が異なる場合は 0）。
  static Future<int> readTodayCount({DateTime? now}) async {
    final today = localDateKey(now);
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(dateKey);
    if (storedDate != today) return 0;
    return prefs.getInt(countKey) ?? 0;
  }

  /// 生成成功時に今日の回数を 1 増やす。
  static Future<int> incrementTodayCount({DateTime? now}) async {
    final today = localDateKey(now);
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(dateKey);
    final current = storedDate == today ? (prefs.getInt(countKey) ?? 0) : 0;
    final next = current + 1;
    await prefs.setString(dateKey, today);
    await prefs.setInt(countKey, next);
    return next;
  }

  /// 今日の手動再生成成功回数（日付が異なる場合は 0）。
  static Future<int> readTodayRefreshCount({DateTime? now}) async {
    final today = localDateKey(now);
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(refreshDateKey);
    if (storedDate != today) return 0;
    return prefs.getInt(refreshCountKey) ?? 0;
  }

  /// 手動再生成成功時に今日の回数を 1 増やす。
  static Future<int> incrementTodayRefreshCount({DateTime? now}) async {
    final today = localDateKey(now);
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(refreshDateKey);
    final current =
        storedDate == today ? (prefs.getInt(refreshCountKey) ?? 0) : 0;
    final next = current + 1;
    await prefs.setString(refreshDateKey, today);
    await prefs.setInt(refreshCountKey, next);
    return next;
  }
}
