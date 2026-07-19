import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/navigation/app_shell_controller.dart';
import 'package:room_manager2/repository/pending_collect_notice_repository.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/repository/room_activity_event_repository.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/repository/user_profile_repository.dart';
import 'package:room_manager2/state/bulk_operation_state_controller.dart';
import 'package:room_manager2/state/rakuten_managed_product_provider.dart';
import 'package:room_manager2/state/room_activity_event_provider.dart';
import 'package:room_manager2/state/room_import_controller.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
import 'package:room_manager2/state/user_profile_provider.dart';
import 'package:room_manager2/widgets/activity/activity_analytics_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapAnalytics({
  required SharedPreferences prefs,
  required ScrollController scrollController,
  BulkOperationStateController? bulkOverride,
}) {
  final bulk = bulkOverride ?? BulkOperationStateController();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: bulk),
      ChangeNotifierProvider(
        create: (ctx) => RoomImportController(bulkOperationState: bulk),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            UserProfileProvider(repository: UserProfileRepository(prefs)),
      ),
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
          bulkOperationState: bulk,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            SavedShopProvider(repository: SavedShopRepository(prefs)),
      ),
      ChangeNotifierProvider(create: (_) => AppShellController()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ActivityAnalyticsTab(
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

  group('ActivityAnalyticsTab 反応空状態 CTA', () {
    testWidgets('「反応を確認する」CTA が表示される', (tester) async {
      await tester.pumpWidget(
        _wrapAnalytics(prefs: prefs, scrollController: scrollController),
      );
      await tester.pumpAndSettle();

      expect(find.text('まだ反応データがありません。'), findsOneWidget);
      expect(find.text('反応を確認する'), findsOneWidget);
    });

    testWidgets('busy 時は CTA が disabled', (tester) async {
      final bulk = BulkOperationStateController()
        ..setRoomReactionSyncRunning(true);

      await tester.pumpWidget(
        _wrapAnalytics(
          prefs: prefs,
          scrollController: scrollController,
          bulkOverride: bulk,
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '反応を確認する'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('押下で既存確認 Dialog が表示されキャンセルできる', (tester) async {
      await tester.pumpWidget(
        _wrapAnalytics(prefs: prefs, scrollController: scrollController),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('反応を確認する'));
      await tester.pumpAndSettle();

      expect(find.text('反応を確認する'), findsWidgets);
      expect(find.text('開始する'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(find.text('開始する'), findsNothing);
    });
  });
}
