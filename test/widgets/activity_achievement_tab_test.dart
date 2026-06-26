import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/navigation/app_shell_controller.dart';
import 'package:room_manager2/repository/pending_collect_notice_repository.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/repository/room_activity_event_repository.dart';
import 'package:room_manager2/state/rakuten_managed_product_provider.dart';
import 'package:room_manager2/state/room_activity_event_provider.dart';
import 'package:room_manager2/widgets/activity/activity_achievement_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapAchievementTab({
  required SharedPreferences prefs,
  required ScrollController scrollController,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => RoomActivityEventProvider(
          repository: RoomActivityEventRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(
        create: (ctx) => RakutenManagedProductProvider(
          repository: RakutenManagedProductRepository(prefs),
          pendingCollectNoticeRepository: PendingCollectNoticeRepository(prefs),
          activityEventProvider: ctx.read<RoomActivityEventProvider>(),
        ),
      ),
      ChangeNotifierProvider(create: (_) => AppShellController()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ActivityAchievementTab(
          onRefresh: () async {},
          bottomInset: 24,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ScrollController scrollController;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    scrollController = ScrollController();
  });

  tearDown(() {
    scrollController.dispose();
  });

  group('ActivityAchievementTab', () {
    testWidgets('実績サブタブに今日のログが表示されない', (tester) async {
      await tester.pumpWidget(
        _wrapAchievementTab(
          prefs: prefs,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日のログ'), findsNothing);
      expect(find.text('もっと見る'), findsNothing);
      expect(find.text('まだログはありません'), findsNothing);
    });

    testWidgets('実績サブタブの主要カードは表示される', (tester) async {
      await tester.pumpWidget(
        _wrapAchievementTab(
          prefs: prefs,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今週の積み上げ'), findsOneWidget);
    });
  });
}
