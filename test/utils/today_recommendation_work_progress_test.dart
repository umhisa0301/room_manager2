import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/today_recommendation.dart';
import 'package:room_manager2/utils/today_recommendation_policy.dart';
import 'package:room_manager2/utils/today_recommendation_work_progress.dart';

RakutenSearchItem _item({required String id, String name = '商品'}) {
  return RakutenSearchItem(
    productId: id,
    itemName: name,
    itemPrice: 1500,
    itemUrl: 'https://example.com/$id',
    affiliateUrl: '',
    imageUrl: '',
    shopName: 'Shop',
    shopCode: 'shop-a',
  );
}

TodayRecommendationEntry _entry({
  required String id,
  TodayRecommendationDecision decision = TodayRecommendationDecision.pending,
  TodayRecommendationSection section = TodayRecommendationSection.popular,
}) {
  return TodayRecommendationEntry(
    item: _item(id: id),
    decision: decision,
    section: section,
  );
}

TodayRecommendationBundle _bundleForToday({
  required List<TodayRecommendationEntry> entries,
  DateTime? now,
}) {
  final date = now ?? DateTime(2026, 7, 7);
  return TodayRecommendationBundle(
    localDateKey: TodayRecommendationWorkProgress.localDateKey(date),
    generatedAt: date,
    entries: entries,
  );
}

