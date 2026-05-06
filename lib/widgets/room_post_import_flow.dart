import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/room_sync_result.dart';
import '../navigation/app_shell_controller.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../services/app_action_service.dart';
import '../services/room_import_limit_policy.dart';
import '../services/room_sync_service.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';

/// [RoomPostImportFlow.executeBatch] から通知される進捗。
typedef RoomPostImportProgressCallback =
    void Function({
      required bool busy,
      required int completed,
      required int total,
    });

/// ホーム / マイページ共通の ROOM 投稿取り込み（内部 API は [RoomSyncService] のまま）。
abstract final class RoomPostImportFlow {
  /// 取り込み後のダイアログ・SnackBar・結果シート。
  static Future<void> presentPostImportUi(
    BuildContext context,
    RoomSyncResult? result, {
    required Future<RoomSyncResult?> Function() startBatch,
  }) async {
    if (result == null) return;
    if (!context.mounted) return;

    if (result.hasFatalError) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ROOM投稿取り込み'),
          content: Text(result.fatalErrorMessage!.trim()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }

    final added =
        result.newlyCollectedCount > 0 || result.roomUrlAddedCount > 0;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added ? 'ROOM投稿の取り込みが完了しました' : 'ROOM投稿の確認が終わりました（追加なし）'),
      ),
    );

    if (!context.mounted) return;
    await showResultSheet(context, result: result, startBatch: startBatch);
  }

  /// 1バッチ実行して結果を返す（ROOM URL 未登録時は null）。
  static Future<RoomSyncResult?> executeBatch(
    BuildContext context, {
    required RoomPostImportProgressCallback onProgress,
  }) async {
    final profile = context.read<UserProfileProvider>().profile.roomUrl.trim();
    if (profile.isEmpty) {
      return null;
    }

    final repo = context.read<RakutenManagedProductRepository>();
    final service = RoomSyncService(
      repository: repo,
      searchRepository: context.read<RakutenSearchRepository>(),
    );
    final limit = RoomImportLimitPolicy.effectiveBatchLimit();

    var lastCompleted = 0;
    var lastTotal = 0;

    onProgress(busy: true, completed: 0, total: 0);

    final result = await service.syncPostedRoomProducts(
      userRoomProfileUrl: profile,
      maxItems: limit,
      onCheckingProgress: (current, total) {
        lastCompleted = current;
        lastTotal = total;
        onProgress(busy: true, completed: current, total: total);
      },
    );

    onProgress(busy: false, completed: lastCompleted, total: lastTotal);
    return result;
  }

  /// 取り込み結果を BottomSheet で表示。「もう10件」で続行コールバック。
  static Future<void> showResultSheet(
    BuildContext context, {
    required RoomSyncResult result,
    required Future<RoomSyncResult?> Function() startBatch,
  }) async {
    final navigatorContext = context;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '取り込み完了',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _heroOutcomeLine(result),
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'ROOM投稿済みの商品をコレ済に反映しました',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    final w = constraints.maxWidth;
                    final half = w > spacing
                        ? (w - spacing) / 2
                        : w;
                    Widget cell(_SummaryMiniCard c) =>
                        SizedBox(width: half, child: c);
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        cell(
                          _SummaryMiniCard(
                            label: '新しく追加',
                            value: result.newlyCollectedCount,
                            emphasize: result.newlyCollectedCount > 0,
                          ),
                        ),
                        cell(
                          _SummaryMiniCard(
                            label: '確認済み',
                            value: result.listingCheckedCount,
                          ),
                        ),
                        cell(
                          _SummaryMiniCard(
                            label: 'すでに登録済み',
                            value: result.listingSyncedSkipCount,
                          ),
                        ),
                        cell(
                          _SummaryMiniCard(
                            label: '失敗',
                            value: result.failedCount,
                            emphasize: result.failedCount > 0,
                            emphasizeColor: AppColors.error,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (result.roomUrlAddedCount > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'ROOMページ紐付け：${result.roomUrlAddedCount}件',
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  '※ROOM本体の投稿数には加算しません',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.35,
                  ),
                ),
                if (result.newlyCollectedSamples.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    '今回追加した商品（一部）',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '最新3件のみ表示しています。すべて見る場合はコレ済一覧へ。',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...result.newlyCollectedSamples
                      .take(3)
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ImportedProductPreviewTile(product: p),
                        ),
                      ),
                ],
                if (result.reactionHighlightSamples.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    '反応があった商品',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'いいね・コメントが付いていた商品です（最大3件）',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...result.reactionHighlightSamples
                      .take(3)
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ImportedProductPreviewTile(product: p),
                        ),
                      ),
                ],
                if (result.failedCount > 0 &&
                    result.failedRoomUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '取り込めなかったROOMページ（先頭3件）',
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...result.failedRoomUrls
                      .take(3)
                      .map(
                        (u) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            u,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: 26),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: AppColors.textOnAccent,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!navigatorContext.mounted) return;
                      navigatorContext
                          .read<AppShellController>()
                          .openRoomCollect(initialTabIndex: 1);
                    });
                  },
                  icon: const Icon(Icons.task_alt_rounded, size: 22),
                  label: const Text(
                    'コレ済をすべて見る',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    foregroundColor: AppColors.accentPrimary,
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final next = await startBatch();
                    if (!navigatorContext.mounted || next == null) return;
                    await presentPostImportUi(
                      navigatorContext,
                      next,
                      startBatch: startBatch,
                    );
                  },
                  icon: const Icon(Icons.playlist_add_rounded, size: 20),
                  label: Text('もう${RoomImportLimitPolicy.freeBatchLimit}件取り込む'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('閉じる'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _heroOutcomeLine(RoomSyncResult r) {
    final n = r.newlyCollectedCount;
    final add = r.roomUrlAddedCount;
    if (n > 0) return '$n件追加しました';
    if (add > 0) return 'ROOMページを$add件紐付けました';
    if (r.failedCount > 0 && r.processedCount == 0) {
      return '追加できませんでした';
    }
    if (r.processedCount == 0) {
      return '新しい投稿は見つかりませんでした';
    }
    return '追加はありませんでした';
  }
}

class _SummaryMiniCard extends StatelessWidget {
  const _SummaryMiniCard({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.emphasizeColor,
  });

  final String label;
  final int value;
  final bool emphasize;
  final Color? emphasizeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: emphasize
          ? (emphasizeColor ?? AppColors.accentPrimary)
          : AppColors.textPrimary,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 2,
              softWrap: true,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text('$value', style: valueStyle),
          ],
        ),
      ),
    );
  }
}

