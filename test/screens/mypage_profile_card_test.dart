import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/repository/easy_initial_setup_repository.dart';
import 'package:room_manager2/repository/operation_tutorial_repository.dart';
import 'package:room_manager2/repository/room_recommendation_profile_repository.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/repository/user_profile_repository.dart';
import 'package:room_manager2/screens/mypage_placeholder_screen.dart';
import 'package:room_manager2/state/operation_tutorial_controller.dart';
import 'package:room_manager2/state/room_recommendation_profile_provider.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
import 'package:room_manager2/state/user_profile_provider.dart';
import 'package:room_manager2/widgets/tutorial/tutorial_target_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap({
  required SharedPreferences prefs,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => UserProfileProvider(
          repository: UserProfileRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => SavedShopProvider(repository: SavedShopRepository(prefs)),
      ),
      ChangeNotifierProvider(
        create: (_) => EasyInitialSetupRepository(prefs),
      ),
      ChangeNotifierProvider(
        create: (_) => OperationTutorialRepository(prefs),
      ),
      ChangeNotifierProvider(
        create: (ctx) => OperationTutorialController(
          ctx.read<OperationTutorialRepository>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => RoomRecommendationProfileProvider(
          repository: RoomRecommendationProfileRepository(prefs),
        ),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mypage profile card duplication', () {
    testWidgets('未設定時は設定完了カードのみでROOMプロフィールは非表示', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        EasyInitialSetupRepository.completedKey: false,
        OperationTutorialRepository.profileDismissedKey: true,
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _wrap(
          prefs: prefs,
          child: const MypagePlaceholderScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('設定を完了しましょう'), findsOneWidget);
      expect(find.text('ROOMプロフィール'), findsNothing);
      expect(find.text('プロフィール設定をまとめて編集'), findsNothing);
      expect(find.byKey(TutorialTargetKeys.setupIncompleteCard), findsOneWidget);
    });

    testWidgets('設定済み時はROOMプロフィールカードを表示', (tester) async {
      SharedPreferences.setMockInitialValues({
        EasyInitialSetupRepository.completedKey: true,
        OperationTutorialRepository.profileDismissedKey: true,
        'user_profile_v1': '{"displayName":"テスト","roomUrl":"https://room.rakuten.co.jp/test/room"}',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _wrap(
          prefs: prefs,
          child: const MypagePlaceholderScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('設定を完了しましょう'), findsNothing);
      expect(find.text('ROOMプロフィール'), findsOneWidget);
      expect(find.byKey(TutorialTargetKeys.roomSettingsCard), findsOneWidget);
    });
  });
}
