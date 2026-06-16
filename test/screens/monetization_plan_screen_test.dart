import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:room_manager2/config/billing_product_config.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/screens/monetization_plan_screen.dart';
import 'package:room_manager2/services/billing_product_service.dart';
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
      BillingProductQueryResult? billingQueryResultOverride,
      bool skipBillingQuery = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MonetizationPlanScreen(
            flags: flags,
            billingQueryResultOverride: billingQueryResultOverride ??
                createPlannedFallbackBillingQueryResult(),
            skipBillingQuery: skipBillingQuery,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders plan screen with current free plan chip', (tester) async {
      await pumpPlanScreen(tester, flags: _allOnFlags());

      expect(find.byKey(const Key('monetization_plan_screen')), findsOneWidget);
      expect(find.byKey(const Key('monetization_plan_current_label')), findsOneWidget);
      expect(find.text(MonetizationPlanDisplayCopy.currentPlanChipLabel), findsOneWidget);
      expect(find.text('無料版'), findsWidgets);
      expect(find.text('現在のプラン'), findsNothing);
    });

    testWidgets('shows Basic card before Free card', (tester) async {
      await pumpPlanScreen(tester, flags: _allOnFlags());

      final basic = find.byKey(const Key('monetization_plan_basic_card'));
      final free = find.byKey(const Key('monetization_plan_free_card'));
      expect(basic, findsOneWidget);
      expect(free, findsOneWidget);

      final basicPos = tester.getTopLeft(basic);
      final freePos = tester.getTopLeft(free);
      final basicComesFirst = basicPos.dy < freePos.dy ||
          (basicPos.dy == freePos.dy && basicPos.dx < freePos.dx);
      expect(basicComesFirst, isTrue);
    });

    testWidgets('shows recommended label on Basic card', (tester) async {
      await pumpPlanScreen(tester, flags: _allOnFlags());

      expect(find.byKey(const Key('monetization_plan_basic_recommended')), findsOneWidget);
      expect(find.text(MonetizationPlanDisplayCopy.basicRecommendedLabel), findsOneWidget);
      expect(find.text(MonetizationPlanDisplayCopy.basicPlanTagline), findsOneWidget);
    });

    testWidgets('shows Free and Basic plan cards with prices', (tester) async {
      await pumpPlanScreen(tester, flags: _allOnFlags());

      expect(find.byKey(const Key('monetization_plan_free_card')), findsOneWidget);
      expect(find.byKey(const Key('monetization_plan_basic_card')), findsOneWidget);
      expect(find.byKey(const Key('monetization_plan_free_price')), findsOneWidget);
      expect(find.byKey(const Key('monetization_plan_basic_price')), findsOneWidget);
      expect(find.text(MonetizationPlanDisplayCopy.freePriceAmount), findsOneWidget);
      expect(find.text(MonetizationPlanDisplayCopy.basicPriceAmount), findsOneWidget);
      expect(find.text(MonetizationPlanDisplayCopy.freePlanTagline), findsOneWidget);
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

    testWidgets('coming soon button shows snackbar without purchase', (
      tester,
    ) async {
      await pumpPlanScreen(tester, flags: _allOnFlags());

      await tester.tap(find.byKey(const Key('monetization_plan_basic_coming_soon')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(MonetizationPlanDisplayCopy.preparingSnackBarMessage),
        findsOneWidget,
      );
    });

    testWidgets('shows free vs basic comparison from limits', (tester) async {
      await pumpPlanScreen(tester, flags: _allOnFlags());

      final free = kFreeMonetizationPlanLimits;
      final basic = kBasicMonetizationPlanLimits;

      expect(find.text('ROOM更新'), findsOneWidget);
      expect(find.text('詳細検索'), findsOneWidget);
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

    testWidgets('comparison table omits non-differentiating keyword search rows', (
      tester,
    ) async {
      await pumpPlanScreen(tester, flags: _allOnFlags());

      expect(find.text('通常キーワード検索'), findsNothing);
      expect(find.text('1件ずつ候補追加'), findsNothing);
      expect(find.text('おすすめコレ一括追加'), findsNothing);
      expect(find.text('楽天検索の一括追加'), findsNothing);
      expect(find.byKey(const Key('monetization_plan_free_footnote')), findsOneWidget);
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

    testWidgets('shows store price when billing query returns basic product', (
      tester,
    ) async {
      await pumpPlanScreen(
        tester,
        flags: _allOnFlags(),
        billingQueryResultOverride: BillingProductQueryResult.fromProducts(
          products: [
            BillingProductDetails(
              productId: BillingProductConfig.basicMonthlyProductId,
              title: 'Basic',
              description: 'desc',
              price: '¥500',
              rawPrice: 500,
              currencyCode: 'JPY',
            ),
          ],
        ),
      );

      expect(find.text('¥500'), findsOneWidget);
      expect(find.text('（予定）'), findsNothing);
    });

    testWidgets('shows planned price when billing products are not found', (
      tester,
    ) async {
      await pumpPlanScreen(
        tester,
        flags: _allOnFlags(),
        billingQueryResultOverride: createPlannedFallbackBillingQueryResult(),
      );

      expect(find.text(MonetizationPlanDisplayCopy.basicPriceAmount), findsOneWidget);
      expect(find.text('（予定）'), findsOneWidget);
      expect(
        find.text(MonetizationPlanDisplayCopy.billingStatusFetchFailed),
        findsOneWidget,
      );
    });

    testWidgets('shows checking status while billing query is loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MonetizationPlanScreen(
            flags: _allOnFlags(),
            skipBillingQuery: false,
            billingProductService: BillingProductService(
              gateway: _NeverCompletingGateway(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(MonetizationPlanDisplayCopy.billingStatusChecking),
        findsOneWidget,
      );
      expect(find.text(MonetizationPlanDisplayCopy.basicPriceLoadingLabel), findsOneWidget);
    });
  });

  group('buildFreeBasicComparisonLines', () {
    test('reflects MonetizationPlanLimits values with six rows', () {
      final lines = buildFreeBasicComparisonLines();
      expect(lines.length, 6);

      final roomLine = lines.firstWhere(
        (line) => line.label == 'ROOM更新',
      );
      expect(roomLine.freeValue, formatRoomImportLimitDisplay(10));
      expect(roomLine.basicValue, '上限なし');

      final genLine = lines.firstWhere(
        (line) => line.label == 'おすすめ生成',
      );
      expect(genLine.freeValue, '1日1回');
      expect(genLine.basicValue, '1日5回');

      final refreshLine = lines.firstWhere(
        (line) => line.label == 'おすすめ再生成',
      );
      expect(refreshLine.freeValue, '1日1回');
      expect(refreshLine.basicValue, '1日5回');

      final detailLine = lines.firstWhere(
        (line) => line.label == '詳細検索',
      );
      expect(detailLine.freeValue, '×');
      expect(detailLine.basicValue, '○');
    });

    test('uses short availability markers for batch add', () {
      final lines = buildFreeBasicComparisonLines();
      final batchLine = lines.firstWhere(
        (line) => line.label == '一括追加',
      );
      expect(batchLine.freeValue, '×');
      expect(batchLine.basicValue, '○');
    });
  });
}

class _NeverCompletingGateway implements InAppPurchaseGateway {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> productIds) {
    return Completer<ProductDetailsResponse>().future;
  }
}
