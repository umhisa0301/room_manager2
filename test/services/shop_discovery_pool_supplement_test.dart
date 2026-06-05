import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/shop_catalog_entry.dart';
import 'package:room_manager2/models/shop_discovery_summary.dart';
import 'package:room_manager2/models/shop_pool_candidate.dart';
import 'package:room_manager2/services/shop_discovery_pool_api_compare.dart';
import 'package:room_manager2/services/shop_discovery_pool_comparator.dart';
import 'package:room_manager2/services/shop_discovery_pool_fallback.dart';
import 'package:room_manager2/services/shop_discovery_pool_quality_report.dart';
import 'package:room_manager2/services/shop_discovery_pool_supplement.dart';
import 'package:room_manager2/services/shop_pool_keyword_relevance.dart';

ShopDiscoverySummary _apiSummary({
  required String shopCode,
  double score = 300,
  int hitItems = 5,
}) {
  return ShopDiscoverySummary(
    shopKey: shopCode,
    shopName: 'API $shopCode',
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    hitItemCount: hitItems,
    maxReviewCount: 500,
    avgReviewAverage: 4.6,
    discoveryScore: score,
    representativeItems: <ShopRepresentativeItem>[
      ShopRepresentativeItem(
        itemName: 'item',
        imageUrl:
            'https://thumbnail.image.rakuten.co.jp/@0_mall/$shopCode/cabinet/a.jpg',
        itemUrl: 'https://www.rakuten.co.jp/$shopCode/',
      ),
    ],
  );
}

ShopPoolCandidate _poolCandidate({
  required String shopCode,
  String genre = '大人用水筒・マグボトル',
  int itemCount = 5,
  double score = 290,
  String imageUrl =
      'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
}) {
  return ShopPoolCandidate(
    shopCode: shopCode,
    shopName: 'Pool $shopCode',
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    representativeImageUrl: imageUrl,
    primaryGenreId: 'g1',
    primaryGenreName: genre,
    itemCount: itemCount,
    safeItemCount: itemCount,
    itemsWithImage: itemCount,
    itemsWithPrice: itemCount,
    averageReviewAverage: 4.5,
    maxReviewCount: 600,
    averagePrice: 2000,
    minPrice: 1000,
    maxPrice: 3000,
    score: score,
    sampleProductIds: const <String>[],
    sourceGenres: const <String>[],
    sourceProductIds: const <String>[],
  );
}

ShopPoolFallbackQualityReport _goodPoolQuality({int poolCandidateCount = 120}) {
  final summaries = List<ShopDiscoverySummary>.generate(
    10,
    (i) => ShopDiscoverySummary(
      shopKey: 'pool-top-$i',
      shopName: 'Pool Top $i',
      shopUrl: 'https://www.rakuten.co.jp/pool-top-$i/',
      hitItemCount: 5,
      maxReviewCount: 500,
      avgReviewAverage: 4.6,
      discoveryScore: 400 - i.toDouble(),
      representativeItems: <ShopRepresentativeItem>[
        ShopRepresentativeItem(
          itemName: 'item',
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/pool-top-$i/cabinet/a.jpg',
          itemUrl: 'https://www.rakuten.co.jp/pool-top-$i/',
        ),
      ],
      discoveryRank: i + 1,
    ),
  );
  return ShopPoolFallbackQualityReport.fromCompareAudit(
    ShopDiscoveryPoolCompareAuditData(
      keyword: '水筒',
      poolTopSummaries: summaries,
      displayedCandidates: List<ShopPoolCandidate>.generate(
        10,
        (i) => _poolCandidate(shopCode: 'pool-top-$i'),
      ),
      relevanceByShopCode: {
        for (final s in summaries)
          s.shopKey: const ShopPoolKeywordRelevanceResult(
            level: ShopPoolKeywordMatchLevel.strong,
            matchedBy: 'itemName',
            relevanceScore: 1,
            isUnknownGenre: false,
          ),
      },
      relevanceStats: const ShopPoolFallbackRelevanceStats(
        strongCount: 10,
        mediumCount: 0,
        weakCount: 0,
        noMatchCount: 0,
        unknownGenreCount: 0,
        excludedNoRelevance: 0,
        demotedWeak: 0,
        relevanceQuality: ShopPoolFallbackRelevanceQuality.good,
      ),
      poolCandidateCount: poolCandidateCount,
      skippedInvalidCount: 0,
    ),
  )!;
}

