import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/dev_automation_config.dart';
import 'package:room_manager2/services/dev_automation_visible_run.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DevAutomationVisibleRun', () {
    testWidgets('startTabTourProductSearch is no-op when automation disabled', (
      WidgetTester tester,
    ) async {
      if (DevAutomationFlags.isEnabled) return;

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      await DevAutomationVisibleRun.startTabTourProductSearch(
        context: tester.element(find.byType(Scaffold)),
        iterations: 1,
      );

      expect(DevAutomationVisibleRun.activeRunner, isNull);
    });
  });
}
