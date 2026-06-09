import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/shop_catalog_entry.dart';
import 'package:room_manager2/models/shop_discovery_summary.dart';
import 'package:room_manager2/models/shop_pool_candidate.dart';
import 'package:room_manager2/services/shop_discovery_pool_api_compare.dart';
import 'package:room_manager2/services/shop_discovery_pool_comparator.dart';
import 'package:room_manager2/services/shop_discovery_pool_fallback.dart';
import 'package:room_manager2/services/shop_discovery_pool_quality_report.dart';
import 'package:room_manager2/services/shop_pool_keyword_relevance.dart';

ShopDiscoverySummary _apiSummary({
  required String shopCode,
  double score = 300,
  int hitItems = 5,
  double avgReview = 4.6,
}) {
  return ShopDiscoverySummary(
    shopKey: shopCode,
    shopName: 'API $shopCode',
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    hitItemCount: hitItems,
    maxReviewCount: 500,
    avgReviewAverage: avgReview,
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
  double score = 250,
}) {
  return ShopPoolCandidate(
    shopCode: shopCode,
    shopName: 'Pool $shopCode',
    shopUrl: 'https://www.rakuten.co.jp/$shopCode/',
    representativeImageUrl:
        'https://thumbnail.image.rakuten.co.jp/@0_mall/$shopCode/cabinet/a.jpg',
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

ShopPoolFallbackQualityReport _strongPoolQuality({
  int poolTopCount = 10,
  double avgHitItemCount = 4.0,
}) {
  final summaries = List<ShopDiscoverySummary>.generate(
    poolTopCount,
    (i) => ShopDiscoverySummary(
      shopKey: 'pool-$i',
      shopName: 'Pool Shop $i',
      shopUrl: 'https://www.rakuten.co.jp/pool-$i/',
      hitItemCount: avgHitItemCount.round().clamp(2, 10),
      maxReviewCount: 500,
      avgReviewAverage: 4.6,
      discoveryScore: 400 - i.toDouble(),
      representativeItems: <ShopRepresentativeItem>[
        ShopRepresentativeItem(
          itemName: 'item',
          imageUrl:
              'https://thumbnail.image.rakuten.co.jp/@0_mall/pool-$i/cabinet/a.jpg',
          itemUrl: 'https://www.rakuten.co.jp/pool-$i/',
        ),
      ],
      discoveryRank: i + 1,
    ),
  );
  final candidates = List<ShopPoolCandidate>.generate(
    poolTopCount,
    (i) => _poolCandidate(shopCode: 'pool-$i', itemCount: 5),
  );
  return ShopPoolFallbackQualityReport.fromCompareAudit(
    ShopDiscoveryPoolCompareAuditData(
      keyword: '水筒',
      poolTopSummaries: summaries,
      displayedCandidates: candidates,
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
      poolCandidateCount: 120,
      skippedInvalidCount: 0,
    ),
  )!;
}

void main() {
  group('ShopDiscoveryApiQualitySummary', () {
    test('API summaries から品質サマリを計算できる', () {
      final q =
          ShopDiscoveryApiQualitySummary.fromSummaries(<ShopDiscoverySummary>[
            _apiSummary(shopCode: 'a', score: 300, hitItems: 5),
            _apiSummary(shopCode: 'b', score: 200, hitItems: 3),
          ]);
      expect(q.count, 2);
      expect(q.avgScore, 250);
      expect(q.avgHitItemCount, 4);
      expect(q.withImageCount, 2);
      expect(q.withShopUrlCount, 2);
    });
  });

  group('ShopDiscoveryPoolComparator overlap', () {
    test('overlapRate / apiOnly / poolOnly が計算できる', () {
      final result = ShopDiscoveryPoolComparator.compare(
        apiSummaries: <ShopDiscoverySummary>[
          _apiSummary(shopCode: 'a'),
          _apiSummary(shopCode: 'b'),
        ],
        poolCandidates: <ShopPoolCandidate>[
          _poolCandidate(shopCode: 'a'),
          _poolCandidate(shopCode: 'c'),
        ],
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(result.overlapRate, 0.5);
      expect(result.apiOnlyCount, 1);
      expect(result.poolOnlyCount, 1);
    });
  });

  group('ShopDiscoveryPoolApiCompare usability flags', () {
    test('poolQuality good + overlap高なら replacement候補', () {
      final pool = _strongPoolQuality();
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: List<ShopDiscoverySummary>.generate(
          10,
          (i) => _apiSummary(shopCode: 'api-$i'),
        ),
        poolCandidates: List<ShopPoolCandidate>.generate(
          120,
          (i) => _poolCandidate(shopCode: 'pool-$i'),
        ),
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(
        ShopDiscoveryPoolApiCompare.evaluateWouldBeUsableAsReplacement(
          comparison: comparison.copyWithOverlapRate(0.6),
          poolQuality: pool,
          apiTopGenres: const <String>[],
        ),
        isTrue,
      );
    });

    test('poolQuality weak なら supplement/replacement false', () {
      final weakPool = ShopPoolFallbackQualityReport.fromCompareAudit(
        ShopDiscoveryPoolCompareAuditData(
          keyword: '水筒',
          poolTopSummaries: List<ShopDiscoverySummary>.generate(
            9,
            (i) => ShopDiscoverySummary(
              shopKey: 'thin-$i',
              shopName: 'Thin $i',
              shopUrl: 'https://www.rakuten.co.jp/thin-$i/',
              hitItemCount: 1,
              maxReviewCount: 100,
              avgReviewAverage: 4.5,
              discoveryScore: 200,
              representativeItems: <ShopRepresentativeItem>[
                ShopRepresentativeItem(
                  itemName: 'x',
                  imageUrl:
                      'https://thumbnail.image.rakuten.co.jp/@0_mall/x/cabinet/a.jpg',
                  itemUrl: 'https://www.rakuten.co.jp/thin-$i/',
                ),
              ],
            ),
          ),
          displayedCandidates: List<ShopPoolCandidate>.generate(
            9,
            (i) => _poolCandidate(shopCode: 'thin-$i', itemCount: 1, genre: ''),
          ),
          relevanceByShopCode: const <String, ShopPoolKeywordRelevanceResult>{},
          relevanceStats: ShopPoolFallbackRelevanceStats.empty,
          poolCandidateCount: 90,
          skippedInvalidCount: 0,
        ),
      )!;
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: <ShopDiscoverySummary>[_apiSummary(shopCode: 'a')],
        poolCandidates: List<ShopPoolCandidate>.generate(
          90,
          (i) => _poolCandidate(shopCode: 'thin-$i', itemCount: 1),
        ),
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(
        ShopDiscoveryPoolApiCompare.evaluateWouldBeUsableAsSupplement(
          comparison: comparison,
          poolQuality: weakPool,
        ),
        isFalse,
      );
      expect(
        ShopDiscoveryPoolApiCompare.evaluateWouldBeUsableAsReplacement(
          comparison: comparison.copyWithOverlapRate(0.8),
          poolQuality: weakPool,
          apiTopGenres: const <String>[],
        ),
        isFalse,
      );
    });

    test('wouldBeUsableAsSupplement は overlap または厚みで true になり得る', () {
      final pool = _strongPoolQuality();
      final lowOverlap = ShopDiscoveryPoolComparator.compare(
        apiSummaries: List<ShopDiscoverySummary>.generate(
          10,
          (i) => _apiSummary(shopCode: 'only-api-$i'),
        ),
        poolCandidates: List<ShopPoolCandidate>.generate(
          120,
          (i) => _poolCandidate(shopCode: 'pool-$i'),
        ),
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(lowOverlap.overlapRate, lessThan(0.3));
      expect(
        ShopDiscoveryPoolApiCompare.evaluateWouldBeUsableAsSupplement(
          comparison: lowOverlap,
          poolQuality: pool,
        ),
        isTrue,
      );
    });
  });

  group('ShopDiscoveryPoolApiCompare.build', () {
    test('repository なしでも比較結果と willUsePoolForUi=false を返す', () {
      final result = ShopDiscoveryPoolApiCompare.build(
        keyword: '水筒',
        apiSummaries: <ShopDiscoverySummary>[
          _apiSummary(shopCode: 'atlas-online'),
        ],
        poolCandidates: List<ShopPoolCandidate>.generate(
          12,
          (i) => _poolCandidate(shopCode: 'pool-$i'),
        ),
        catalogEntries: const <ShopCatalogEntry>[],
        repository: null,
      );
      expect(result.comparison.apiSummaryCount, 1);
      expect(result.poolQuality, isNull);
      expect(result.wouldBeUsableAsSupplement, isFalse);
      expect(result.wouldBeUsableAsReplacement, isFalse);
      expect(result.buildQualityLogLine(), contains('willUsePoolForUi=false'));
      expect(result.buildQualityLogLine(), contains('willSkipApi=false'));
    });

    test('TOP比較ログ用データが最大3件に制限される', () {
      final result = ShopDiscoveryPoolApiCompare.build(
        keyword: '水筒',
        apiSummaries: List<ShopDiscoverySummary>.generate(
          5,
          (i) => _apiSummary(shopCode: 'api-$i', score: 500.0 - i),
        ),
        poolCandidates: const <ShopPoolCandidate>[],
        catalogEntries: const <ShopCatalogEntry>[],
        repository: null,
        topLogLimit: 3,
      );
      expect(result.apiTopEntries.length, lessThanOrEqualTo(3));
      expect(result.poolTopEntries.length, lessThanOrEqualTo(3));
    });

    test('品質ログに keyword と poolQualityLevel が含まれる', () {
      final line = ShopDiscoveryPoolApiCompare.build(
        keyword: 'コーヒー',
        apiSummaries: <ShopDiscoverySummary>[_apiSummary(shopCode: 'x')],
        poolCandidates: const <ShopPoolCandidate>[],
        catalogEntries: const <ShopCatalogEntry>[],
        repository: null,
      ).buildQualityLogLine();
      expect(line, contains('keyword=コーヒー'));
      expect(line, contains('poolQualityLevel=insufficient'));
      expect(line, contains('[SHOP_DISCOVERY_POOL_API_COMPARE_QUALITY]'));
    });

    test('TOPログは apiTop1 / poolTop1 形式', () {
      final line = ShopDiscoveryPoolApiCompare.build(
        keyword: '水筒',
        apiSummaries: <ShopDiscoverySummary>[
          _apiSummary(shopCode: 'atlas-online', score: 436.7, hitItems: 13),
        ],
        poolCandidates: const <ShopPoolCandidate>[],
        catalogEntries: const <ShopCatalogEntry>[],
        repository: null,
      ).buildTopLogLine();
      expect(line, contains('[SHOP_DISCOVERY_POOL_API_COMPARE_TOP]'));
      expect(line, contains('apiTop1=shopCode:atlas-online'));
      expect(line, contains('hitItems:13'));
    });
  });
}

extension _ComparisonOverlap on ShopDiscoveryPoolComparisonResult {
  ShopDiscoveryPoolComparisonResult copyWithOverlapRate(double rate) {
    final apiCount = apiSummaryCount;
    final overlapCount = (apiCount * rate).round();
    return ShopDiscoveryPoolComparisonResult(
      apiSummaryCount: apiSummaryCount,
      poolCandidateCount: poolCandidateCount,
      poolCandidateCountBeforeSavedExclude:
          poolCandidateCountBeforeSavedExclude,
      poolCandidateCountAfterSavedExclude: poolCandidateCountAfterSavedExclude,
      catalogShopCount: catalogShopCount,
      overlapByShopCodeCount: overlapCount,
      apiOnlyCount: apiCount - overlapCount,
      poolOnlyCount: poolOnlyCount,
      catalogOnlyCount: catalogOnlyCount,
      savedExcludedCount: savedExcludedCount,
      topApiShops: topApiShops,
      topPoolShops: topPoolShops,
      topOverlapShops: topOverlapShops,
      missingReasonSummary: missingReasonSummary,
      poolTopScoreMax: poolTopScoreMax,
      poolTopScoreMin: poolTopScoreMin,
      apiTopScoreMax: apiTopScoreMax,
      catalogShopTotal: catalogShopTotal,
      poolHasEnoughCandidatesForDisplay: poolHasEnoughCandidatesForDisplay,
      overlapRate: rate,
    );
  }
}
