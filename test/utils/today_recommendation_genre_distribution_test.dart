import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/today_recommendation_genre_distribution.dart';
import 'package:room_manager2/utils/today_recommendation_policy.dart';

TodayRecommendPickCandidate _c({
  required String id,
  required String sourceGenre,
  required double score,
  String? shop,
}) {
  return TodayRecommendPickCandidate(
    productId: id,
    score: score,
    sourceGenreId: sourceGenre,
    itemGenreId: '$id-sub',
    shopCode: shop ?? id,
    mainTopicKey: '',
    titleToken: '',
    priceBand: 'mid',
  );
}

void main() {
  group('TodayRecommendationGenreDistribution', () {
    test('保存ジャンル3件で最終10件が1ジャンルに偏りすぎない', () {
      const fav = ['g1', 'g2', 'g3'];
      final candidates = <TodayRecommendPickCandidate>[
        ...List.generate(
          8,
          (i) => _c(id: 'g1_$i', sourceGenre: 'g1', score: 100 - i.toDouble()),
        ),
        ...List.generate(
          8,
          (i) => _c(id: 'g2_$i', sourceGenre: 'g2', score: 90 - i.toDouble()),
        ),
        ...List.generate(
          8,
          (i) => _c(id: 'g3_$i', sourceGenre: 'g3', score: 80 - i.toDouble()),
        ),
      ];
      final picked = TodayRecommendationGenreDistribution.pickProductIds(
        candidates: candidates,
        favoriteGenreIds: fav,
      );
      expect(picked.length, TodayRecommendationPolicy.displayCap);
      final dist = TodayRecommendationGenreDistribution.distributionBySourceGenre(
        pickedProductIds: picked,
        sourceGenreByProductId: {
          for (final id in picked)
            id: id.startsWith('g1')
                ? 'g1'
                : id.startsWith('g2')
                ? 'g2'
                : 'g3',
        },
        favoriteGenreIds: fav,
      );
      expect(dist['g1'], lessThanOrEqualTo(6));
      expect(dist['g2'], greaterThanOrEqualTo(1));
      expect(dist['g3'], greaterThanOrEqualTo(1));
      expect(
        TodayRecommendationGenreDistribution.isGenreSkewed(
          distribution: dist,
          favoriteGenreCount: 3,
          finalCount: picked.length,
        ),
        isFalse,
      );
    });

    test('他ジャンル候補がない場合は偏りを許容する', () {
      const fav = ['g1', 'g2', 'g3'];
      final candidates = List.generate(
        12,
        (i) => _c(id: 'only_$i', sourceGenre: 'g1', score: 100 - i.toDouble()),
      );
      final picked = TodayRecommendationGenreDistribution.pickProductIds(
        candidates: candidates,
        favoriteGenreIds: fav,
      );
      expect(picked.length, 10);
      expect(picked.every((id) => id.startsWith('only')), isTrue);
    });

    test('computeTargetQuotas は3ジャンル10件で4/3/3', () {
      final q = TodayRecommendationGenreDistribution.computeTargetQuotas(
        favoriteGenreIds: const ['a', 'b', 'c'],
        total: 10,
      );
      expect(q.values.reduce((a, b) => a + b), 10);
      expect(q.values.toList()..sort(), [3, 3, 4]);
    });
  });
}
