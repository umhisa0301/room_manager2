import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/product_catalog_config.dart';
import 'package:room_manager2/models/catalog_product.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/utils/catalog_product_mapper.dart';
import 'package:room_manager2/utils/today_recommendation_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogProduct _catalogProduct({
  String canonicalId = 'shop:item001',
  String genreId = '100227',
  int reviewCount = 10,
  double reviewAverage = 4.5,
  CatalogProductSourceTrust sourceTrust = CatalogProductSourceTrust.high,
  DateTime? lastValidatedAt,
  CatalogProductQualityStatus? qualityStatus,
}) {
  final now = lastValidatedAt ?? DateTime(2026, 5, 31, 12);
  return CatalogProduct(
    canonicalId: canonicalId,
    productId: canonicalId,
    itemCode: canonicalId,
    itemUrl: 'https://item.rakuten.co.jp/shop/item001/',
    normalizedItemUrl: 'https://item.rakuten.co.jp/shop/item001/',
    itemName: '水筒 500ml',
    itemPrice: 1980,
    imageUrl:
        'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
    shopCode: 'shop',
    shopName: 'テストショップ',
    shopUrl: '',
    genreId: genreId,
    genreName: '水・ソフトドリンク',
    reviewAverage: reviewAverage,
    reviewCount: reviewCount,
    affiliateUrl: '',
    itemCaption: '',
    source: CatalogProductSource.search,
    sourceTrust: sourceTrust,
    fetchedAt: now,
    lastValidatedAt: now,
    lastAccessedAt: now,
    qualityStatus:
        qualityStatus ??
        const CatalogProductQualityStatus(
          hasImage: true,
          hasPrice: true,
          hasValidUrl: true,
          safe: true,
        ),
    aliases: [canonicalId],
    cacheTtlSeconds: ProductCatalogConfig.defaultProductCacheTtlSeconds,
  );
}

