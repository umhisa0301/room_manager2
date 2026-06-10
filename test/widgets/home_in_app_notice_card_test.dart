import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/models/room_reaction_sync_history_entry.dart';
import 'package:room_manager2/navigation/app_shell_controller.dart';
import 'package:room_manager2/widgets/home_in_app_notice_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

RoomReactionSyncHistoryEntry _reactionHistoryEntry({
  String syncedAtIso = '2026-06-09T20:30:15.000Z',
  int likeIncreasedItems = 2,
}) {
  return RoomReactionSyncHistoryEntry(
    syncedAtIso: syncedAtIso,
    checkedItems: 10,
    updatedItems: 2,
    likeIncreasedItems: likeIncreasedItems,
    commentIncreasedItems: 0,
    unchangedItems: 8,
    hasReactionItems: 5,
    commentedItems: 1,
    stopReason: '',
    hasNextCursor: false,
    topReactedProducts: const [],
  );
}

void _seedReactionHistory(List<RoomReactionSyncHistoryEntry> entries) {
  SharedPreferences.setMockInitialValues({
    'room_reaction_sync_history_v1_json':
        entries.map((e) => jsonEncode(e.toJson())).toList(),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child, {AppShellController? shell}) {
    return ChangeNotifierProvider(
      create: (_) => shell ?? AppShellController(),
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

    testWidgets('shows reaction increased notice from sync history', (
      tester,
    ) async {
      _seedReactionHistory([
        _reactionHistoryEntry(syncedAtIso: '2026-06-09T19:00:00.000Z'),
        _reactionHistoryEntry(likeIncreasedItems: 3),
      ]);

      await tester.pumpWidget(
        wrap(
          const HomeInAppNoticeSlot(
            milestonePostCount: 0,
            recPendingCount: 0,
            recTotalCount: 0,
            recIsLoading: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('反応がありました'), findsOneWidget);
      expect(find.text('分析で見る'), findsOneWidget);
    });

    testWidgets('reaction notice 分析で見る opens activity tab', (tester) async {
      _seedReactionHistory([
        _reactionHistoryEntry(syncedAtIso: '2026-06-09T19:00:00.000Z'),
        _reactionHistoryEntry(likeIncreasedItems: 1),
      ]);
      final shell = AppShellController();

      await tester.pumpWidget(
        wrap(
          const HomeInAppNoticeSlot(
            milestonePostCount: 0,
            recPendingCount: 0,
            recTotalCount: 0,
            recIsLoading: false,
          ),
          shell: shell,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('分析で見る'));
      await tester.pumpAndSettle();

      expect(shell.currentIndex, 3);
      final intent = shell.takePendingActivityIntent();
      expect(intent, isNotNull);
      expect(intent!.subTabIndex, 1);
      expect(intent.scrollToRoomReactionSection, isTrue);
    });

    testWidgets('dismissed reaction notice stays hidden after rebuild', (
      tester,
    ) async {
      _seedReactionHistory([
        _reactionHistoryEntry(syncedAtIso: '2026-06-09T19:00:00.000Z'),
        _reactionHistoryEntry(likeIncreasedItems: 2),
      ]);

      await tester.pumpWidget(
        wrap(
          const HomeInAppNoticeSlot(
            milestonePostCount: 0,
            recPendingCount: 0,
            recTotalCount: 0,
            recIsLoading: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('反応がありました'), findsOneWidget);

      await tester.tap(find.byTooltip('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('反応がありました'), findsNothing);

      await tester.pumpWidget(
        wrap(
          const HomeInAppNoticeSlot(
            milestonePostCount: 0,
            recPendingCount: 0,
            recTotalCount: 0,
            recIsLoading: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('反応がありました'), findsNothing);
    });
  });
}
