import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/room_reaction_sync_history_entry.dart';
import '../navigation/app_shell_controller.dart';
import '../services/home_in_app_notice_dismiss_store.dart';
import '../services/room_reaction_sync_history_store.dart';
import '../theme/home_screen_colors.dart';
import '../utils/home_in_app_notice.dart';

/// ホーム「今日のROOM運用」直下に表示するお知らせカード（最大1件）。
class HomeInAppNoticeSlot extends StatefulWidget {
  const HomeInAppNoticeSlot({
    super.key,
    required this.milestonePostCount,
    required this.recPendingCount,
    required this.recTotalCount,
    required this.recIsLoading,
    this.reactionHistoryRefreshNonce = 0,
  });

  final int milestonePostCount;
  final int recPendingCount;
  final int recTotalCount;
  final bool recIsLoading;
  final int reactionHistoryRefreshNonce;

  @override
  State<HomeInAppNoticeSlot> createState() => _HomeInAppNoticeSlotState();
}

class _HomeInAppNoticeSlotState extends State<HomeInAppNoticeSlot> {
  final Set<String> _sessionDismissedKeys = {};
  Set<String> _persistedDismissedKeys = {};
  RoomReactionSyncHistoryEntry? _latestReactionSyncHistory;
  int _reactionSyncHistoryCount = 0;
  bool _storeLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNoticeContext());
  }

  @override
  void didUpdateWidget(covariant HomeInAppNoticeSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reactionHistoryRefreshNonce !=
        widget.reactionHistoryRefreshNonce) {
      unawaited(_loadNoticeContext());
    }
  }

  Future<void> _loadNoticeContext() async {
    final results = await Future.wait([
      HomeInAppNoticeDismissStore.loadDismissedKeysForToday(),
      RoomReactionSyncHistoryStore.loadEntries(),
    ]);
    if (!mounted) return;
    final entries = results[1] as List<RoomReactionSyncHistoryEntry>;
    setState(() {
      _persistedDismissedKeys = results[0] as Set<String>;
      _latestReactionSyncHistory =
          entries.isEmpty ? null : entries.first;
      _reactionSyncHistoryCount = entries.length;
      _storeLoaded = true;
    });
  }

  Set<String> get _allDismissedKeys => {
    ..._persistedDismissedKeys,
    ..._sessionDismissedKeys,
  };

  HomeInAppNotice? get _selectedNotice {
    if (!_storeLoaded) return null;
    return HomeInAppNoticeSelector.select(
      milestonePostCount: widget.milestonePostCount,
      recPendingCount: widget.recPendingCount,
      recTotalCount: widget.recTotalCount,
      recIsLoading: widget.recIsLoading,
      dismissedKeys: _allDismissedKeys,
      todayDateKey: HomeInAppNoticeDismissStore.todayDateKey(),
      latestReactionSyncHistory: _latestReactionSyncHistory,
      reactionSyncHistoryCount: _reactionSyncHistoryCount,
    );
  }

  void _dismiss(String noticeKey) {
    setState(() => _sessionDismissedKeys.add(noticeKey));
    unawaited(HomeInAppNoticeDismissStore.dismissForToday(noticeKey));
  }

  void _onAction(HomeInAppNoticeAction action) {
    final shell = context.read<AppShellController>();
    switch (action) {
      case HomeInAppNoticeAction.openActivity:
        shell.openActivityTab(subTabIndex: 1, scrollToRoomReactionSection: true);
      case HomeInAppNoticeAction.openRoomCollect:
        shell.openRoomCollect(initialTabIndex: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = _selectedNotice;
    if (notice == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _HomeInAppNoticeCard(
        notice: notice,
        onDismiss: () => _dismiss(notice.noticeKey),
        onAction: notice.action == null
            ? null
            : () => _onAction(notice.action!),
      ),
    );
  }
}

class _HomeInAppNoticeCard extends StatelessWidget {
  const _HomeInAppNoticeCard({
    required this.notice,
    required this.onDismiss,
    this.onAction,
  });

  final HomeInAppNotice notice;
  final VoidCallback onDismiss;
  final VoidCallback? onAction;

  IconData _iconForNotice(HomeInAppNotice n) {
    if (n.noticeKey.startsWith('rec_completed_')) {
      return Icons.check_circle_outline_rounded;
    }
    if (n.action == HomeInAppNoticeAction.openActivity) {
      return Icons.favorite_border_rounded;
    }
    return Icons.emoji_events_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconForNotice(notice);

    return Material(
      color: HomeScreenColors.groupedSectionFill.withValues(alpha: 0.55),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: HomeScreenColors.sectionOutlineNeutral.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon,
                size: 18,
                color: HomeScreenColors.accentSectionHeading.withValues(
                  alpha: 0.75,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: HomeScreenColors.titlePrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notice.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: HomeScreenColors.bodyOnSection.withValues(
                        alpha: 0.88,
                      ),
                    ),
                  ),
                  if (onAction != null &&
                      notice.actionLabel?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: HomeScreenColors.accentSectionHeading,
                      ),
                      child: Text(
                        notice.actionLabel!.trim(),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              visualDensity: VisualDensity.compact,
              tooltip: '閉じる',
              color: HomeScreenColors.footnoteMuted,
            ),
          ],
        ),
      ),
    );
  }
}
