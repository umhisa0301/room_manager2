import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/shop_catalog_entry.dart';
import 'package:room_manager2/models/shop_discovery_summary.dart';
import 'package:room_manager2/models/shop_pool_candidate.dart';
import 'package:room_manager2/services/shop_discovery_pool_comparator.dart';

ShopDiscoverySummary _apiSummary({
  required String shopCode,
  double score = 100,
}) {
  return ShopDiscoverySummary(
    shopKey: shopCode,
    shopName: 'Shop $shopCode',
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    hitItemCount: 3,
    maxReviewCount: 20,
    avgReviewAverage: 4.2,
    discoveryScore: score,
    representativeItems: const <ShopRepresentativeItem>[],
  );
}

ShopPoolCandidate _pool({
  required String shopCode,
  double score = 50,
}) {
  return ShopPoolCandidate(
    shopCode: shopCode,
    shopName: 'Pool $shopCode',
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    representativeImageUrl: '',
    primaryGenreId: '',
    primaryGenreName: '',
    itemCount: 2,
    safeItemCount: 2,
    itemsWithImage: 1,
    itemsWithPrice: 1,
    averageReviewAverage: 4.0,
    maxReviewCount: 10,
    averagePrice: 1000,
    minPrice: 800,
    maxPrice: 1200,
    score: score,
    sampleProductIds: const <String>[],
    sourceGenres: const <String>[],
    sourceProductIds: const <String>[],
  );
}

ShopCatalogEntry _catalog({
  required String shopCode,
}) {
  final now = DateTime.now();
  return ShopCatalogEntry(
    shopCode: shopCode,
    shopName: 'Catalog $shopCode',
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    representativeImageUrl: '',
    primaryGenreId: '',
    primaryGenreName: '',
    genreIds: const <String>[],
    genreNames: const <String>[],
    itemCountInCatalog: 1,
    safeItemCount: 1,
    itemsWithImage: 1,
    itemsWithPrice: 1,
    averageReviewAverage: 4.0,
    maxReviewCount: 10,
    averagePrice: 1000,
    minPrice: 1000,
    maxPrice: 1000,
    source: ShopCatalogSource.shopDiscovery,
    sourceTrust: ShopCatalogSourceTrust.medium,
    lastFetchedAt: now,
    lastValidatedAt: now,
    lastAccessedAt: now,
    cacheTtlSeconds: 3600,
    qualityStatus: const ShopCatalogQualityStatus(
      hasRepresentativeImage: false,
      hasShopUrl: true,
      hasPrimaryGenre: false,
      safe: true,
    ),
    aliases: <String>[shopCode],
    sampleProductIds: const <String>[],
  );
}

