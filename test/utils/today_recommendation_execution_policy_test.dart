import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/today_recommendation_policy.dart';

void main() {
  group('TodayRecommendationExecutionPolicy', () {
    test('10件そろっても保存ジャンル必須プランは件数では打ち切らない', () {
      expect(
        TodayRecommendationExecutionPolicy.shouldRunAssistPlan(
          finalizedEntryCount: 10,
          hasAssistPlan: true,
          apiCallsSoFar: 1,
        ),
        isFalse,
      );
      expect(
        TodayRecommendationExecutionPolicy.shouldSkipMandatoryGenrePlan(
          apiCallsSoFar: 1,
        ),
        isFalse,
      );
      expect(
        TodayRecommendationExecutionPolicy.shouldSkipMandatoryGenrePlan(
          apiCallsSoFar: 4,
        ),
        isTrue,
      );
    });

    test('補助プランは件数不足かつAPI余裕があるときのみ', () {
      expect(
        TodayRecommendationExecutionPolicy.shouldRunAssistPlan(
          finalizedEntryCount: 9,
          hasAssistPlan: true,
          apiCallsSoFar: 3,
        ),
        isTrue,
      );
      expect(
        TodayRecommendationExecutionPolicy.shouldRunAssistPlan(
          finalizedEntryCount: 9,
          hasAssistPlan: true,
          apiCallsSoFar: 4,
        ),
        isFalse,
      );
    });
  });
}
