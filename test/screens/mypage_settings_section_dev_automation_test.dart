import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/dev_automation_config.dart';
import 'package:room_manager2/screens/mypage_placeholder_screen.dart';

Widget _settingsSection({
  required VoidCallback onOpenPlan,
  VoidCallback? onOpenDevAutomation,
}) {
  return SingleChildScrollView(
    child: MyPageSettingsSection(
      onOpenPlan: onOpenPlan,
      onOpenDevAutomation: onOpenDevAutomation,
      onOpenInitialSetup: () {},
      onOpenSavedShops: () {},
    ),
  );
}

void main() {
  group('MyPageSettingsSection dev automation entry', () {
    testWidgets('shows entry button only when callback is provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _settingsSection(onOpenPlan: () {}),
          ),
        ),
      );

      expect(find.text('開発者向け自動検証'), findsNothing);
    });

    testWidgets('shows entry button when dev automation callback is provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _settingsSection(
              onOpenPlan: () {},
              onOpenDevAutomation: () {},
            ),
          ),
        ),
      );

      expect(find.text('開発者向け自動検証'), findsOneWidget);
    });

    testWidgets('entry visibility matches DevAutomationFlags.isEnabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _settingsSection(
              onOpenPlan: () {},
              onOpenDevAutomation:
                  DevAutomationFlags.isEnabled ? () {} : null,
            ),
          ),
        ),
      );

      if (DevAutomationFlags.isEnabled) {
        expect(find.text('開発者向け自動検証'), findsOneWidget);
      } else {
        expect(find.text('開発者向け自動検証'), findsNothing);
      }
    });
  });
}
