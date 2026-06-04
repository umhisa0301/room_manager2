import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/models/rakuten_product_search_condition.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/rakuten_search_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

RakutenSearchItem _sampleItem({String id = 'shop:item001'}) {
  return RakutenSearchItem(
    productId: id,
    itemName: '木のおもちゃ',
    itemPrice: 1980,
    itemUrl: 'https://item.rakuten.co.jp/shop/item001/',
    affiliateUrl: '',
    imageUrl:
        'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
    shopName: 'テストショップ',
    shopCode: 'shop',
    genreId: '100',
    genreName: 'おもちゃ',
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
    int targetVisibleCount = RakutenSearchRepository.keywordManagedExclusionTargetVisibleCount,
    int hitsPerPage = 30,
    int startPage = 1,
    int maxFetchPages = RakutenSearchRepository.keywordManagedExclusionMaxApiPages,
    Duration interPageDelay = const Duration(milliseconds: 220),
    bool applyDisplayQualityGate = true,
  }) async {
    return RakutenKeywordSearchRepositoryResult(
      items: List<RakutenSearchItem>.from(_items),
      receivedAnyItemFromApi: _items.isNotEmpty,
      targetVisibleCount: 100,
      apiPagesFetched: 1,
      stopReason: RakutenKeywordSearchStopReason.reachedTarget,
    );
  }
}

class _ThrowingProductCatalogRepository extends ProductCatalogRepository {
  _ThrowingProductCatalogRepository(super.prefs);

  @override
  Future<ProductCatalogUpsertBatchResult> upsertAll(
    Iterable<CatalogProduct> incomingProducts,
  ) async {
    throw StateError('catalog upsert failed');
  }
}

void main() {
  Future<ProductCatalogRepository> newCatalogRepo() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = ProductCatalogRepository(prefs);
    await repo.clear();
    return repo;
  }

  group('RakutenSearchProvider product catalog', () {
    test('検索成功後も結果件数・並び順は API リストのまま', () async {
      final items = [_sampleItem(id: 'shop:a'), _sampleItem(id: 'shop:b')];
      final catalog = await newCatalogRepo();
      final provider = RakutenSearchProvider(
        repository: _StubManagedSearchRepository(items),
        productCatalogRepository: catalog,
      );
      final sessionId = provider.beginSearchSession(modeTag: 'product');
      await provider.searchWithCondition(
        const RakutenProductSearchCondition(keyword: 'おもちゃ').normalized(),
        excludeRegisteredProductIds: const {},
        sessionId: sessionId,
        modeTag: 'product',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(provider.status, RakutenSearchStatus.success);
      expect(provider.results.length, 2);
      expect(provider.results[0].productId, 'shop:a');
      expect(provider.results[1].productId, 'shop:b');
    });

    test('カタログ upsert 失敗でも検索は成功のまま', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final catalog = _ThrowingProductCatalogRepository(prefs);
      final provider = RakutenSearchProvider(
        repository: _StubManagedSearchRepository([_sampleItem()]),
        productCatalogRepository: catalog,
      );
      final sessionId = provider.beginSearchSession(modeTag: 'genre');
      await provider.searchWithCondition(
        const RakutenProductSearchCondition(
          keyword: 'おもちゃ',
          genreId: '100',
        ).normalized(),
        excludeRegisteredProductIds: const {},
        sessionId: sessionId,
        modeTag: 'genre',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(provider.status, RakutenSearchStatus.success);
      expect(provider.results.length, 1);
    });

    test('shopDiscovery 検索成功後も結果件数・並び順は API リストのまま', () async {
      final items = [_sampleItem(id: 'shop:a'), _sampleItem(id: 'shop:b')];
      final catalog = await newCatalogRepo();
      final provider = RakutenSearchProvider(
        repository: _StubManagedSearchRepository(items),
        productCatalogRepository: catalog,
      );
      final sessionId = provider.beginSearchSession(modeTag: 'shopDiscovery');
      await provider.searchWithCondition(
        const RakutenProductSearchCondition(keyword: '水筒').normalized(),
        excludeRegisteredProductIds: const {},
        sessionId: sessionId,
        modeTag: 'shopDiscovery',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(provider.status, RakutenSearchStatus.success);
      expect(provider.results.length, 2);
      expect(provider.results[0].productId, 'shop:a');
      expect(provider.results[1].productId, 'shop:b');
    });

    test('shopDiscovery でも ProductCatalog upsert が実行される', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final catalog = await newCatalogRepo();
      final provider = RakutenSearchProvider(
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
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(provider.status, RakutenSearchStatus.success);
      expect(catalog.count(), 1);
      final stored = catalog.getByCanonicalId('shop:item001');
      expect(stored?.source, CatalogProductSource.shopDiscovery);
      expect(stored?.sourceTrust, CatalogProductSourceTrust.medium);
    });

    test('shopDiscovery カタログ upsert 失敗でも検索は成功のまま', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final catalog = _ThrowingProductCatalogRepository(prefs);
      final provider = RakutenSearchProvider(
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
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(provider.status, RakutenSearchStatus.success);
      expect(provider.results.length, 1);
    });
  });
}
