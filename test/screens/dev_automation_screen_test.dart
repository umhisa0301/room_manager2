import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/config/dev_automation_config.dart';
import 'package:room_manager2/navigation/app_shell_controller.dart';
import 'package:room_manager2/repository/pending_collect_notice_repository.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/repository/room_activity_event_repository.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/screens/dev_automation_screen.dart';
import 'package:room_manager2/services/dev_automation_runner.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/rakuten_managed_product_provider.dart';
import 'package:room_manager2/state/rakuten_search_provider.dart';
import 'package:room_manager2/state/room_activity_event_provider.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap({required SharedPreferences prefs, required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppShellController()),
      Provider<RakutenSearchRepository>(
        create: (_) => RakutenSearchRepository(apiService: RakutenApiService()),
      ),
      ChangeNotifierProvider(
        create: (ctx) => RakutenSearchProvider(
          repository: ctx.read<RakutenSearchRepository>(),
        ),
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
        ),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            SavedShopProvider(repository: SavedShopRepository(prefs)),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  group('DevAutomationScreen', () {
    testWidgets('does not show content when automation is disabled', (
      WidgetTester tester,
    ) async {
      if (DevAutomationFlags.isEnabled) return;

      await tester.pumpWidget(const MaterialApp(home: DevAutomationScreen()));
      await tester.pumpAndSettle();

      expect(find.text(DevAutomationScreen.title), findsNothing);
      expect(find.text('主要タブ巡回 + 主要操作検証'), findsNothing);
    });

    testWidgets('shows scenario UI when automation is enabled', (
      WidgetTester tester,
    ) async {
      if (!DevAutomationFlags.isEnabled) return;

      await tester.pumpWidget(
        _wrap(prefs: prefs, child: const DevAutomationScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text(DevAutomationScreen.title), findsWidgets);
      expect(find.text('この機能は検証ビルド専用です'), findsOneWidget);
      expect(find.text('主要タブ巡回 + 主要操作検証'), findsOneWidget);
      expect(
        find.textContaining('おすすめコレ表示'),
        findsOneWidget,
      );
      expect(find.text('開始'), findsOneWidget);
      expect(find.text('停止'), findsOneWidget);
      expect(
        find.text('${DevAutomationRunner.defaultIterations}'),
        findsOneWidget,
      );
    });

    testWidgets('shows validation error for invalid iteration count', (
      WidgetTester tester,
    ) async {
      if (!DevAutomationFlags.isEnabled) return;

      await tester.pumpWidget(
        _wrap(prefs: prefs, child: const DevAutomationScreen()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();

      expect(find.textContaining('実行回数は'), findsOneWidget);
    });

    testWidgets('pops with iteration count when start is pressed', (
      WidgetTester tester,
    ) async {
      if (!DevAutomationFlags.isEnabled) return;

      int? poppedIterations;

      await tester.pumpWidget(
        _wrap(
          prefs: prefs,
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    poppedIterations = await Navigator.of(context).push<int>(
                      MaterialPageRoute<int>(
                        builder: (_) => const DevAutomationScreen(),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('開始'), findsOneWidget);

      await tester.tap(find.text('開始'));
      await tester.pumpAndSettle();

      expect(poppedIterations, DevAutomationRunner.defaultIterations);
      expect(find.text(DevAutomationScreen.title), findsNothing);
    });
  });
}
