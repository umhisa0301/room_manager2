import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';

MonetizationFlagSnapshot _allEnabledFlags() => resolveMonetizationFlags(
      monetizationEnabled: true,
      adsEnabled: true,
      subscriptionEnabled: true,
      freePlanLimitsEnabled: true,
      proPlanEnabled: true,
    );

void main() {
  group('resolvePlanLimitsFor', () {
    test('free plan limits match expected values', () {
      const limits = kFreeMonetizationPlanLimits;
      expect(limits.adsRemoved, isFalse);
      expect(limits.dailyRecommendationLimit, 1);
      expect(limits.dailyRecommendationRefreshLimit, 1);
      expect(limits.batchCandidateAddEnabled, isFalse);
      expect(limits.roomImportLimitPerRun, 10);
      expect(limits.reactionAnalyticsDetailEnabled, isFalse);
      expect(limits.advancedRakutenSearchSortEnabled, isFalse);
      expect(limits.aiCommentGenerationEnabled, isFalse);
      expect(limits.aiImprovementSuggestionEnabled, isFalse);
      expect(limits.conditionalBatchProcessingEnabled, isFalse);
      expect(resolvePlanLimitsFor(MonetizationPlan.free), limits);
    });

    test('basic plan limits match expected values', () {
      const limits = kBasicMonetizationPlanLimits;
      expect(limits.adsRemoved, isTrue);
      expect(limits.dailyRecommendationLimit, 5);
      expect(limits.dailyRecommendationRefreshLimit, 5);
      expect(limits.batchCandidateAddEnabled, isTrue);
      expect(limits.roomImportLimitPerRun, isNull);
      expect(limits.reactionAnalyticsDetailEnabled, isTrue);
      expect(limits.advancedRakutenSearchSortEnabled, isTrue);
      expect(limits.aiCommentGenerationEnabled, isFalse);
      expect(limits.aiImprovementSuggestionEnabled, isFalse);
      expect(limits.conditionalBatchProcessingEnabled, isFalse);
      expect(resolvePlanLimitsFor(MonetizationPlan.basic), limits);
    });

    test('pro plan limits match expected values', () {
      const limits = kProMonetizationPlanLimits;
      expect(limits.adsRemoved, isTrue);
      expect(limits.dailyRecommendationLimit, 10);
      expect(limits.dailyRecommendationRefreshLimit, 10);
      expect(limits.batchCandidateAddEnabled, isTrue);
      expect(limits.roomImportLimitPerRun, isNull);
      expect(limits.reactionAnalyticsDetailEnabled, isTrue);
      expect(limits.advancedRakutenSearchSortEnabled, isTrue);
      expect(limits.aiCommentGenerationEnabled, isFalse);
      expect(limits.aiImprovementSuggestionEnabled, isFalse);
      expect(limits.conditionalBatchProcessingEnabled, isFalse);
      expect(resolvePlanLimitsFor(MonetizationPlan.pro), limits);
    });
  });

  group('clampMonetizationPlan', () {
    test('returns free when monetization is disabled', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: false,
        adsEnabled: true,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: true,
      );
      expect(
        clampMonetizationPlan(MonetizationPlan.pro, flags),
        MonetizationPlan.free,
      );
    });

    test('returns free when subscription is disabled', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: true,
        subscriptionEnabled: false,
        freePlanLimitsEnabled: true,
        proPlanEnabled: true,
      );
      expect(
        clampMonetizationPlan(MonetizationPlan.basic, flags),
        MonetizationPlan.free,
      );
      expect(
        clampMonetizationPlan(MonetizationPlan.pro, flags),
        MonetizationPlan.free,
      );
    });

    test('downgrades pro to basic when pro plan is disabled', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: false,
      );
      expect(
        clampMonetizationPlan(MonetizationPlan.pro, flags),
        MonetizationPlan.basic,
      );
      expect(
        clampMonetizationPlan(MonetizationPlan.basic, flags),
        MonetizationPlan.basic,
      );
    });

    test('keeps pro when pro plan is enabled', () {
      final flags = _allEnabledFlags();
      expect(
        clampMonetizationPlan(MonetizationPlan.pro, flags),
        MonetizationPlan.pro,
      );
    });
  });

  group('resolveCurrentMonetizationPlan', () {
    test('defaults to free with compile-time flags', () {
      expect(resolveCurrentMonetizationPlan(), MonetizationPlan.free);
    });

    test('returns free when monetization is disabled', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: false,
        adsEnabled: true,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: true,
      );
      expect(
        resolveCurrentMonetizationPlan(
          flags: flags,
          purchasedPlanOverride: MonetizationPlan.pro,
        ),
        MonetizationPlan.free,
      );
    });

    test('returns free when subscription is disabled', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: true,
        subscriptionEnabled: false,
        freePlanLimitsEnabled: true,
        proPlanEnabled: true,
      );
      expect(
        resolveCurrentMonetizationPlan(
          flags: flags,
          purchasedPlanOverride: MonetizationPlan.basic,
        ),
        MonetizationPlan.free,
      );
    });

    test('returns purchased basic when subscription is enabled', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: false,
      );
      expect(
        resolveCurrentMonetizationPlan(
          flags: flags,
          purchasedPlanOverride: MonetizationPlan.basic,
        ),
        MonetizationPlan.basic,
      );
    });

    test('downgrades purchased pro when pro plan is disabled', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: false,
      );
      expect(
        resolveCurrentMonetizationPlan(
          flags: flags,
          purchasedPlanOverride: MonetizationPlan.pro,
        ),
        MonetizationPlan.basic,
      );
    });
  });

  group('resolvePlanLimits', () {
    test('returns pro limits when pro is enabled', () {
      final context = resolvePlanLimits(MonetizationPlan.pro, _allEnabledFlags());
      expect(context.plan, MonetizationPlan.pro);
      expect(context.limits, kProMonetizationPlanLimits);
      expect(context.limitsEnforcementEnabled, isTrue);
    });

    test('returns basic limits when pro is disabled but basic requested', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: false,
      );
      final context = resolvePlanLimits(MonetizationPlan.pro, flags);
      expect(context.plan, MonetizationPlan.basic);
      expect(context.limits, kBasicMonetizationPlanLimits);
    });

    test('limitsEnforcementEnabled is false when FREE_PLAN_LIMITS_ENABLED is off', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      final context = resolvePlanLimits(MonetizationPlan.free, flags);
      expect(context.limitsEnforcementEnabled, isFalse);
      expect(context.limits, kFreeMonetizationPlanLimits);
    });
  });

  group('resolvePurchasedMonetizationPlan', () {
    tearDown(() {
      registerPurchasedMonetizationPlanProvider(null);
    });

    test('returns free when provider is not registered', () {
      registerPurchasedMonetizationPlanProvider(null);
      expect(resolvePurchasedMonetizationPlan(), MonetizationPlan.free);
    });

    test('uses registered provider', () {
      registerPurchasedMonetizationPlanProvider(() => MonetizationPlan.basic);
      expect(resolvePurchasedMonetizationPlan(), MonetizationPlan.basic);
    });
  });

  group('resolvePlanLimitsForCurrentUser', () {
    test('defaults to free with limits enforcement off at compile time', () {
      final context = resolvePlanLimitsForCurrentUser();
      expect(context.plan, MonetizationPlan.free);
      expect(context.limits, kFreeMonetizationPlanLimits);
      expect(context.limitsEnforcementEnabled, isFalse);
    });
  });

  group('resolveLimitsEnforcementEnabled', () {
    test('is false when free plan limits define is off', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      expect(resolveLimitsEnforcementEnabled(flags), isFalse);
    });

    test('is false when monetization is off even if free limits define is on', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: false,
        adsEnabled: false,
        subscriptionEnabled: false,
        freePlanLimitsEnabled: true,
        proPlanEnabled: false,
      );
      expect(resolveLimitsEnforcementEnabled(flags), isFalse);
    });

    test('is true when monetization and free limits defines are on', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: false,
      );
      expect(resolveLimitsEnforcementEnabled(flags), isTrue);
    });
  });

  group('monetizationPlanDebugLogLine', () {
    test('contains plan and limitsEnabled without secrets', () {
      const context = MonetizationPlanContext(
        plan: MonetizationPlan.free,
        limits: kFreeMonetizationPlanLimits,
        limitsEnforcementEnabled: false,
      );
      final line = monetizationPlanDebugLogLine(context);
      expect(line, '[MONETIZATION_PLAN] plan=free limitsEnabled=false');
    });
  });

  group('MonetizationFlagSnapshot.fromCompileTime', () {
    test('matches MonetizationFlags compile-time values', () {
      final snapshot = MonetizationFlagSnapshot.fromCompileTime();
      expect(snapshot.isMonetizationEnabled, MonetizationFlags.isMonetizationEnabled);
      expect(snapshot.isAdsEnabled, MonetizationFlags.isAdsEnabled);
      expect(snapshot.isSubscriptionEnabled, MonetizationFlags.isSubscriptionEnabled);
      expect(
        snapshot.isFreePlanLimitsEnabled,
        MonetizationFlags.isFreePlanLimitsEnabled,
      );
      expect(snapshot.isProPlanEnabled, MonetizationFlags.isProPlanEnabled);
    });
  });
}
