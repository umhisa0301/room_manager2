import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/today_recommendation.dart';
import 'package:room_manager2/services/recommendation_generation_count_store.dart';
import 'package:room_manager2/services/recommendation_refresh_limit.dart';
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

  group('resolveRecommendationRefreshAvailability', () {
    final flags = _limitsOnFlags();

    test('FREE_PLAN_LIMITS_ENABLED=false allows regardless of count', () {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      final state = resolveRecommendationRefreshAvailability(
        usedCount: 99,
        planContext: _contextFor(MonetizationPlan.free, offFlags),
      );
      expect(state.allowed, isTrue);
      expect(state.limitsEnforcementEnabled, isFalse);
      expect(state.reasonCode, isNull);
    });

    test('MONETIZATION_ENABLED=false allows regardless of count', () {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: false,
        adsEnabled: true,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: true,
      );
      final state = resolveRecommendationRefreshAvailability(
        usedCount: 99,
        planContext: _contextFor(MonetizationPlan.free, offFlags),
      );
      expect(state.allowed, isTrue);
      expect(state.limitsEnforcementEnabled, isFalse);
    });

    test('free refresh 0/1 is allowed', () {
      final state = resolveRecommendationRefreshAvailability(
        usedCount: 0,
        planContext: _contextFor(MonetizationPlan.free, flags),
      );
      expect(state.allowed, isTrue);
      expect(state.usedCount, 0);
      expect(state.limit, 1);
      expect(state.plan, MonetizationPlan.free);
    });

    test('free refresh 1/1 is blocked', () {
      final state = resolveRecommendationRefreshAvailability(
        usedCount: 1,
        planContext: _contextFor(MonetizationPlan.free, flags),
      );
      expect(state.allowed, isFalse);
      expect(state.reasonCode, 'daily_refresh_limit_reached');
    });

    test('basic refresh 4/5 is allowed', () {
      final state = resolveRecommendationRefreshAvailability(
        usedCount: 4,
        planContext: _contextFor(MonetizationPlan.basic, flags),
      );
      expect(state.allowed, isTrue);
      expect(state.limit, 5);
    });

    test('basic refresh 5/5 is blocked', () {
      final state = resolveRecommendationRefreshAvailability(
        usedCount: 5,
        planContext: _contextFor(MonetizationPlan.basic, flags),
      );
      expect(state.allowed, isFalse);
    });

    test('pro refresh 9/10 is allowed', () {
      final state = resolveRecommendationRefreshAvailability(
        usedCount: 9,
        planContext: _contextFor(MonetizationPlan.pro, flags),
      );
      expect(state.allowed, isTrue);
      expect(state.limit, 10);
    });

    test('pro refresh 10/10 is blocked', () {
      final state = resolveRecommendationRefreshAvailability(
        usedCount: 10,
        planContext: _contextFor(MonetizationPlan.pro, flags),
      );
      expect(state.allowed, isFalse);
    });
  });

  group('isManualRecommendationRefresh', () {
    const today = '2026-06-15';
    final bundleWithEntries = TodayRecommendationBundle(
      localDateKey: today,
      generatedAt: DateTime(2026, 6, 15),
      entries: [
        TodayRecommendationEntry(
          item: RakutenSearchItem(
            productId: 'p1',
            itemName: 'n',
            itemPrice: 100,
            itemUrl: 'https://example.com',
            affiliateUrl: 'https://example.com/a',
            imageUrl: '',
            shopName: 's',
            genreId: 'g',
          ),
          section: TodayRecommendationSection.popular,
        ),
      ],
    );

    test('manual with existing entries is refresh', () {
      expect(
        isManualRecommendationRefresh(
          manual: true,
          bundleBefore: bundleWithEntries,
          todayLocalDateKey: today,
        ),
        isTrue,
      );
    });

    test('manual on empty bundle is not refresh', () {
      expect(
        isManualRecommendationRefresh(
          manual: true,
          bundleBefore: TodayRecommendationBundle(
            localDateKey: today,
            generatedAt: DateTime(2026, 6, 15),
            entries: const [],
          ),
          todayLocalDateKey: today,
        ),
        isFalse,
      );
    });

    test('non-manual is not refresh', () {
      expect(
        isManualRecommendationRefresh(
          manual: false,
          bundleBefore: bundleWithEntries,
          todayLocalDateKey: today,
        ),
        isFalse,
      );
    });
  });

  group('recordSuccessfulRecommendationRefresh', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('increments only on explicit record call', () async {
      final now = DateTime(2026, 6, 15);
      expect(
        await resolveRecommendationRefreshAvailabilityForToday(
          now: now,
          flags: _limitsOnFlags(),
          purchasedPlanOverride: MonetizationPlan.free,
        ),
        predicate<RecommendationRefreshLimitState>(
          (s) => s.usedCount == 0 && s.allowed,
        ),
      );
      await recordSuccessfulRecommendationRefresh(now: now);
      final after = await resolveRecommendationRefreshAvailabilityForToday(
        now: now,
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.free,
      );
      expect(after.usedCount, 1);
      expect(after.allowed, isFalse);
    });

    test('new day resets used count to 0', () async {
      final day1 = DateTime(2026, 6, 15);
      await recordSuccessfulRecommendationRefresh(now: day1);
      final day2 = DateTime(2026, 6, 16);
      final state = await resolveRecommendationRefreshAvailabilityForToday(
        now: day2,
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.free,
      );
      expect(state.usedCount, 0);
      expect(state.allowed, isTrue);
    });

    test('generation count and refresh count are independent', () async {
      final now = DateTime(2026, 6, 15);
      await RecommendationGenerationCountStore.incrementTodayCount(now: now);
      await recordSuccessfulRecommendationRefresh(now: now);
      expect(
        await RecommendationGenerationCountStore.readTodayCount(now: now),
        1,
      );
      expect(
        await RecommendationGenerationCountStore.readTodayRefreshCount(now: now),
        1,
      );
    });
  });

  group('user messages', () {
    test('free blocked message includes basic hint in body builder', () {
      const state = RecommendationRefreshLimitState(
        allowed: false,
        usedCount: 1,
        limit: 1,
        plan: MonetizationPlan.free,
        limitsEnforcementEnabled: true,
        reasonCode: 'daily_refresh_limit_reached',
      );
      final body = buildRecommendationRefreshLimitBlockedBody(state);
      expect(body, contains('無料版では、おすすめコレの再生成は1日1回までです'));
      expect(body, contains('Basicプランでは、1日5回まで再生成できる予定です'));
    });
  });
}
