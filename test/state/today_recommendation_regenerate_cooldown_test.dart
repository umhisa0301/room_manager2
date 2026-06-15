import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_product_search_condition.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/user_profile.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/repository/today_recommendation_repository.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/today_recommendation_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubSearchRepository extends RakutenSearchRepository {
  _StubSearchRepository() : super(apiService: RakutenApiService());

  @override
  Future<List<RakutenSearchItem>> search({
    required RakutenProductSearchCondition condition,
    int maxPages = 4,
    int startPage = 1,
    RakutenSearchPurpose searchPurpose = RakutenSearchPurpose.normal,
    String fetchScreen = 'productSearch',
  }) async {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TodayRecommendationProvider manual regenerate cooldown', () {
    late SharedPreferences prefs;
    late TodayRecommendationProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      provider = TodayRecommendationProvider(
        repository: TodayRecommendationRepository(prefs),
        searchRepository: _StubSearchRepository(),
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('manual regenerate blocked immediately after generation', () async {
      await provider.regenerateToday(
        profile: const UserProfile(favoriteGenreIds: '100227'),
        managedItems: const [],
        savedShops: const [],
        trigger: 'manual',
        manual: true,
      );

      expect(provider.manualRegenerateCooldownStatus().canRegenerate, isFalse);

      await provider.regenerateToday(
        profile: const UserProfile(favoriteGenreIds: '100227'),
        managedItems: const [],
        savedShops: const [],
        trigger: 'manual',
        manual: true,
      );

      expect(provider.lastGuardReason, contains('manualCooldown'));
    });
  });
}
