import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/post_comment_generation_count_store.dart';
import 'package:room_manager2/services/post_comment_generation_limit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bucketName = 'recommendation';

  group('PostCommentGenerationCountStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('readTodayGeneratedProductKeys returns empty when no prior usage',
        () async {
      final keys =
          await PostCommentGenerationCountStore.readTodayGeneratedProductKeys(
        bucketName: bucketName,
        now: DateTime(2026, 7, 1),
      );
      expect(keys, isEmpty);
    });

    test('recordGeneratedProductKey accumulates keys for same day', () async {
      final now = DateTime(2026, 7, 1, 12);
      await PostCommentGenerationCountStore.recordGeneratedProductKey(
        bucketName: bucketName,
        productKey: 'shop:itemA',
        now: now,
      );
      await PostCommentGenerationCountStore.recordGeneratedProductKey(
        bucketName: bucketName,
        productKey: 'shop:itemB',
        now: now,
      );

      final keys =
          await PostCommentGenerationCountStore.readTodayGeneratedProductKeys(
        bucketName: bucketName,
        now: now,
      );
      expect(keys, {'shop:itemA', 'shop:itemB'});
    });

    test('readTodayGeneratedProductKeys resets when date changes', () async {
      final day1 = DateTime(2026, 7, 1);
      await PostCommentGenerationCountStore.recordGeneratedProductKey(
        bucketName: bucketName,
        productKey: 'shop:itemA',
        now: day1,
      );

      final keys =
          await PostCommentGenerationCountStore.readTodayGeneratedProductKeys(
        bucketName: bucketName,
        now: DateTime(2026, 7, 2),
      );
      expect(keys, isEmpty);
    });

    test('recordGeneratedProductKey ignores empty product key', () async {
      final now = DateTime(2026, 7, 1);
      await PostCommentGenerationCountStore.recordGeneratedProductKey(
        bucketName: bucketName,
        productKey: '   ',
        now: now,
      );

      final keys =
          await PostCommentGenerationCountStore.readTodayGeneratedProductKeys(
        bucketName: bucketName,
        now: now,
      );
      expect(keys, isEmpty);
    });

    test('bucket keys are isolated per bucket name', () async {
      final now = DateTime(2026, 7, 1);
      await PostCommentGenerationCountStore.recordGeneratedProductKey(
        bucketName: PostCommentGenerationBucket.recommendation.name,
        productKey: 'shop:itemA',
        now: now,
      );

      final recommendationKeys =
          await PostCommentGenerationCountStore.readTodayGeneratedProductKeys(
        bucketName: PostCommentGenerationBucket.recommendation.name,
        now: now,
      );
      final otherKeys =
          await PostCommentGenerationCountStore.readTodayGeneratedProductKeys(
        bucketName: 'search',
        now: now,
      );

      expect(recommendationKeys, {'shop:itemA'});
      expect(otherKeys, isEmpty);
    });
  });
}
