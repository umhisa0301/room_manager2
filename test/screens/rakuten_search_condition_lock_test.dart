import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/models/rakuten_product_search_condition.dart';
import 'package:room_manager2/services/rakuten_search_condition_availability.dart';
import 'package:room_manager2/utils/rakuten_keyword_search_sort.dart';

MonetizationFlagSnapshot _limitsOnFlags() => resolveMonetizationFlags(
      monetizationEnabled: true,
      adsEnabled: false,
      subscriptionEnabled: true,
      freePlanLimitsEnabled: true,
      proPlanEnabled: true,
    );

void main() {
  group('RakutenSearch advanced condition lock UI probe', () {
    testWidgets('free + limits on shows lock hint and disables sort', (
      tester,
    ) async {
      final state = resolveRakutenSearchConditionAvailability(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.free,
      );
      expect(state.allowed, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RakutenAdvancedSearchUiProbe(
              advancedState: state,
              keywordEnabled: true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('rakuten_search_advanced_conditions_locked_hint')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('rakuten_search_sort_locked_hint')),
        findsOneWidget,
      );
      expect(find.textContaining('通常のキーワード検索'), findsOneWidget);
      expect(find.byKey(const Key('rakuten_search_keyword_search_button')), findsOneWidget);
    });

    testWidgets('limits off hides lock hint and enables sort', (tester) async {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      final state = resolveRakutenSearchConditionAvailability(
        flags: offFlags,
        purchasedPlanOverride: MonetizationPlan.free,
      );
      expect(state.allowed, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RakutenAdvancedSearchUiProbe(
              advancedState: state,
              keywordEnabled: true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('rakuten_search_advanced_conditions_locked_hint')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('rakuten_search_sort_locked_hint')),
        findsNothing,
      );
      expect(find.byKey(const Key('rakuten_search_sort_dropdown')), findsOneWidget);
    });

    testWidgets('basic + limits on enables sort without lock hint', (
      tester,
    ) async {
      final state = resolveRakutenSearchConditionAvailability(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.basic,
      );
      expect(state.allowed, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RakutenAdvancedSearchUiProbe(
              advancedState: state,
              keywordEnabled: true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('rakuten_search_advanced_conditions_locked_hint')),
        findsNothing,
      );
      expect(find.byKey(const Key('rakuten_search_sort_dropdown')), findsOneWidget);
    });
  });

  group('RakutenSearch advanced condition guard probe', () {
    test('free + limits on strips price and sort from condition', () {
      const raw = RakutenProductSearchCondition(
        keyword: 'イヤホン',
        minPrice: 1000,
        maxPrice: 8000,
        sort: '-itemPrice',
        excludeKeyword: '中古',
      );
      final state = resolveRakutenSearchConditionAvailability(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.free,
      );
      final guarded = guardRakutenSearchConditionForPlan(
        condition: raw,
        advancedAllowed: state.allowed,
        scope: RakutenSearchAdvancedConditionScope.productKeyword,
      );
      expect(guarded.minPrice, isNull);
      expect(guarded.maxPrice, isNull);
      expect(guarded.sort, isNull);
      expect(guarded.excludeKeyword, isEmpty);
      expect(guarded.keyword, 'イヤホン');
    });

    test('basic + limits on keeps price and sort', () {
      const raw = RakutenProductSearchCondition(
        keyword: 'イヤホン',
        minPrice: 1000,
        sort: '-itemPrice',
      );
      final state = resolveRakutenSearchConditionAvailability(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.basic,
      );
      final guarded = guardRakutenSearchConditionForPlan(
        condition: raw,
        advancedAllowed: state.allowed,
        scope: RakutenSearchAdvancedConditionScope.productKeyword,
      );
      expect(guarded.minPrice, 1000);
      expect(guarded.sort, '-itemPrice');
    });
  });
}

/// 楽天検索画面の詳細条件ロック分岐をテスト用に再現する。
class _RakutenAdvancedSearchUiProbe extends StatelessWidget {
  const _RakutenAdvancedSearchUiProbe({
    required this.advancedState,
    required this.keywordEnabled,
  });

  final RakutenSearchConditionAvailabilityState advancedState;
  final bool keywordEnabled;

  @override
  Widget build(BuildContext context) {
    final advancedAllowed = advancedState.allowed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!advancedAllowed &&
            advancedState.limitsEnforcementEnabled &&
            !advancedState.allowed)
          Text(
            rakutenSearchConditionLockedMessage(),
            key: const Key('rakuten_search_advanced_conditions_locked_hint'),
          ),
        if (keywordEnabled)
          ElevatedButton(
            key: const Key('rakuten_search_keyword_search_button'),
            onPressed: () {},
            child: const Text('キーワード検索を実行'),
          ),
        if (advancedAllowed)
          DropdownButton<RakutenKeywordSearchSortMode>(
            key: const Key('rakuten_search_sort_dropdown'),
            value: RakutenKeywordSearchSortMode.reviewCountDescending,
            items: rakutenKeywordSearchUserSelectableSortModes
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(rakutenKeywordSearchSortDisplayLabel(m)),
                  ),
                )
                .toList(),
            onChanged: (_) {},
          )
        else if (advancedState.limitsEnforcementEnabled)
          Text(
            '並び順：${rakutenKeywordSearchSortDisplayLabel(rakutenKeywordSearchDefaultSortMode)}',
            key: const Key('rakuten_search_sort_locked_hint'),
          ),
      ],
    );
  }
}