void main() {
  group('ShopDiscoveryPoolSupplement.build', () {
    test('APIにない高品質Pool候補が supplement に選ばれる', () {
      final api = List<ShopDiscoverySummary>.generate(
        10,
        (i) => _apiSummary(shopCode: 'api-$i'),
      );
      final pool = <ShopPoolCandidate>[
        ...List<ShopPoolCandidate>.generate(
          10,
          (i) => _poolCandidate(shopCode: 'api-$i', score: 250),
        ),
        _poolCandidate(shopCode: 'tiger-online', score: 295, itemCount: 5),
      ];
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
      );
      final result = ShopDiscoveryPoolSupplement.build(
        keyword: '水筒',
        apiSummaries: api,
        poolCandidates: pool,
        comparison: comparison,
        poolQuality: _goodPoolQuality(),
      );
      expect(result.selectedSupplements.length, greaterThanOrEqualTo(1));
      expect(
        result.selectedSupplements.any((e) => e.shopCode == 'tiger-online'),
        isTrue,
      );
      expect(
        result.selectedSupplements.first.reason,
        isIn(<ShopDiscoveryPoolSupplementReason>[
          ShopDiscoveryPoolSupplementReason.strongRelevance,
          ShopDiscoveryPoolSupplementReason.highHitItemCount,
          ShopDiscoveryPoolSupplementReason.apiMissingButPoolStrong,
        ]),
      );
    });

    test('API結果に含まれるshopCodeは supplement から除外される', () {
      final api = [_apiSummary(shopCode: 'shared-shop')];
      final pool = [_poolCandidate(shopCode: 'shared-shop')];
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
      );
      final result = ShopDiscoveryPoolSupplement.build(
        keyword: '水筒',
        apiSummaries: api,
        poolCandidates: pool,
        comparison: comparison,
        poolQuality: _goodPoolQuality(poolCandidateCount: 1),
      );
      expect(result.selectedSupplements, isEmpty);
      expect(result.eligibleSupplementCount, 0);
    });

    test('relevance weak は除外される', () {
      final api = [_apiSummary(shopCode: 'api-only')];
      final pool = [
        _poolCandidate(shopCode: 'weak-shop', genre: 'その他', itemCount: 2),
      ];
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
      );
      final result = ShopDiscoveryPoolSupplement.build(
        keyword: '水筒',
        apiSummaries: api,
        poolCandidates: pool,
        comparison: comparison,
        poolQuality: _goodPoolQuality(poolCandidateCount: 1),
      );
      expect(result.selectedSupplements, isEmpty);
    });

    test('hitItemCount=1 は除外される', () {
      final api = [_apiSummary(shopCode: 'api-only')];
      final pool = [
        _poolCandidate(shopCode: 'thin-shop', itemCount: 1, score: 300),
      ];
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
      );
      final result = ShopDiscoveryPoolSupplement.build(
        keyword: '水筒',
        apiSummaries: api,
        poolCandidates: pool,
        comparison: comparison,
        poolQuality: _goodPoolQuality(poolCandidateCount: 1),
      );
      expect(result.selectedSupplements, isEmpty);
    });

    test('imageなし / shopUrlなし は除外される', () {
      final api = [_apiSummary(shopCode: 'api-only')];
      final pool = [
        _poolCandidate(shopCode: 'no-img', imageUrl: ''),
        ShopPoolCandidate(
          shopCode: 'no-url',
          shopName: 'No URL',
          shopUrl: '',
          representativeImageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/no-url/cabinet/a.jpg',
          primaryGenreId: 'g1',
          primaryGenreName: '大人用水筒・マグボトル',
          itemCount: 3,
          safeItemCount: 3,
          itemsWithImage: 3,
          itemsWithPrice: 3,
          averageReviewAverage: 4.5,
          maxReviewCount: 100,
          averagePrice: 1000,
          minPrice: 500,
          maxPrice: 2000,
          score: 280,
          sampleProductIds: const <String>[],
          sourceGenres: const <String>[],
          sourceProductIds: const <String>[],
        ),
      ];
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
      );
      final result = ShopDiscoveryPoolSupplement.build(
        keyword: '水筒',
        apiSummaries: api,
        poolCandidates: pool,
        comparison: comparison,
        poolQuality: _goodPoolQuality(poolCandidateCount: 2),
      );
      expect(result.selectedSupplements, isEmpty);
    });

    test('最大3件までに制限される', () {
      final api = [_apiSummary(shopCode: 'api-only')];
      final pool = List<ShopPoolCandidate>.generate(
        6,
        (i) => _poolCandidate(shopCode: 'extra-$i', score: 300.0 - i),
      );
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
      );
      final result = ShopDiscoveryPoolSupplement.build(
        keyword: '水筒',
        apiSummaries: api,
        poolCandidates: pool,
        comparison: comparison,
        poolQuality: _goodPoolQuality(poolCandidateCount: 6),
      );
      expect(result.selectedSupplements.length, 3);
      expect(result.eligibleSupplementCount, 6);
    });

    test('overlapRate=1.0 で API が Pool 上位を覆う場合 supplement 0', () {
      final codes = List<String>.generate(10, (i) => 'shop-$i');
      final api = codes.map((c) => _apiSummary(shopCode: c)).toList();
      final pool = codes.map((c) => _poolCandidate(shopCode: c)).toList();
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(comparison.overlapRate, 1.0);
      final result = ShopDiscoveryPoolSupplement.build(
        keyword: 'コーヒー',
        apiSummaries: api,
        poolCandidates: pool,
        comparison: comparison,
        poolQuality: _goodPoolQuality(),
      );
      expect(result.selectedSupplements, isEmpty);
      expect(result.zeroReason, 'apiAlreadyCoversPoolTop');
      expect(result.wouldShowSupplementIfEnabled, isFalse);
    });

    test('wouldShowSupplementIfEnabled と willUsePoolForUi / willSkipApi', () {
      final api = List<ShopDiscoverySummary>.generate(
        10,
        (i) => _apiSummary(shopCode: 'api-$i'),
      );
      final pool = <ShopPoolCandidate>[
        ...List<ShopPoolCandidate>.generate(
          9,
          (i) => _poolCandidate(shopCode: 'api-$i'),
        ),
        _poolCandidate(shopCode: 'bonus-shop', score: 310),
      ];
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
      );
      final result = ShopDiscoveryPoolSupplement.build(
        keyword: '水筒',
        apiSummaries: api,
        poolCandidates: pool,
        comparison: comparison,
        poolQuality: _goodPoolQuality(),
      );
      expect(result.selectedSupplements, isNotEmpty);
      expect(result.wouldShowSupplementIfEnabled, isTrue);
      expect(result.buildSummaryLogLine(), contains('willUsePoolForUi=false'));
      expect(result.buildSummaryLogLine(), contains('willSkipApi=false'));
    });

    test('保存ショップは supplement から除外される', () {
      final api = [_apiSummary(shopCode: 'api-only')];
      final pool = [_poolCandidate(shopCode: 'saved-shop')];
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
        savedShopCodes: {'saved-shop'},
      );
      final result = ShopDiscoveryPoolSupplement.build(
        keyword: '水筒',
        apiSummaries: api,
        poolCandidates: pool,
        comparison: comparison,
        poolQuality: _goodPoolQuality(poolCandidateCount: 1),
        savedShopCodes: {'saved-shop'},
      );
      expect(result.selectedSupplements, isEmpty);
    });
  });

  group('ShopDiscoveryPoolSupplement apiWeakSignal', () {
    test('apiWeakSignal / poolCouldCoverApiWeakness が計算できる', () {
      final api = List<ShopDiscoverySummary>.generate(
        8,
        (i) => _apiSummary(shopCode: 'api-$i', hitItems: 1),
      );
      final pool = List<ShopPoolCandidate>.generate(
        12,
        (i) => _poolCandidate(shopCode: 'pool-$i'),
      );
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
      );
      final poolQuality = _goodPoolQuality();
      final weak = ShopDiscoveryPoolSupplement.evaluateApiWeakSignal(
        apiSummaries: api,
        apiQuality: ShopDiscoveryApiQualitySummary.fromSummaries(api),
        comparison: comparison,
        poolShopCodes: pool.map((e) => e.shopCode).toSet(),
        apiPagesFailed: 1,
      );
      expect(weak.signal, isTrue);
      expect(weak.reason, contains('apiSummaryCountLow'));
      expect(weak.reason, contains('partialApiPagesFailed'));

      final couldCover = ShopDiscoveryPoolSupplement.evaluatePoolCouldCoverApiWeakness(
        poolQuality: poolQuality,
        comparison: comparison,
        apiWeakSignal: weak.signal,
      );
      expect(couldCover, isTrue);
    });
  });

  group('ShopDiscoveryPoolSupplement logs', () {
    test('summary / top ログ形式', () {
      final api = [_apiSummary(shopCode: 'api-a')];
      final pool = [_poolCandidate(shopCode: 'pool-b')];
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
      );
      final result = ShopDiscoveryPoolSupplement.build(
        keyword: '水筒',
        apiSummaries: api,
        poolCandidates: pool,
        comparison: comparison,
        poolQuality: _goodPoolQuality(poolCandidateCount: 1),
      );
      expect(result.buildSummaryLogLine(),
          contains('[SHOP_DISCOVERY_POOL_SUPPLEMENT_SUMMARY]'));
      expect(result.buildTopLogLine(),
          contains('[SHOP_DISCOVERY_POOL_SUPPLEMENT_TOP]'));
    });
  });
}
