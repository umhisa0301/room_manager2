import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/post_comment_generation_result.dart';
import '../models/saved_post_comment_generation_result.dart';
import 'post_comment_generation_count_store.dart';

/// recommendation bucket 等の AI 投稿文生成結果を商品キー単位で端末ローカルに保持する。
abstract final class PostCommentGenerationResultStore {
  static String dateKeyFor(String bucketName) =>
      'post_comment_generation_${bucketName}_saved_results_date';

  static String resultsMapKeyFor(String bucketName) =>
      'post_comment_generation_${bucketName}_saved_results';

  /// 指定 bucket・商品キーの当日保存済み生成結果（日付が異なる場合は null）。
  static Future<SavedPostCommentGenerationResult?> readTodaySavedResult({
    required String bucketName,
    required String productKey,
    DateTime? now,
  }) async {
    final key = productKey.trim();
    if (key.isEmpty) return null;

    final today = PostCommentGenerationCountStore.localDateKey(now);
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(dateKeyFor(bucketName));
    if (storedDate != today) return null;

    final raw = prefs.getString(resultsMapKeyFor(bucketName));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final entry = decoded[key];
      if (entry is! Map) return null;
      final saved = SavedPostCommentGenerationResult.fromJson(
        Map<String, dynamic>.from(entry),
      );
      if (saved.dateKey != today) return null;
      return saved;
    } catch (_) {
      return null;
    }
  }

  /// 生成成功時に商品キー単位で結果を bucket の当日マップへ保存する。
  static Future<void> saveTodayResult({
    required String bucketName,
    required String productKey,
    required PostCommentGenerationResult result,
    DateTime? now,
  }) async {
    final key = productKey.trim();
    if (key.isEmpty) return;

    final today = PostCommentGenerationCountStore.localDateKey(now);
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(dateKeyFor(bucketName));

    final Map<String, dynamic> map;
    if (storedDate == today) {
      final existing = await _readResultsMap(bucketName: bucketName);
      map = Map<String, dynamic>.from(existing);
    } else {
      map = {};
    }

    map[key] = SavedPostCommentGenerationResult.fromGenerationResult(
      result: result,
      productKey: key,
      bucket: bucketName,
      dateKey: today,
      generatedAt: now,
    ).toJson();

    await prefs.setString(dateKeyFor(bucketName), today);
    await prefs.setString(resultsMapKeyFor(bucketName), jsonEncode(map));
  }

  static Future<Map<String, dynamic>> _readResultsMap({
    required String bucketName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(resultsMapKeyFor(bucketName));
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return {};
    }
  }
}
