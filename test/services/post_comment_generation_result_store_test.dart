import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/post_comment_generation_result.dart';
import 'package:room_manager2/models/saved_post_comment_generation_result.dart';
import 'package:room_manager2/services/post_comment_generation_count_store.dart';
import 'package:room_manager2/services/post_comment_generation_result_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bucketName = 'recommendation';

  group('SavedPostCommentGenerationResult', () {
    test('displayText prefers fullText', () {
      const saved = SavedPostCommentGenerationResult(
        body: '本文',
        hashtags: ['#tag'],
        fullText: '全文テキスト',
        generatedAt: '2026-07-03T12:00:00.000',
        productKey: 'shop:itemA',
        bucket: bucketName,
        dateKey: '2026-07-03',
      );
      expect(saved.displayText, '全文テキスト');
    });

    test('round-trips through JSON', () {
      final original = SavedPostCommentGenerationResult.fromGenerationResult(
        result: const PostCommentGenerationResult(
          body: '本文',
          hashtags: ['#おすすめ'],
          fullText: '本文\n\n#おすすめ',
        ),
        productKey: 'shop:itemA',
        bucket: bucketName,
        dateKey: '2026-07-03',
        generatedAt: DateTime(2026, 7, 3, 12),
      );
      final restored = SavedPostCommentGenerationResult.fromJson(original.toJson());
      expect(restored.body, original.body);
      expect(restored.hashtags, original.hashtags);
      expect(restored.fullText, original.fullText);
      expect(restored.productKey, original.productKey);
      expect(restored.bucket, original.bucket);
      expect(restored.dateKey, original.dateKey);
    });
  });

  group('PostCommentGenerationResultStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('readTodaySavedResult returns null when nothing stored', () async {
      final saved = await PostCommentGenerationResultStore.readTodaySavedResult(
        bucketName: bucketName,
        productKey: 'shop:itemA',
        now: DateTime(2026, 7, 3),
      );
      expect(saved, isNull);
    });

    test('saveTodayResult and readTodaySavedResult round-trip', () async {
      const result = PostCommentGenerationResult(
        body: '保存本文',
        hashtags: ['#tag'],
        fullText: '保存全文',
      );
      final now = DateTime(2026, 7, 3, 15);

      await PostCommentGenerationResultStore.saveTodayResult(
        bucketName: bucketName,
        productKey: 'shop:itemA',
        result: result,
        now: now,
      );

      final saved = await PostCommentGenerationResultStore.readTodaySavedResult(
        bucketName: bucketName,
        productKey: 'shop:itemA',
        now: now,
      );

      expect(saved, isNotNull);
      expect(saved!.displayText, '保存全文');
      expect(saved.productKey, 'shop:itemA');
      expect(saved.bucket, bucketName);
      expect(
        saved.dateKey,
        PostCommentGenerationCountStore.localDateKey(now),
      );
    });

    test('readTodaySavedResult resets when date changes', () async {
      const result = PostCommentGenerationResult(
        body: '保存本文',
        fullText: '保存全文',
      );
      final day1 = DateTime(2026, 7, 3);

      await PostCommentGenerationResultStore.saveTodayResult(
        bucketName: bucketName,
        productKey: 'shop:itemA',
        result: result,
        now: day1,
      );

      final saved = await PostCommentGenerationResultStore.readTodaySavedResult(
        bucketName: bucketName,
        productKey: 'shop:itemA',
        now: DateTime(2026, 7, 4),
      );
      expect(saved, isNull);
    });

    test('saveTodayResult clears previous day map when date changes', () async {
      const result = PostCommentGenerationResult(
        body: '新しい日',
        fullText: '新しい日',
      );
      final day1 = DateTime(2026, 7, 3);
      final day2 = DateTime(2026, 7, 4);

      await PostCommentGenerationResultStore.saveTodayResult(
        bucketName: bucketName,
        productKey: 'shop:itemA',
        result: const PostCommentGenerationResult(
          body: '古い日',
          fullText: '古い日',
        ),
        now: day1,
      );

      await PostCommentGenerationResultStore.saveTodayResult(
        bucketName: bucketName,
        productKey: 'shop:itemB',
        result: result,
        now: day2,
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(
        PostCommentGenerationResultStore.resultsMapKeyFor(bucketName),
      );
      final map = jsonDecode(raw!) as Map<String, dynamic>;
      expect(map.keys, ['shop:itemB']);
    });
  });
}