void main() {
  group('ShopDiscoveryPoolComparator', () {
    test('shopCode overlap を数えられる', () {
      final result = ShopDiscoveryPoolComparator.compare(
        apiSummaries: <ShopDiscoverySummary>[
          _apiSummary(shopCode: 'a'),
          _apiSummary(shopCode: 'b'),
        ],
        poolCandidates: <ShopPoolCandidate>[
          _pool(shopCode: 'b'),
          _pool(shopCode: 'c'),
        ],
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(result.overlapByShopCodeCount, 1);
    });

    test('apiOnly / poolOnly が正しく出る', () {
      final result = ShopDiscoveryPoolComparator.compare(
        apiSummaries: <ShopDiscoverySummary>[_apiSummary(shopCode: 'a')],
        poolCandidates: <ShopPoolCandidate>[_pool(shopCode: 'b')],
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(result.apiOnlyCount, 1);
      expect(result.poolOnlyCount, 1);
    });

    test('catalog entries も比較できる', () {
      final result = ShopDiscoveryPoolComparator.compare(
        apiSummaries: <ShopDiscoverySummary>[_apiSummary(shopCode: 'a')],
        poolCandidates: <ShopPoolCandidate>[_pool(shopCode: 'a')],
        catalogEntries: <ShopCatalogEntry>[_catalog(shopCode: 'x')],
      );
      expect(result.catalogShopCount, 1);
      expect(result.catalogOnlyCount, 1);
    });

    test('shopCode 空は比較対象外', () {
      final result = ShopDiscoveryPoolComparator.compare(
        apiSummaries: <ShopDiscoverySummary>[
          _apiSummary(shopCode: ''),
          _apiSummary(shopCode: 'a'),
        ],
        poolCandidates: <ShopPoolCandidate>[_pool(shopCode: '')],
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(result.apiSummaryCount, 1);
      expect(result.poolCandidateCount, 0);
    });

    test('poolCandidateCount が0でも落ちない', () {
      final result = ShopDiscoveryPoolComparator.compare(
        apiSummaries: <ShopDiscoverySummary>[_apiSummary(shopCode: 'a')],
        poolCandidates: const <ShopPoolCandidate>[],
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(result.poolCandidateCount, 0);
    });

    test('catalogShopCount が0でも落ちない', () {
      final result = ShopDiscoveryPoolComparator.compare(
        apiSummaries: const <ShopDiscoverySummary>[],
        poolCandidates: <ShopPoolCandidate>[_pool(shopCode: 'a')],
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(result.catalogShopCount, 0);
    });

    test('savedShopCodes を渡すと savedExcludedCount が出る', () {
      final result = ShopDiscoveryPoolComparator.compare(
        apiSummaries: const <ShopDiscoverySummary>[],
        poolCandidates: <ShopPoolCandidate>[
          _pool(shopCode: 'saved'),
          _pool(shopCode: 'other'),
        ],
        catalogEntries: const <ShopCatalogEntry>[],
        savedShopCodes: const <String>{'saved'},
      );
      expect(result.savedExcludedCount, 1);
      expect(result.poolCandidateCountBeforeSavedExclude, 2);
      expect(result.poolCandidateCountAfterSavedExclude, 1);
    });

    test('overlapRate が計算される', () {
      final result = ShopDiscoveryPoolComparator.compare(
        apiSummaries: <ShopDiscoverySummary>[
          _apiSummary(shopCode: 'a'),
          _apiSummary(shopCode: 'b'),
        ],
        poolCandidates: <ShopPoolCandidate>[
          _pool(shopCode: 'a'),
        ],
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(result.overlapRate, 0.5);
    });

    test('poolHasEnoughCandidatesForDisplay が10件以上で true', () {
      final pool = List<ShopPoolCandidate>.generate(
        10,
        (i) => _pool(shopCode: 's$i'),
      );
      final result = ShopDiscoveryPoolComparator.compare(
        apiSummaries: const <ShopDiscoverySummary>[],
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(result.poolHasEnoughCandidatesForDisplay, isTrue);
    });

    test('top*Shops が最大3件に制限される', () {
      final result = ShopDiscoveryPoolComparator.compare(
        apiSummaries: <ShopDiscoverySummary>[
          _apiSummary(shopCode: 'a'),
          _apiSummary(shopCode: 'b'),
          _apiSummary(shopCode: 'c'),
          _apiSummary(shopCode: 'd'),
        ],
        poolCandidates: <ShopPoolCandidate>[
          _pool(shopCode: 'a'),
          _pool(shopCode: 'b'),
          _pool(shopCode: 'c'),
          _pool(shopCode: 'x'),
        ],
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(result.topApiShops.length, lessThanOrEqualTo(3));
      expect(result.topPoolShops.length, lessThanOrEqualTo(3));
      expect(result.topOverlapShops.length, lessThanOrEqualTo(3));
    });

    test('API summaries の並び順と件数を変更しない', () {
      final api = <ShopDiscoverySummary>[
        _apiSummary(shopCode: 'a'),
        _apiSummary(shopCode: 'b'),
      ];
      final before = api.map((e) => e.shopKey).toList(growable: false);
      ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: const <ShopPoolCandidate>[],
        catalogEntries: const <ShopCatalogEntry>[],
      );
      final after = api.map((e) => e.shopKey).toList(growable: false);
      expect(after, before);
    });

    test('dedupe signature が同一なら同じ値になる', () {
      final api = <ShopDiscoverySummary>[
        _apiSummary(shopCode: 'a'),
        _apiSummary(shopCode: 'b'),
      ];
      final sig1 = ShopDiscoveryPoolComparator.buildDedupeSignature(
        mode: 'shopDiscovery',
        keyword: '水筒',
        apiSummaries: api,
        poolCandidateCount: 12,
        catalogShopCount: 5,
      );
      final sig2 = ShopDiscoveryPoolComparator.buildDedupeSignature(
        mode: 'shopDiscovery',
        keyword: '水筒',
        apiSummaries: api,
        poolCandidateCount: 12,
        catalogShopCount: 5,
      );
      expect(sig1, sig2);
    });

    test('dedupe signature が違えば別値になる', () {
      final api = <ShopDiscoverySummary>[_apiSummary(shopCode: 'a')];
      final sig1 = ShopDiscoveryPoolComparator.buildDedupeSignature(
        mode: 'shopDiscovery',
        keyword: '水筒',
        apiSummaries: api,
        poolCandidateCount: 12,
        catalogShopCount: 5,
      );
      final sig2 = ShopDiscoveryPoolComparator.buildDedupeSignature(
        mode: 'shopDiscovery',
        keyword: 'コーヒー',
        apiSummaries: api,
        poolCandidateCount: 12,
        catalogShopCount: 5,
      );
      expect(sig1 == sig2, isFalse);
    });
  });
}
