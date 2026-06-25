import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_product_search_condition.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/room_recommendation_profile.dart';
import 'package:room_manager2/models/user_profile.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/repository/today_recommendation_repository.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/today_recommendation_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

RakutenSearchItem _stubItem(int index) => RakutenSearchItem(
      productId: 'stub-shop:item$index',
      itemName: 'キッチン 便利 時短 商品$index',
      itemPrice: 1500 + index * 100,
      itemUrl: 'https://item.rakuten.co.jp/stub-shop/item$index/',
      affiliateUrl: '',
      imageUrl:
          'https://thumbnail.image.rakuten.co.jp/@0_mall/stub-shop/cabinet/a.jpg',
      shopName: 'Stub Shop $index',
      shopCode: 'stub-shop-$index',
      shopUrl: 'https://www.rakuten.co.jp/stub-shop/',
      genreId: '100227',
      genreName: 'キッチン',
      reviewCount: 20 + index,
      reviewAverage: 4.2,
    );

class _CountingProfileSearchRepository extends RakutenSearchRepository {
  _CountingProfileSearchRepository({
    this.failWith429AfterFirst = false,
    this.itemsPerCall = 5,
  }) : super(apiService: RakutenApiService());

  final bool failWith429AfterFirst;
  final int itemsPerCall;
  int callCount = 0;

  @override
  Future<List<RakutenSearchItem>> search({
    required RakutenProductSearchCondition condition,
    int maxPages = 4,
    int startPage = 1,
    RakutenSearchPurpose searchPurpose = RakutenSearchPurpose.normal,
    String fetchScreen = 'productSearch',
  }) async {
    callCount += 1;
    if (failWith429AfterFirst && callCount > 1) {
      throw Exception('(429) allowed requests has been exceeded');
    }
    return List<RakutenSearchItem>.generate(itemsPerCall, _stubItem);
  }
}

RoomRecommendationProfile _diagnosedProfile() => RoomRecommendationProfile(
      primaryTypeId: 'life_convenience',
      interestCategoryIds: const ['kitchen', 'gift', 'pet', 'gadget_appliance'],
      priorityRuleIds: const ['review_trust', 'practical_lifehack'],
      searchKeywordPresets: const [
        '時短 キッチン',
        '便利 ギフト',
        'レビュー ペット',
        '家電 ガジェット',
        '暮らし 収納',
      ],
      diagnosedAt: DateTime(2026, 6, 26),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TodayRecommendationProvider profile early stop', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('3件候補が集まった時点で残り検索クエリを実行しない', () async {
      final searchRepo = _CountingProfileSearchRepository();
      final provider = TodayRecommendationProvider(
        repository: TodayRecommendationRepository(prefs),
        searchRepository: searchRepo,
      );

      await provider.regenerateToday(
        profile: const UserProfile(),
        managedItems: const [],
        savedShops: const [],
        recommendationProfile: _diagnosedProfile(),
        trigger: 'test',
      );

      expect(searchRepo.callCount, 1);
      expect(provider.bundle?.entries.length, 3);
    });

    test('429発生時、候補が3件以上あれば生成完了できる', () async {
      final searchRepo = _CountingProfileSearchRepository(
        failWith429AfterFirst: true,
        itemsPerCall: 8,
      );
      final provider = TodayRecommendationProvider(
        repository: TodayRecommendationRepository(prefs),
        searchRepository: searchRepo,
      );

      await provider.regenerateToday(
        profile: const UserProfile(),
        managedItems: const [],
        savedShops: const [],
        recommendationProfile: _diagnosedProfile(),
        trigger: 'test',
      );

      expect(searchRepo.callCount, 1);
      expect(provider.bundle?.entries.length, 3);
      expect(provider.errorMessage, isNull);
    });

    test('一部クエリ失敗でも取得済み候補で表示できる', () async {
      final searchRepo = _CountingProfileSearchRepository(
        failWith429AfterFirst: true,
        itemsPerCall: 1,
      );
      final provider = TodayRecommendationProvider(
        repository: TodayRecommendationRepository(prefs),
        searchRepository: searchRepo,
      );

      await provider.regenerateToday(
        profile: const UserProfile(),
        managedItems: const [],
        savedShops: const [],
        recommendationProfile: _diagnosedProfile(),
        trigger: 'test',
      );

      expect(provider.bundle, isNotNull);
      expect(provider.bundle!.entries, isNotEmpty);
      expect(searchRepo.callCount, 2);
    });
  });
}
