import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/repository/easy_initial_setup_repository.dart';
import 'package:room_manager2/repository/operation_tutorial_repository.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/repository/user_profile_repository.dart';
import 'package:room_manager2/screens/mypage_placeholder_screen.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
import 'package:room_manager2/state/user_profile_provider.dart';
import 'package:room_manager2/repository/room_recommendation_profile_repository.dart';
import 'package:room_manager2/state/room_recommendation_profile_provider.dart';
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

  group('MyPageSetupIncompleteCard visibility', () {
    testWidgets('hidden while profile tutorial is not dismissed', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        EasyInitialSetupRepository.completedKey: false,
        OperationTutorialRepository.profileDismissedKey: false,
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
    });

    testWidgets('shown when tutorial dismissed and setup incomplete', (
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
      expect(find.text('プロフィール設定を編集'), findsOneWidget);
      expect(find.text('初期設定を再開'), findsNothing);
    });
  });
}
