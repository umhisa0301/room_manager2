import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/models/rakuten_product_search_condition.dart';
import 'package:room_manager2/services/rakuten_search_condition_availability.dart';

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
  group('resolveRakutenSearchConditionAvailability', () {
    final flags = _limitsOnFlags();

    test('FREE_PLAN_LIMITS_ENABLED=false allows regardless of plan', () {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      final state = resolveRakutenSearchConditionAvailability(
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
      final state = resolveRakutenSearchConditionAvailability(
        planContext: _contextFor(MonetizationPlan.free, offFlags),
      );
      expect(state.allowed, isTrue);
      expect(state.limitsEnforcementEnabled, isFalse);
    });

    test('free + limits on is not allowed', () {
      final state = resolveRakutenSearchConditionAvailability(
        planContext: _contextFor(MonetizationPlan.free, flags),
      );
      expect(state.allowed, isFalse);
      expect(state.plan, MonetizationPlan.free);
      expect(state.limitsEnforcementEnabled, isTrue);
      expect(state.reasonCode, 'plan_locked');
    });

    test('basic + limits on is allowed', () {
      final state = resolveRakutenSearchConditionAvailability(
        planContext: _contextFor(MonetizationPlan.basic, flags),
      );
      expect(state.allowed, isTrue);
      expect(state.plan, MonetizationPlan.basic);
      expect(state.reasonCode, isNull);
    });

    test('pro + limits on is allowed', () {
      final state = resolveRakutenSearchConditionAvailability(
        planContext: _contextFor(MonetizationPlan.pro, flags),
      );
      expect(state.allowed, isTrue);
      expect(state.plan, MonetizationPlan.pro);
    });
  });

  group('canUseAdvancedRakutenSearchConditions', () {
    test('returns true when limits off', () {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      expect(
        canUseAdvancedRakutenSearchConditions(
          flags: offFlags,
          purchasedPlanOverride: MonetizationPlan.free,
        ),
        isTrue,
      );
    });
  });

  group('guardRakutenSearchConditionForPlan', () {
    const raw = RakutenProductSearchCondition(
      keyword: '水筒',
      minPrice: 1000,
      maxPrice: 5000,
      excludeKeyword: '中古',
      minReviewCount: 10,
      minReviewAverage: 4.0,
      minCommentCount: 5,
      genreId: '123',
      sort: '-itemPrice',
    );

    test('free strips advanced fields for product keyword search', () {
      final guarded = guardRakutenSearchConditionForPlan(
        condition: raw,
        advancedAllowed: false,
        scope: RakutenSearchAdvancedConditionScope.productKeyword,
      );
      expect(guarded.keyword, '水筒');
      expect(guarded.minPrice, isNull);
      expect(guarded.maxPrice, isNull);
      expect(guarded.excludeKeyword, isEmpty);
      expect(guarded.minReviewCount, isNull);
      expect(guarded.minReviewAverage, isNull);
      expect(guarded.minCommentCount, isNull);
      expect(guarded.genreId, isNull);
      expect(guarded.sort, isNull);
    });

    test('free keeps genreId for genre explore', () {
      final guarded = guardRakutenSearchConditionForPlan(
        condition: raw,
        advancedAllowed: false,
        scope: RakutenSearchAdvancedConditionScope.genreExplore,
      );
      expect(guarded.genreId, '123');
      expect(guarded.minPrice, isNull);
      expect(guarded.sort, isNull);
    });

    test('free keeps shopCode for saved shop keyword search', () {
      const savedShopRaw = RakutenProductSearchCondition(
        keyword: 'バッグ',
        shopCode: 'shop-1',
        minPrice: 2000,
        sort: '+itemPrice',
      );
      final guarded = guardRakutenSearchConditionForPlan(
        condition: savedShopRaw,
        advancedAllowed: false,
        scope: RakutenSearchAdvancedConditionScope.savedShopKeyword,
      );
      expect(guarded.keyword, 'バッグ');
      expect(guarded.shopCode, 'shop-1');
      expect(guarded.minPrice, isNull);
      expect(guarded.sort, isNull);
    });

    test('basic keeps advanced fields', () {
      final guarded = guardRakutenSearchConditionForPlan(
        condition: raw,
        advancedAllowed: true,
        scope: RakutenSearchAdvancedConditionScope.productKeyword,
      );
      expect(guarded.minPrice, 1000);
      expect(guarded.sort, '-itemPrice');
      expect(guarded.genreId, '123');
    });
  });

  group('user messages', () {
    test('free locked body includes basic hint', () {
      const state = RakutenSearchConditionAvailabilityState(
        allowed: false,
        plan: MonetizationPlan.free,
        limitsEnforcementEnabled: true,
        reasonCode: 'plan_locked',
      );
      final body = buildRakutenSearchConditionLockedBody(state);
      expect(body, contains('Basicプラン向けの機能です'));
      expect(body, contains('通常のキーワード検索'));
      expect(body, contains('価格帯や並び順を調整'));
    });
  });
}
