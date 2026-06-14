import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';

void main() {
  group('resolveMonetizationFlags', () {
    test('defaults to all false when every define is false', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: false,
        adsEnabled: false,
        subscriptionEnabled: false,
        freePlanLimitsEnabled: false,
        proPlanEnabled: false,
      );
      expect(flags.isMonetizationEnabled, isFalse);
      expect(flags.isAdsEnabled, isFalse);
      expect(flags.isSubscriptionEnabled, isFalse);
      expect(flags.isFreePlanLimitsEnabled, isFalse);
      expect(flags.isProPlanEnabled, isFalse);
    });

    test('ads stays false when monetization is false even if ads define is true', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: false,
        adsEnabled: true,
        subscriptionEnabled: false,
        freePlanLimitsEnabled: false,
        proPlanEnabled: false,
      );
      expect(flags.isMonetizationEnabled, isFalse);
      expect(flags.isAdsEnabled, isFalse);
    });

    test('ads is true when monetization and ads defines are true', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: true,
        subscriptionEnabled: false,
        freePlanLimitsEnabled: false,
        proPlanEnabled: false,
      );
      expect(flags.isMonetizationEnabled, isTrue);
      expect(flags.isAdsEnabled, isTrue);
      expect(flags.isSubscriptionEnabled, isFalse);
      expect(flags.isFreePlanLimitsEnabled, isFalse);
      expect(flags.isProPlanEnabled, isFalse);
    });

    test('subscription is true when monetization and subscription defines are true', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: false,
      );
      expect(flags.isSubscriptionEnabled, isTrue);
      expect(flags.isAdsEnabled, isFalse);
    });

    test('free plan limits is true when monetization and free limits defines are true', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: false,
        freePlanLimitsEnabled: true,
        proPlanEnabled: false,
      );
      expect(flags.isFreePlanLimitsEnabled, isTrue);
    });

    test('pro is false when subscription is false even if pro define is true', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: false,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      expect(flags.isProPlanEnabled, isFalse);
    });

    test('pro is true when monetization, subscription, and pro defines are true', () {
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: true,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: true,
      );
      expect(flags.isMonetizationEnabled, isTrue);
      expect(flags.isAdsEnabled, isTrue);
      expect(flags.isSubscriptionEnabled, isTrue);
      expect(flags.isFreePlanLimitsEnabled, isTrue);
      expect(flags.isProPlanEnabled, isTrue);
    });
  });

  group('MonetizationFlags compile-time defaults', () {
    test('all effective flags are false when defines are omitted at compile time', () {
      expect(MonetizationFlags.isMonetizationEnabled, isFalse);
      expect(MonetizationFlags.isAdsEnabled, isFalse);
      expect(MonetizationFlags.isSubscriptionEnabled, isFalse);
      expect(MonetizationFlags.isFreePlanLimitsEnabled, isFalse);
      expect(MonetizationFlags.isProPlanEnabled, isFalse);
    });

    test('derived flags match resolveMonetizationFlags for current compile-time defines', () {
      final expected = resolveMonetizationFlags(
        monetizationEnabled: MonetizationConfig.kMonetizationDartDefineEnabled,
        adsEnabled: MonetizationConfig.kAdsDartDefineEnabled,
        subscriptionEnabled: MonetizationConfig.kSubscriptionDartDefineEnabled,
        freePlanLimitsEnabled:
            MonetizationConfig.kFreePlanLimitsDartDefineEnabled,
        proPlanEnabled: MonetizationConfig.kProPlanDartDefineEnabled,
      );
      expect(MonetizationFlags.isMonetizationEnabled, expected.isMonetizationEnabled);
      expect(MonetizationFlags.isAdsEnabled, expected.isAdsEnabled);
      expect(MonetizationFlags.isSubscriptionEnabled, expected.isSubscriptionEnabled);
      expect(
        MonetizationFlags.isFreePlanLimitsEnabled,
        expected.isFreePlanLimitsEnabled,
      );
      expect(MonetizationFlags.isProPlanEnabled, expected.isProPlanEnabled);
    });

    test('debugLogLine contains no secret values', () {
      final line = MonetizationFlags.debugLogLine;
      expect(line, startsWith('[MONETIZATION_FLAGS]'));
      expect(line, contains('monetization='));
      expect(line, contains('ads='));
      expect(line, contains('subscription='));
      expect(line, contains('freeLimits='));
      expect(line, contains('pro='));
    });
  });

  group('MonetizationFlagSnapshot.fromCompileTime', () {
    test('matches resolveMonetizationFlags for current compile-time defines', () {
      final expected = resolveMonetizationFlags(
        monetizationEnabled: MonetizationConfig.kMonetizationDartDefineEnabled,
        adsEnabled: MonetizationConfig.kAdsDartDefineEnabled,
        subscriptionEnabled: MonetizationConfig.kSubscriptionDartDefineEnabled,
        freePlanLimitsEnabled:
            MonetizationConfig.kFreePlanLimitsDartDefineEnabled,
        proPlanEnabled: MonetizationConfig.kProPlanDartDefineEnabled,
      );
      final snapshot = MonetizationFlagSnapshot.fromCompileTime();
      expect(snapshot.isMonetizationEnabled, expected.isMonetizationEnabled);
      expect(snapshot.isAdsEnabled, expected.isAdsEnabled);
      expect(snapshot.isSubscriptionEnabled, expected.isSubscriptionEnabled);
      expect(snapshot.isFreePlanLimitsEnabled, expected.isFreePlanLimitsEnabled);
      expect(snapshot.isProPlanEnabled, expected.isProPlanEnabled);
    });
  });
}
