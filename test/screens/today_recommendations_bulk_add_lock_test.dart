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
  group('TodayRecommendations bulk add lock UI probe', () {
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
            body: _BulkAddUiProbe(
              batchAddState: state,
              selectableCount: 3,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('today_recommendation_bulk_selection_header')), findsNothing);
      expect(find.byKey(const Key('today_recommendation_bulk_add_locked_hint')), findsOneWidget);
      expect(find.textContaining('1件ずつ追加できます'), findsOneWidget);
      expect(find.byKey(const Key('today_recommendation_bulk_add_button')), findsNothing);
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
            body: _BulkAddUiProbe(
              batchAddState: state,
              selectableCount: 3,
              selectedCount: 2,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('today_recommendation_bulk_selection_header')), findsOneWidget);
      expect(find.byKey(const Key('today_recommendation_bulk_add_locked_hint')), findsNothing);
      expect(find.byKey(const Key('today_recommendation_bulk_add_button')), findsOneWidget);
    });

    testWidgets('selectable=0 shows neither header nor lock hint', (tester) async {
      final state = resolveBatchCandidateAddAvailability(
        flags: _limitsOnFlags(),
        purchasedPlanOverride: MonetizationPlan.free,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _BulkAddUiProbe(
              batchAddState: state,
              selectableCount: 0,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('today_recommendation_bulk_selection_header')), findsNothing);
      expect(find.byKey(const Key('today_recommendation_bulk_add_locked_hint')), findsNothing);
      expect(find.byKey(const Key('today_recommendation_bulk_add_button')), findsNothing);
    });
  });
}

/// おすすめコレ画面の一括追加UI分岐をテスト用に再現する。
class _BulkAddUiProbe extends StatelessWidget {
  const _BulkAddUiProbe({
    required this.batchAddState,
    required this.selectableCount,
    this.selectedCount = 0,
  });

  final BatchCandidateAddAvailabilityState batchAddState;
  final int selectableCount;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    final bulkSelectAllowed = batchAddState.allowed && selectableCount > 0;
    return Column(
      children: [
        if (bulkSelectAllowed)
          SearchBulkSelectionHeader(
            key: const Key('today_recommendation_bulk_selection_header'),
            screen: 'todayRecommendations',
            selectedCount: selectedCount,
            totalSelectable: selectableCount,
            onToggleAll: (_) {},
          )
        else if (selectableCount > 0 &&
            batchAddState.limitsEnforcementEnabled &&
            !batchAddState.allowed)
          Text(
            batchCandidateAddLockedMessage(),
            key: const Key('today_recommendation_bulk_add_locked_hint'),
          ),
        if (selectedCount > 0 && batchAddState.allowed)
          Text(
            'まとめて候補に追加（$selectedCount件）',
            key: const Key('today_recommendation_bulk_add_button'),
          ),
      ],
    );
  }
}