void main() {
  group('TodayRecommendationCatalogPolicy', () {
    test('カタログ10件・保存ジャンル3系統で API 全スキップ可', () {
      const catalog = TodayRecommendCatalogCollectResult(
        catalogCount: 20,
        catalogCandidates: 10,
        catalogAccepted: 10,
        catalogRejectedStale: 0,
        catalogRejectedQuality: 0,
        catalogRejectedManaged: 0,
        catalogRejectedGenre: 0,
        catalogRejectedTrust: 0,
        catalogRejectedDuplicate: 0,
        sourceGenreIds: {'100227', '100316', '100026'},
      );
      expect(
        TodayRecommendationCatalogPolicy.shouldSkipAllApiPlans(
          catalog: catalog,
          favoriteGenreIds: {'100227', '100316', '100026'},
        ),
        isTrue,
      );
    });

    test('カタログ不足では API 全スキップしない', () {
      const catalog = TodayRecommendCatalogCollectResult(
        catalogCount: 5,
        catalogCandidates: 5,
        catalogAccepted: 5,
        catalogRejectedStale: 0,
        catalogRejectedQuality: 0,
        catalogRejectedManaged: 0,
        catalogRejectedGenre: 0,
        catalogRejectedTrust: 0,
        catalogRejectedDuplicate: 0,
        sourceGenreIds: {'100227'},
      );
      expect(
        TodayRecommendationCatalogPolicy.shouldSkipAllApiPlans(
          catalog: catalog,
          favoriteGenreIds: {'100227', '100316'},
        ),
        isFalse,
      );
    });
  });

  group('TodayRecommendationCatalog.collectIntoPool', () {
    late SharedPreferences prefs;
    late ProductCatalogRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = ProductCatalogRepository(prefs);
      await repo.clear();
    });

    test('PRODUCT_CATALOG_ENABLED=false では空結果', () {
      if (ProductCatalogConfig.kProductCatalogEnabled) return;
      final pool = <String, RakutenSearchItem>{};
      final result = TodayRecommendationCatalog.collectIntoPool(
        repository: repo,
        pool: pool,
        onAcceptMeta: (_, __) {},
        favoriteGenreIds: {'100227'},
        excludeIds: const {},
        doneItems: const [],
        candidateItems: const [],
        exposureRecords: const {},
        now: DateTime(2026, 5, 31, 12),
      );
      expect(result.catalogAccepted, 0);
      expect(pool, isEmpty);
    });

    test(
      '品質OKなカタログ商品がプールに入る',
      () async {
        if (!ProductCatalogConfig.kProductCatalogEnabled) return;
        await repo.upsert(_catalogProduct());
        final pool = <String, RakutenSearchItem>{};
        final meta = <String, String>{};
        final result = TodayRecommendationCatalog.collectIntoPool(
          repository: repo,
          pool: pool,
          onAcceptMeta: (id, genre) => meta[id] = genre,
          favoriteGenreIds: {'100227'},
          excludeIds: const {},
          doneItems: const [],
          candidateItems: const [],
          exposureRecords: const {},
          now: DateTime(2026, 5, 31, 12),
        );
        expect(result.catalogAccepted, 1);
        expect(pool.length, 1);
        expect(meta['shop:item001'], '100227');
        expect(pool['shop:item001']!.itemName, contains('水筒'));
      },
    );

    test('stale は除外される', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      final stale = _catalogProduct(
        lastValidatedAt: DateTime(2026, 5, 20, 12),
      );
      await repo.upsert(stale);
      final pool = <String, RakutenSearchItem>{};
      final result = TodayRecommendationCatalog.collectIntoPool(
        repository: repo,
        pool: pool,
        onAcceptMeta: (_, __) {},
        favoriteGenreIds: {'100227'},
        excludeIds: const {},
        doneItems: const [],
        candidateItems: const [],
        exposureRecords: const {},
        now: DateTime(2026, 5, 31, 12),
      );
      expect(result.catalogRejectedStale, greaterThan(0));
      expect(pool, isEmpty);
    });

    test('候補済み productId は除外される', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      await repo.upsert(_catalogProduct());
      final pool = <String, RakutenSearchItem>{};
      final result = TodayRecommendationCatalog.collectIntoPool(
        repository: repo,
        pool: pool,
        onAcceptMeta: (_, __) {},
        favoriteGenreIds: {'100227'},
        excludeIds: {'shop:item001'},
        doneItems: const [],
        candidateItems: [
          RakutenManagedProduct(
            productId: 'shop:item001',
            itemName: 'x',
            itemPrice: 100,
            itemUrl: 'https://item.rakuten.co.jp/shop/item001/',
            imageUrl: '',
            shopName: '',
            shopCode: '',
            shopUrl: '',
            genreId: '',
            status: RakutenManagedProductStatus.candidate,
            createdAt: DateTime(2026, 5, 31),
            updatedAt: DateTime(2026, 5, 31),
            addedAt: DateTime(2026, 5, 31),
            extractedUrl: '',
            extractionStatus: RakutenUrlExtractionStatus.notStarted,
            extractionErrorMessage: '',
          ),
        ],
        exposureRecords: const {},
        now: DateTime(2026, 5, 31, 12),
      );
      expect(result.catalogRejectedManaged, greaterThan(0));
      expect(pool, isEmpty);
    });

    test('upsertCatalogFromRecommendItems は todayRecommendation になる', () async {
      if (!ProductCatalogConfig.kProductCatalogEnabled) return;
      const item = RakutenSearchItem(
        productId: 'shop:rec001',
        itemName: 'おすすめ商品',
        itemPrice: 1000,
        itemUrl: 'https://item.rakuten.co.jp/shop/rec001/',
        affiliateUrl: '',
        imageUrl:
            'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
        shopName: 'ショップ',
        shopCode: 'shop',
        genreId: '100227',
        genreName: '水',
        reviewCount: 5,
        reviewAverage: 4.0,
      );
      await upsertCatalogFromRecommendItems(repo, [item]);
      final stored = repo.getByCanonicalId('shop:rec001');
      expect(stored, isNotNull);
      expect(stored!.source, CatalogProductSource.todayRecommendation);
      expect(stored.sourceTrust, CatalogProductSourceTrust.high);
    });
  });
}
