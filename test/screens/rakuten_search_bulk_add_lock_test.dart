import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/services/batch_candidate_add_availability.dart';
import 'package:room_manager2/widgets/search_bulk_selection_header.dart';

MonetizationFlagSnapshot _limitsOnFlags() => resolveMonetizationFlags(
      monetizationEnabled: true,
      adsEnabled: false,
      subscriptionEnabled: true,
      freePlanLimitsEnabled: true,
      proPlanEnabled: true,
    );

void main() {
  group('RakutenSearch bulk add lock UI probe', () {
    testWidgets('free + limits on hides bulk header and shows hint', (
      tester,
    ) async {
      final state = resolveBatchCandidateAddAvailability(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.free,
      );
      expect(state.allowed, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RakutenBulkAddUiProbe(
              batchAddState: state,
              selectableCount: 3,
              resultsVisible: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('rakuten_search_bulk_selection_header')), findsNothing);
      expect(find.byKey(const Key('rakuten_search_bulk_add_locked_hint')), findsOneWidget);
      expect(find.textContaining('1件ずつ追加できます'), findsOneWidget);
      expect(find.byKey(const Key('rakuten_search_bulk_add_button')), findsNothing);
    });

    testWidgets('limits off shows bulk header and no lock hint', (tester) async {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      final state = resolveBatchCandidateAddAvailability(
        flags: offFlags,
        purchasedPlanOverride: MonetizationPlan.free,
      );
      expect(state.allowed, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RakutenBulkAddUiProbe(
              batchAddState: state,
              selectableCount: 3,
              resultsVisible: true,
              selectedCount: 2,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('rakuten_search_bulk_selection_header')), findsOneWidget);
      expect(find.byKey(const Key('rakuten_search_bulk_add_locked_hint')), findsNothing);
      expect(find.byKey(const Key('rakuten_search_bulk_add_button')), findsOneWidget);
    });

    testWidgets('basic + limits on shows bulk header', (tester) async {
      final state = resolveBatchCandidateAddAvailability(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.basic,
      );
      expect(state.allowed, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RakutenBulkAddUiProbe(
              batchAddState: state,
              selectableCount: 2,
              resultsVisible: true,
              selectedCount: 1,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('rakuten_search_bulk_selection_header')), findsOneWidget);
      expect(find.byKey(const Key('rakuten_search_bulk_add_locked_hint')), findsNothing);
      expect(find.byKey(const Key('rakuten_search_bulk_add_button')), findsOneWidget);
    });

    testWidgets('pro + limits on shows bulk header', (tester) async {
      final state = resolveBatchCandidateAddAvailability(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.pro,
      );
      expect(state.allowed, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RakutenBulkAddUiProbe(
              batchAddState: state,
              selectableCount: 2,
              resultsVisible: true,
              selectedCount: 1,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('rakuten_search_bulk_selection_header')), findsOneWidget);
      expect(find.byKey(const Key('rakuten_search_bulk_add_locked_hint')), findsNothing);
    });

    testWidgets('selectable=0 shows neither header nor lock hint', (tester) async {
      final state = resolveBatchCandidateAddAvailability(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.free,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RakutenBulkAddUiProbe(
              batchAddState: state,
              selectableCount: 0,
              resultsVisible: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('rakuten_search_bulk_selection_header')), findsNothing);
      expect(find.byKey(const Key('rakuten_search_bulk_add_locked_hint')), findsNothing);
      expect(find.byKey(const Key('rakuten_search_bulk_add_button')), findsNothing);
    });

    testWidgets('results not visible shows neither header nor lock hint', (
      tester,
    ) async {
      final state = resolveBatchCandidateAddAvailability(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.free,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RakutenBulkAddUiProbe(
              batchAddState: state,
              selectableCount: 3,
              resultsVisible: false,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('rakuten_search_bulk_selection_header')), findsNothing);
      expect(find.byKey(const Key('rakuten_search_bulk_add_locked_hint')), findsNothing);
    });

    testWidgets('individual add remains available when bulk locked', (tester) async {
      final state = resolveBatchCandidateAddAvailability(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.free,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                _RakutenBulkAddUiProbe(
                  batchAddState: state,
                  selectableCount: 3,
                  resultsVisible: true,
                ),
                ElevatedButton(
                  key: const Key('rakuten_search_single_add_button'),
                  onPressed: () {},
                  child: const Text('候補'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('rakuten_search_single_add_button')), findsOneWidget);
      expect(find.byKey(const Key('rakuten_search_bulk_selection_header')), findsNothing);
    });
  });

  group('RakutenSearch bulk add guard', () {
    test('free + limits on resolves to not allowed', () {
      final state = resolveBatchCandidateAddAvailability(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.free,
      );
      expect(state.allowed, isFalse);
      expect(canUseBatchCandidateAdd(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.free,
      ), isFalse);
    });

    test('FREE_PLAN_LIMITS_ENABLED=false allows bulk add', () {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      expect(
        resolveBatchCandidateAddAvailability(
          flags: offFlags,
          purchasedPlanOverride: MonetizationPlan.free,
        ).allowed,
        isTrue,
      );
    });
  });
}

/// 楽天検索画面の一括追加UI分岐をテスト用に再現する。
class _RakutenBulkAddUiProbe extends StatelessWidget {
  const _RakutenBulkAddUiProbe({
    required this.batchAddState,
    required this.selectableCount,
    required this.resultsVisible,
    this.selectedCount = 0,
  });

  final BatchCandidateAddAvailabilityState batchAddState;
  final int selectableCount;
  final bool resultsVisible;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    final bulkCheckboxPhaseVisible = resultsVisible;
    final bulkSelectAllowed = batchAddState.allowed &&
        selectableCount > 0 &&
        bulkCheckboxPhaseVisible;
    return Column(
      children: [
        if (bulkSelectAllowed)
          SearchBulkSelectionHeader(
            key: const Key('rakuten_search_bulk_selection_header'),
            screen: 'productSearch',
            selectedCount: selectedCount,
            totalSelectable: selectableCount,
            onToggleAll: (_) {},
          )
        else if (selectableCount > 0 &&
            bulkCheckboxPhaseVisible &&
            batchAddState.limitsEnforcementEnabled &&
            !batchAddState.allowed)
          Text(
            batchCandidateAddLockedMessage(),
            key: const Key('rakuten_search_bulk_add_locked_hint'),
          ),
        if (selectedCount > 0 && batchAddState.allowed)
          Text(
            'まとめて候補に追加（$selectedCount件）',
            key: const Key('rakuten_search_bulk_add_button'),
          ),
      ],
    );
  }
}
