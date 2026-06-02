import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/constants/shop_pool_fallback_keyword_synonyms.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/models/shop_pool_candidate.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
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
      safe: true,
    ),
    aliases: <String>[canonicalId],
    cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
  );
}

ShopPoolCandidate _candidate({
  required String shopCode,
  required String shopName,
  String primaryGenreName = '',
  List<String> sourceProductIds = const <String>[],
}) {
  return ShopPoolCandidate(
    shopCode: shopCode,
    shopName: shopName,
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    representativeImageUrl: '',
    primaryGenreId: '100',
    primaryGenreName: primaryGenreName,
    itemCount: sourceProductIds.isEmpty ? 1 : sourceProductIds.length,
    safeItemCount: sourceProductIds.isEmpty ? 1 : sourceProductIds.length,
    itemsWithImage: 0,
    itemsWithPrice: 1,
    averageReviewAverage: 4.5,
    maxReviewCount: 100,
    averagePrice: 2000,
    minPrice: 1000,
    maxPrice: 3000,
    score: 200,
    sampleProductIds: sourceProductIds,
    sourceGenres: const <String>[],
    sourceProductIds: sourceProductIds,
  );
}

void main() {
  group('ShopPoolFallbackKeywordSynonyms', () {
    test('水筒の同義語を返す', () {
      final tokens = ShopPoolFallbackKeywordSynonyms.tokensFor('水筒');
      expect(tokens, contains('水筒'));
      expect(tokens, contains('ボトル'));
      expect(tokens, contains('タンブラー'));
      expect(tokens, contains('マグボトル'));
    });
  });

  group('ShopPoolKeywordRelevance', () {
    late ProductCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = ProductCatalogRepository(await SharedPreferences.getInstance());
      await repo.clear();
    });

    test('水筒で商品名マッチは strong', () async {
      await repo.upsertAll(<CatalogProduct>[
        _product(
          canonicalId: 'bottle-1',
          shopCode: 'bottle-shop',
          shopName: 'ボトル専門店',
          itemName: 'ステンレス水筒 500ml',
        ),
      ]);
      final result = ShopPoolKeywordRelevance.evaluate(
        repository: repo,
        keyword: '水筒',
        candidate: _candidate(
          shopCode: 'bottle-shop',
          shopName: 'ボトル専門店',
          sourceProductIds: const <String>['bottle-1'],
        ),
      );
      expect(result.level, ShopPoolKeywordMatchLevel.strong);
      expect(result.matchedBy, 'itemName');
    });

    test('水筒でお名前シールは noMatch', () async {
      await repo.upsertAll(<CatalogProduct>[
        _product(
          canonicalId: 'label-1',
          shopCode: 'naireseisakusho',
          shopName: 'レスタス お名前シール&スタンプ',
          itemName: 'お名前シール セット',
          genreName: '文房具',
        ),
      ]);
      final result = ShopPoolKeywordRelevance.evaluate(
        repository: repo,
        keyword: '水筒',
        candidate: _candidate(
          shopCode: 'naireseisakusho',
          shopName: 'レスタス お名前シール&スタンプ',
          primaryGenreName: '文房具',
          sourceProductIds: const <String>['label-1'],
        ),
      );
      expect(result.level, ShopPoolKeywordMatchLevel.none);
    });

    test('ジャンル名マッチは medium', () async {
      await repo.upsertAll(<CatalogProduct>[
        _product(
          canonicalId: 'g-1',
          shopCode: 'genre-shop',
          shopName: 'キッチン店',
          itemName: '保存容器',
          genreName: 'タンブラー・水筒',
        ),
      ]);
      final result = ShopPoolKeywordRelevance.evaluate(
        repository: repo,
        keyword: '水筒',
        candidate: _candidate(
          shopCode: 'genre-shop',
          shopName: 'キッチン店',
          primaryGenreName: 'タンブラー・水筒',
          sourceProductIds: const <String>['g-1'],
        ),
      );
      expect(result.level, ShopPoolKeywordMatchLevel.medium);
      expect(result.matchedBy, 'genreName');
    });

    test('unknown genre を検出する', () {
      expect(
        ShopPoolKeywordRelevance.isUnknownGenre(
          _candidate(shopCode: 'x', shopName: 'x'),
        ),
        isTrue,
      );
      expect(
        ShopPoolKeywordRelevance.isUnknownGenre(
          _candidate(
            shopCode: 'x',
            shopName: 'x',
            primaryGenreName: 'キッチン用品',
          ),
        ),
        isFalse,
      );
    });
  });
}
