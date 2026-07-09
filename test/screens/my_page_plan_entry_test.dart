import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/screens/monetization_plan_screen.dart';
import 'package:room_manager2/screens/mypage_placeholder_screen.dart';
import 'package:room_manager2/services/analytics_service.dart';

Widget _settingsSection({
  required VoidCallback onOpenPlan,
  VoidCallback? onOpenInitialSetup,
}) {
  return SingleChildScrollView(
    child: MyPageSettingsSection(
      onOpenPlan: onOpenPlan,
      onOpenInitialSetup: onOpenInitialSetup ?? () {},
      onOpenSavedShops: () {},
    ),
  );
}

void main() {
  group('MyPage plan entry', () {
    testWidgets('shows plan entry in settings section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _settingsSection(onOpenPlan: () {}),
          ),
        ),
      );

      expect(find.byKey(const Key('mypage_plan_entry')), findsOneWidget);
      expect(find.text('プランを見る'), findsOneWidget);
      expect(find.text('現在のプラン'), findsOneWidget);
    });

    testWidgets('navigates to MonetizationPlanScreen on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _settingsSection(
              onOpenPlan: () {
                Navigator.of(tester.element(find.byType(Scaffold))).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => Provider<AnalyticsService>.value(
                      value: const NoOpAnalyticsService(),
                      child: const MonetizationPlanScreen(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('mypage_plan_entry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('monetization_plan_screen')), findsOneWidget);
      expect(find.text('プランを見る'), findsWidgets);
    });
  });
}
