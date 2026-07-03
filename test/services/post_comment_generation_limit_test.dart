import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/post_comment_generation_limit.dart';
import 'package:room_manager2/utils/today_recommendation_policy.dart';

void main() {
  group('PostCommentGenerationLimit', () {
    const bucket = PostCommentGenerationBucket.recommendation;

    test('recommendation daily limit matches visible display cap', () {
      expect(
        kPostCommentGenerationRecommendationDailyProductLimit,
        TodayRecommendationPolicy.visibleDisplayCap,
      );
    });

    test('allows generation when enforcement is off', () {
      final state = resolvePostCommentGenerationAvailability(
        bucket: bucket,
        productKey: 'shop:itemA',
        generatedProductKeys: {'shop:itemA', 'shop:itemB', 'shop:itemC'},
        enforcementEnabled: false,
      );
      expect(state.allowed, isTrue);
      expect(state.reasonCode, isNull);
    });

    test('allows first three distinct products', () {
      for (final key in ['shop:itemA', 'shop:itemB', 'shop:itemC']) {
        final state = resolvePostCommentGenerationAvailability(
          bucket: bucket,
          productKey: key,
          generatedProductKeys: switch (key) {
            'shop:itemA' => {},
            'shop:itemB' => {'shop:itemA'},
            'shop:itemC' => {'shop:itemA', 'shop:itemB'},
            _ => {},
          },
          enforcementEnabled: true,
        );
        expect(state.allowed, isTrue, reason: key);
        expect(state.reasonCode, isNull, reason: key);
      }
    });

    test('blocks fourth distinct product with daily_limit_reached', () {
      final state = resolvePostCommentGenerationAvailability(
        bucket: bucket,
        productKey: 'shop:itemD',
        generatedProductKeys: {
          'shop:itemA',
          'shop:itemB',
          'shop:itemC',
        },
        enforcementEnabled: true,
      );
      expect(state.allowed, isFalse);
      expect(state.reasonCode, kPostCommentDailyLimitReasonCode);
      expect(state.usedCount, 3);
      expect(state.limit, kPostCommentGenerationRecommendationDailyProductLimit);
    });

    test('blocks same product with product_already_generated', () {
      final state = resolvePostCommentGenerationAvailability(
        bucket: bucket,
        productKey: 'shop:itemA',
        generatedProductKeys: {'shop:itemA'},
        enforcementEnabled: true,
      );
      expect(state.allowed, isFalse);
      expect(state.reasonCode, kPostCommentProductAlreadyGeneratedReasonCode);
    });

    test('same product check takes priority over daily limit', () {
      final state = resolvePostCommentGenerationAvailability(
        bucket: bucket,
        productKey: 'shop:itemA',
        generatedProductKeys: {
          'shop:itemA',
          'shop:itemB',
          'shop:itemC',
        },
        enforcementEnabled: true,
      );
      expect(state.reasonCode, kPostCommentProductAlreadyGeneratedReasonCode);
    });

    test('daily limit blocked message matches spec', () {
      expect(
        buildPostCommentGenerationDailyLimitBlockedMessage(),
        '本日のAI生成回数の上限に達しました。明日またお試しください。',
      );
    });

    test('product already generated blocked message matches spec', () {
      expect(
        buildPostCommentGenerationProductAlreadyGeneratedBlockedMessage(),
        'この商品のAI投稿文は本日すでに生成済みです。',
      );
    });
  });
}
