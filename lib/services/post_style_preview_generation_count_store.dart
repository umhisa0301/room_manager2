import 'package:shared_preferences/shared_preferences.dart';

/// 投稿スタイル設定の「生成イメージ」AI更新の1日あたり成功回数を端末ローカルに保持する。
///
/// recommendation bucket の商品別生成回数とは別カウント。
abstract final class PostStylePreviewGenerationCountStore {
  static const String dateKey = 'post_style_preview_generation_date';
  static const String countKey = 'post_style_preview_generation_count';

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
}
