import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/services/subscription_status.dart';

void main() {
  group('PurchaseEntitlement.none (default)', () {
    const entitlement = PurchaseEntitlement.none();

    test('status is none', () {
      expect(entitlement.status, SubscriptionStatus.none);
    });

    test('isActive is false', () {
      expect(entitlement.isActive, isFalse);
    });

    test('isBasicActive is false', () {
      expect(entitlement.isBasicActive, isFalse);
    });

    test('isProActive is false', () {
      expect(entitlement.isProActive, isFalse);
    });

    test('adsRemoved is false', () {
      expect(entitlement.adsRemoved, isFalse);
    });

    test('resolvedPlan is free', () {
      expect(entitlement.resolvedPlan, MonetizationPlan.free);
    });
  });

  group('PurchaseEntitlement basicActive', () {
    const entitlement = PurchaseEntitlement(status: SubscriptionStatus.basicActive);

    test('isActive is true', () {
      expect(entitlement.isActive, isTrue);
    });

    test('isBasicActive is true', () {
      expect(entitlement.isBasicActive, isTrue);
    });

    test('isProActive is false', () {
      expect(entitlement.isProActive, isFalse);
    });

    test('adsRemoved is true', () {
      expect(entitlement.adsRemoved, isTrue);
    });

    test('resolvedPlan is basic', () {
      expect(entitlement.resolvedPlan, MonetizationPlan.basic);
    });
  });

  group('PurchaseEntitlement proActive', () {
    const entitlement = PurchaseEntitlement(status: SubscriptionStatus.proActive);

    test('isActive is true', () {
      expect(entitlement.isActive, isTrue);
    });

    test('isBasicActive is false', () {
      expect(entitlement.isBasicActive, isFalse);
    });

    test('isProActive is true', () {
      expect(entitlement.isProActive, isTrue);
    });

    test('adsRemoved is true', () {
      expect(entitlement.adsRemoved, isTrue);
    });

    test('resolvedPlan is pro', () {
      expect(entitlement.resolvedPlan, MonetizationPlan.pro);
    });
  });

  group('PurchaseEntitlement with expired expiresAt', () {
    final expired = PurchaseEntitlement(
      status: SubscriptionStatus.basicActive,
      expiresAt: DateTime(2000),
    );

    test('isActive is false when expiresAt is in the past', () {
      expect(expired.isActive, isFalse);
    });

    test('isBasicActive is false when expired', () {
      expect(expired.isBasicActive, isFalse);
    });

    test('adsRemoved is false when expired', () {
      expect(expired.adsRemoved, isFalse);
    });

    test('resolvedPlan is free when expired', () {
      expect(expired.resolvedPlan, MonetizationPlan.free);
    });
  });

  group('resolveMonetizationPlanFromEntitlement', () {
    test('none -> free', () {
      expect(
        resolveMonetizationPlanFromEntitlement(const PurchaseEntitlement.none()),
        MonetizationPlan.free,
      );
    });

    test('basicActive -> basic', () {
      expect(
        resolveMonetizationPlanFromEntitlement(
          const PurchaseEntitlement(status: SubscriptionStatus.basicActive),
        ),
        MonetizationPlan.basic,
      );
    });

    test('proActive -> pro', () {
      expect(
        resolveMonetizationPlanFromEntitlement(
          const PurchaseEntitlement(status: SubscriptionStatus.proActive),
        ),
        MonetizationPlan.pro,
      );
    });

    test('expired basicActive -> free', () {
      final expired = PurchaseEntitlement(
        status: SubscriptionStatus.basicActive,
        expiresAt: DateTime(2000),
      );
      expect(
        resolveMonetizationPlanFromEntitlement(expired),
        MonetizationPlan.free,
      );
    });
  });

  group('resolveCurrentMonetizationPlan with entitlement', () {
    MonetizationFlagSnapshot allEnabled() => resolveMonetizationFlags(
          monetizationEnabled: true,
          adsEnabled: true,
          subscriptionEnabled: true,
          freePlanLimitsEnabled: true,
          proPlanEnabled: true,
        );

    test('basicActive entitlement -> basic plan when subscription enabled', () {
      const entitlement = PurchaseEntitlement(status: SubscriptionStatus.basicActive);
      final plan = resolveCurrentMonetizationPlan(
        flags: allEnabled(),
        purchasedPlanOverride: entitlement.resolvedPlan,
      );
      expect(plan, MonetizationPlan.basic);
    });

    test('proActive entitlement -> pro plan when all enabled', () {
      const entitlement = PurchaseEntitlement(status: SubscriptionStatus.proActive);
      final plan = resolveCurrentMonetizationPlan(
        flags: allEnabled(),
        purchasedPlanOverride: entitlement.resolvedPlan,
      );
      expect(plan, MonetizationPlan.pro);
    });

    test('basicActive entitlement -> free when SUBSCRIPTION_ENABLED=false', () {
      const entitlement = PurchaseEntitlement(status: SubscriptionStatus.basicActive);
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: false,
        freePlanLimitsEnabled: true,
        proPlanEnabled: false,
      );
      final plan = resolveCurrentMonetizationPlan(
        flags: flags,
        purchasedPlanOverride: entitlement.resolvedPlan,
      );
      expect(plan, MonetizationPlan.free);
    });

    test('basicActive entitlement -> free when MONETIZATION_ENABLED=false', () {
      const entitlement = PurchaseEntitlement(status: SubscriptionStatus.basicActive);
      final flags = resolveMonetizationFlags(
        monetizationEnabled: false,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: true,
      );
      final plan = resolveCurrentMonetizationPlan(
        flags: flags,
        purchasedPlanOverride: entitlement.resolvedPlan,
      );
      expect(plan, MonetizationPlan.free);
    });

    test('proActive entitlement -> basic when PRO_PLAN_ENABLED=false', () {
      const entitlement = PurchaseEntitlement(status: SubscriptionStatus.proActive);
      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: false,
      );
      final plan = resolveCurrentMonetizationPlan(
        flags: flags,
        purchasedPlanOverride: entitlement.resolvedPlan,
      );
      expect(plan, MonetizationPlan.basic);
    });
  });
}
