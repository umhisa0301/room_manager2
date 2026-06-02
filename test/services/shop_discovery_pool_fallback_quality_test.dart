import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/shop_discovery_summary.dart';
import 'package:room_manager2/models/shop_pool_candidate.dart';
import 'package:room_manager2/services/shop_discovery_pool_fallback.dart';
import 'package:room_manager2/services/shop_discovery_pool_quality_report.dart';
import 'package:room_manager2/services/shop_pool_keyword_relevance.dart';

ShopDiscoverySummary _summary({
  required String code,
  required String name,
  required double score,
  required double avgReview,
  required int maxReviewCount,
  required int hitItems,
  required int rank,
  String imageUrl =
      'https://thumbnail.image.rakuten.co.jp/@0_mall/test/cabinet/a.jpg',
  String shopUrl = 'https://www.rakuten.co.jp/test-shop/',
}) {
  return ShopDiscoverySummary(
    shopKey: code,
    shopName: name,
    shopUrl: shopUrl,
    hitItemCount: hitItems,
    maxReviewCount: maxReviewCount,
    avgReviewAverage: avgReview,
    discoveryScore: score,
    representativeItems: <ShopRepresentativeItem>[
      ShopRepresentativeItem(
        itemName: '$name item',
        imageUrl: imageUrl,
        itemUrl: shopUrl,
      ),
    ],
    origin: 'shopPoolFallback',
    discoveryKeyword: '水筒',
    discoveryRank: rank,
  );
}

ShopPoolCandidate _candidate({required String code, required String genre}) {
  return ShopPoolCandidate(
    shopCode: code,
    shopName: code,
    shopUrl: 'https://www.rakuten.co.jp/$code/',
    representativeImageUrl:
        'https://thumbnail.image.rakuten.co.jp/@0_mall/test/cabinet/$code.jpg',
    primaryGenreId: '100',
    primaryGenreName: genre,
    itemCount: 5,
    safeItemCount: 5,
    itemsWithImage: 5,
    itemsWithPrice: 5,
    averageReviewAverage: 4.2,
    maxReviewCount: 100,
    averagePrice: 2000,
    minPrice: 1000,
    maxPrice: 3000,
    score: 200,
    sampleProductIds: const <String>[],
    sourceGenres: const <String>[],
    sourceProductIds: const <String>[],
  );
}

ShopDiscoveryPoolFallbackResult _fallback({
  required bool usedFallback,
  required List<ShopDiscoverySummary> summaries,
  required List<ShopPoolCandidate> displayedCandidates,
  ShopPoolFallbackRelevanceStats? relevanceStats,
  Map<String, ShopPoolKeywordRelevanceResult>? relevanceByShopCode,
}) {
  final byCode = relevanceByShopCode ??
      <String, ShopPoolKeywordRelevanceResult>{
        for (final s in summaries)
          s.shopKey: const ShopPoolKeywordRelevanceResult(
            level: ShopPoolKeywordMatchLevel.strong,
            matchedBy: 'itemName',
            relevanceScore: 1,
            isUnknownGenre: false,
          ),
      };
  return ShopDiscoveryPoolFallbackResult(
    summaries: summaries,
    usedFallback: usedFallback,
    reason: 'apiFailed',
    poolCandidateCount: 156,
    convertedCount: summaries.length,
    savedExcludedCount: 2,
    skippedInvalidCount: 1,
    unsafeExcludedCount: 3,
    keyword: '水筒',
    fallbackRankByShopCode: {
      for (final s in summaries) s.shopKey: s.discoveryRank ?? 0,
    },
    displayedCandidates: displayedCandidates,
    relevanceByShopCode: byCode,
    relevanceStats:
        relevanceStats ??
        ShopPoolFallbackRelevanceStats(
          strongCount: summaries.length,
          mediumCount: 0,
          weakCount: 0,
          noMatchCount: 0,
          unknownGenreCount: 0,
          excludedNoRelevance: 0,
          demotedWeak: 0,
          relevanceQuality: ShopPoolFallbackRelevanceQuality.excellent,
        ),
  );
}

