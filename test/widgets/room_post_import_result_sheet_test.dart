import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/models/room_sync_result.dart';
import 'package:room_manager2/navigation/app_shell_controller.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/theme/home_screen_colors.dart';
import 'package:room_manager2/widgets/room_post_import_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpImportResultSheet(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final productRepo = RakutenManagedProductRepository(prefs);
    final shell = AppShellController();

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: shell),
            Provider<RakutenManagedProductRepository>.value(value: productRepo),
          ],
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      RoomPostImportFlow.showResultSheet(
                        context,
                        result: const RoomSyncResult(
                          processedCount: 1,
                          newlyCollectedCount: 2,
                          roomUrlAddedCount: 0,
                          skippedCount: 0,
                          failedCount: 0,
                        ),
                        startBatch: () async => null,
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('RoomPostImportFlow.showResultSheet', () {
    testWidgets('新文言を表示し旧文言とデバッグUIを出さない', (tester) async {
      await pumpImportResultSheet(tester);

      expect(find.text('取り込み完了'), findsOneWidget);
      expect(
        find.text('投稿済みの商品をコレ済に追加しました。'),
        findsOneWidget,
      );
      expect(
        find.text('新しいROOM投稿をコレ済に追加しました。'),
        findsNothing,
      );
      expect(find.text('デバッグログをコピー'), findsNothing);
      expect(find.textContaining('（debug）'), findsNothing);
    });

    testWidgets('閉じるリンクがティール系である', (tester) async {
      await pumpImportResultSheet(tester);

      final closeButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '閉じる'),
      );
      expect(
        closeButton.style?.foregroundColor?.resolve({}),
        HomeScreenColors.homeAccentTeal,
      );
    });
  });
}
