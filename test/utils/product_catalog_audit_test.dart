import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/services/product_catalog_shop_aggregator.dart';
import 'package:room_manager2/utils/catalog_product_mapper.dart';
import 'package:room_manager2/utils/product_catalog_audit.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/utils/product_catalog_upsert_timing.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogProduct _product({
  required String canonicalId,
  required String shopCode,
  CatalogProductSource source = CatalogProductSource.search,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.high,
  DateTime? lastValidatedAt,
  bool safe = true,
  String itemName = '安全な商品',
}) {
  final now = lastValidatedAt ?? DateTime.now();
  return CatalogProduct(
    canonicalId: canonicalId,
    productId: canonicalId,
    itemCode: canonicalId,
    itemUrl: 'https://item.rakuten.co.jp/$shopCode/$canonicalId/',
    normalizedItemUrl: 'https://item.rakuten.co.jp/$shopCode/$canonicalId/',
    itemName: itemName,
    itemPrice: 1200,
    imageUrl:
        'https://thumbnail.image.rakuten.co.jp/@0_mall/$shopCode/cabinet/a.jpg',
    shopCode: shopCode,
    shopName: 'テストショップ',
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    genreId: '100',
    genreName: 'ジャンルA',
    reviewAverage: 4.5,
    reviewCount: 10,
    affiliateUrl: '',
    itemCaption: '',
    source: source,
    sourceTrust: sourceTrust,
    fetchedAt: now,
    lastValidatedAt: now,
    lastAccessedAt: now,
    qualityStatus: CatalogProductQualityStatus(
      hasImage: true,
      hasPrice: true,
      hasValidUrl: true,
      safe: safe,
    ),
    aliases: [canonicalId],
    cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
  );
}

