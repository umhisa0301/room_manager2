import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/rakuten_product_search_condition.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/shop_discovery_summary.dart';
import 'package:room_manager2/repository/genre_master_repository.dart';
import 'package:room_manager2/repository/pending_collect_notice_repository.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/repository/room_activity_event_repository.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/screens/shop_discovery_detail_screen.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/rakuten_managed_product_provider.dart';
import 'package:room_manager2/state/room_activity_event_provider.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

RakutenSearchItem _detailItem({
  String productId = 'deep-shop:item001',
  String shopCode = 'deep-shop',
  String itemUrl = 'https://item.rakuten.co.jp/deep-shop/item001/',
}) {
  return RakutenSearchItem(
    productId: productId,
    itemName: '水筒 500ml',
    itemPrice: 1980,
    itemUrl: itemUrl,
    affiliateUrl: '',
    imageUrl:
        'https://thumbnail.image.rakuten.co.jp/@0_mall/$shopCode/cabinet/a.jpg',
    shopName: '水筒ショップ',
    shopCode: shopCode,
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    genreId: '100227',
    genreName: '水・ソフトドリンク',
  );
}

ShopDiscoverySummary _summary({String shopCode = 'deep-shop'}) {
  return ShopDiscoverySummary(
    shopKey: shopCode,
    shopName: '水筒ショップ',
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    hitItemCount: 2,
    maxReviewCount: 100,
    avgReviewAverage: 4.5,
    discoveryScore: 10,
    representativeItems: const [],
  );
}

class _StubSearchRepository extends RakutenSearchRepository {
  _StubSearchRepository(this._items) : super(apiService: RakutenApiService());

  final List<RakutenSearchItem> _items;

  @override
  Future<List<RakutenSearchItem>> search({
    required RakutenProductSearchCondition condition,
    int maxPages = 4,
    int startPage = 1,
    RakutenSearchPurpose searchPurpose = RakutenSearchPurpose.normal,
    String fetchScreen = 'productSearch',
  }) async {
    return List<RakutenSearchItem>.from(_items);
  }
}

Widget _wrap({
  required Widget child,
  required ProductCatalogRepository catalog,
  required RakutenSearchRepository searchRepository,
  required SharedPreferences prefs,
}) {
  return MultiProvider(
    providers: [
      Provider<ProductCatalogRepository>.value(value: catalog),
      Provider<RakutenSearchRepository>.value(value: searchRepository),
      Provider<GenreMasterRepository>(
        create: (_) => GenreMasterRepository(prefs: prefs),
      ),
      ChangeNotifierProvider(
        create: (_) => SavedShopProvider(
          repository: SavedShopRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => RoomActivityEventProvider(
          repository: RoomActivityEventRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => RakutenManagedProductProvider(
          repository: RakutenManagedProductRepository(prefs),
          pendingCollectNoticeRepository: PendingCollectNoticeRepository(prefs),
          activityEventProvider: context.read<RoomActivityEventProvider>(),
        ),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShopDiscoveryDetailScreen catalog upsert', () {
    late SharedPreferences prefs;
    late ProductCatalogRepository catalog;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      catalog = ProductCatalogRepository(prefs);
      await catalog.clear();
    });

    testWidgets('initial items が ProductCatalog に upsert される', (tester) async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;

      await tester.pumpWidget(
        _wrap(
          prefs: prefs,
          catalog: catalog,
          searchRepository: _StubSearchRepository(const []),
          child: ShopDiscoveryDetailScreen(
            summary: _summary(),
            items: [
              _detailItem(),
              _detailItem(
                productId: 'deep-shop:item002',
                itemUrl: 'https://item.rakuten.co.jp/deep-shop/item002/',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(catalog.count(), 2);
    });

    testWidgets('_loadItemsFromShopCode 結果が ProductCatalog に upsert される', (
      tester,
    ) async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;

      await tester.pumpWidget(
        _wrap(
          prefs: prefs,
          catalog: catalog,
          searchRepository: _StubSearchRepository([
            _detailItem(),
            _detailItem(
              productId: 'deep-shop:item002',
              itemUrl: 'https://item.rakuten.co.jp/deep-shop/item002/',
            ),
          ]),
          child: ShopDiscoveryDetailScreen(
            summary: _summary(),
            items: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(catalog.count(), 2);
    });

    testWidgets('build 再実行で重複 upsert しない', (tester) async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;

      await tester.pumpWidget(
        _wrap(
          prefs: prefs,
          catalog: catalog,
          searchRepository: _StubSearchRepository(const []),
          child: ShopDiscoveryDetailScreen(
            summary: _summary(),
            items: [_detailItem()],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(catalog.count(), 1);

      await tester.pump();
      await tester.pumpAndSettle();
      expect(catalog.count(), 1);
    });
  });

  group('ShopDiscoveryDetailScreen save shop', () {
    testWidgets('未保存時に「このショップを保存」が表示されタップで保存される', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final catalog = ProductCatalogRepository(prefs);
      await catalog.clear();

      await tester.pumpWidget(
        _wrap(
          prefs: prefs,
          catalog: catalog,
          searchRepository: _StubSearchRepository(const []),
          child: ShopDiscoveryDetailScreen(
            summary: _summary(shopCode: 'the-charme'),
            items: [_detailItem(shopCode: 'the-charme')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final savedProvider = tester
          .element(find.byType(ShopDiscoveryDetailScreen))
          .read<SavedShopProvider>();

      expect(find.text('このショップを保存'), findsOneWidget);
      expect(savedProvider.isSaved('the-charme'), isFalse);

      await tester.tap(find.byKey(const Key('shop_discovery_detail_save_shop')));
      await tester.pumpAndSettle();

      expect(savedProvider.isSaved('the-charme'), isTrue);
      expect(find.text('保存済み'), findsOneWidget);
      expect(find.text('このショップを保存'), findsNothing);
      expect(savedProvider.shops.where((e) => e.shopId == 'the-charme').length, 1);
    });

    testWidgets('保存済みの場合は「保存済み」表示で重複保存しない', (tester) async {
      SharedPreferences.setMockInitialValues({
        'saved_shops_v1': jsonEncode([
          {
            'shopId': 'the-charme',
            'shopName': '水筒ショップ',
            'shopUrl': 'https://www.rakuten.co.jp/the-charme/',
            'savedAt': '2026-06-06T00:00:00.000',
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final catalog = ProductCatalogRepository(prefs);
      await catalog.clear();

      await tester.pumpWidget(
        _wrap(
          prefs: prefs,
          catalog: catalog,
          searchRepository: _StubSearchRepository(const []),
          child: ShopDiscoveryDetailScreen(
            summary: _summary(shopCode: 'the-charme'),
            items: [_detailItem(shopCode: 'the-charme')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final savedProvider = tester
          .element(find.byType(ShopDiscoveryDetailScreen))
          .read<SavedShopProvider>();

      expect(find.text('保存済み'), findsOneWidget);
      expect(find.text('このショップを保存'), findsNothing);
      expect(savedProvider.isSaved('the-charme'), isTrue);
      expect(savedProvider.shops.where((e) => e.shopId == 'the-charme').length, 1);
      await tester.tap(find.byKey(const Key('shop_discovery_detail_save_shop')));
      await tester.pumpAndSettle();
      expect(savedProvider.shops.where((e) => e.shopId == 'the-charme').length, 1);
    });
  });
}
