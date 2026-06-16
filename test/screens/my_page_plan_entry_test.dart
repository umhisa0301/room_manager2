import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/screens/monetization_plan_screen.dart';
import 'package:room_manager2/screens/mypage_placeholder_screen.dart';

void main() {
  group('MyPage plan entry', () {
    testWidgets('shows plan entry in settings section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MyPageSettingsSection(
              onOpenPlan: () {},
              onOpenInitialSetup: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('mypage_plan_entry')), findsOneWidget);
      expect(find.text('プランを見る'), findsOneWidget);
      expect(find.text('無料版とBasicプランの違い'), findsOneWidget);
    });

    testWidgets('navigates to MonetizationPlanScreen on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MyPageSettingsSection(
              onOpenPlan: () {
                Navigator.of(tester.element(find.byType(Scaffold))).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const MonetizationPlanScreen(),
                  ),
                );
              },
              onOpenInitialSetup: () {},
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
