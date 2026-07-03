import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// AI投稿文生成の bucket 別・当日生成済み商品キーを端末ローカルに保持する。
abstract final class PostCommentGenerationCountStore {
  static String dateKeyFor(String bucketName) =>
      'post_comment_generation_${bucketName}_date';

  static String productKeysKeyFor(String bucketName) =>
      'post_comment_generation_${bucketName}_product_keys';

  /// ローカル暦日のキー（yyyy-MM-dd）。
  static String localDateKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// 指定 bucket の今日の生成成功済み商品キー（日付が異なる場合は空）。
  static Future<Set<String>> readTodayGeneratedProductKeys({
    required String bucketName,
    DateTime? now,
  }) async {
    final today = localDateKey(now);
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(dateKeyFor(bucketName));
    if (storedDate != today) return {};

    final raw = prefs.getString(productKeysKeyFor(bucketName));
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  /// 生成成功時に商品キーを bucket の当日セットへ追加する。
  static Future<Set<String>> recordGeneratedProductKey({
    required String bucketName,
    required String productKey,
    DateTime? now,
  }) async {
    final key = productKey.trim();
    if (key.isEmpty) return {};

    final today = localDateKey(now);
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(dateKeyFor(bucketName));
    final keys = storedDate == today
        ? await readTodayGeneratedProductKeys(
            bucketName: bucketName,
            now: now,
          )
        : <String>{};
    keys.add(key);

    final sorted = keys.toList()..sort();
    await prefs.setString(dateKeyFor(bucketName), today);
    await prefs.setString(
      productKeysKeyFor(bucketName),
      jsonEncode(sorted),
    );
    return keys;
  }
}
