import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/post_comment_generation_count_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PostCommentGenerationCountStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('readTodayCount returns 0 when no prior usage', () async {
      final count = await PostCommentGenerationCountStore.readTodayCount(
        now: DateTime(2026, 7, 1),
      );
      expect(count, 0);
    });

    test('incrementTodayCount increases count for same day', () async {
      final now = DateTime(2026, 7, 1, 12);
      expect(
        await PostCommentGenerationCountStore.incrementTodayCount(now: now),
        1,
      );
      expect(
        await PostCommentGenerationCountStore.incrementTodayCount(now: now),
        2,
      );
      expect(
        await PostCommentGenerationCountStore.readTodayCount(now: now),
        2,
      );
    });

    test('readTodayCount resets when date changes', () async {
      final day1 = DateTime(2026, 7, 1);
      await PostCommentGenerationCountStore.incrementTodayCount(now: day1);
      expect(
        await PostCommentGenerationCountStore.readTodayCount(
          now: DateTime(2026, 7, 2),
        ),
        0,
      );
    });
  });
}
