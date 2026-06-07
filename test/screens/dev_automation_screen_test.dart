import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/dev_automation_config.dart';
import 'package:room_manager2/screens/dev_automation_screen.dart';

void main() {
  group('DevAutomationScreen', () {
    testWidgets('does not show content when automation is disabled', (
      WidgetTester tester,
    ) async {
      if (DevAutomationFlags.isEnabled) return;

      await tester.pumpWidget(
        const MaterialApp(home: DevAutomationScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text(DevAutomationScreen.title), findsNothing);
      expect(find.text('まだ実行機能はありません'), findsNothing);
    });

    testWidgets('shows placeholder content when automation is enabled', (
      WidgetTester tester,
    ) async {
      if (!DevAutomationFlags.isEnabled) return;

      await tester.pumpWidget(
        const MaterialApp(home: DevAutomationScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text(DevAutomationScreen.title), findsWidgets);
      expect(find.text('この機能は検証ビルド専用です'), findsOneWidget);
      expect(find.text('まだ実行機能はありません'), findsOneWidget);
      expect(find.text('主要タブ巡回'), findsOneWidget);
      expect(find.text('水筒検索反復'), findsOneWidget);
    });
  });
}