void main() {
  final now = DateTime(2026, 7, 7, 12);

  group('TodayRecommendationWorkProgress', () {
    test('0 processed visible entries is not complete', () {
      final bundle = _bundleForToday(
        now: now,
        entries: [
          _entry(id: '1'),
          _entry(id: '2'),
          _entry(id: '3'),
        ],
      );

      expect(
        TodayRecommendationWorkProgress.isVisibleReviewComplete(
          bundle: bundle,
          savedShopCount: 0,
          collectedProductIds: const {},
          isLoading: false,
          now: now,
        ),
        isFalse,
      );
      expect(
        TodayRecommendationWorkProgress.processedVisibleCount(
          bundle: bundle,
          savedShopCount: 0,
          collectedProductIds: const {},
          now: now,
        ),
        0,
      );
    });

    test('1 or 2 processed visible entries remain incomplete', () {
      final bundle = _bundleForToday(
        now: now,
        entries: [
          _entry(id: '1', decision: TodayRecommendationDecision.skipped),
          _entry(id: '2'),
          _entry(id: '3'),
        ],
      );

      expect(
        TodayRecommendationWorkProgress.isVisibleReviewComplete(
          bundle: bundle,
          savedShopCount: 0,
          collectedProductIds: const {},
          isLoading: false,
          now: now,
        ),
        isFalse,
      );

      final twoProcessed = _bundleForToday(
        now: now,
        entries: [
          _entry(id: '1', decision: TodayRecommendationDecision.skipped),
          _entry(id: '2', decision: TodayRecommendationDecision.addedCandidate),
          _entry(id: '3'),
        ],
      );
      expect(
        TodayRecommendationWorkProgress.isVisibleReviewComplete(
          bundle: twoProcessed,
          savedShopCount: 0,
          collectedProductIds: const {},
          isLoading: false,
          now: now,
        ),
        isFalse,
      );
    });

    test('all 3 visible entries processed is complete', () {
      final bundle = _bundleForToday(
        now: now,
        entries: [
          _entry(id: '1', decision: TodayRecommendationDecision.skipped),
          _entry(id: '2', decision: TodayRecommendationDecision.addedCandidate),
          _entry(id: '3', decision: TodayRecommendationDecision.skipped),
        ],
      );

      expect(
        TodayRecommendationWorkProgress.isVisibleReviewComplete(
          bundle: bundle,
          savedShopCount: 0,
          collectedProductIds: const {},
          isLoading: false,
          now: now,
        ),
        isTrue,
      );
      expect(
        TodayRecommendationWorkProgress.processedVisibleCount(
          bundle: bundle,
          savedShopCount: 0,
          collectedProductIds: const {},
          now: now,
        ),
        3,
      );
    });

    test('already collected product counts as processed even when pending', () {
      final bundle = _bundleForToday(
        now: now,
        entries: [
          _entry(id: '1'),
          _entry(id: '2'),
          _entry(id: '3'),
        ],
      );

      expect(
        TodayRecommendationWorkProgress.isVisibleReviewComplete(
          bundle: bundle,
          savedShopCount: 0,
          collectedProductIds: const {'1', '2', '3'},
          isLoading: false,
          now: now,
        ),
        isTrue,
      );
    });

    test('completion follows custom visibleDisplayCap', () {
      final bundle = _bundleForToday(
        now: now,
        entries: [
          _entry(id: '1', decision: TodayRecommendationDecision.skipped),
          _entry(id: '2', decision: TodayRecommendationDecision.skipped),
          _entry(id: '3'),
          _entry(id: '4'),
        ],
      );

      expect(
        TodayRecommendationWorkProgress.isVisibleReviewComplete(
          bundle: bundle,
          savedShopCount: 0,
          collectedProductIds: const {},
          isLoading: false,
          now: now,
          cap: 2,
        ),
        isTrue,
      );
      expect(
        TodayRecommendationWorkProgress.isVisibleReviewComplete(
          bundle: bundle,
          savedShopCount: 0,
          collectedProductIds: const {},
          isLoading: false,
          now: now,
          cap: TodayRecommendationPolicy.visibleDisplayCap,
        ),
        isFalse,
      );
    });

    test('previous day bundle does not complete today work', () {
      final bundle = TodayRecommendationBundle(
        localDateKey: '2026-07-06',
        generatedAt: DateTime(2026, 7, 6),
        entries: [
          _entry(id: '1', decision: TodayRecommendationDecision.skipped),
          _entry(id: '2', decision: TodayRecommendationDecision.skipped),
          _entry(id: '3', decision: TodayRecommendationDecision.skipped),
        ],
      );

      expect(
        TodayRecommendationWorkProgress.isVisibleReviewComplete(
          bundle: bundle,
          savedShopCount: 0,
          collectedProductIds: const {},
          isLoading: false,
          now: now,
        ),
        isFalse,
      );
    });

    test('loading state is never complete', () {
      final bundle = _bundleForToday(
        now: now,
        entries: [
          _entry(id: '1', decision: TodayRecommendationDecision.skipped),
          _entry(id: '2', decision: TodayRecommendationDecision.skipped),
          _entry(id: '3', decision: TodayRecommendationDecision.skipped),
        ],
      );

      expect(
        TodayRecommendationWorkProgress.isVisibleReviewComplete(
          bundle: bundle,
          savedShopCount: 0,
          collectedProductIds: const {},
          isLoading: true,
          now: now,
        ),
        isFalse,
      );
    });

    test('collectedProductIdsFrom includes done products only', () {
      final t = DateTime(2026, 7, 7);
      RakutenManagedProduct product({
        required String id,
        required RakutenManagedProductStatus status,
      }) {
        return RakutenManagedProduct(
          productId: id,
          itemName: 'Item',
          itemPrice: 1000,
          itemUrl: 'https://example.com/$id',
          imageUrl: '',
          shopName: 'Shop',
          shopCode: 'shop-a',
          shopUrl: '',
          genreId: '',
          status: status,
          createdAt: t,
          updatedAt: t,
          addedAt: t,
          extractedUrl: '',
          extractionStatus: RakutenUrlExtractionStatus.notStarted,
          extractionErrorMessage: '',
          doneAt: status == RakutenManagedProductStatus.done ? t : null,
        );
      }

      final ids = TodayRecommendationWorkProgress.collectedProductIdsFrom([
        product(id: 'done-1', status: RakutenManagedProductStatus.done),
        product(id: 'candidate-1', status: RakutenManagedProductStatus.candidate),
      ]);

      expect(ids, {'done-1'});
    });
  });
}
