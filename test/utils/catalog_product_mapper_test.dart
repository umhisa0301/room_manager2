import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/services/genre_master_service.dart';
import 'package:room_manager2/utils/catalog_product_keys.dart';
import 'package:room_manager2/services/product_catalog_shop_aggregator.dart';
import 'package:room_manager2/utils/catalog_product_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

RakutenSearchItem _searchItem({
  String productId = 'shop:item001',
  String itemName = '木のおもちゃ',
  int itemPrice = 1980,
  String itemUrl = 'https://item.rakuten.co.jp/shop/item001/',
  String shopCode = 'shop',
}) {
  return RakutenSearchItem(
    productId: productId,
    itemName: itemName,
    itemPrice: itemPrice,
    itemUrl: itemUrl,
    affiliateUrl: '',
    imageUrl:
        'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
    shopName: 'テストショップ',
    shopCode: shopCode,
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    genreId: '100',
    genreName: 'おもちゃ',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveCatalogGenreName', () {
    setUpAll(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => '.',
      );
      await GenreMasterService.instance.load();
    });

    test('genreName があるときはそのまま', () {
      expect(
        resolveCatalogGenreName(genreId: '100000', genreName: '既存名'),
        '既存名',
      );
    });

    test('genreId のみのとき GenreMaster で補完', () {
      if (!GenreMasterService.instance.isLoaded) return;
      final resolved = resolveCatalogGenreName(
        genreId: '100000',
        genreName: '',
      );
      expect(resolved, '百貨店・総合通販・ギフト');
    });

    test('catalogProductFromSearchItem が genreName を補完して保存する', () async {
      if (!GenreMasterService.instance.isLoaded) return;
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ProductCatalogRepository(prefs);
      await repo.clear();
      final item = RakutenSearchItem(
        productId: 'shop:genre001',
        itemName: 'テスト商品',
        itemPrice: 1000,
        itemUrl: 'https://item.rakuten.co.jp/shop/genre001/',
        affiliateUrl: '',
        imageUrl:
            'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
        shopName: 'テストショップ',
        shopCode: 'shop',
        genreId: '100000',
        genreName: '',
      );
      await upsertCatalogFromSearchItems(repo, [item]);
      final stored = repo.getByCanonicalId('shop:genre001');
      expect(stored?.genreName, '百貨店・総合通販・ギフト');
    });
  });

  group('catalogProductFromSearchItem', () {
    test('RakutenSearchItem から CatalogProduct に変換できる', () {
      final product = catalogProductFromSearchItem(_searchItem());
      expect(product.canonicalId, 'shop:item001');
      expect(product.itemName, '木のおもちゃ');
      expect(product.itemPrice, 1980);
      expect(product.normalizedItemUrl, isNotEmpty);
      expect(product.genreId, '100');
      expect(product.genreName, 'おもちゃ');
    });

    test('source=search / sourceTrust=high になる', () {
      final product = catalogProductFromSearchItem(_searchItem());
      expect(product.source, CatalogProductSource.search);
      expect(product.sourceTrust, CatalogProductSourceTrust.high);
    });

    test('alias が生成される', () {
      final product = catalogProductFromSearchItem(_searchItem());
      expect(product.aliases, contains('shop:item001'));
      expect(
        product.aliases,
        contains(
          CatalogProductKeys.normalizeItemUrl(
            'https://item.rakuten.co.jp/shop/item001/',
          ),
        ),
      );
    });

    test('安全 NG は qualityStatus.safe=false になる', () {
      final product = catalogProductFromSearchItem(
        _searchItem(itemName: '大人のおもちゃ 初心者向け'),
      );
      expect(product.qualityStatus.safe, isFalse);
    });

    test('画像なし・価格なしは保存可能で qualityStatus に反映される', () {
      final product = catalogProductFromSearchItem(
        _searchItem(itemPrice: 0, itemName: '木のおもちゃ'),
      );
      expect(product.isSavable, isTrue);
      expect(product.qualityStatus.hasPrice, isFalse);
      expect(product.qualityStatus.safe, isTrue);
    });
  });

  group('upsertCatalogFromSearchItems', () {
    late SharedPreferences prefs;
    late ProductCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = ProductCatalogRepository(prefs);
      await repo.clear();
    });

    test('kProductCatalogEnabled=false のとき no-op', () async {
      if (ProductCatalogConfig.kProductCatalogEnabled) return;
      final summary = await upsertCatalogFromSearchItems(
        repo,
        [_searchItem()],
      );
      expect(summary, const ProductCatalogUpsertSummary.skipped());
      expect(repo.count(), 0);
    });

    test('安全 NG は upsert 対象から除外される', () async {
      final safe = catalogProductFromSearchItem(_searchItem());
      final unsafe = catalogProductFromSearchItem(
        _searchItem(itemName: '大人のおもちゃ 初心者向け'),
      );
      expect(unsafe.qualityStatus.safe, isFalse);
      final products = [safe, unsafe]
          .where((p) => p.isSavable && p.qualityStatus.safe)
          .toList();
      expect(products.length, 1);
      await repo.upsertAll(products);
      expect(repo.count(), 1);
      expect(repo.findByAlias('shop:item001')?.canonicalId, 'shop:item001');
    });

    test(
      'kProductCatalogEnabled=true のとき upsertAll が永続化する',
      () async {
        if (!ProductCatalogConfig.kProductCatalogEnabled) return;
        final summary = await upsertCatalogFromSearchItems(
          repo,
          [_searchItem()],
          catalogMode: 'productSearch',
        );
        expect(summary.upserted, greaterThan(0));
        expect(repo.count(), 1);
      },
    );

    test('変換商品を upsert すると alias で検索できる', () async {
      final product = catalogProductFromSearchItem(_searchItem());
      await repo.upsertAll([product]);
      final normUrl = CatalogProductKeys.normalizeItemUrl(
        'https://item.rakuten.co.jp/shop/item001/',
      );
      expect(repo.findByAlias(normUrl)?.canonicalId, 'shop:item001');
      expect(repo.findByAlias('shop:item001')?.canonicalId, 'shop:item001');
    });

    test('catalogUpsertModeLabelForSearchModeTag がモード別ラベルを返す', () {
      expect(catalogUpsertModeLabelForSearchModeTag('product'), 'productSearch');
      expect(catalogUpsertModeLabelForSearchModeTag('genre'), 'genreSearch');
      expect(
        catalogUpsertModeLabelForSearchModeTag('savedShop'),
        'savedShopSearch',
      );
    });
  });

  group('upsertCatalogFromShopDiscoveryItems', () {
    late SharedPreferences prefs;
    late ProductCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = ProductCatalogRepository(prefs);
      await repo.clear();
    });

    test('kProductCatalogEnabled=false のとき no-op', () async {
      if (ProductCatalogConfig.kProductCatalogEnabled) return;
      final summary = await upsertCatalogFromShopDiscoveryItems(
        repo,
        [_searchItem()],
      );
      expect(summary, const ProductCatalogUpsertSummary.skipped());
      expect(repo.count(), 0);
    });

    test('source=shopDiscovery / sourceTrust=medium になる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await upsertCatalogFromShopDiscoveryItems(repo, [_searchItem()]);
      final stored = repo.getByCanonicalId('shop:item001');
      expect(stored?.source, CatalogProductSource.shopDiscovery);
      expect(stored?.sourceTrust, CatalogProductSourceTrust.medium);
    });

    test('安全 NG は upsert 対象から除外される', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final summary = await upsertCatalogFromShopDiscoveryItems(
        repo,
        [
          _searchItem(),
          _searchItem(
            productId: 'shop:unsafe',
            itemName: '大人のおもちゃ 初心者向け',
          ),
        ],
      );
      expect(summary.qualityNg, 1);
      expect(summary.upserted, 1);
      expect(repo.count(), 1);
    });

    test('canonicalId 不可商品は保存しない', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final summary = await upsertCatalogFromShopDiscoveryItems(
        repo,
        [
          _searchItem(),
          RakutenSearchItem(
            productId: '',
            itemName: 'URL不正',
            itemPrice: 1000,
            itemUrl: '',
            affiliateUrl: '',
            imageUrl:
                'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
            shopName: 'テストショップ',
            shopCode: 'shop',
          ),
        ],
      );
      expect(summary.upserted, 1);
      expect(repo.count(), 1);
    });

    test('genreId のみのとき GenreMaster で genreName を補完して保存する', () async {
      if (!GenreMasterService.instance.isLoaded) return;
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final item = RakutenSearchItem(
        productId: 'shop:disc001',
        itemName: 'テスト商品',
        itemPrice: 1000,
        itemUrl: 'https://item.rakuten.co.jp/shop/disc001/',
        affiliateUrl: '',
        imageUrl:
            'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
        shopName: 'テストショップ',
        shopCode: 'shop',
        genreId: '100000',
        genreName: '',
      );
      await upsertCatalogFromShopDiscoveryItems(repo, [item]);
      final stored = repo.getByCanonicalId('shop:disc001');
      expect(stored?.genreName, '百貨店・総合通販・ギフト');
    });

    test('同一 shopCode 複数商品を保存すると aggregator の itemCount が 2 以上になる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await upsertCatalogFromShopDiscoveryItems(
        repo,
        [
          _searchItem(productId: 'shop:item001'),
          _searchItem(
            productId: 'shop:item002',
            itemUrl: 'https://item.rakuten.co.jp/shop/item002/',
          ),
        ],
      );
      final result = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(result.candidates.single.shopCode, 'shop');
      expect(result.candidates.single.itemCount, 2);
    });
  });

  group('upsertCatalogFromShopDiscoveryDetailItems', () {
    late SharedPreferences prefs;
    late ProductCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = ProductCatalogRepository(prefs);
      await repo.clear();
    });

    test('initialItems / medium trust で upsert される', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final summary = await upsertCatalogFromShopDiscoveryDetailItems(
        repo,
        [_searchItem()],
        shopCode: 'shop',
        upsertSource: 'initialItems',
        sourceTrust: CatalogProductSourceTrust.medium,
      );
      expect(summary.upserted, 1);
      final stored = repo.getByCanonicalId('shop:item001');
      expect(stored?.source, CatalogProductSource.shopDiscovery);
      expect(stored?.sourceTrust, CatalogProductSourceTrust.medium);
    });

    test('loadedByShopCode / high trust で upsert される', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await upsertCatalogFromShopDiscoveryDetailItems(
        repo,
        [_searchItem()],
        shopCode: 'shop',
        upsertSource: 'loadedByShopCode',
        sourceTrust: CatalogProductSourceTrust.high,
      );
      final stored = repo.getByCanonicalId('shop:item001');
      expect(stored?.sourceTrust, CatalogProductSourceTrust.high);
    });

    test('unsafe / canonicalId不可は保存されない', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final summary = await upsertCatalogFromShopDiscoveryDetailItems(
        repo,
        [
          _searchItem(),
          _searchItem(
            productId: 'shop:unsafe',
            itemName: '大人のおもちゃ 初心者向け',
          ),
          RakutenSearchItem(
            productId: '',
            itemName: 'URL不正',
            itemPrice: 1000,
            itemUrl: '',
            affiliateUrl: '',
            imageUrl:
                'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
            shopName: 'テストショップ',
            shopCode: 'shop',
          ),
        ],
        shopCode: 'shop',
        upsertSource: 'initialItems',
      );
      expect(summary.qualityNg, 1);
      expect(summary.upserted, 1);
      expect(repo.count(), 1);
    });

    test('同一 shopCode 複数商品で itemCount2Plus になる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await upsertCatalogFromShopDiscoveryDetailItems(
        repo,
        [
          _searchItem(productId: 'shop:item001'),
          _searchItem(
            productId: 'shop:item002',
            itemUrl: 'https://item.rakuten.co.jp/shop/item002/',
          ),
        ],
        shopCode: 'shop',
        upsertSource: 'initialItems',
      );
      final result = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(result.candidates.single.itemCount, 2);
      expect(
        repo.getAll().where((p) => p.shopCode.trim() == 'shop').length,
        2,
      );
    });

    test('別 canonicalId なら productCountForShop=2 / inserted+updated 内訳', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final summary = await upsertCatalogFromShopDiscoveryDetailItems(
        repo,
        [
          _searchItem(productId: 'shop:item001'),
          _searchItem(
            productId: 'shop:item002',
            itemUrl: 'https://item.rakuten.co.jp/shop/item002/',
          ),
        ],
        shopCode: 'shop',
        upsertSource: 'initialItems',
      );
      expect(summary.inserted, 2);
      expect(summary.updated, 0);
      expect(summary.upserted, 2);
      expect(
        repo.getAll().where((p) => p.shopCode.trim() == 'shop').length,
        2,
      );
      final aggregate = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(aggregate.candidates.single.sourceProductIds.length, 2);
    });

    test('同一 canonicalId 2件は merge で productCountForShop=1', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final summary = await upsertCatalogFromShopDiscoveryDetailItems(
        repo,
        [
          _searchItem(
            productId: 'takeya-tea:item001',
            shopCode: 'takeya-tea',
            itemUrl: 'https://item.rakuten.co.jp/takeya-tea/item001/',
          ),
          _searchItem(
            productId: 'takeya-tea:item001',
            shopCode: 'takeya-tea',
            itemName: '別名表示の同一商品',
            itemUrl: 'https://item.rakuten.co.jp/takeya-tea/item001/',
          ),
        ],
        shopCode: 'takeya-tea',
        upsertSource: 'initialItems',
      );
      expect(summary.inserted, 1);
      expect(summary.updated, 1);
      expect(summary.upserted, 2);
      expect(
        repo.getAll().where((p) => p.shopCode.trim() == 'takeya-tea').length,
        1,
      );
      final traces = buildShopDiscoveryDetailCatalogItemTraces(
        items: [
          _searchItem(
            productId: 'takeya-tea:item001',
            shopCode: 'takeya-tea',
          ),
          _searchItem(
            productId: 'takeya-tea:item001',
            shopCode: 'takeya-tea',
            itemName: '別名表示の同一商品',
          ),
        ],
        shopCode: 'takeya-tea',
        repository: repo,
      );
      expect(traces.length, 2);
      expect(traces[0].saved, isTrue);
      expect(traces[1].reason, 'canonicalDuplicate');
      expect(traces[1].saved, isFalse);
    });

    test('既存商品への同一 canonicalId 2件は inserted=0 updated=2', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll([
        catalogProductFromSearchItem(
          _searchItem(
            productId: 'takeya-tea:existing',
            shopCode: 'takeya-tea',
            itemUrl: 'https://item.rakuten.co.jp/takeya-tea/existing/',
          ),
          source: CatalogProductSource.shopDiscovery,
          sourceTrust: CatalogProductSourceTrust.medium,
        ),
      ]);
      final summary = await upsertCatalogFromShopDiscoveryDetailItems(
        repo,
        [
          _searchItem(
            productId: 'takeya-tea:existing',
            shopCode: 'takeya-tea',
          ),
          _searchItem(
            productId: 'takeya-tea:existing',
            shopCode: 'takeya-tea',
            itemName: '更新2',
          ),
        ],
        shopCode: 'takeya-tea',
        upsertSource: 'initialItems',
      );
      expect(summary.inserted, 0);
      expect(summary.updated, 2);
      expect(
        repo.getAll().where((p) => p.shopCode.trim() == 'takeya-tea').length,
        1,
      );
    });
  });

  group('buildShopDiscoveryDetailCatalogItemTraces', () {
    late ProductCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = ProductCatalogRepository(prefs);
      await repo.clear();
    });

    test('同一 productId 2件目は canonicalDuplicate', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await upsertCatalogFromSearchItems(
        repo,
        [_searchItem(productId: 'shop:dup')],
        source: CatalogProductSource.shopDiscovery,
        sourceTrust: CatalogProductSourceTrust.medium,
      );
      final traces = buildShopDiscoveryDetailCatalogItemTraces(
        items: [
          _searchItem(productId: 'shop:dup'),
          _searchItem(productId: 'shop:dup', itemName: '同一商品コピー'),
        ],
        shopCode: 'shop',
        repository: repo,
      );
      expect(traces[1].reason, 'canonicalDuplicate');
    });
  });

  group('ShopDiscoveryDetailCatalogUpsertGuard', () {
    test('同一 signature では2回目 upsert しない', () {
      final guard = ShopDiscoveryDetailCatalogUpsertGuard();
      final items = [_searchItem(), _searchItem(productId: 'shop:item002')];
      expect(guard.shouldUpsertInitial(items), isTrue);
      guard.markInitialUpserted(items);
      expect(guard.shouldUpsertInitial(items), isFalse);
    });

    test('initial / loaded は別管理', () {
      final guard = ShopDiscoveryDetailCatalogUpsertGuard();
      final initial = [_searchItem()];
      final loaded = [
        _searchItem(productId: 'shop:item002'),
      ];
      expect(guard.shouldUpsertInitial(initial), isTrue);
      guard.markInitialUpserted(initial);
      expect(guard.shouldUpsertLoaded(loaded), isTrue);
    });
  });
}
