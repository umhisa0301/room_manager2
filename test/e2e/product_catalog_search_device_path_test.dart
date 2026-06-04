import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/models/rakuten_product_search_condition.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/rakuten_search_provider.dart';
import 'package:room_manager2/utils/catalog_product_keys.dart';
import 'package:room_manager2/utils/catalog_product_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

RakutenSearchItem _sampleItem({
  String id = 'shop:item001',
  String itemUrl = 'https://item.rakuten.co.jp/shop/item001/',
}) {
  return RakutenSearchItem(
    productId: id,
    itemName: '水筒 500ml',
    itemPrice: 1980,
    itemUrl: itemUrl,
    affiliateUrl: '',
    imageUrl:
        'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
    shopName: 'テストショップ',
    shopCode: 'shop',
    genreId: '100227',
    genreName: '水・ソフトドリンク',
  );
}

class _StubManagedSearchRepository extends RakutenSearchRepository {
  _StubManagedSearchRepository(this._items)
    : super(apiService: RakutenApiService());

  final List<RakutenSearchItem> _items;

  @override
  Future<RakutenKeywordSearchRepositoryResult> searchKeywordWithManagedExclusion({
    required RakutenProductSearchCondition condition,
    required Set<String> excludeRegisteredProductIds,
    Set<String> excludeCandidateProductIds = const {},
    Set<String> excludeDoneProductIds = const {},
    Set<String> excludeSavedShopCodes = const {},
    String fetchMode = 'product',
    int targetVisibleCount =
        RakutenSearchRepository.keywordManagedExclusionTargetVisibleCount,
    int hitsPerPage = 30,
    int startPage = 1,
    int maxFetchPages = RakutenSearchRepository.keywordManagedExclusionMaxApiPages,
    Duration interPageDelay = const Duration(milliseconds: 220),
    bool applyDisplayQualityGate = true,
  }) async {
    return RakutenKeywordSearchRepositoryResult(
      items: List<RakutenSearchItem>.from(_items),
      receivedAnyItemFromApi: _items.isNotEmpty,
      targetVisibleCount: targetVisibleCount,
      apiPagesFetched: 1,
      stopReason: RakutenKeywordSearchStopReason.reachedTarget,
    );
  }
}

/// 実機と同一コードパス（Provider → mapper → repository）の保存・再起動確認。
///
/// 実行例:
/// `flutter test --dart-define=PRODUCT_CATALOG_ENABLED=true --dart-define=CATALOG_AUDIT_LOGS=true test/e2e/product_catalog_search_device_path_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Product catalog search device path', () {
    late SharedPreferences prefs;
    late ProductCatalogRepository catalog;
    late RakutenSearchProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      catalog = ProductCatalogRepository(prefs);
      await catalog.clear();
      provider = RakutenSearchProvider(
        repository: _StubManagedSearchRepository(const []),
        productCatalogRepository: catalog,
      );
    });

    test('kProductCatalogEnabled=false では upsert skipped', () async {
      if (ProductCatalogConfig.kProductCatalogEnabled) return;
      final summary = await upsertCatalogFromSearchItems(
        catalog,
        [_sampleItem()],
        catalogMode: 'productSearch',
      );
      expect(summary, const ProductCatalogUpsertSummary.skipped());
      expect(catalog.count(), 0);
    });

    test('商品名検索 productSearch で upsert し永続化する', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;

      final items = [
        _sampleItem(id: 'shop:a'),
        _sampleItem(id: 'shop:b', itemUrl: 'https://item.rakuten.co.jp/shop/b/'),
      ];
      provider = RakutenSearchProvider(
        repository: _StubManagedSearchRepository(items),
        productCatalogRepository: catalog,
      );

      final sessionId = provider.beginSearchSession(modeTag: 'product');
      await provider.searchWithCondition(
        const RakutenProductSearchCondition(keyword: '水筒').normalized(),
        excludeRegisteredProductIds: const {},
        sessionId: sessionId,
        modeTag: 'product',
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(provider.status, RakutenSearchStatus.success);
      expect(provider.results.length, 2);
      expect(provider.results[0].productId, 'shop:a');
      expect(provider.results[1].productId, 'shop:b');

      expect(catalog.count(), greaterThan(0));
      final sample = provider.results.first;
      final canonicalId = CatalogProductKeys.resolveCanonicalId(
        productId: sample.productId,
        itemUrl: sample.itemUrl,
      );
      expect(canonicalId, isNotNull);

      final stored = catalog.getByCanonicalId(canonicalId!);
      expect(stored, isNotNull);
      expect(stored!.source, CatalogProductSource.search);
      expect(stored.sourceTrust, CatalogProductSourceTrust.high);
      expect(stored.qualityStatus.safe, isTrue);

      final normUrl = CatalogProductKeys.normalizeItemUrl(sample.itemUrl);
      expect(catalog.findByAlias(normUrl), isNotNull);
      expect(catalog.findByAlias(sample.productId), isNotNull);

      final reloaded = ProductCatalogRepository(prefs);
      expect(reloaded.count(), catalog.count());
      expect(
        reloaded.getByCanonicalId(canonicalId)?.itemName,
        stored.itemName,
      );
    });

    test('shopDiscovery でも ProductCatalog upsert が実行される', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;

      provider = RakutenSearchProvider(
        repository: _StubManagedSearchRepository([_sampleItem()]),
        productCatalogRepository: catalog,
      );
      final sessionId = provider.beginSearchSession(modeTag: 'shopDiscovery');
      await provider.searchWithCondition(
        const RakutenProductSearchCondition(keyword: '水筒').normalized(),
        excludeRegisteredProductIds: const {},
        sessionId: sessionId,
        modeTag: 'shopDiscovery',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(provider.status, RakutenSearchStatus.success);
      expect(catalog.count(), 1);
      expect(
        catalog.getByCanonicalId('shop:item001')?.source,
        CatalogProductSource.shopDiscovery,
      );
    });
  });
}
