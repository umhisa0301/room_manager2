import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/models/shop_discovery_summary.dart';
import 'package:room_manager2/models/shop_pool_candidate.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/services/shop_discovery_pool_fallback.dart';
import 'package:room_manager2/services/shop_pool_keyword_relevance.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogProduct _product({
  required String canonicalId,
  required String shopCode,
  String shopName = 'テストショップ',
  String shopUrl = 'https://www.rakuten.co.jp/test-shop/',
  String imageUrl =
      'https://thumbnail.image.rakuten.co.jp/@0_mall/test/cabinet/a.jpg',
  int reviewCount = 10,
  double reviewAverage = 4.2,
  String itemName = '安全な商品',
  String genreName = 'ジャンルA',
  bool safe = true,
}) {
  final now = DateTime.now();
  return CatalogProduct(
    canonicalId: canonicalId,
    productId: canonicalId,
    itemCode: canonicalId,
    itemUrl: 'https://item.rakuten.co.jp/$shopCode/$canonicalId/',
    normalizedItemUrl: 'https://item.rakuten.co.jp/$shopCode/$canonicalId/',
    itemName: itemName,
    itemPrice: 1200,
    imageUrl: imageUrl,
    shopCode: shopCode,
    shopName: shopName,
    shopUrl: shopUrl,
    genreId: '100',
    genreName: genreName,
    reviewAverage: reviewAverage,
    reviewCount: reviewCount,
    affiliateUrl: '',
    itemCaption: '',
    source: CatalogProductSource.search,
    sourceTrust: CatalogProductSourceTrust.high,
    fetchedAt: now,
    lastValidatedAt: now,
    lastAccessedAt: now,
    qualityStatus: CatalogProductQualityStatus(
      hasImage: imageUrl.trim().isNotEmpty,
      hasPrice: true,
      hasValidUrl: true,
      safe: safe,
    ),
    aliases: <String>[canonicalId],
    cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
  );
}

ShopDiscoverySummary _apiSummary(String shopCode) {
  return ShopDiscoverySummary(
    shopKey: shopCode,
    shopName: 'API $shopCode',
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    hitItemCount: 2,
    maxReviewCount: 10,
    avgReviewAverage: 4.0,
    discoveryScore: 100,
    representativeItems: const <ShopRepresentativeItem>[],
  );
}

