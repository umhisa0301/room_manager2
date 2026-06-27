import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/repository/easy_initial_setup_repository.dart';
import 'package:room_manager2/repository/operation_tutorial_repository.dart';
import 'package:room_manager2/repository/user_profile_repository.dart';
import 'package:room_manager2/state/operation_tutorial_controller.dart';
import 'package:room_manager2/state/user_profile_provider.dart';
import 'package:room_manager2/widgets/tutorial/tutorial_overlay_host.dart';
import 'package:room_manager2/widgets/tutorial/tutorial_target_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TutorialOverlayHost', () {
    late OperationTutorialController controller;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      final repo = OperationTutorialRepository(prefs);
      controller = OperationTutorialController(repo);
    });

    Widget wrap(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProfileProvider>(
            create: (_) => UserProfileProvider(
              repository: UserProfileRepository(prefs),
            ),
          ),
          ChangeNotifierProvider<EasyInitialSetupRepository>(
            create: (_) => EasyInitialSetupRepository(prefs),
          ),
          ChangeNotifierProvider<OperationTutorialController>.value(
            value: controller,
          ),
        ],
        child: MaterialApp(
          home: TutorialOverlayHost(child: child),
        ),
      );
    }

    testWidgets('shows overlay when tutorial active', (tester) async {
      await tester.pumpWidget(
        wrap(
          Scaffold(
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
        wrap(
          Scaffold(
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

    testWidgets('blocks background tap while tutorial active', (tester) async {
      var backgroundTapped = false;

      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: ListView(
              children: [
                SizedBox(
                  key: TutorialTargetKeys.roomSettingsCard,
                  height: 120,
                  child: ElevatedButton(
                    onPressed: () => backgroundTapped = true,
                    child: const Text('背景ボタン'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      controller.startProfileTutorial(forceReplay: false);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('背景ボタン'));
      await tester.pump();

      expect(backgroundTapped, isFalse);
      expect(find.byKey(const Key('tutorial_next_button')), findsOneWidget);
    });

    testWidgets('blocks background scroll while tutorial active', (tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: ListView(
              controller: scrollController,
              children: [
                Container(
                  key: TutorialTargetKeys.roomSettingsCard,
                  height: 120,
                  color: Colors.blue,
                ),
                for (var i = 0; i < 30; i++)
                  SizedBox(height: 48, child: Text('row $i')),
              ],
            ),
          ),
        ),
      );

      controller.startProfileTutorial(forceReplay: false);
      await tester.pump();
      await tester.pump();

      final before = scrollController.offset;
      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pump();
      expect(scrollController.offset, before);
    });

    testWidgets('未設定時 step0 targets setup incomplete card key', (tester) async {
      await SharedPreferences.getInstance().then((p) async {
        await p.setBool(EasyInitialSetupRepository.completedKey, false);
      });

      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: ListView(
              children: [
                Container(
                  key: TutorialTargetKeys.setupIncompleteCard,
                  height: 120,
                  color: Colors.orange,
                ),
                Container(
                  key: TutorialTargetKeys.roomTypeDiagnosisCard,
                  height: 120,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ),
      );

      controller.startProfileTutorial(forceReplay: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ROOMプロフィール'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });
  });
}
