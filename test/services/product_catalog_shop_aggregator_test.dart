import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/services/product_catalog_shop_aggregator.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogProduct _product({
  required String canonicalId,
  required String shopCode,
  String shopName = 'テストショップ',
  String genreId = '100',
  String genreName = 'ジャンルA',
  String imageUrl =
      'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
  int itemPrice = 1200,
  double reviewAverage = 4.5,
  int reviewCount = 20,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.high,
  DateTime? lastValidatedAt,
  bool safe = true,
  String itemName = '安全な商品名',
}) {
  final now = lastValidatedAt ?? DateTime(2026, 5, 31, 12);
  return CatalogProduct(
    canonicalId: canonicalId,
    productId: canonicalId,
    itemCode: canonicalId,
    itemUrl: 'https://item.rakuten.co.jp/$shopCode/item/',
    normalizedItemUrl: 'https://item.rakuten.co.jp/$shopCode/item/',
    itemName: itemName,
    itemPrice: itemPrice,
    imageUrl: imageUrl,
    shopCode: shopCode,
    shopName: shopName,
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    genreId: genreId,
    genreName: genreName,
    reviewAverage: reviewAverage,
    reviewCount: reviewCount,
    affiliateUrl: '',
    itemCaption: '',
    source: CatalogProductSource.search,
    sourceTrust: sourceTrust,
    fetchedAt: now,
    lastValidatedAt: now,
    lastAccessedAt: now,
    qualityStatus: CatalogProductQualityStatus(
      hasImage: imageUrl.trim().isNotEmpty,
      hasPrice: itemPrice > 0,
      hasValidUrl: true,
      safe: safe,
    ),
    aliases: [canonicalId],
    cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
  );
}

void main() {
  group('ProductCatalogShopAggregator', () {
    late ProductCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = ProductCatalogRepository(prefs);
      await repo.clear();
    });

    test('カタログ空なら空リスト', () {
      final result = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(result.candidates, isEmpty);
      expect(result.stats.catalogProducts, 0);
    });

    test('shopCode 単位に集計できる', () async {
      await repo.upsertAll([
        _product(canonicalId: 'a:1', shopCode: 'shop-a'),
        _product(canonicalId: 'a:2', shopCode: 'shop-a'),
        _product(canonicalId: 'b:1', shopCode: 'shop-b'),
      ]);
      final result = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(result.candidates.length, 2);
      final codes = result.candidates.map((e) => e.shopCode).toSet();
      expect(codes, containsAll(['shop-a', 'shop-b']));
    });

    test('shopCode 空は除外', () async {
      await repo.upsertAll([
        _product(canonicalId: 'empty:1', shopCode: ''),
        _product(canonicalId: 'ok:1', shopCode: 'ok-shop'),
      ]);
      final result = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(result.candidates.length, 1);
      expect(result.candidates.first.shopCode, 'ok-shop');
      expect(result.stats.emptyShopCodeExcluded, 1);
    });

    test('unsafe 商品は除外', () async {
      await repo.upsertAll([
        _product(
          canonicalId: 'ng:1',
          shopCode: 'ng-shop',
          safe: false,
          itemName: 'アダルト商品',
        ),
        _product(canonicalId: 'ok:1', shopCode: 'ok-shop'),
      ]);
      final result = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(result.candidates.map((e) => e.shopCode), ['ok-shop']);
      expect(result.stats.unsafeExcluded, greaterThanOrEqualTo(1));
    });

    test('stale 商品は除外', () async {
      await repo.upsertAll([
        _product(
          canonicalId: 'stale:1',
          shopCode: 'stale-shop',
          lastValidatedAt: DateTime(2026, 5, 20, 12),
        ),
        _product(canonicalId: 'fresh:1', shopCode: 'fresh-shop'),
      ]);
      final result = ProductCatalogShopAggregator.aggregate(
        repository: repo,
        now: DateTime(2026, 5, 31, 13),
      );
      expect(result.candidates.map((e) => e.shopCode), ['fresh-shop']);
      expect(result.stats.staleExcluded, 1);
    });

    test('sourceTrust=low は除外', () async {
      await repo.upsertAll([
        _product(
          canonicalId: 'low:1',
          shopCode: 'low-shop',
          sourceTrust: CatalogProductSourceTrust.low,
        ),
        _product(canonicalId: 'high:1', shopCode: 'high-shop'),
      ]);
      final result = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(result.candidates.map((e) => e.shopCode), ['high-shop']);
      expect(result.stats.lowTrustExcluded, 1);
    });

    test('representativeImageUrl が安全画像になる', () async {
      await repo.upsertAll([
        _product(
          canonicalId: 'img:1',
          shopCode: 'img-shop',
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/img-shop/cabinet/x.jpg',
        ),
      ]);
      final result = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(result.candidates.single.representativeImageUrl, contains('img-shop'));
    });

    test('primaryGenreId が件数最多ジャンルになる', () async {
      await repo.upsertAll([
        _product(canonicalId: 'g1:1', shopCode: 'genre-shop', genreId: '200'),
        _product(canonicalId: 'g1:2', shopCode: 'genre-shop', genreId: '200'),
        _product(canonicalId: 'g2:1', shopCode: 'genre-shop', genreId: '100'),
      ]);
      final result = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(result.candidates.single.primaryGenreId, '200');
    });

    test('score 順になる', () async {
      await repo.upsertAll([
        _product(
          canonicalId: 'small:1',
          shopCode: 'small-shop',
          reviewCount: 1,
          reviewAverage: 3,
        ),
        _product(
          canonicalId: 'big:1',
          shopCode: 'big-shop',
          reviewCount: 100,
          reviewAverage: 4.8,
        ),
        _product(
          canonicalId: 'big:2',
          shopCode: 'big-shop',
          reviewCount: 80,
          reviewAverage: 4.5,
        ),
      ]);
      final result = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(result.candidates.first.shopCode, 'big-shop');
      expect(
        result.candidates.first.score,
        greaterThan(result.candidates.last.score),
      );
    });

    test('sampleProductIds が入る', () async {
      await repo.upsertAll([
        _product(canonicalId: 's:1', shopCode: 'sample-shop'),
        _product(canonicalId: 's:2', shopCode: 'sample-shop'),
      ]);
      final result = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(result.candidates.single.sampleProductIds, isNotEmpty);
      expect(result.candidates.single.sampleProductIds, contains('s:1'));
    });

    test('保存ショップ除外を指定できる', () async {
      await repo.upsertAll([
        _product(canonicalId: 'saved:1', shopCode: 'saved-shop'),
        _product(canonicalId: 'other:1', shopCode: 'other-shop'),
      ]);
      final result = ProductCatalogShopAggregator.aggregate(
        repository: repo,
        excludeSavedShopCodes: {'saved-shop'},
      );
      expect(result.candidates.map((e) => e.shopCode), ['other-shop']);
      expect(result.stats.savedExcluded, 1);
    });

    test('未確認 shopName は表示名に使わない', () async {
      await repo.upsert(
        _product(
          canonicalId: 'name:1',
          shopCode: 'girl-k',
          shopName: 'girl-k',
        ),
      );
      final result = ProductCatalogShopAggregator.aggregate(repository: repo);
      expect(result.candidates.single.shopName, 'ショップ未確認');
    });
  });
}
