import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/today_recommendation_exposure_policy.dart';

void main() {
  group('TodayRecommendExposurePolicy', () {
    test('見送り済みは一定期間除外される', () {
      final now = DateTime(2026, 5, 31);
      final records = TodayRecommendExposurePolicy.mergeRecords([
        TodayRecommendExposureRecord(
          productId: 'p1',
          itemUrl: 'https://example.com/a',
          dismissedAt: now.subtract(const Duration(days: 1)),
        ),
      ]);
      expect(
        TodayRecommendExposurePolicy.exclusionReason(
          productId: 'p1',
          itemUrl: 'https://example.com/a',
          recordsById: records,
          now: now,
        ),
        'dismissedRecently',
      );
    });

    test('表示済みは一定期間除外される', () {
      final now = DateTime(2026, 5, 31);
      final records = TodayRecommendExposurePolicy.mergeRecords([
        TodayRecommendExposureRecord(
          productId: 'p2',
          itemUrl: 'https://example.com/b',
          shownAt: now.subtract(const Duration(days: 3)),
        ),
      ]);
      expect(
        TodayRecommendExposurePolicy.exclusionReason(
          productId: 'p2',
          itemUrl: 'https://example.com/b',
          recordsById: records,
          now: now,
        ),
        'shownRecently',
      );
    });

    test('古い表示済みは除外されない', () {
      final now = DateTime(2026, 5, 31);
      final records = TodayRecommendExposurePolicy.mergeRecords([
        TodayRecommendExposureRecord(
          productId: 'p3',
          itemUrl: 'https://example.com/c',
          shownAt: now.subtract(const Duration(days: 20)),
        ),
      ]);
      expect(
        TodayRecommendExposurePolicy.exclusionReason(
          productId: 'p3',
          itemUrl: 'https://example.com/c',
          recordsById: records,
          now: now,
        ),
        isNull,
      );
    });
  });
}
