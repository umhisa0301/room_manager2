import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/models/rakuten_product_search_condition.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/today_recommendation.dart';
import 'package:room_manager2/models/user_profile.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/repository/today_recommendation_repository.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/services/recommendation_generation_count_store.dart';
import 'package:room_manager2/services/recommendation_refresh_limit.dart';
import 'package:room_manager2/state/today_recommendation_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubSearchRepository extends RakutenSearchRepository {
  _StubSearchRepository({this.onSearch}) : super(apiService: RakutenApiService());

  final Future<List<RakutenSearchItem>> Function()? onSearch;

  @override
  Future<List<RakutenSearchItem>> search({
    required RakutenProductSearchCondition condition,
    int maxPages = 4,
    int startPage = 1,
    RakutenSearchPurpose searchPurpose = RakutenSearchPurpose.normal,
    String fetchScreen = 'productSearch',
  }) async {
    if (onSearch != null) return onSearch!();
    return List<RakutenSearchItem>.generate(
      10,
      (i) => RakutenSearchItem(
        productId: 'stub-shop:item$i',
        itemName: '商品$i',
        itemPrice: 1000 + i,
        itemUrl: 'https://item.rakuten.co.jp/stub-shop/item$i/',
        affiliateUrl: '',
        imageUrl:
            'https://thumbnail.image.rakuten.co.jp/@0_mall/stub-shop/cabinet/a.jpg',
        shopName: 'Stub Shop',
        shopCode: 'stub-shop',
        shopUrl: 'https://www.rakuten.co.jp/stub-shop/',
        genreId: '100227',
        genreName: '水・ソフトドリンク',
        reviewCount: 10,
        reviewAverage: 4.5,
      ),
    );
  }
}

