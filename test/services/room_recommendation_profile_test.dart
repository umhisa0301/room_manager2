import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/data/priority_rule_definitions.dart';
import 'package:room_manager2/models/room_recommendation_profile.dart';
import 'package:room_manager2/models/today_recommendation.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/services/recommendation_query_builder.dart';
import 'package:room_manager2/services/recommendation_reason_builder.dart';
import 'package:room_manager2/services/recommendation_scoring_service.dart';
import 'package:room_manager2/services/room_diagnosis_service.dart';
import 'package:room_manager2/utils/profile_recommendation_integration.dart';

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
      expect(queries.length, lessThanOrEqualTo(RecommendationQueryBuilder.maxQueries));
      for (final q in queries) {
        expect(q.contains('送料無料'), isFalse);
      }
      for (final rule in PriorityRuleDefinitions.all) {
        for (final word in [...rule.searchKeywords, ...rule.boostKeywords]) {
          expect(word, isNot('送料無料'));
        }
      }
    });

    test('visual_sns × food_sweets でインスタ映え スイーツ系クエリが生成される', () {
      final profile = RoomDiagnosisService.buildProfile(
        const RoomDiagnosisAnswers(
          primaryTypeId: 'visual_mood',
          priorityRuleIds: ['visual_sns'],
          interestCategoryIds: ['food_sweets'],
          commentToneId: 'cheerful_recommend',
        ),
      );

      final queries = RecommendationQueryBuilder.buildQueries(profile);
      expect(
        queries.any(
          (q) =>
              (q.contains('インスタ映え') ||
                  q.contains('写真映え') ||
                  q.contains('SNS映え')) &&
              q.contains('スイーツ'),
        ),
        isTrue,
      );
    });

    test('パターンA: 暮らし便利型で時短・ライフハック系クエリが生成される', () {
      final profile = RoomDiagnosisService.buildProfile(
        const RoomDiagnosisAnswers(
          primaryTypeId: 'life_convenience',
          priorityRuleIds: ['practical_lifehack', 'review_trust'],
          interestCategoryIds: [
            'kitchen',
            'storage_interior',
            'cleaning_laundry',
          ],
          commentToneId: 'soft_natural',
        ),
      );
      final queries = RecommendationQueryBuilder.buildQueries(profile);

      expect(
        queries.any((q) => q.contains('時短') && q.contains('キッチン')),
        isTrue,
      );
      expect(
        queries.any(
          (q) =>
              (q.contains('ライフハック') || q.contains('収納術')) &&
              q.contains('収納'),
        ),
        isTrue,
      );
      expect(
        queries.any(
          (q) =>
              (q.contains('家事ラク') ||
                  q.contains('時短') ||
                  q.contains('収納術')) &&
              q.contains('掃除'),
        ),
        isTrue,
      );
    });

    test('パターンB: おしゃれ・気分上げ型で高見え・インスタ映え系クエリが生成される', () {
      final profile = RoomDiagnosisService.buildProfile(
        const RoomDiagnosisAnswers(
          primaryTypeId: 'visual_mood',
          priorityRuleIds: ['visual_sns', 'seasonal_trend'],
          interestCategoryIds: ['beauty_cosme', 'fashion', 'food_sweets'],
          commentToneId: 'cheerful_recommend',
        ),
      );
      final queries = RecommendationQueryBuilder.buildQueries(profile);

      expect(
        queries.any(
          (q) =>
              q.contains('高見え') &&
              (q.contains('ファッション') || q.contains('コスメ')),
        ) ||
            queries.any(
              (q) =>
                  (q.contains('インスタ映え') || q.contains('写真映え')) &&
                  q.contains('スイーツ'),
            ),
        isTrue,
      );
      expect(
        queries.any(
          (q) =>
              (q.contains('写真映え') || q.contains('インスタ映え')) &&
              q.contains('コスメ'),
        ),
        isTrue,
      );
    });

    test('パターンC: コスパ型でコスパ・お試し系が効き人気ワード単独は除外される', () {
      final profile = RoomDiagnosisService.buildProfile(
        const RoomDiagnosisAnswers(
          primaryTypeId: 'value_balance',
          priorityRuleIds: ['value_balance', 'review_trust'],
          interestCategoryIds: ['food_sweets', 'beauty_cosme', 'kitchen'],
          commentToneId: 'practical_clear',
        ),
      );
      final queries = RecommendationQueryBuilder.buildQueries(profile);

      expect(
        queries.any(
          (q) =>
              (q.contains('コスパ') ||
                  q.contains('お試し') ||
                  q.contains('大容量') ||
                  q.contains('セット')) &&
              (q.contains('スイーツ') ||
                  q.contains('コスメ') ||
                  q.contains('キッチン')),
        ),
        isTrue,
      );
      expect(queries.every((q) => !q.contains('送料無料')), isTrue);
      expect(
        queries.any((q) => q.trim() == '人気 おすすめ'),
        isFalse,
      );
    });

    test('パターンD: ギフト型で手土産・プチギフト系クエリが生成される', () {
      final profile = RoomDiagnosisService.buildProfile(
        const RoomDiagnosisAnswers(
          primaryTypeId: 'gift_event',
          priorityRuleIds: ['gift_event', 'seasonal_trend'],
          interestCategoryIds: ['gift', 'food_sweets', 'baby_kids'],
          commentToneId: 'polite_intro',
        ),
      );
      final queries = RecommendationQueryBuilder.buildQueries(profile);

      expect(
        queries.any(
          (q) => q.contains('手土産') && q.contains('スイーツ'),
        ),
        isTrue,
      );
      expect(
        queries.any(
          (q) => q.contains('プチギフト') && q.contains('雑貨'),
        ),
        isTrue,
      );
      expect(
        queries.any(
          (q) => q.contains('内祝い') && q.contains('ベビー'),
        ),
        isTrue,
      );
    });

    test('プロファイル検索プランはAPI上限以内に収まる', () {
      final profile = RoomDiagnosisService.buildProfile(
        const RoomDiagnosisAnswers(
          primaryTypeId: 'life_convenience',
          priorityRuleIds: ['practical_lifehack', 'review_trust'],
          interestCategoryIds: ['kitchen', 'storage_interior', 'cleaning_laundry'],
          commentToneId: 'soft_natural',
        ),
      );
      final plans = ProfileRecommendationIntegration.buildSearchPlans(profile);
      expect(
        plans.length,
        lessThanOrEqualTo(ProfileRecommendationIntegration.maxInitialSearchQueries),
      );
    });

    test('プロファイル検索プランは初回最大3クエリに制限される', () {
      final profile = RoomRecommendationProfile(
        primaryTypeId: 'life_convenience',
        interestCategoryIds: const ['kitchen', 'gift', 'pet'],
        priorityRuleIds: const ['review_trust'],
        searchKeywordPresets: const [
          'q1',
          'q2',
          'q3',
          'q4',
          'q5',
        ],
        diagnosedAt: DateTime(2026, 6, 26),
      );
      final plans = ProfileRecommendationIntegration.buildSearchPlans(profile);
      expect(plans.length, 3);
    });
  });

  group('RoomDiagnosisService.buildResultNarrative', () {
    test('タイプ・関心ジャンル・重視条件をつなげた説明文を返す', () {
      final text = RoomDiagnosisService.buildResultNarrative(
        primaryTypeId: 'life_convenience',
        interestCategoryIds: const ['gift', 'pet', 'gadget_appliance'],
        priorityRuleIds: const ['review_trust'],
      );
      expect(text, contains('暮らし便利型をベースに'));
      expect(text, contains('ギフト・ペット・家電・ガジェットまわり'));
      expect(text, contains('レビューが多く'));
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

    test('value_balance で送料無料は加点されない', () {
      final valueProfile = RoomRecommendationProfile(
        primaryTypeId: 'value_balance',
        interestCategoryIds: ['food_sweets'],
        priorityRuleIds: ['value_balance'],
        diagnosedAt: DateTime(2026, 6, 25),
      );
      final withFreeShipping = RecommendationScoringService.score(
        item: _item(
          productId: 'e',
          itemName: '送料無料 大容量 コスパ お試しセット',
          genreName: 'スイーツ',
        ),
        profile: valueProfile,
      );
      expect(withFreeShipping.matchedKeywords, isNot(contains('送料無料')));
      expect(
        withFreeShipping.matchedKeywords,
        anyElement(
          anyOf(contains('コスパ'), contains('大容量'), contains('お試し'), contains('セット')),
        ),
      );
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

    test('ギフト型の理由文が贈り物寄りになる', () {
      final profile = RoomDiagnosisService.buildProfile(
        const RoomDiagnosisAnswers(
          primaryTypeId: 'gift_event',
          priorityRuleIds: ['gift_event'],
          interestCategoryIds: ['gift', 'food_sweets'],
          commentToneId: 'polite_intro',
        ),
      );
      final reason = RecommendationReasonBuilder.build(
        profile: profile,
        item: _item(
          productId: 'f',
          itemName: '手土産スイーツ',
          genreName: 'ギフト',
        ),
      );
      expect(
        reason.contains('ギフト') || reason.contains('贈り物') || reason.contains('手土産'),
        isTrue,
      );
    });
  });

  group('ProfileRecommendationIntegration', () {
    test('3枠が役割ごとに選定される', () {
      final profile = RoomDiagnosisService.buildProfile(
        const RoomDiagnosisAnswers(
          primaryTypeId: 'life_convenience',
          priorityRuleIds: ['practical_lifehack', 'review_trust'],
          interestCategoryIds: ['kitchen', 'storage_interior'],
          commentToneId: 'soft_natural',
        ),
      );

      final kitchenMatch = RecommendationScoringService.score(
        item: _item(
          productId: 'p1',
          itemName: '時短 家事ラク キッチン便利グッズ',
          genreName: 'キッチン',
          reviewCount: 5,
          reviewAverage: 3.5,
        ),
        profile: profile,
      );
      final trustedItem = RecommendationScoringService.score(
        item: _item(
          productId: 'p2',
          itemName: '定番キッチン用品',
          genreName: 'キッチン',
          reviewCount: 120,
          reviewAverage: 4.5,
        ),
        profile: profile,
      );
      final discoveryItem = RecommendationScoringService.score(
        item: _item(
          productId: 'p3',
          itemName: '収納ボックス',
          genreName: '収納',
          reviewCount: 8,
          reviewAverage: 4.0,
        ),
        profile: profile,
      );

      final entries = ProfileRecommendationIntegration.pickTopThreeWithRoles(
        candidates: [
          (
            item: _item(
              productId: 'p1',
              itemName: '時短 家事ラク キッチン便利グッズ',
              genreName: 'キッチン',
              reviewCount: 5,
              reviewAverage: 3.5,
            ),
            score: 200 + kitchenMatch.totalScore,
            priceScore: 0,
            section: TodayRecommendationSection.sellable,
            profileScore: kitchenMatch,
          ),
          (
            item: _item(
              productId: 'p2',
              itemName: '定番キッチン用品',
              genreName: 'キッチン',
              reviewCount: 120,
              reviewAverage: 4.5,
            ),
            score: 180 + trustedItem.totalScore,
            priceScore: 0,
            section: TodayRecommendationSection.popular,
            profileScore: trustedItem,
          ),
          (
            item: _item(
              productId: 'p3',
              itemName: '収納ボックス',
              genreName: '収納',
              reviewCount: 8,
              reviewAverage: 4.0,
            ),
            score: 150 + discoveryItem.totalScore,
            priceScore: 0,
            section: TodayRecommendationSection.fresh,
            profileScore: discoveryItem,
          ),
        ],
        profile: profile,
        savedShopCount: 1,
      );

      expect(entries.length, 3);
      expect(entries.map((e) => e.item.productId).toSet().length, 3);
      expect(entries[0].reason, contains('暮らし便利型'));
      expect(entries[1].reason, contains('レビュー'));
      expect(entries[2].reason, contains('発見候補'));
    });
  });
}
