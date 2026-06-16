import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/screens/monetization_plan_screen.dart';
import 'package:room_manager2/utils/monetization_plan_display.dart';

MonetizationFlagSnapshot _allOnFlags() => resolveMonetizationFlags(
      monetizationEnabled: true,
      adsEnabled: true,
      subscriptionEnabled: true,
      freePlanLimitsEnabled: true,
      proPlanEnabled: true,
    );

MonetizationFlagSnapshot _monetizationOffFlags() => resolveMonetizationFlags(
      monetizationEnabled: false,
      adsEnabled: true,
      subscriptionEnabled: true,
      freePlanLimitsEnabled: true,
      proPlanEnabled: true,
    );

MonetizationFlagSnapshot _subscriptionOffFlags() => resolveMonetizationFlags(
      monetizationEnabled: true,
      adsEnabled: true,
      subscriptionEnabled: false,
      freePlanLimitsEnabled: true,
      proPlanEnabled: true,
    );

void main() {
  group('MonetizationPlanScreen', () {
    Future<void> pumpPlanScreen(
      WidgetTester tester, {
      MonetizationFlagSnapshot? flags,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MonetizationPlanScreen(flags: flags),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders plan screen with current free plan', (tester) async {
      await pumpPlanScreen(tester, flags: _allOnFlags());

      expect(find.byKey(const Key('monetization_plan_screen')), findsOneWidget);
      expect(find.byKey(const Key('monetization_plan_current_label')), findsOneWidget);
      expect(find.text('無料版'), findsWidgets);
    });

    testWidgets('shows preparing notice instead of purchase button', (
      tester,
    ) async {
      await pumpPlanScreen(tester, flags: _allOnFlags());

      expect(find.byKey(const Key('monetization_plan_preparing_notice')), findsOneWidget);
      expect(find.textContaining('準備中'), findsWidgets);
      expect(find.byKey(const Key('monetization_plan_basic_coming_soon')), findsOneWidget);
      expect(find.text('今すぐ購入'), findsNothing);
      expect(find.text('購入する'), findsNothing);
    });

    testWidgets('shows basic planned monthly price', (tester) async {
      await pumpPlanScreen(tester, flags: _allOnFlags());

      expect(find.byKey(const Key('monetization_plan_basic_price')), findsOneWidget);
      expect(find.text(MonetizationPlanDisplayCopy.basicPlannedMonthlyPriceLabel), findsOneWidget);
    });

    testWidgets('shows free vs basic comparison from limits', (tester) async {
      await pumpPlanScreen(tester, flags: _allOnFlags());

      final free = kFreeMonetizationPlanLimits;
      final basic = kBasicMonetizationPlanLimits;

      expect(
        find.text(formatRoomImportLimitDisplay(free.roomImportLimitPerRun)),
        findsWidgets,
      );
      expect(
        find.text(formatRoomImportLimitDisplay(basic.roomImportLimitPerRun)),
        findsWidgets,
      );
      expect(
        find.text(formatDailyCountDisplay(free.dailyRecommendationLimit)),
        findsWidgets,
      );
      expect(
        find.text(formatDailyCountDisplay(basic.dailyRecommendationLimit)),
        findsWidgets,
      );
      expect(
        find.text(formatDailyCountDisplay(free.dailyRecommendationRefreshLimit)),
        findsWidgets,
      );
      expect(
        find.text(formatDailyCountDisplay(basic.dailyRecommendationRefreshLimit)),
        findsWidgets,
      );
      expect(
        find.text(formatFeatureAvailability(free.batchCandidateAddEnabled)),
        findsWidgets,
      );
      expect(
        find.text(formatFeatureAvailability(basic.batchCandidateAddEnabled)),
        findsWidgets,
      );
      expect(
        find.text(formatFeatureAvailability(free.advancedRakutenSearchSortEnabled)),
        findsWidgets,
      );
      expect(
        find.text(formatFeatureAvailability(basic.advancedRakutenSearchSortEnabled)),
        findsWidgets,
      );
    });

    testWidgets('shows subdued pro teaser', (tester) async {
      await pumpPlanScreen(tester, flags: _allOnFlags());

      await tester.scrollUntilVisible(
        find.byKey(const Key('monetization_plan_pro_teaser')),
        48,
      );

      expect(find.byKey(const Key('monetization_plan_pro_teaser')), findsOneWidget);
      expect(find.textContaining('今後追加予定'), findsOneWidget);
    });

    testWidgets('does not crash when MONETIZATION_ENABLED=false', (tester) async {
      await pumpPlanScreen(tester, flags: _monetizationOffFlags());

      expect(find.byKey(const Key('monetization_plan_screen')), findsOneWidget);
      expect(find.text('無料版'), findsWidgets);
    });

    testWidgets('does not crash when SUBSCRIPTION_ENABLED=false', (tester) async {
      await pumpPlanScreen(tester, flags: _subscriptionOffFlags());

      expect(find.byKey(const Key('monetization_plan_screen')), findsOneWidget);
      expect(find.text('無料版'), findsWidgets);
    });
  });

  group('buildFreeBasicComparisonLines', () {
    test('reflects MonetizationPlanLimits values', () {
      final lines = buildFreeBasicComparisonLines();
      final roomLine = lines.firstWhere(
        (line) => line.label == 'ROOMデータ更新 / 管理商品数',
      );
      expect(roomLine.freeValue, formatRoomImportLimitDisplay(10));
      expect(roomLine.basicValue, '上限なし');

      final genLine = lines.firstWhere(
        (line) => line.label == 'おすすめコレ生成',
      );
      expect(genLine.freeValue, '1日1回');
      expect(genLine.basicValue, '1日5回');
    });
  });
}
