import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/navigation/app_shell_controller.dart';
import 'package:room_manager2/widgets/home_in_app_notice_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return ChangeNotifierProvider(
      create: (_) => AppShellController(),
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('HomeInAppNoticeSlot', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows post milestone notice when data matches', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const HomeInAppNoticeSlot(
            milestonePostCount: 1,
            recPendingCount: 0,
            recTotalCount: 0,
            recIsLoading: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('いい感じです'), findsOneWidget);
      expect(find.textContaining('1件投稿できました'), findsOneWidget);
    });

    testWidgets('shows rec completed when no posts today', (tester) async {
      await tester.pumpWidget(
        wrap(
          const HomeInAppNoticeSlot(
            milestonePostCount: 0,
            recPendingCount: 0,
            recTotalCount: 3,
            recIsLoading: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日のおすすめを確認しました'), findsOneWidget);
    });

    testWidgets('close hides notice for the session', (tester) async {
      await tester.pumpWidget(
        wrap(
          const HomeInAppNoticeSlot(
            milestonePostCount: 1,
            recPendingCount: 0,
            recTotalCount: 0,
            recIsLoading: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('いい感じです'), findsOneWidget);

      await tester.tap(find.byTooltip('閉じる'));
      await tester.pumpAndSettle();

      expect(find.text('いい感じです'), findsNothing);
    });

    testWidgets('dismissed notice stays hidden after rebuild', (tester) async {
      await tester.pumpWidget(
        wrap(
          const HomeInAppNoticeSlot(
            milestonePostCount: 1,
            recPendingCount: 0,
            recTotalCount: 0,
            recIsLoading: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('閉じる'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        wrap(
          const HomeInAppNoticeSlot(
            milestonePostCount: 1,
            recPendingCount: 0,
            recTotalCount: 0,
            recIsLoading: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('いい感じです'), findsNothing);
    });
  });
}
