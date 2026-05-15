import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/room_reaction_sync_history_entry.dart';
import '../services/room_reaction_sync_history_store.dart';
import '../state/bulk_operation_state_controller.dart';
import '../theme/app_theme.dart';

/// ROOM同期カード内：直近の反応確認結果（メモリ＋端末履歴から表示）。
class RoomSyncLastReactionSummary extends StatelessWidget {
  const RoomSyncLastReactionSummary({super.key, required this.entry});

  final RoomReactionSyncHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      height: 1.35,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '前回の反応確認',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '確認${entry.checkedItems}件 / 反応あり${entry.hasReactionItems}件 / '
              'コメントあり${entry.commentedItems}件',
              style: subtle,
            ),
            if (entry.topReactedProducts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '反応があった商品',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              ...entry.topReactedProducts.take(3).map((p) {
                final title = p.title.trim().isEmpty ? '（商品名なし）' : p.title.trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '・$title / いいね ${p.roomLikeCount} / コメント ${p.roomCommentCount}',
                    style: subtle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// [BulkOperationStateController] または履歴ストアから直近サマリを表示する。
class RoomSyncLastReactionSummaryPanel extends StatefulWidget {
  const RoomSyncLastReactionSummaryPanel({super.key});

  @override
  State<RoomSyncLastReactionSummaryPanel> createState() =>
      _RoomSyncLastReactionSummaryPanelState();
}

class _RoomSyncLastReactionSummaryPanelState
    extends State<RoomSyncLastReactionSummaryPanel> {
  RoomReactionSyncHistoryEntry? _stored;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStored());
  }

  Future<void> _loadStored() async {
    final e = await RoomReactionSyncHistoryStore.loadLatest();
    if (!mounted || e == null) return;
    setState(() => _stored = e);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BulkOperationStateController>(
      builder: (context, bulk, _) {
        final entry = bulk.lastReactionSyncSummary ?? _stored;
        if (entry == null) return const SizedBox.shrink();
        return RoomSyncLastReactionSummary(entry: entry);
      },
    );
  }
}
