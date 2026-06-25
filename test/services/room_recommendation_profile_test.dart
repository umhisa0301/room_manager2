import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/data/priority_rule_definitions.dart';
import 'package:room_manager2/models/room_recommendation_profile.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/services/recommendation_query_builder.dart';
import 'package:room_manager2/services/recommendation_reason_builder.dart';
import 'package:room_manager2/services/recommendation_scoring_service.dart';
import 'package:room_manager2/services/room_diagnosis_service.dart';

RakutenSearchItem _item({
  required String productId,
  required String itemName,
  String genreName = '',
  int reviewCount = 0,
  double reviewAverage = 0,
}) {
  return RakutenSearchItem(
    productId: productId,
    itemName: itemName,
    itemPrice: 1500,
    itemUrl: 'https://example.com/$productId',
    affiliateUrl: '',
    imageUrl: 'https://example.com/$productId.jpg',
    shopName: 'テストショップ',
    genreName: genreName,
    reviewCount: reviewCount,
    reviewAverage: reviewAverage,
  );
}

void main() {
  group('RoomDiagnosisService', () {
    test('診断回答からRoomRecommendationProfileが作成される', () {
      final profile = RoomDiagnosisService.buildProfile(
        const RoomDiagnosisAnswers(
          primaryTypeId: 'life_convenience',
          priorityRuleIds: ['practical_lifehack', 'review_trust'],
          interestCategoryIds: ['kitchen', 'storage_interior'],
          commentToneId: 'soft_natural',
        ),
      );

      expect(profile.primaryTypeId, 'life_convenience');
      expect(profile.priorityRuleIds, ['practical_lifehack', 'review_trust']);
      expect(profile.interestCategoryIds, ['kitchen', 'storage_interior']);
      expect(profile.commentToneId, 'soft_natural');
      expect(profile.isDiagnosed, isTrue);
      expect(profile.searchKeywordPresets, isNotEmpty);
    });
  });

  group('RecommendationQueryBuilder', () {
    test('practical_lifehack × kitchen で複合検索クエリが生成される', () {
      final profile = RoomDiagnosisService.buildProfile(
        const RoomDiagnosisAnswers(
          primaryTypeId: 'life_convenience',
          priorityRuleIds: ['practical_lifehack'],
          interestCategoryIds: ['kitchen'],
          commentToneId: 'practical_clear',
        ),
      );

      final queries = RecommendationQueryBuilder.buildQueries(profile);
      expect(queries, isNotEmpty);
      expect(
        queries.any((q) => q.contains('キッチン') && q.contains(' ')),
        isTrue,
      );
      expect(
        queries.any(
          (q) =>
              (q.contains('ライフハック') || q.contains('時短')) &&
              q.contains('キッチン'),
        ),
        isTrue,
      );
    });

    test('送料無料が検索クエリに含まれない', () {
      final profile = RoomDiagnosisService.buildProfile(
        const RoomDiagnosisAnswers(
          primaryTypeId: 'value_balance',
          priorityRuleIds: ['value_balance', 'review_trust'],
          interestCategoryIds: ['kitchen', 'fashion'],
          commentToneId: 'cheerful_recommend',
        ),
      );

      final queries = RecommendationQueryBuilder.buildQueries(profile);
      for (final q in queries) {
        expect(q.contains('送料無料'), isFalse);
      }
      for (final rule in PriorityRuleDefinitions.all) {
        for (final word in [...rule.searchKeywords, ...rule.boostKeywords]) {
          expect(word, isNot('送料無料'));
        }
      }
    });
  });

  group('RecommendationScoringService', () {
    final profile = RoomRecommendationProfile(
      primaryTypeId: 'life_convenience',
      interestCategoryIds: ['kitchen'],
      priorityRuleIds: ['practical_lifehack'],
      diagnosedAt: DateTime(2026, 6, 25),
    );

    test('優先条件ワード一致でスコアが上がる', () {
      final matched = RecommendationScoringService.score(
        item: _item(
          productId: 'a',
          itemName: '時短 家事ラク キッチン便利グッズ',
          genreName: 'キッチン',
        ),
        profile: profile,
      );
      final unmatched = RecommendationScoringService.score(
        item: _item(productId: 'b', itemName: '無関係な商品名'),
        profile: profile,
      );

      expect(matched.totalScore, greaterThan(unmatched.totalScore));
      expect(matched.priorityScore, greaterThan(0));
    });

    test('人気・おすすめ・売れ筋は強加点されない', () {
      final popular = RecommendationScoringService.score(
        item: _item(productId: 'c', itemName: '人気 おすすめ 売れ筋'),
        profile: profile,
      );
      expect(popular.weakKeywordScore, lessThanOrEqualTo(3));
      expect(popular.priorityScore, 0);
    });
  });

  group('RecommendationReasonBuilder', () {
    test('診断済みの場合、おすすめ理由にタイプまたは優先条件が反映される', () {
      final profile = RoomDiagnosisService.buildProfile(
        const RoomDiagnosisAnswers(
          primaryTypeId: 'life_convenience',
          priorityRuleIds: ['practical_lifehack'],
          interestCategoryIds: ['kitchen'],
          commentToneId: 'soft_natural',
        ),
      );
      final reason = RecommendationReasonBuilder.build(
        profile: profile,
        item: _item(
          productId: 'd',
          itemName: '時短キッチングッズ',
          genreName: 'キッチン',
        ),
      );

      expect(reason.contains('暮らし便利型'), isTrue);
      expect(
        reason.contains('実用性') || reason.contains('キッチン'),
        isTrue,
      );
    });
  });
}