void main() {
  group('logShopPoolAggregationDiagnostics', () {
    late ProductCatalogRepository repo;
    final now = DateTime(2026, 6, 3, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = ProductCatalogRepository(prefs);
      await repo.clear();
      ProductCatalogUpsertTimingRegistry.resetForTest();
    });

    test('medium shopDiscovery 商品2件の同一 shopCode が pool itemCount=2 になる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll([
        _product(
          canonicalId: 'sd:1',
          shopCode: 'deep-shop',
          source: CatalogProductSource.shopDiscovery,
          sourceTrust: CatalogProductSourceTrust.medium,
          lastValidatedAt: now,
        ),
        _product(
          canonicalId: 'sd:2',
          shopCode: 'deep-shop',
          source: CatalogProductSource.shopDiscovery,
          sourceTrust: CatalogProductSourceTrust.medium,
          lastValidatedAt: now,
        ),
      ]);
      final aggregate = ProductCatalogShopAggregator.aggregate(
        repository: repo,
        now: now,
      );
      final candidate = aggregate.candidates.singleWhere(
        (e) => e.shopCode == 'deep-shop',
      );
      expect(candidate.itemCount, 2);
      expect(candidate.sourceProductIds.length, 2);
    });

    test('stale 商品のみ残ると pool itemCount=1 になる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll([
        _product(
          canonicalId: 'fresh:1',
          shopCode: 'mixed-shop',
          lastValidatedAt: now,
        ),
        _product(
          canonicalId: 'stale:1',
          shopCode: 'mixed-shop',
          lastValidatedAt: DateTime(2026, 5, 20, 12),
        ),
      ]);
      final aggregate = ProductCatalogShopAggregator.aggregate(
        repository: repo,
        now: now,
      );
      final candidate = aggregate.candidates.singleWhere(
        (e) => e.shopCode == 'mixed-shop',
      );
      expect(candidate.itemCount, 1);
    });

    test('maxProductsPerShop 相当でも fresh が複数あれば pool itemCount>=2', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final products = <CatalogProduct>[];
      for (var i = 0; i < 5; i++) {
        products.add(
          _product(
            canonicalId: 'max:$i',
            shopCode: 'max-shop',
            lastValidatedAt: now,
          ),
        );
      }
      for (var i = 0; i < 16; i++) {
        products.add(
          _product(
            canonicalId: 'old:$i',
            shopCode: 'max-shop',
            lastValidatedAt: DateTime(2026, 5, 20, 12),
          ),
        );
      }
      await repo.upsertAll(products);
      final aggregate = ProductCatalogShopAggregator.aggregate(
        repository: repo,
        now: now,
      );
      final candidate = aggregate.candidates.singleWhere(
        (e) => e.shopCode == 'max-shop',
      );
      expect(candidate.itemCount, 5);
    });

    test('診断関数は例外なく実行できる', () {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      expect(
        () => logShopPoolAggregationDiagnostics(
          repository: repo,
          now: now,
        ),
        returnsNormally,
      );
    });

    test('保存ショップ検索相当 search/high で同一 shopCode 複数商品が pool に蓄積', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll([
        _product(
          canonicalId: 'saved:1',
          shopCode: 'my-shop',
          source: CatalogProductSource.search,
          sourceTrust: CatalogProductSourceTrust.high,
          lastValidatedAt: now,
        ),
        _product(
          canonicalId: 'saved:2',
          shopCode: 'my-shop',
          source: CatalogProductSource.search,
          sourceTrust: CatalogProductSourceTrust.high,
          lastValidatedAt: now,
        ),
      ]);
      final aggregate = ProductCatalogShopAggregator.aggregate(
        repository: repo,
        now: now,
      );
      final candidate = aggregate.candidates.singleWhere(
        (e) => e.shopCode == 'my-shop',
      );
      expect(candidate.itemCount, 2);
    });

    test('stale 深さ投影で wouldItemCount2Plus を計算できる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll([
        _product(
          canonicalId: 'fresh:1',
          shopCode: 'stale-depth-shop',
          lastValidatedAt: now,
        ),
        _product(
          canonicalId: 'stale:1',
          shopCode: 'stale-depth-shop',
          lastValidatedAt: DateTime(2026, 5, 20, 12),
        ),
      ]);
      final projection = computeShopPoolStaleDepthProjection(
        repository: repo,
        now: now,
      );
      expect(projection.currentItemCount2Plus, 0);
      expect(projection.staleUsableForDepth, 1);
      expect(projection.wouldItemCount2PlusIfStaleDepthAllowed, 1);
    });

    test('isStaleUsableForDepthOnly は shopCode/itemName/genreId を要求', () {
      final usable = _product(
        canonicalId: 'x',
        shopCode: 's',
        lastValidatedAt: now,
      );
      expect(isStaleUsableForDepthOnly(usable), isTrue);
      expect(
        isStaleUsableForDepthOnly(
          usable.copyWith(itemName: ''),
        ),
        isFalse,
      );
    });

    test('computeShopDiscoveryEnrichmentOpportunity は API を呼ばない', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll([
        _product(
          canonicalId: 'd:1',
          shopCode: 'shop-a',
          lastValidatedAt: now,
        ),
      ]);
      final opp = computeShopDiscoveryEnrichmentOpportunity(
        repository: repo,
        displayedShopCodes: const ['shop-a', 'shop-b'],
        keyword: '水筒',
      );
      expect(opp.displayedShopCount, 2);
      expect(opp.shopsEligibleForManualEnrich, 2);
      expect(opp.estimatedApiCallsIfEnrichTop3, 2);
    });

    test('logShopDiscoveryDetailDepthTrace / PoolTrace は例外なく実行できる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll([
        _product(
          canonicalId: 'trace:1',
          shopCode: 'trace-shop',
          lastValidatedAt: now,
        ),
      ]);
      expect(
        () => logShopDiscoveryDetailDepthTrace(
          repository: repo,
          shopCode: 'trace-shop',
          now: now,
        ),
        returnsNormally,
      );
      expect(
        () => logShopDiscoveryDetailPoolTrace(
          repository: repo,
          shopCode: 'trace-shop',
          now: now,
        ),
        returnsNormally,
      );
    });

    test('logShopDiscoveryDetailCatalogItemTrace は duplicate reason を含める', () {
      expect(
        () => logShopDiscoveryDetailCatalogItemTrace(
          shopCode: 'dup-shop',
          inputItems: 2,
          savedForShop: 1,
          traces: const [
            ShopDiscoveryDetailCatalogItemTraceLine(
              itemCode: 'dup-shop:a',
              inputCanonicalId: 'dup-shop:a',
              canonicalId: 'dup-shop:a',
              shopCode: 'dup-shop',
              itemName: '商品A',
              normalizedItemUrl: '-',
              saved: true,
              reason: '-',
              getByCanonicalIdFound: true,
              findByAliasFound: true,
              resolvedCanonicalId: 'dup-shop:a',
              resolvedShopCode: 'dup-shop',
              sameShopCode: true,
            ),
            ShopDiscoveryDetailCatalogItemTraceLine(
              itemCode: 'dup-shop:a',
              inputCanonicalId: 'dup-shop:a',
              canonicalId: 'dup-shop:a',
              shopCode: 'dup-shop',
              itemName: '商品Aコピー',
              normalizedItemUrl: '-',
              saved: false,
              reason: 'canonicalDuplicate',
              getByCanonicalIdFound: false,
              findByAliasFound: false,
              resolvedCanonicalId: '-',
              resolvedShopCode: '-',
              sameShopCode: true,
            ),
          ],
        ),
        returnsNormally,
      );
    });

    test('logSavedOrDiscoveryShopDepthAfterUpsert は例外なく実行できる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll([
        _product(
          canonicalId: 'depth:1',
          shopCode: 'depth-shop',
          lastValidatedAt: now,
        ),
        _product(
          canonicalId: 'depth:2',
          shopCode: 'depth-shop',
          lastValidatedAt: now,
        ),
      ]);
      expect(
        () => logSavedOrDiscoveryShopDepthAfterUpsert(
          repository: repo,
          shopCode: 'depth-shop',
          now: now,
        ),
        returnsNormally,
      );
    });
  });

  group('buildShopDiscoveryDetailCatalogItemTraces integration', () {
    test('detail upsert 後 poolItemCount が2になる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ProductCatalogRepository(prefs);
      await repo.clear();
      final now = DateTime(2026, 6, 4, 12);
      await upsertCatalogFromShopDiscoveryDetailItems(
        repo,
        [
          RakutenSearchItem(
            productId: 'pool:1',
            itemName: '商品1',
            itemPrice: 1000,
            itemUrl: 'https://item.rakuten.co.jp/pool-shop/one/',
            affiliateUrl: '',
            imageUrl:
                'https://thumbnail.image.rakuten.co.jp/@0_mall/pool-shop/cabinet/a.jpg',
            shopName: 'プールショップ',
            shopCode: 'pool-shop',
          ),
          RakutenSearchItem(
            productId: 'pool:2',
            itemName: '商品2',
            itemPrice: 2000,
            itemUrl: 'https://item.rakuten.co.jp/pool-shop/two/',
            affiliateUrl: '',
            imageUrl:
                'https://thumbnail.image.rakuten.co.jp/@0_mall/pool-shop/cabinet/b.jpg',
            shopName: 'プールショップ',
            shopCode: 'pool-shop',
          ),
        ],
        shopCode: 'pool-shop',
        upsertSource: 'initialItems',
        now: now,
      );
      final aggregate = ProductCatalogShopAggregator.aggregate(
        repository: repo,
        now: now,
      );
      final candidate = aggregate.candidates.singleWhere(
        (e) => e.shopCode == 'pool-shop',
      );
      expect(candidate.itemCount, 2);
      expect(candidate.sourceProductIds.length, 2);
      expect(candidate.sampleProductIds.length, 2);
    });
  });

  group('ProductCatalogUpsertTimingRegistry', () {
    setUp(ProductCatalogUpsertTimingRegistry.resetForTest);

    test('upsert 完了前の read は usesFreshCatalog=false', () {
      ProductCatalogUpsertTimingRegistry.markShopDiscoveryScheduled(
        catalogCountBefore: 100,
      );
      final readAt = DateTime.now();
      expect(
        ProductCatalogUpsertTimingRegistry.readUsesFreshCatalog(readAt),
        isFalse,
      );
    });

    test('upsert 完了後の read は usesFreshCatalog=true', () {
      ProductCatalogUpsertTimingRegistry.markShopDiscoveryScheduled(
        catalogCountBefore: 100,
      );
      ProductCatalogUpsertTimingRegistry.markShopDiscoveryCompleted(
        catalogCountAfter: 199,
      );
      final readAt = DateTime.now().add(const Duration(milliseconds: 1));
      expect(
        ProductCatalogUpsertTimingRegistry.readUsesFreshCatalog(readAt),
        isTrue,
      );
      expect(ProductCatalogUpsertTimingRegistry.shopDiscoveryDurationMs, isNotNull);
    });
  });
}