class _ImportedProductPreviewTile extends StatelessWidget {
  const _ImportedProductPreviewTile({required this.product});

  static const Color _roomReactionPink = Color(0xFFE91E63);

  final RakutenManagedProduct product;

  bool _hasPositiveRoomReaction() {
    final lc = product.roomLikeCount;
    final cc = product.roomCommentCount;
    return (lc != null && lc > 0) || (cc != null && cc > 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = product.itemName.trim().isEmpty
        ? 'ROOM投稿の商品'
        : product.itemName.trim();
    final provider = context.read<RakutenManagedProductProvider>();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.65)),
        color: AppColors.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: product.imageUrl.trim().isNotEmpty
                        ? Image.network(
                            product.imageUrl.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _thumbPlaceholder(theme),
                          )
                        : _thumbPlaceholder(theme),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_hasPositiveRoomReaction())
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: _roomReactionPink.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _roomReactionPink.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                child: Text(
                                  '反応あり',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: _roomReactionPink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                          else if (product.roomUrl.trim().isNotEmpty)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1B5E20,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(
                                    0xFF1B5E20,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                child: Text(
                                  'ROOM投稿済み',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF1B5E20),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          if (product.roomLikeCount != null)
                            Text(
                              '♡${product.roomLikeCount}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: product.roomLikeCount! > 0
                                    ? _roomReactionPink
                                    : AppColors.textTertiary,
                              ),
                            ),
                          if (product.roomCommentCount != null)
                            Text(
                              '💬${product.roomCommentCount}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: product.roomCommentCount! > 0
                                    ? _roomReactionPink
                                    : AppColors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: product.roomUrl.trim().isEmpty
                      ? null
                      : () => AppActionService.openUrl(
                          context,
                          url: product.roomUrl.trim(),
                        ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('ROOMで見る'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final err = await provider.openRakutenItemPage(
                      context,
                      product.productId,
                    );
                    if (!context.mounted || err == null) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(err)));
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                  label: const Text('楽天で見る'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _thumbPlaceholder(ThemeData theme) {
    return ColoredBox(
      color: AppColors.surfaceVariant,
      child: Icon(
        Icons.image_outlined,
        color: AppColors.textTertiary,
        size: 26,
      ),
    );
  }

}
