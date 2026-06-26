import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/state/operation_tutorial_controller.dart';
import 'package:room_manager2/repository/operation_tutorial_repository.dart';
import 'package:room_manager2/widgets/tutorial/tutorial_overlay_host.dart';
import 'package:room_manager2/widgets/tutorial/tutorial_target_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TutorialOverlayHost', () {
    late OperationTutorialController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = OperationTutorialRepository(prefs);
      controller = OperationTutorialController(repo);
    });

    testWidgets('shows overlay when tutorial active', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OperationTutorialController>.value(
            value: controller,
            child: TutorialOverlayHost(
              child: Scaffold(
                body: ListView(
                  children: [
                    Container(
                      key: TutorialTargetKeys.roomSettingsCard,
                      height: 120,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      controller.startProfileTutorial(forceReplay: false);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('tutorial_next_button')), findsOneWidget);
      expect(find.byKey(const Key('tutorial_skip_button')), findsOneWidget);
      expect(find.text('ROOMプロフィール'), findsOneWidget);
    });

    testWidgets('next button advances steps', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OperationTutorialController>.value(
            value: controller,
            child: TutorialOverlayHost(
              child: Scaffold(
                body: ListView(
                  children: [
                    Container(
                      key: TutorialTargetKeys.roomSettingsCard,
                      height: 120,
                    ),
                    Container(
                      key: TutorialTargetKeys.roomTypeDiagnosisCard,
                      height: 120,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      controller.startProfileTutorial(forceReplay: false);
      await tester.pump();
      await tester.pump();

      expect(controller.stepIndex, 0);
      await tester.tap(find.byKey(const Key('tutorial_next_button')));
      await tester.pump();
      expect(controller.stepIndex, 1);
      expect(find.text('ROOMタイプ診断'), findsOneWidget);
    });
  });
}
