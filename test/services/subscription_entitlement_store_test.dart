import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/services/billing_purchase_service.dart';
import 'package:room_manager2/services/subscription_entitlement_store.dart';
import 'package:room_manager2/services/subscription_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SubscriptionEntitlementStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      unregisterGlobalSubscriptionEntitlementStore();
      registerPurchasedMonetizationPlanProvider(null);
    });

    test('load returns none when nothing saved', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SubscriptionEntitlementStore(prefs);

      await store.load();

      expect(store.entitlement.status, SubscriptionStatus.none);
      expect(store.entitlement.isActive, isFalse);
    });

    test('save and load basicActive entitlement', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SubscriptionEntitlementStore(prefs);
      const entitlement = PurchaseEntitlement(
        status: SubscriptionStatus.basicActive,
        source: BillingPurchaseService.entitlementSource,
      );

      await store.save(entitlement);
      await store.load();

      expect(store.entitlement.status, SubscriptionStatus.basicActive);
      expect(store.entitlement.source, BillingPurchaseService.entitlementSource);
      expect(store.entitlement.isBasicActive, isTrue);
      expect(store.entitlement.adsRemoved, isTrue);
      expect(store.entitlement.resolvedPlan, MonetizationPlan.basic);
    });

    test('clear removes persisted basic entitlement', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SubscriptionEntitlementStore(prefs);
      await store.save(
        const PurchaseEntitlement(status: SubscriptionStatus.basicActive),
      );

      await store.clear();
      await store.load();

      expect(store.entitlement.status, SubscriptionStatus.none);
    });

    test('readStoredPurchaseEntitlement uses global store', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SubscriptionEntitlementStore(prefs);
      registerGlobalSubscriptionEntitlementStore(store);
      await store.save(
        const PurchaseEntitlement(status: SubscriptionStatus.basicActive),
      );

      expect(readStoredPurchaseEntitlement().isBasicActive, isTrue);
    });

    test('resolveCurrentMonetizationPlan uses stored basic when flags on', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SubscriptionEntitlementStore(prefs);
      registerGlobalSubscriptionEntitlementStore(store);
      registerPurchasedMonetizationPlanProvider(() {
        return resolvePurchasedMonetizationPlanFromResolvedPlan(
          readStoredPurchaseEntitlement().resolvedPlan,
        );
      });
      await store.save(
        const PurchaseEntitlement(status: SubscriptionStatus.basicActive),
      );

      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: true,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: true,
      );

      expect(resolveCurrentMonetizationPlan(flags: flags), MonetizationPlan.basic);
    });

    test('stored basic is free when SUBSCRIPTION_ENABLED=false', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SubscriptionEntitlementStore(prefs);
      registerGlobalSubscriptionEntitlementStore(store);
      registerPurchasedMonetizationPlanProvider(() {
        return resolvePurchasedMonetizationPlanFromResolvedPlan(
          readStoredPurchaseEntitlement().resolvedPlan,
        );
      });
      await store.save(
        const PurchaseEntitlement(status: SubscriptionStatus.basicActive),
      );

      final flags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: true,
        subscriptionEnabled: false,
        freePlanLimitsEnabled: true,
        proPlanEnabled: true,
      );

      expect(resolveCurrentMonetizationPlan(flags: flags), MonetizationPlan.free);
    });

    test('stored basic is free when MONETIZATION_ENABLED=false', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SubscriptionEntitlementStore(prefs);
      registerGlobalSubscriptionEntitlementStore(store);
      registerPurchasedMonetizationPlanProvider(() {
        return resolvePurchasedMonetizationPlanFromResolvedPlan(
          readStoredPurchaseEntitlement().resolvedPlan,
        );
      });
      await store.save(
        const PurchaseEntitlement(status: SubscriptionStatus.basicActive),
      );

      final flags = resolveMonetizationFlags(
        monetizationEnabled: false,
        adsEnabled: true,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: true,
      );

      expect(resolveCurrentMonetizationPlan(flags: flags), MonetizationPlan.free);
    });
  });
}
