import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/services/batch_candidate_add_availability.dart';

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
  group('resolveBatchCandidateAddAvailability', () {
    final flags = _limitsOnFlags();

    test('FREE_PLAN_LIMITS_ENABLED=false allows regardless of plan', () {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      final state = resolveBatchCandidateAddAvailability(
        planContext: _contextFor(MonetizationPlan.free, offFlags),
      );
      expect(state.allowed, isTrue);
      expect(state.limitsEnforcementEnabled, isFalse);
      expect(state.reasonCode, isNull);
    });

    test('MONETIZATION_ENABLED=false allows regardless of plan', () {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: false,
        adsEnabled: true,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: true,
      );
      final state = resolveBatchCandidateAddAvailability(
        planContext: _contextFor(MonetizationPlan.free, offFlags),
      );
      expect(state.allowed, isTrue);
      expect(state.limitsEnforcementEnabled, isFalse);
    });

    test('free + limits on is not allowed', () {
      final state = resolveBatchCandidateAddAvailability(
        planContext: _contextFor(MonetizationPlan.free, flags),
      );
      expect(state.allowed, isFalse);
      expect(state.plan, MonetizationPlan.free);
      expect(state.limitsEnforcementEnabled, isTrue);
      expect(state.reasonCode, 'plan_locked');
    });

    test('basic + limits on is allowed', () {
      final state = resolveBatchCandidateAddAvailability(
        planContext: _contextFor(MonetizationPlan.basic, flags),
      );
      expect(state.allowed, isTrue);
      expect(state.plan, MonetizationPlan.basic);
      expect(state.reasonCode, isNull);
    });

    test('pro + limits on is allowed', () {
      final state = resolveBatchCandidateAddAvailability(
        planContext: _contextFor(MonetizationPlan.pro, flags),
      );
      expect(state.allowed, isTrue);
      expect(state.plan, MonetizationPlan.pro);
    });
  });

  group('canUseBatchCandidateAdd', () {
    test('returns true when limits off', () {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      expect(
        canUseBatchCandidateAdd(
          flags: offFlags,
          purchasedPlanOverride: MonetizationPlan.free,
        ),
        isTrue,
      );
    });
  });

  group('user messages', () {
    test('free locked body includes basic hint', () {
      const state = BatchCandidateAddAvailabilityState(
        allowed: false,
        plan: MonetizationPlan.free,
        limitsEnforcementEnabled: true,
        reasonCode: 'plan_locked',
      );
      final body = buildBatchCandidateAddLockedBody(state);
      expect(body, contains('一括追加はBasicプラン向けの機能です'));
      expect(body, contains('1件ずつ追加できます'));
      expect(body, contains('まとめて候補に追加できる予定です'));
    });
  });
}
