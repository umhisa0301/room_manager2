import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/repository/easy_initial_setup_repository.dart';
import 'package:room_manager2/repository/operation_tutorial_repository.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/repository/user_profile_repository.dart';
import 'package:room_manager2/screens/easy_initial_setup_screen.dart';
import 'package:room_manager2/screens/mypage_placeholder_screen.dart'
    show ProfileEditSheet;
import 'package:room_manager2/screens/room_type_diagnosis_screen.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/operation_tutorial_controller.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
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
      SharedPreferences.setMockInitialValues({
        EasyInitialSetupRepository.completedKey: true,
      });
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
          ChangeNotifierProvider<SavedShopProvider>(
            create: (_) => SavedShopProvider(
              repository: SavedShopRepository(prefs),
            ),
          ),
          Provider(
            create: (_) => RakutenSearchRepository(apiService: RakutenApiService()),
          ),
          Provider(create: (_) => ProductCatalogRepository(prefs)),
          ChangeNotifierProvider<OperationTutorialController>.value(
            value: controller,
          ),
        ],
        child: MaterialApp(
          home: TutorialOverlayHost(child: child),
        ),
      );
    }

    Future<void> startTutorialAndSettle(WidgetTester tester) async {
      controller.startProfileTutorial(forceReplay: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
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

      await startTutorialAndSettle(tester);

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

      await startTutorialAndSettle(tester);

      expect(controller.stepIndex, 0);
      await tester.tap(find.byKey(const Key('tutorial_next_button')));
      await tester.pump();
      expect(controller.stepIndex, 1);
      expect(find.text('ROOMタイプ診断'), findsOneWidget);
    });

    testWidgets('skip button closes tutorial', (tester) async {
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: ListView(
              children: [
                Container(
                  key: TutorialTargetKeys.roomSettingsCard,
                  height: 120,
                ),
              ],
            ),
          ),
        ),
      );

      await startTutorialAndSettle(tester);
      await tester.tap(find.byKey(const Key('tutorial_skip_button')));
      await tester.pump();

      expect(controller.isActive, isFalse);
    });

    testWidgets('blocks non-target background tap while tutorial active',
        (tester) async {
      var nonTargetTapped = false;

      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: ListView(
              children: [
                ElevatedButton(
                  onPressed: () => nonTargetTapped = true,
                  child: const Text('対象外ボタン'),
                ),
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

      await startTutorialAndSettle(tester);

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();

      expect(nonTargetTapped, isFalse);
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

      await startTutorialAndSettle(tester);

      final before = scrollController.offset;
      await tester.dragFrom(
        const Offset(200, 400),
        const Offset(0, -240),
      );
      await tester.pump();
      expect(scrollController.offset, before);
    });

    testWidgets('target tap closes overlay on configured step', (tester) async {
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

      await startTutorialAndSettle(tester);

      expect(find.byKey(const Key('tutorial_target_tap_area')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tutorial_target_tap_area')));
      await tester.pump();

      expect(controller.isActive, isFalse);
      expect(find.byKey(const Key('tutorial_next_button')), findsNothing);
    });

    testWidgets('設定済み step0 targetAction opens profile edit sheet',
        (tester) async {
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

      await startTutorialAndSettle(tester);
      await tester.tap(find.byKey(const Key('tutorial_target_tap_area')));
      await tester.pumpAndSettle();

      expect(controller.isActive, isFalse);
      expect(find.byType(ProfileEditSheet), findsOneWidget);
    });

    testWidgets('未設定 step0 targetAction opens profile setup screen',
        (tester) async {
      await prefs.setBool(EasyInitialSetupRepository.completedKey, false);

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
              ],
            ),
          ),
        ),
      );

      await startTutorialAndSettle(tester);
      await tester.tap(find.byKey(const Key('tutorial_target_tap_area')));
      await tester.pumpAndSettle();

      expect(controller.isActive, isFalse);
      expect(find.byType(EasyInitialSetupScreen), findsOneWidget);
    });

    testWidgets('step1 targetAction opens room type diagnosis screen',
        (tester) async {
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

      await startTutorialAndSettle(tester);
      await tester.tap(find.byKey(const Key('tutorial_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const Key('tutorial_target_tap_area')));
      await tester.pumpAndSettle();

      expect(controller.isActive, isFalse);
      expect(find.byType(RoomTypeDiagnosisScreen), findsOneWidget);
    });

    testWidgets('未設定時 step0 targets setup incomplete card key', (tester) async {
      await prefs.setBool(EasyInitialSetupRepository.completedKey, false);

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

      await startTutorialAndSettle(tester);

      expect(find.text('ROOMプロフィール'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });
  });
}
