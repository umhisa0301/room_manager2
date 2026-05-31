import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/today_recommendation_genre_page_store.dart';

void main() {
  group('TodayRecommendGenrePageStore', () {
    test('page=1固定にならず次回は page を進める', () {
      final now = DateTime(2026, 5, 31);
      const sort = '-reviewCount';
      final cursor = TodayRecommendGenrePageCursor(
        lastFetchedPage: 2,
        lastFetchedSort: sort,
        lastFetchedAt: now.subtract(const Duration(hours: 1)),
      );
      expect(
        TodayRecommendGenrePageStore.resolveNextPage(
          cursor: cursor,
          sort: sort,
          now: now,
        ),
        3,
      );
    });

    test('枯渇クールダウン中は page 1 に戻る', () {
      final now = DateTime(2026, 5, 31);
      const sort = '-reviewCount';
      final cursor = TodayRecommendGenrePageCursor(
        lastFetchedPage: 5,
        lastFetchedSort: sort,
        exhaustedUntil: now.add(const Duration(hours: 2)),
      );
      expect(
        TodayRecommendGenrePageStore.resolveNextPage(
          cursor: cursor,
          sort: sort,
          now: now,
        ),
        1,
      );
    });

    test('maxPage 超過後は 1 にラップ', () {
      final now = DateTime(2026, 5, 31);
      const sort = '-reviewCount';
      final cursor = TodayRecommendGenrePageCursor(
        lastFetchedPage: TodayRecommendGenrePageStore.maxPage,
        lastFetchedSort: sort,
      );
      expect(
        TodayRecommendGenrePageStore.resolveNextPage(
          cursor: cursor,
          sort: sort,
          now: now,
        ),
        1,
      );
    });

    test('rawCount が少ないと exhaustedUntil が設定される', () {
      final now = DateTime(2026, 5, 31);
      final advanced = TodayRecommendGenrePageStore.advance(
        previous: null,
        sort: '-reviewCount',
        pageUsed: 3,
        rawCount: 5,
        usableCount: 2,
        managedExcludedCount: 3,
        now: now,
      );
      expect(advanced.lastFetchedPage, 3);
      expect(advanced.exhaustedUntil, isNotNull);
    });
  });
}
