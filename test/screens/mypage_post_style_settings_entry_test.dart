import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/repository/easy_initial_setup_repository.dart';
import 'package:room_manager2/repository/operation_tutorial_repository.dart';
import 'package:room_manager2/repository/post_style_settings_repository.dart';
import 'package:room_manager2/repository/room_recommendation_profile_repository.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/repository/user_profile_repository.dart';
import 'package:room_manager2/screens/mypage_placeholder_screen.dart';
import 'package:room_manager2/screens/post_style_settings_screen.dart';
import 'package:room_manager2/state/operation_tutorial_controller.dart';
import 'package:room_manager2/state/post_style_settings_provider.dart';
import 'package:room_manager2/state/room_recommendation_profile_provider.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
import 'package:room_manager2/state/user_profile_provider.dart';
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
      ChangeNotifierProvider(
        create: (_) => PostStyleSettingsProvider(
          repository: PostStyleSettingsRepository(prefs),
        ),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Mypage post style settings entry', () {
    testWidgets('shows post style settings entry', (tester) async {
      setTallViewport(tester);
      SharedPreferences.setMockInitialValues({
        EasyInitialSetupRepository.completedKey: true,
        OperationTutorialRepository.profileDismissedKey: true,
        'user_profile_v1':
            '{"displayName":"テスト","roomUrl":"https://room.rakuten.co.jp/test/room"}',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _wrap(
          prefs: prefs,
          child: const MypagePlaceholderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('投稿スタイル設定'), findsOneWidget);
      expect(
        find.text('AI投稿文の文体・長さ・ハッシュタグを調整'),
        findsOneWidget,
      );
    });

    testWidgets('navigates to post style settings screen on tap', (
      tester,
    ) async {
      setTallViewport(tester);
      SharedPreferences.setMockInitialValues({
        EasyInitialSetupRepository.completedKey: true,
        OperationTutorialRepository.profileDismissedKey: true,
        'user_profile_v1':
            '{"displayName":"テスト","roomUrl":"https://room.rakuten.co.jp/test/room"}',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _wrap(
          prefs: prefs,
          child: const MypagePlaceholderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('投稿スタイル設定'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('投稿スタイル設定'));
      await tester.pumpAndSettle();

      expect(find.byType(PostStyleSettingsScreen), findsOneWidget);
      expect(find.text('生成イメージ'), findsOneWidget);
    });
  });
}
