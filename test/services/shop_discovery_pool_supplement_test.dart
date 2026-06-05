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
  String? shopName,
  String genre = '大人用水筒・マグボトル',
  int itemCount = 5,
  double score = 290,
  String imageUrl =
      'https://thumbnail.image.rakuten.co.jp/@0_mall/shop/cabinet/a.jpg',
}) {
  return ShopPoolCandidate(
    shopCode: shopCode,
    shopName: shopName ?? 'Pool $shopCode',
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

  group('ShopDiscoveryPoolSupplement display decision', () {
    test('overlapRate=1.0 では recommendedDisplayCount=0', () {
      final codes = List<String>.generate(10, (i) => 'shop-$i');
      final api = codes.map((c) => _apiSummary(shopCode: c)).toList();
      final pool = <ShopPoolCandidate>[
        ...codes.map((c) => _poolCandidate(shopCode: c)),
        _poolCandidate(shopCode: 'extra-pool', score: 320),
      ];
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
      expect(result.displayDecision.recommendedDisplayCount, 0);
      expect(result.displayDecision.decision, 'hide');
      expect(result.displayDecision.reason, 'apiAlreadyCoversPoolTop');
    });

    test('overlapRate=0.9 かつ APIにない強候補で recommendedDisplayCount=1', () {
      final api = List<ShopDiscoverySummary>.generate(
        10,
        (i) => _apiSummary(shopCode: 'api-$i'),
      );
      final pool = <ShopPoolCandidate>[
        ...List<ShopPoolCandidate>.generate(
          9,
          (i) => _poolCandidate(shopCode: 'api-$i'),
        ),
        _poolCandidate(
          shopCode: 'soukaidrink',
          shopName: '楽天24 ドリンク館',
          score: 310,
          itemCount: 17,
        ),
      ];
      final comparison = ShopDiscoveryPoolComparator.compare(
        apiSummaries: api,
        poolCandidates: pool,
        catalogEntries: const <ShopCatalogEntry>[],
      );
      expect(comparison.overlapRate, closeTo(0.9, 0.01));
      final result = ShopDiscoveryPoolSupplement.build(
        keyword: '水筒',
        apiSummaries: api,
        poolCandidates: pool,
        comparison: comparison,
        poolQuality: _goodPoolQuality(),
      );
      expect(result.displayDecision.recommendedDisplayCount, 1);
      expect(result.displayDecision.maxAllowedDisplayCount, 2);
    });

    test('apiWeakSignal=true では recommendedDisplayCount が増え得る', () {
      final recommended = ShopDiscoveryPoolSupplement.evaluateRecommendedDisplayCount(
        selectedCount: 3,
        overlapRate: 0.7,
        apiWeakSignal: true,
        wouldShow: true,
        poolQuality: _goodPoolQuality(),
        selected: const <ShopDiscoveryPoolSupplementCandidate>[],
        keyword: '水筒',
        poolTopGenres: const <String>['大人用水筒・マグボトル'],
      );
      expect(recommended, greaterThanOrEqualTo(2));
    });

    test('genericShop / broadShop が判定できる', () {
      expect(
        ShopDiscoveryPoolSupplement.evaluateGenericShop('rakuten24', '楽天24'),
        isTrue,
      );
      expect(
        ShopDiscoveryPoolSupplement.evaluateGenericShop(
          'soukaidrink',
          '楽天24 ドリンク館',
        ),
        isFalse,
      );
      expect(
        ShopDiscoveryPoolSupplement.evaluateBroadShop(
          shopCode: 'f272132-izumisano',
          shopName: '大阪府泉佐野市',
          genre: 'コーヒー飲料',
        ),
        isTrue,
      );
    });

    test('hitItemCount が低い候補は showEligible=false になり得る', () {
      final selected = [
        ShopDiscoveryPoolSupplementCandidate(
          rank: 1,
          shopCode: 'thin-shop',
          shopName: 'Thin Shop',
          score: 280,
          relevance: ShopPoolKeywordMatchLevel.strong,
          matchedBy: 'itemName',
          hitItemCount: 2,
          avgReview: 4.5,
          maxReviewCount: 100,
          primaryGenreName: '大人用水筒・マグボトル',
          matchedGenreName: '大人用水筒・マグボトル',
          hasImage: true,
          hasShopUrl: true,
          reason: ShopDiscoveryPoolSupplementReason.strongRelevance,
        ),
      ];
      final decisions = ShopDiscoveryPoolSupplement.evaluateCandidateDecisions(
        keyword: '水筒',
        selected: selected,
        recommendedDisplayCount: 1,
        apiWeakSignal: false,
        poolTopGenres: const <String>['大人用水筒・マグボトル'],
        poolQuality: _goodPoolQuality(),
        overlapRate: 0.9,
      );
      expect(decisions.single.showEligible, isFalse);
      expect(decisions.single.strongItemEvidence, isFalse);
      expect(decisions.single.reason, 'lowHitItemCountOrBroadShop');
    });

    test('ジャンル不整合なら showEligible=false になり得る', () {
      final align = ShopDiscoveryPoolSupplement.evaluateGenreAlignment(
        keyword: 'ベビー',
        genre: '大人用水筒・マグボトル',
        poolTopGenres: const <String>['大人用水筒・マグボトル'],
      );
      expect(align.aligned, isFalse);
      expect(align.reason, 'genreMismatchForKeyword');
    });

    test('水筒 + strong itemName + hitItems>=5 で strongItemEvidence=true', () {
      final candidate = ShopDiscoveryPoolSupplementCandidate(
        rank: 1,
        shopCode: 'soukaidrink',
        shopName: '楽天24 ドリンク館',
        score: 502,
        relevance: ShopPoolKeywordMatchLevel.strong,
        matchedBy: 'itemName',
        hitItemCount: 22,
        avgReview: 4.5,
        maxReviewCount: 600,
        primaryGenreName: '炭酸飲料',
        matchedGenreName: '大人用水筒・マグボトル',
        hasImage: true,
        hasShopUrl: true,
        reason: ShopDiscoveryPoolSupplementReason.strongRelevance,
      );
      expect(
        ShopDiscoveryPoolSupplement.evaluateStrongItemEvidence(
          keyword: '水筒',
          candidate: candidate,
          poolQuality: _goodPoolQuality(),
          overlapRate: 0.9,
          genericShop: false,
          broadShop: false,
        ),
        isTrue,
      );
    });

    test('strongItemEvidence=true なら genreAligned=false でも showEligible=true', () {
      final selected = [
        ShopDiscoveryPoolSupplementCandidate(
          rank: 1,
          shopCode: 'soukaidrink',
          shopName: '楽天24 ドリンク館',
          score: 502,
          relevance: ShopPoolKeywordMatchLevel.strong,
          matchedBy: 'itemName',
          hitItemCount: 22,
          avgReview: 4.5,
          maxReviewCount: 600,
          primaryGenreName: '炭酸飲料',
          matchedGenreName: '大人用水筒・マグボトル',
          hasImage: true,
          hasShopUrl: true,
          reason: ShopDiscoveryPoolSupplementReason.strongRelevance,
        ),
        ShopDiscoveryPoolSupplementCandidate(
          rank: 2,
          shopCode: 'rakuten24',
          shopName: '楽天24',
          score: 264,
          relevance: ShopPoolKeywordMatchLevel.strong,
          matchedBy: 'itemName',
          hitItemCount: 6,
          avgReview: 4.5,
          maxReviewCount: 500,
          primaryGenreName: '大人用水筒・マグボトル',
          matchedGenreName: '大人用水筒・マグボトル',
          hasImage: true,
          hasShopUrl: true,
          reason: ShopDiscoveryPoolSupplementReason.strongRelevance,
        ),
      ];
      final decisions = ShopDiscoveryPoolSupplement.evaluateCandidateDecisions(
        keyword: '水筒',
        selected: selected,
        recommendedDisplayCount: 1,
        apiWeakSignal: false,
        poolTopGenres: const <String>['大人用水筒・マグボトル'],
        poolQuality: _goodPoolQuality(),
        overlapRate: 0.9,
      );
      expect(decisions[0].showEligible, isTrue);
      expect(decisions[0].shopCode, 'soukaidrink');
      expect(decisions[0].genreAligned, isFalse);
      expect(decisions[0].strongItemEvidence, isTrue);
      expect(decisions[0].reason, 'strongItemEvidenceDespiteUnknownGenre');
      expect(decisions[1].showEligible, isFalse);
      expect(decisions[1].genericShop, isTrue);
    });

    test('genericShop=true は strongItemEvidence があっても showEligible=false', () {
      final candidate = ShopDiscoveryPoolSupplementCandidate(
        rank: 1,
        shopCode: 'rakuten24',
        shopName: '楽天24',
        score: 264,
        relevance: ShopPoolKeywordMatchLevel.strong,
        matchedBy: 'itemName',
        hitItemCount: 6,
        avgReview: 4.5,
        maxReviewCount: 500,
        primaryGenreName: '大人用水筒・マグボトル',
        matchedGenreName: '大人用水筒・マグボトル',
        hasImage: true,
        hasShopUrl: true,
        reason: ShopDiscoveryPoolSupplementReason.strongRelevance,
      );
      expect(
        ShopDiscoveryPoolSupplement.evaluateStrongItemEvidence(
          keyword: '水筒',
          candidate: candidate,
          poolQuality: _goodPoolQuality(),
          overlapRate: 0.9,
          genericShop: true,
          broadShop: false,
        ),
        isFalse,
      );
      final decisions = ShopDiscoveryPoolSupplement.evaluateCandidateDecisions(
        keyword: '水筒',
        selected: [candidate],
        recommendedDisplayCount: 1,
        apiWeakSignal: false,
        poolTopGenres: const <String>['大人用水筒・マグボトル'],
        poolQuality: _goodPoolQuality(),
        overlapRate: 0.9,
      );
      expect(decisions.single.showEligible, isFalse);
      expect(decisions.single.genericShop, isTrue);
    });

    test('broadShop=true は showEligible=false', () {
      final decisions = ShopDiscoveryPoolSupplement.evaluateCandidateDecisions(
        keyword: 'コーヒー',
        selected: [
          ShopDiscoveryPoolSupplementCandidate(
            rank: 1,
            shopCode: 'f272132-izumisano',
            shopName: '大阪府泉佐野市',
            score: 285,
            relevance: ShopPoolKeywordMatchLevel.strong,
            matchedBy: 'itemName',
            hitItemCount: 8,
            avgReview: 4.5,
            maxReviewCount: 100,
            primaryGenreName: 'コーヒー飲料',
            matchedGenreName: 'コーヒー飲料',
            hasImage: true,
            hasShopUrl: true,
            reason: ShopDiscoveryPoolSupplementReason.strongRelevance,
          ),
        ],
        recommendedDisplayCount: 1,
        apiWeakSignal: false,
        poolTopGenres: const <String>['コーヒー飲料'],
        poolQuality: _goodPoolQuality(),
        overlapRate: 0.9,
      );
      expect(decisions.single.broadShop, isTrue);
      expect(decisions.single.showEligible, isFalse);
    });

    test('candidate1 不適格なら candidate2 に displayRank=1', () {
      final decisions = ShopDiscoveryPoolSupplement.evaluateCandidateDecisions(
        keyword: '水筒',
        selected: [
          ShopDiscoveryPoolSupplementCandidate(
            rank: 1,
            shopCode: 'rakuten24',
            shopName: '楽天24',
            score: 293,
            relevance: ShopPoolKeywordMatchLevel.strong,
            matchedBy: 'itemName',
            hitItemCount: 6,
            avgReview: 4.5,
            maxReviewCount: 500,
            primaryGenreName: '大人用水筒・マグボトル',
            matchedGenreName: '大人用水筒・マグボトル',
            hasImage: true,
            hasShopUrl: true,
            reason: ShopDiscoveryPoolSupplementReason.strongRelevance,
          ),
          ShopDiscoveryPoolSupplementCandidate(
            rank: 2,
            shopCode: 'the-charme',
            shopName: 'ピーコック魔法瓶 楽天市場店',
            score: 323,
            relevance: ShopPoolKeywordMatchLevel.strong,
            matchedBy: 'itemName',
            hitItemCount: 7,
            avgReview: 4.5,
            maxReviewCount: 500,
            primaryGenreName: '大人用水筒・マグボトル',
            matchedGenreName: '大人用水筒・マグボトル',
            hasImage: true,
            hasShopUrl: true,
            reason: ShopDiscoveryPoolSupplementReason.strongRelevance,
          ),
        ],
        recommendedDisplayCount: 1,
        apiWeakSignal: false,
        poolTopGenres: const <String>['大人用水筒・マグボトル'],
        poolQuality: _goodPoolQuality(),
        overlapRate: 0.9,
      );
      expect(decisions[0].showEligible, isFalse);
      expect(decisions[1].showEligible, isTrue);
      expect(decisions[1].displayRank, 1);
    });

    test('ベビー相当で水筒系のみの Pool では recommendedDisplayCount=0', () {
      final recommended = ShopDiscoveryPoolSupplement.evaluateRecommendedDisplayCount(
        selectedCount: 3,
        overlapRate: 1.0,
        apiWeakSignal: false,
        wouldShow: false,
        poolQuality: _goodPoolQuality(),
        selected: [
          ShopDiscoveryPoolSupplementCandidate(
            rank: 1,
            shopCode: 'tiger-online',
            shopName: 'タイガー魔法瓶',
            score: 295,
            relevance: ShopPoolKeywordMatchLevel.strong,
            matchedBy: 'genreName',
            hitItemCount: 5,
            avgReview: 4.5,
            maxReviewCount: 500,
            primaryGenreName: '大人用水筒・マグボトル',
            matchedGenreName: '大人用水筒・マグボトル',
            hasImage: true,
            hasShopUrl: true,
            reason: ShopDiscoveryPoolSupplementReason.strongRelevance,
          ),
        ],
        keyword: 'ベビー',
        poolTopGenres: const <String>[
          '大人用水筒・マグボトル',
          '子供用水筒・マグボトル',
        ],
      );
      expect(recommended, 0);
    });

    test('decision / candidate ログと willUsePoolForUi / willSkipApi', () {
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
      expect(result.buildDecisionLogLine(),
          contains('[SHOP_DISCOVERY_POOL_SUPPLEMENT_DECISION]'));
      expect(result.buildCandidateDecisionLogLine(),
          contains('[SHOP_DISCOVERY_POOL_SUPPLEMENT_CANDIDATE_DECISION]'));
      expect(result.buildDecisionLogLine(), contains('willUsePoolForUi=false'));
      expect(result.buildDecisionLogLine(), contains('willSkipApi=false'));
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