void main() {
  group('ShopDiscoveryPoolFallbackQualityReport', () {
    test('fallback quality サマリを計算できる', () {
      final summaries = <ShopDiscoverySummary>[
        _summary(
          code: 's1',
          name: 'ショップ1',
          score: 310.2,
          avgReview: 4.7,
          maxReviewCount: 2172,
          hitItems: 5,
          rank: 1,
        ),
        _summary(
          code: 's2',
          name: 'ショップ2',
          score: 220.0,
          avgReview: 4.5,
          maxReviewCount: 500,
          hitItems: 4,
          rank: 2,
        ),
        _summary(
          code: 's3',
          name: 'ショップ3',
          score: 180.4,
          avgReview: 4.2,
          maxReviewCount: 300,
          hitItems: 3,
          rank: 3,
        ),
      ];
      final report = ShopPoolFallbackQualityReport.fromFallback(
        _fallback(
          usedFallback: true,
          summaries: summaries,
          displayedCandidates: <ShopPoolCandidate>[
            _candidate(code: 's1', genre: '水・ソフトドリンク'),
            _candidate(code: 's2', genre: '水・ソフトドリンク'),
            _candidate(code: 's3', genre: 'キッチン用品'),
          ],
        ),
      );
      expect(report, isNotNull);
      expect(report!.fallbackCount, 3);
      expect(report.keywordMatchStrong, 3);
      expect(report.withImageCount, 3);
    });

    test('qualityLevel を relevance 込みで判定できる', () {
      expect(
        ShopPoolFallbackQualityReport.evaluateQualityLevel(
          fallbackCount: 10,
          avgReview: 4.5,
          withImageCount: 10,
          keywordStrongOrMediumMatchCount: 7,
          unknownGenreRatio: 0.2,
          topGenres: const <String>['水筒:5', 'ボトル:5'],
        ),
        ShopPoolFallbackQualityLevel.excellent,
      );
      expect(
        ShopPoolFallbackQualityReport.evaluateQualityLevel(
          fallbackCount: 10,
          avgReview: 4.5,
          withImageCount: 10,
          keywordStrongOrMediumMatchCount: 2,
          unknownGenreRatio: 1.0,
          topGenres: const <String>['unknown:10'],
        ),
        isNot(ShopPoolFallbackQualityLevel.excellent),
      );
      expect(
        ShopPoolFallbackQualityReport.evaluateQualityLevel(
          fallbackCount: 6,
          avgReview: 4.1,
          withImageCount: 5,
          keywordStrongOrMediumMatchCount: 3,
          unknownGenreRatio: 0.3,
        ),
        ShopPoolFallbackQualityLevel.good,
      );
      expect(
        ShopPoolFallbackQualityReport.evaluateQualityLevel(
          fallbackCount: 3,
          avgReview: 3.1,
          withImageCount: 1,
          keywordStrongOrMediumMatchCount: 0,
          unknownGenreRatio: 1.0,
        ),
        ShopPoolFallbackQualityLevel.weak,
      );
    });

    test('noimage は withImageCount に含めない', () {
      final report = ShopPoolFallbackQualityReport.fromFallback(
        _fallback(
          usedFallback: true,
          summaries: <ShopDiscoverySummary>[
            _summary(
              code: 's1',
              name: 'ショップ1',
              score: 100,
              avgReview: 4.0,
              maxReviewCount: 10,
              hitItems: 2,
              rank: 1,
              imageUrl: 'https://thumbnail.image.rakuten.co.jp/noimage.jpg',
            ),
          ],
          displayedCandidates: <ShopPoolCandidate>[
            _candidate(code: 's1', genre: 'ジャンル'),
          ],
        ),
      );
      expect(report!.withImageCount, 0);
    });

    test('TOPログに relevance/matchedBy が入る', () {
      final report = ShopPoolFallbackQualityReport.fromFallback(
        _fallback(
          usedFallback: true,
          summaries: <ShopDiscoverySummary>[
            _summary(
              code: 's1',
              name: 'ボトル店',
              score: 200,
              avgReview: 4.5,
              maxReviewCount: 100,
              hitItems: 3,
              rank: 1,
            ),
          ],
          displayedCandidates: <ShopPoolCandidate>[
            _candidate(code: 's1', genre: 'キッチン'),
          ],
          relevanceByShopCode: <String, ShopPoolKeywordRelevanceResult>{
            's1': const ShopPoolKeywordRelevanceResult(
              level: ShopPoolKeywordMatchLevel.strong,
              matchedBy: 'itemName',
              relevanceScore: 2,
              isUnknownGenre: false,
            ),
          },
        ),
      );
      expect(report!.topEntries.first.toLogString(), contains('relevance:strong'));
      expect(report.topEntries.first.toLogString(), contains('matchedBy:itemName'));
    });

    test('通常API成功時は fallback quality report を作らない', () {
      final report = ShopPoolFallbackQualityReport.fromFallback(
        _fallback(
          usedFallback: false,
          summaries: <ShopDiscoverySummary>[
            _summary(
              code: 'api-1',
              name: 'APIショップ',
              score: 300,
              avgReview: 4.6,
              maxReviewCount: 500,
              hitItems: 5,
              rank: 1,
            ),
          ],
          displayedCandidates: <ShopPoolCandidate>[
            _candidate(code: 'api-1', genre: '家電'),
          ],
        ),
      );
      expect(report, isNull);
    });
  });
}