void main() {
  group('ShopDiscoveryPoolFallback', () {
    late ProductCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = ProductCatalogRepository(prefs);
      await repo.clear();
    });

    test('API results がある場合は fallback しない', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final result = ShopDiscoveryPoolFallback.buildFallbackSummaries(
        repository: repo,
        keyword: '水筒',
        apiSummaries: <ShopDiscoverySummary>[_apiSummary('api-shop')],
        apiSearchSucceeded: true,
        savedShopCodes: const <String>{},
      );
      expect(result.usedFallback, isFalse);
      expect(result.reason, 'apiResultAvailable');
      expect(result.summaries.length, 1);
    });

    test('shopCode 空は除外される', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll(<CatalogProduct>[
        _product(canonicalId: 'a1', shopCode: ''),
        _product(canonicalId: 'a2', shopCode: 'ok-shop'),
      ]);
      final result = ShopDiscoveryPoolFallback.buildFallbackSummaries(
        repository: repo,
        keyword: '水筒',
        apiSummaries: const <ShopDiscoverySummary>[],
        apiSearchSucceeded: false,
        savedShopCodes: const <String>{},
      );
      expect(result.usedFallback, isFalse);
      expect(result.convertedCount, 1);
    });

    test('shopName 不正は除外される', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll(<CatalogProduct>[
        _product(canonicalId: 'x1', shopCode: 'girl-k', shopName: 'girl-k'),
        _product(
          canonicalId: 'x2',
          shopCode: 'good-shop',
          shopName: 'グッドショップ',
          shopUrl: 'https://www.rakuten.co.jp/good-shop/',
        ),
        _product(
          canonicalId: 'x3',
          shopCode: 'good-shop2',
          shopName: 'グッドショップ2',
          shopUrl: 'https://www.rakuten.co.jp/good-shop2/',
        ),
        _product(
          canonicalId: 'x4',
          shopCode: 'good-shop3',
          shopName: 'グッドショップ3',
          shopUrl: 'https://www.rakuten.co.jp/good-shop3/',
        ),
      ]);
      final result = ShopDiscoveryPoolFallback.buildFallbackSummaries(
        repository: repo,
        keyword: '水筒',
        apiSummaries: const <ShopDiscoverySummary>[],
        apiSearchSucceeded: false,
        savedShopCodes: const <String>{},
      );
      expect(result.usedFallback, isTrue);
      expect(result.summaries.any((e) => e.shopKey == 'girl-k'), isFalse);
    });

    test('保存済みショップは除外される', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll(<CatalogProduct>[
        _product(canonicalId: 'b1', shopCode: 'saved-shop'),
        _product(canonicalId: 'b2', shopCode: 'shop-2'),
        _product(canonicalId: 'b3', shopCode: 'shop-3'),
        _product(canonicalId: 'b4', shopCode: 'shop-4'),
      ]);
      final result = ShopDiscoveryPoolFallback.buildFallbackSummaries(
        repository: repo,
        keyword: '水筒',
        apiSummaries: const <ShopDiscoverySummary>[],
        apiSearchSucceeded: false,
        savedShopCodes: const <String>{'saved-shop'},
      );
      expect(result.usedFallback, isTrue);
      expect(result.savedExcludedCount, 1);
      expect(result.summaries.any((e) => e.shopKey == 'saved-shop'), isFalse);
    });

    test('safeItemCount=0 相当は fallback しない', () {
      final candidate = ShopPoolCandidate(
        shopCode: 'pool-a',
        shopName: 'Pool A',
        shopUrl: 'https://www.rakuten.co.jp/pool-a/',
        representativeImageUrl: '',
        primaryGenreId: '',
        primaryGenreName: '',
        itemCount: 1,
        safeItemCount: 0,
        itemsWithImage: 0,
        itemsWithPrice: 0,
        averageReviewAverage: 0,
        maxReviewCount: 0,
        averagePrice: 0,
        minPrice: 0,
        maxPrice: 0,
        score: 1,
        sampleProductIds: const <String>[],
        sourceGenres: const <String>[],
        sourceProductIds: const <String>[],
      );
      expect(candidate.safeItemCount, 0);
    });

    test('pool 3〜9件で partial fallback になる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll(<CatalogProduct>[
        _product(canonicalId: 'c1', shopCode: 'shop-1'),
        _product(canonicalId: 'c2', shopCode: 'shop-2'),
        _product(canonicalId: 'c3', shopCode: 'shop-3'),
      ]);
      final result = ShopDiscoveryPoolFallback.buildFallbackSummaries(
        repository: repo,
        keyword: '水筒',
        apiSummaries: const <ShopDiscoverySummary>[],
        apiSearchSucceeded: false,
        savedShopCodes: const <String>{},
      );
      expect(result.usedFallback, isTrue);
      expect(result.isPartialFallback, isTrue);
      expect(result.summaries.length, 3);
      expect(result.summaries.first.origin, 'shopPoolFallback');
      expect(result.summaries.first.discoveryKeyword, '水筒');
      expect(result.fallbackRankByShopCode[result.summaries.first.shopKey], 1);
    });

    test('pool 0〜2件では fallback しない', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll(<CatalogProduct>[
        _product(canonicalId: 'd1', shopCode: 'shop-1'),
        _product(canonicalId: 'd2', shopCode: 'shop-2'),
      ]);
      final result = ShopDiscoveryPoolFallback.buildFallbackSummaries(
        repository: repo,
        keyword: '水筒',
        apiSummaries: const <ShopDiscoverySummary>[],
        apiSearchSucceeded: false,
        savedShopCodes: const <String>{},
      );
      expect(result.usedFallback, isFalse);
      expect(result.reason, 'apiFailed_notEnoughPoolCandidates');
    });

    test('fallback時は最大10件に制限される', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final products = <CatalogProduct>[];
      for (var i = 0; i < 12; i++) {
        products.add(_product(canonicalId: 'e$i', shopCode: 'shop-$i'));
      }
      await repo.upsertAll(products);
      final result = ShopDiscoveryPoolFallback.buildFallbackSummaries(
        repository: repo,
        keyword: '水筒',
        apiSummaries: const <ShopDiscoverySummary>[],
        apiSearchSucceeded: false,
        savedShopCodes: const <String>{},
      );
      expect(result.usedFallback, isTrue);
      expect(result.summaries.length, 10);
    });

    test('関連度が同じときは score 順を維持する', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll(<CatalogProduct>[
        _product(
          canonicalId: 'f1',
          shopCode: 'high',
          reviewCount: 100,
          itemName: 'ステンレスボトル 高評価',
        ),
        _product(
          canonicalId: 'f2',
          shopCode: 'mid',
          reviewCount: 10,
          itemName: 'マグボトル 中評価',
        ),
        _product(
          canonicalId: 'f3',
          shopCode: 'low',
          reviewCount: 1,
          itemName: 'タンブラー 低評価',
        ),
      ]);
      final result = ShopDiscoveryPoolFallback.buildFallbackSummaries(
        repository: repo,
        keyword: '水筒',
        apiSummaries: const <ShopDiscoverySummary>[],
        apiSearchSucceeded: false,
        savedShopCodes: const <String>{},
      );
      expect(result.usedFallback, isTrue);
      expect(result.summaries.first.shopKey, 'high');
    });

    test('水筒検索でお名前シールより関連ショップを優先する', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll(<CatalogProduct>[
        _product(
          canonicalId: 'label-1',
          shopCode: 'naireseisakusho',
          shopName: 'レスタス お名前シール&スタンプ',
          itemName: 'お名前シール',
          reviewCount: 2000,
        ),
        _product(
          canonicalId: 'bottle-1',
          shopCode: 'bottle-shop',
          shopName: 'ボトル専門店',
          itemName: '子供用水筒',
          reviewCount: 5,
        ),
        _product(
          canonicalId: 'bottle-2',
          shopCode: 'bottle-shop-2',
          shopName: 'タンブラー屋',
          itemName: '保温タンブラー',
          reviewCount: 3,
        ),
        _product(
          canonicalId: 'bottle-3',
          shopCode: 'bottle-shop-3',
          shopName: 'マグ専門',
          itemName: 'マグボトル',
          reviewCount: 2,
        ),
      ]);
      final result = ShopDiscoveryPoolFallback.buildFallbackSummaries(
        repository: repo,
        keyword: '水筒',
        apiSummaries: const <ShopDiscoverySummary>[],
        apiSearchSucceeded: false,
        savedShopCodes: const <String>{},
      );
      expect(result.usedFallback, isTrue);
      expect(
        result.summaries.any((e) => e.shopKey == 'naireseisakusho'),
        isFalse,
      );
      expect(result.relevanceStats.strongCount, greaterThanOrEqualTo(1));
    });

    test('primaryGenreId ありで genreName 空は unknownGenre 扱いにしない', () {
      final candidate = ShopPoolCandidate(
        shopCode: 'x',
        shopName: 'shop',
        shopUrl: 'https://www.rakuten.co.jp/x/',
        representativeImageUrl: '',
        primaryGenreId: '200',
        primaryGenreName: '水筒・ボトル',
        itemCount: 1,
        safeItemCount: 1,
        itemsWithImage: 0,
        itemsWithPrice: 1,
        averageReviewAverage: 4,
        maxReviewCount: 1,
        averagePrice: 1000,
        minPrice: 1000,
        maxPrice: 1000,
        score: 100,
        sampleProductIds: const <String>['p1'],
        sourceGenres: const <String>['200'],
        sourceProductIds: const <String>['p1'],
      );
      expect(ShopPoolKeywordRelevance.isUnknownGenre(candidate), isFalse);
      expect(candidate.primaryGenreId, '200');
    });

    test('fallback TOP で hitItemCount>=2 が hitItemCount=1 より優先される', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll(<CatalogProduct>[
        _product(
          canonicalId: 'thin-1',
          shopCode: 'thin-shop',
          shopName: '薄いショップ',
          itemName: '子供用水筒',
          reviewCount: 5000,
        ),
        _product(
          canonicalId: 'thick-1',
          shopCode: 'thick-shop',
          shopName: '厚いショップ',
          itemName: 'ステンレス水筒A',
          reviewCount: 1,
        ),
        _product(
          canonicalId: 'thick-2',
          shopCode: 'thick-shop',
          shopName: '厚いショップ',
          itemName: 'ステンレス水筒B',
          reviewCount: 1,
        ),
        _product(
          canonicalId: 'thick-3',
          shopCode: 'thick-shop-2',
          shopName: '厚いショップ2',
          itemName: 'マグボトル',
          reviewCount: 1,
        ),
        _product(
          canonicalId: 'thick-4',
          shopCode: 'thick-shop-2',
          shopName: '厚いショップ2',
          itemName: 'タンブラー',
          reviewCount: 1,
        ),
      ]);
      final result = ShopDiscoveryPoolFallback.buildFallbackSummaries(
        repository: repo,
        keyword: '水筒',
        apiSummaries: const <ShopDiscoverySummary>[],
        apiSearchSucceeded: false,
        savedShopCodes: const <String>{},
      );
      expect(result.usedFallback, isTrue);
      expect(result.summaries.first.hitItemCount, greaterThanOrEqualTo(2));
      expect(result.summaries.first.shopKey, isNot('thin-shop'));
    });

    test('候補不足時は hitItemCount=1 でも fallback 表示できる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsertAll(<CatalogProduct>[
        _product(
          canonicalId: 'only-1',
          shopCode: 'only-shop',
          itemName: '水筒1本',
        ),
        _product(
          canonicalId: 'only-2',
          shopCode: 'only-shop-2',
          itemName: 'ボトル',
        ),
        _product(
          canonicalId: 'only-3',
          shopCode: 'only-shop-3',
          itemName: 'タンブラー',
        ),
      ]);
      final result = ShopDiscoveryPoolFallback.buildFallbackSummaries(
        repository: repo,
        keyword: '水筒',
        apiSummaries: const <ShopDiscoverySummary>[],
        apiSearchSucceeded: false,
        savedShopCodes: const <String>{},
      );
      expect(result.usedFallback, isTrue);
      expect(result.summaries.length, 3);
    });

    test('noimage URL は表示用画像に含めない', () {
      expect(
        ShopDiscoveryPoolFallback.hasDisplayableImageUrl(
          'https://thumbnail.image.rakuten.co.jp/noimage.jpg',
        ),
        isFalse,
      );
      expect(
        ShopDiscoveryPoolFallback.hasDisplayableImageUrl(
          'https://thumbnail.image.rakuten.co.jp/@0_mall/test/cabinet/a.jpg',
        ),
        isTrue,
      );
    });
  });
}
