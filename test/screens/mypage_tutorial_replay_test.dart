import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/screens/mypage_placeholder_screen.dart';
import 'package:room_manager2/state/operation_tutorial_controller.dart';
import 'package:room_manager2/repository/operation_tutorial_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _settingsSection({required VoidCallback onOpenTutorialReplay}) {
  return SingleChildScrollView(
    child: MyPageSettingsSection(
      onOpenPlan: () {},
      onOpenInitialSetup: () {},
      onOpenSavedShops: () {},
      onOpenTutorialReplay: onOpenTutorialReplay,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MyPage tutorial replay entry', () {
  late OperationTutorialController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        OperationTutorialRepository.profileDismissedKey: true,
        OperationTutorialRepository.profileCompletedKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = OperationTutorialRepository(prefs);
      controller = OperationTutorialController(repo);
    });

    testWidgets('shows replay menu item', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _settingsSection(onOpenTutorialReplay: () {}),
          ),
        ),
      );

      expect(find.byKey(const Key('mypage_tutorial_replay_entry')), findsOneWidget);
      expect(find.text('操作ガイドをもう一度見る'), findsOneWidget);
    });

    testWidgets('tap starts tutorial with forceReplay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<OperationTutorialController>.value(
              value: controller,
              child: _settingsSection(
                onOpenTutorialReplay: () {
                  controller.startProfileTutorial(forceReplay: true);
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('mypage_tutorial_replay_entry')));
      await tester.pump();

      expect(controller.isActive, isTrue);
      expect(controller.isForceReplay, isTrue);
    });
  });
}
