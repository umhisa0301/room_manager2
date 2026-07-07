import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/services/post_style_preview_generation_count_store.dart';
import 'package:room_manager2/services/post_style_preview_generation_limit.dart';
import 'package:shared_preferences/shared_preferences.dart';

MonetizationFlagSnapshot _limitsOnFlags() => resolveMonetizationFlags(
      monetizationEnabled: true,
      adsEnabled: false,
      subscriptionEnabled: true,
      freePlanLimitsEnabled: true,
      proPlanEnabled: true,
    );

MonetizationPlanContext _contextFor(
  MonetizationPlan plan,
  MonetizationFlagSnapshot flags,
) =>
    resolvePlanLimits(plan, flags);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolvePostStylePreviewGenerationAvailability', () {
    final flags = _limitsOnFlags();

    test('stub mode (enforcement off) allows regardless of count', () {
      final state = resolvePostStylePreviewGenerationAvailability(
        usedCount: 99,
        planContext: _contextFor(MonetizationPlan.free, flags),
        enforcementEnabled: false,
      );
      expect(state.allowed, isTrue);
      expect(state.appliesDailyLimit, isFalse);
      expect(state.remoteGenerationEnabled, isFalse);
      expect(state.reasonCode, isNull);
    });

    test('paid basic user is unlimited on remote', () {
      final state = resolvePostStylePreviewGenerationAvailability(
        usedCount: 99,
        planContext: _contextFor(MonetizationPlan.basic, flags),
        enforcementEnabled: true,
      );
      expect(state.allowed, isTrue);
      expect(state.appliesDailyLimit, isFalse);
      expect(state.remoteGenerationEnabled, isTrue);
    });

    test('paid pro user is unlimited on remote', () {
      final state = resolvePostStylePreviewGenerationAvailability(
        usedCount: 99,
        planContext: _contextFor(MonetizationPlan.pro, flags),
        enforcementEnabled: true,
      );
      expect(state.allowed, isTrue);
      expect(state.appliesDailyLimit, isFalse);
    });

    test('free 0/3 is allowed', () {
      final state = resolvePostStylePreviewGenerationAvailability(
        usedCount: 0,
        planContext: _contextFor(MonetizationPlan.free, flags),
        enforcementEnabled: true,
      );
      expect(state.allowed, isTrue);
      expect(state.appliesDailyLimit, isTrue);
      expect(state.limit, 3);
    });

    test('free 2/3 is allowed', () {
      final state = resolvePostStylePreviewGenerationAvailability(
        usedCount: 2,
        planContext: _contextFor(MonetizationPlan.free, flags),
        enforcementEnabled: true,
      );
      expect(state.allowed, isTrue);
    });

    test('free 3/3 is blocked', () {
      final state = resolvePostStylePreviewGenerationAvailability(
        usedCount: 3,
        planContext: _contextFor(MonetizationPlan.free, flags),
        enforcementEnabled: true,
      );
      expect(state.allowed, isFalse);
      expect(state.reasonCode, kPostStylePreviewDailyLimitReasonCode);
    });

    test('FREE_PLAN_LIMITS_ENABLED=false allows free user', () {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      final state = resolvePostStylePreviewGenerationAvailability(
        usedCount: 99,
        planContext: _contextFor(MonetizationPlan.free, offFlags),
        enforcementEnabled: true,
      );
      expect(state.allowed, isTrue);
      expect(state.appliesDailyLimit, isFalse);
    });
  });

  group('postStylePreviewGenerationUsageLabel', () {
    test('free remaining label', () {
      final state = resolvePostStylePreviewGenerationAvailability(
        usedCount: 1,
        planContext: _contextFor(MonetizationPlan.free, _limitsOnFlags()),
        enforcementEnabled: true,
      );
      expect(postStylePreviewGenerationUsageLabel(state), '本日の生成イメージ: あと2回');
    });

    test('paid unlimited label', () {
      final state = resolvePostStylePreviewGenerationAvailability(
        usedCount: 5,
        planContext: _contextFor(MonetizationPlan.basic, _limitsOnFlags()),
        enforcementEnabled: true,
      );
      expect(postStylePreviewGenerationUsageLabel(state), '生成イメージ: 無制限');
    });

    test('blocked label', () {
      final state = resolvePostStylePreviewGenerationAvailability(
        usedCount: 3,
        planContext: _contextFor(MonetizationPlan.free, _limitsOnFlags()),
        enforcementEnabled: true,
      );
      expect(
        postStylePreviewGenerationUsageLabel(state),
        buildPostStylePreviewGenerationLimitBlockedMessage(),
      );
    });
  });

  group('shouldRecordPostStylePreviewGeneration', () {
    test('records only for free remote with daily limit', () {
      final freeState = resolvePostStylePreviewGenerationAvailability(
        usedCount: 0,
        planContext: _contextFor(MonetizationPlan.free, _limitsOnFlags()),
        enforcementEnabled: true,
      );
      expect(
        shouldRecordPostStylePreviewGeneration(
          state: freeState,
          enforcementEnabled: true,
        ),
        isTrue,
      );

      final basicState = resolvePostStylePreviewGenerationAvailability(
        usedCount: 0,
        planContext: _contextFor(MonetizationPlan.basic, _limitsOnFlags()),
        enforcementEnabled: true,
      );
      expect(
        shouldRecordPostStylePreviewGeneration(
          state: basicState,
          enforcementEnabled: true,
        ),
        isFalse,
      );

      final stubState = resolvePostStylePreviewGenerationAvailability(
        usedCount: 0,
        planContext: _contextFor(MonetizationPlan.free, _limitsOnFlags()),
        enforcementEnabled: false,
      );
      expect(
        shouldRecordPostStylePreviewGeneration(
          state: stubState,
          enforcementEnabled: false,
        ),
        isFalse,
      );
    });
  });

  group('PostStylePreviewGenerationCountStore', () {
    test('increments and resets on new day', () async {
      SharedPreferences.setMockInitialValues({});
      final day1 = DateTime(2026, 7, 7);
      final day2 = DateTime(2026, 7, 8);

      expect(
        await PostStylePreviewGenerationCountStore.readTodayCount(now: day1),
        0,
      );
      expect(
        await PostStylePreviewGenerationCountStore.incrementTodayCount(
          now: day1,
        ),
        1,
      );
      expect(
        await PostStylePreviewGenerationCountStore.incrementTodayCount(
          now: day1,
        ),
        2,
      );
      expect(
        await PostStylePreviewGenerationCountStore.readTodayCount(now: day2),
        0,
      );
    });
  });
}
