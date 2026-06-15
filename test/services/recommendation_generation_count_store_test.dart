import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/recommendation_generation_count_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecommendationGenerationCountStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('localDateKey formats local calendar day', () {
      expect(
        RecommendationGenerationCountStore.localDateKey(
          DateTime(2026, 6, 15, 23, 59),
        ),
        '2026-06-15',
      );
    });

    test('readTodayCount returns 0 when no data', () async {
      expect(
        await RecommendationGenerationCountStore.readTodayCount(),
        0,
      );
    });

    test('incrementTodayCount increases count for same day', () async {
      final now = DateTime(2026, 6, 15, 10);
      expect(
        await RecommendationGenerationCountStore.incrementTodayCount(now: now),
        1,
      );
      expect(
        await RecommendationGenerationCountStore.readTodayCount(now: now),
        1,
      );
      expect(
        await RecommendationGenerationCountStore.incrementTodayCount(now: now),
        2,
      );
    });

    test('readTodayCount resets when date changes', () async {
      final yesterday = DateTime(2026, 6, 14, 20);
      await RecommendationGenerationCountStore.incrementTodayCount(
        now: yesterday,
      );
      expect(
        await RecommendationGenerationCountStore.readTodayCount(
          now: DateTime(2026, 6, 15, 8),
        ),
        0,
      );
    });
  });
}