TodayRecommendationBundle _completedBundle(String dateKey) {
  return TodayRecommendationBundle(
    localDateKey: dateKey,
    generatedAt: DateTime(2026, 6, 15, 8),
    entries: List<TodayRecommendationEntry>.generate(
      10,
      (i) => TodayRecommendationEntry(
        item: RakutenSearchItem(
          productId: 'done-$i',
          itemName: '商品$i',
          itemPrice: 1000,
          itemUrl: 'https://item.rakuten.co.jp/stub-shop/item$i/',
          affiliateUrl: '',
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/stub-shop/cabinet/a.jpg',
          shopName: 'Stub Shop',
          shopCode: 'stub-shop',
          genreId: '100227',
          reviewCount: 10,
          reviewAverage: 4.5,
        ),
        section: TodayRecommendationSection.popular,
        decision: TodayRecommendationDecision.addedCandidate,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final limitsOnFlags = resolveMonetizationFlags(
    monetizationEnabled: true,
    adsEnabled: false,
    subscriptionEnabled: true,
    freePlanLimitsEnabled: true,
    proPlanEnabled: true,
  );

  group('TodayRecommendationProvider manual refresh limit', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('successful manual refresh increments refresh count only', () async {
      final repo = TodayRecommendationRepository(prefs);
      final todayKey = RecommendationGenerationCountStore.localDateKey();
      await repo.save(
        TodayRecommendationBundle(
          localDateKey: todayKey,
          generatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          entries: [
            TodayRecommendationEntry(
              item: RakutenSearchItem(
                productId: 'existing-1',
                itemName: '既存商品',
                itemPrice: 1000,
                itemUrl: 'https://item.rakuten.co.jp/stub-shop/item0/',
                affiliateUrl: '',
                imageUrl:
                    'https://thumbnail.image.rakuten.co.jp/@0_mall/stub-shop/cabinet/a.jpg',
                shopName: 'Stub Shop',
                shopCode: 'stub-shop',
                genreId: '100227',
                reviewCount: 10,
                reviewAverage: 4.5,
              ),
              section: TodayRecommendationSection.popular,
            ),
          ],
        ),
      );
      await RecommendationGenerationCountStore.incrementTodayCount();

      final provider = TodayRecommendationProvider(
        repository: repo,
        searchRepository: _StubSearchRepository(),
      );
      addTearDown(provider.dispose);
      provider.reloadBundleFromStorage();

      await provider.regenerateToday(
        profile: const UserProfile(favoriteGenreIds: '100227'),
        managedItems: const [],
        savedShops: const [],
        trigger: 'manual',
        manual: true,
      );
      expect(provider.bundle?.entries.length, 10);
      expect(
        await RecommendationGenerationCountStore.readTodayRefreshCount(),
        1,
      );
      expect(
        await RecommendationGenerationCountStore.readTodayCount(),
        1,
      );
    });

    test('failed manual refresh does not increment refresh count', () async {
      final repo = TodayRecommendationRepository(prefs);
      final todayKey = RecommendationGenerationCountStore.localDateKey();
      await repo.save(
        TodayRecommendationBundle(
          localDateKey: todayKey,
          generatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          entries: [
            TodayRecommendationEntry(
              item: RakutenSearchItem(
                productId: 'existing-1',
                itemName: '既存商品',
                itemPrice: 1000,
                itemUrl: 'https://item.rakuten.co.jp/stub-shop/item0/',
                affiliateUrl: '',
                imageUrl:
                    'https://thumbnail.image.rakuten.co.jp/@0_mall/stub-shop/cabinet/a.jpg',
                shopName: 'Stub Shop',
                shopCode: 'stub-shop',
                genreId: '100227',
                reviewCount: 10,
                reviewAverage: 4.5,
              ),
              section: TodayRecommendationSection.popular,
            ),
          ],
        ),
      );

      final provider = TodayRecommendationProvider(
        repository: repo,
        searchRepository: _StubSearchRepository(
          onSearch: () async => throw Exception('Rakuten API error (500)'),
        ),
      );
      addTearDown(provider.dispose);
      provider.reloadBundleFromStorage();

      await provider.regenerateToday(
        profile: const UserProfile(favoriteGenreIds: '100227'),
        managedItems: const [],
        savedShops: const [],
        trigger: 'manual',
        manual: true,
      );
      expect(
        await RecommendationGenerationCountStore.readTodayRefreshCount(),
        0,
      );
    });

    test('cooldown blocks manual refresh before daily refresh limit', () async {
      final repo = TodayRecommendationRepository(prefs);
      final todayKey = RecommendationGenerationCountStore.localDateKey();
      await repo.save(
        TodayRecommendationBundle(
          localDateKey: todayKey,
          generatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          entries: [
            TodayRecommendationEntry(
              item: RakutenSearchItem(
                productId: 'existing-1',
                itemName: '既存商品',
                itemPrice: 1000,
                itemUrl: 'https://item.rakuten.co.jp/stub-shop/item0/',
                affiliateUrl: '',
                imageUrl:
                    'https://thumbnail.image.rakuten.co.jp/@0_mall/stub-shop/cabinet/a.jpg',
                shopName: 'Stub Shop',
                shopCode: 'stub-shop',
                genreId: '100227',
                reviewCount: 10,
                reviewAverage: 4.5,
              ),
              section: TodayRecommendationSection.popular,
            ),
          ],
        ),
      );

      final provider = TodayRecommendationProvider(
        repository: repo,
        searchRepository: _StubSearchRepository(),
      );
      addTearDown(provider.dispose);
      provider.reloadBundleFromStorage();

      await provider.regenerateToday(
        profile: const UserProfile(favoriteGenreIds: '100227'),
        managedItems: const [],
        savedShops: const [],
        trigger: 'manual',
        manual: true,
      );

      await provider.regenerateToday(
        profile: const UserProfile(favoriteGenreIds: '100227'),
        managedItems: const [],
        savedShops: const [],
        trigger: 'manual',
        manual: true,
      );

      expect(provider.lastGuardReason, contains('manualCooldown'));
      expect(
        await RecommendationGenerationCountStore.readTodayRefreshCount(),
        1,
      );
    });

    test('completed bundle manual refresh is allowed when under refresh limit',
        () async {
      final repo = TodayRecommendationRepository(prefs);
      final todayKey = RecommendationGenerationCountStore.localDateKey();
      await repo.save(_completedBundle(todayKey));

      final provider = TodayRecommendationProvider(
        repository: repo,
        searchRepository: _StubSearchRepository(),
      );
      addTearDown(provider.dispose);
      provider.reloadBundleFromStorage();

      expect(provider.isCompleted, isTrue);

      final blocked = resolveRecommendationRefreshAvailability(
        usedCount: 1,
        flags: limitsOnFlags,
        purchasedPlanOverride: MonetizationPlan.free,
      );
      expect(blocked.allowed, isFalse);

      final allowed = resolveRecommendationRefreshAvailability(
        usedCount: 0,
        flags: limitsOnFlags,
        purchasedPlanOverride: MonetizationPlan.free,
      );
      expect(allowed.allowed, isTrue);
    });
  });
}
