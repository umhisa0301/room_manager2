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

ShopPoolCandidate _candidate({
  required String code,
  required String genre,
  String primaryGenreId = '',
  int itemCount = 5,
}) {
  return ShopPoolCandidate(
    shopCode: code,
    shopName: code,
    shopUrl: 'https://www.rakuten.co.jp/$code/',
    representativeImageUrl:
        'https://thumbnail.image.rakuten.co.jp/@0_mall/test/cabinet/$code.jpg',
    primaryGenreId: primaryGenreId,
    primaryGenreName: genre,
    itemCount: itemCount,
    safeItemCount: itemCount,
    itemsWithImage: itemCount,
    itemsWithPrice: itemCount,
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
  final byCode =
      relevanceByShopCode ??
      <String, ShopPoolKeywordRelevanceResult>{
        for (final s in summaries)
          s.shopKey: ShopPoolKeywordRelevanceResult(
            level: ShopPoolKeywordMatchLevel.strong,
            matchedBy: 'itemName',
            relevanceScore: 1,
            isUnknownGenre: displayedCandidates
                .firstWhere((c) => c.shopCode == s.shopKey)
                .primaryGenreName
                .trim()
                .isEmpty,
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
          unknownGenreCount: summaries.length,
          excludedNoRelevance: 0,
          demotedWeak: 0,
          relevanceQuality: ShopPoolFallbackRelevanceQuality.good,
        ),
  );
}

void main() {
  group('ShopDiscoveryPoolFallbackQualityReport', () {
    test('strong=9 でも hitItemCount=1 だらけなら qualityLevel=weak', () {
      final summaries = List<ShopDiscoverySummary>.generate(
        9,
        (i) => _summary(
          code: 'thin-$i',
          name: '薄いショップ$i',
          score: 300 - i.toDouble(),
          avgReview: 4.55,
          maxReviewCount: 100,
          hitItems: 1,
          rank: i + 1,
        ),
      );
      final candidates = List<ShopPoolCandidate>.generate(
        9,
        (i) => _candidate(
          code: 'thin-$i',
          genre: '',
          primaryGenreId: '',
          itemCount: 1,
        ),
      );
      final report = ShopPoolFallbackQualityReport.fromFallback(
        _fallback(
          usedFallback: true,
          summaries: summaries,
          displayedCandidates: candidates,
        ),
      );
      expect(report, isNotNull);
      expect(report!.hitItemCount1, 9);
      expect(report.hitItemCount2Plus, 0);
      expect(report.avgHitItemCount, 1.0);
      expect(report.unknownGenreRatio, 1.0);
      expect(report.thinCandidateCount, 9);
      expect(report.depthQuality, ShopPoolFallbackDepthQuality.weak);
      expect(report.qualityLevel, ShopPoolFallbackQualityLevel.weak);
      expect(report.qualityLevel, isNot(ShopPoolFallbackQualityLevel.good));
    });

    test('unknownGenreRatio=1.0 なら excellent/good にならない', () {
      expect(
        ShopPoolFallbackQualityReport.evaluateDepthQuality(
          fallbackCount: 9,
          avgHitItemCount: 1.0,
          hitItemCount2Plus: 0,
          unknownGenreRatio: 1.0,
          thinCandidateCount: 9,
        ),
        ShopPoolFallbackDepthQuality.weak,
      );
      expect(
        ShopPoolFallbackQualityReport.evaluateOverallQualityLevel(
          relevanceQuality: ShopPoolFallbackRelevanceQuality.good,
          depthQuality: ShopPoolFallbackDepthQuality.weak,
          displayQuality: ShopPoolFallbackDisplayQuality.good,
          unknownGenreRatio: 1.0,
          avgHitItemCount: 1.0,
        ),
        ShopPoolFallbackQualityLevel.weak,
      );
    });

    test('hitItemCount2Plus が多い場合は depthQuality good 以上になり得る', () {
      expect(
        ShopPoolFallbackQualityReport.evaluateDepthQuality(
          fallbackCount: 6,
          avgHitItemCount: 2.5,
          hitItemCount2Plus: 6,
          unknownGenreRatio: 0.2,
          thinCandidateCount: 0,
        ),
        ShopPoolFallbackDepthQuality.good,
      );
    });

    test('厚み・ジャンルが十分な場合のみ excellent に近づく', () {
      expect(
        ShopPoolFallbackQualityReport.evaluateDepthQuality(
          fallbackCount: 10,
          avgHitItemCount: 2.2,
          hitItemCount2Plus: 8,
          unknownGenreRatio: 0.3,
          thinCandidateCount: 1,
        ),
        ShopPoolFallbackDepthQuality.excellent,
      );
      expect(
        ShopPoolFallbackQualityReport.evaluateOverallQualityLevel(
          relevanceQuality: ShopPoolFallbackRelevanceQuality.excellent,
          depthQuality: ShopPoolFallbackDepthQuality.excellent,
          displayQuality: ShopPoolFallbackDisplayQuality.excellent,
          unknownGenreRatio: 0.3,
          avgHitItemCount: 2.2,
        ),
        ShopPoolFallbackQualityLevel.excellent,
      );
    });

    test('hitItemCount1 / hitItemCount2Plus / thinCandidateCount が正しい', () {
      final report = ShopPoolFallbackQualityReport.fromFallback(
        _fallback(
          usedFallback: true,
          summaries: <ShopDiscoverySummary>[
            _summary(
              code: 'a',
              name: 'A',
              score: 100,
              avgReview: 4.0,
              maxReviewCount: 10,
              hitItems: 1,
              rank: 1,
            ),
            _summary(
              code: 'b',
              name: 'B',
              score: 90,
              avgReview: 4.0,
              maxReviewCount: 10,
              hitItems: 3,
              rank: 2,
            ),
          ],
          displayedCandidates: <ShopPoolCandidate>[
            _candidate(code: 'a', genre: '', itemCount: 1),
            _candidate(code: 'b', genre: 'キッチン', itemCount: 3),
          ],
          relevanceByShopCode: <String, ShopPoolKeywordRelevanceResult>{
            'a': const ShopPoolKeywordRelevanceResult(
              level: ShopPoolKeywordMatchLevel.strong,
              matchedBy: 'itemName',
              relevanceScore: 1,
              isUnknownGenre: true,
            ),
            'b': const ShopPoolKeywordRelevanceResult(
              level: ShopPoolKeywordMatchLevel.strong,
              matchedBy: 'itemName',
              relevanceScore: 1,
              isUnknownGenre: false,
            ),
          },
          relevanceStats: const ShopPoolFallbackRelevanceStats(
            strongCount: 2,
            mediumCount: 0,
            weakCount: 0,
            noMatchCount: 0,
            unknownGenreCount: 1,
            excludedNoRelevance: 0,
            demotedWeak: 0,
            relevanceQuality: ShopPoolFallbackRelevanceQuality.weak,
          ),
        ),
      );
      expect(report!.hitItemCount1, 1);
      expect(report.hitItemCount2Plus, 1);
      expect(report.thinCandidateCount, 1);
    });

    test('displayQuality は画像・URL・レビューから判定される', () {
      expect(
        ShopPoolFallbackQualityReport.evaluateDisplayQuality(
          fallbackCount: 5,
          avgReview: 4.5,
          withImageCount: 5,
          withShopUrlCount: 5,
        ),
        ShopPoolFallbackDisplayQuality.excellent,
      );
      expect(
        ShopPoolFallbackQualityReport.evaluateDisplayQuality(
          fallbackCount: 5,
          avgReview: 3.0,
          withImageCount: 2,
          withShopUrlCount: 5,
        ),
        ShopPoolFallbackDisplayQuality.weak,
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
            _candidate(code: 's1', genre: 'ジャンル', itemCount: 2),
          ],
        ),
      );
      expect(report!.withImageCount, 0);
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
