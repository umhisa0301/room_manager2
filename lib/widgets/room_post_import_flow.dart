import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/room_sync_result.dart';
import '../navigation/app_shell_controller.dart';
import '../repository/rakuten_managed_product_repository.dart';
import '../services/app_action_service.dart';
import '../services/room_import_limit_policy.dart';
import '../services/room_sync_service.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';

/// [RoomPostImportFlow.executeBatch] から通知される進捗。
typedef RoomPostImportProgressCallback = void Function({
  required bool busy,
  required int completed,
  required int total,
  required String processingHint,
});

/// ホーム / マイページ共通の ROOM 投稿取り込み（内部 API は [RoomSyncService] のまま）。
abstract final class RoomPostImportFlow {
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
    final service = RoomSyncService(repository: repo);
    final limit = RoomImportLimitPolicy.effectiveBatchLimit();

    var lastCompleted = 0;
    var lastTotal = 0;

    onProgress(
      busy: true,
      completed: 0,
      total: 0,
      processingHint: '',
    );

    final result = await service.syncPostedRoomProducts(
      userRoomProfileUrl: profile,
      maxItems: limit,
      onCheckingProgress: (current, total) {
        lastCompleted = current;
        lastTotal = total;
        onProgress(
          busy: true,
          completed: current,
          total: total,
          processingHint: '',
        );
      },
      onProcessingHint: (hint) {
        onProgress(
          busy: true,
          completed: lastCompleted,
          total: lastTotal,
          processingHint: hint,
        );
      },
    );

    onProgress(
      busy: false,
      completed: 0,
      total: 0,
      processingHint: '',
    );
    return result;
  }

  /// 取り込み結果を BottomSheet で表示。「もう10件」で続行コールバック。
  static Future<void> showResultSheet(
    BuildContext context, {
    required RoomSyncResult result,
    Future<void> Function()? onImportAnotherBatch,
  }) async {
    final navigatorContext = context;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '取り込み完了',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  _primaryOutcomeLine(result),
                  style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 16),
                _SummaryRow(
                  label: '新しく追加',
                  count: result.newlyCollectedCount,
                  emphasize: result.newlyCollectedCount > 0,
                ),
                _SummaryRow(
                  label: 'すでに取り込み済み',
                  count: result.listingSyncedSkipCount,
                ),
                _SummaryRow(
                  label: '確認した商品',
                  count: result.listingCheckedCount,
                ),
                _SummaryRow(
                  label: '取り込めなかった商品',
                  count: result.failedCount,
                  emphasize: result.failedCount > 0,
                  emphasizeColor: AppColors.error,
                ),
                if (result.roomUrlAddedCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '※既存のコレ済にROOMページを紐付け：${result.roomUrlAddedCount}件',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '楽天ROOMで投稿済みの商品を、アプリの「コレ済」に反映しました。',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                ),
                Text(
                  '楽天ROOM側で新しく投稿した場合は、再度取り込むと反映されます。',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                ),
                if (result.newlyCollectedSamples.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    '今回追加した商品',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...result.newlyCollectedSamples.take(3).map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ImportedProductPreviewTile(product: p),
                        ),
                      ),
                ],
                if (result.failedCount > 0 && result.failedRoomUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '取り込めなかったROOMページ（先頭3件）',
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                  ),
                  const SizedBox(height: 4),
                  ...result.failedRoomUrls.take(3).map(
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
                const SizedBox(height: 8),
                Text(
                  '追加取得：${result.additionalFetchStatusLabel}',
                  style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!navigatorContext.mounted) return;
                      navigatorContext.read<AppShellController>().openRoomCollect(
                            initialTabIndex: 1,
                          );
                    });
                  },
                  icon: const Icon(Icons.task_alt_rounded, size: 20),
                  label: const Text('コレ済を見る'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onImportAnotherBatch == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await onImportAnotherBatch();
                        },
                  icon: const Icon(Icons.playlist_add_rounded, size: 20),
                  label: Text(
                    'もう${RoomImportLimitPolicy.freeBatchLimit}件取り込む',
                  ),
                ),
                const SizedBox(height: 8),
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

  static String _primaryOutcomeLine(RoomSyncResult r) {
    final n = r.newlyCollectedCount;
    final add = r.roomUrlAddedCount;
    if (n > 0) {
      return '$n件の商品をコレ済に追加しました';
    }
    if (add > 0) {
      return '既存のコレ済にROOMページを$add件ぶん紐付けました';
    }
    if (r.failedCount > 0 && r.processedCount == 0) {
      return 'このバッチではコレ済への追加がありませんでした';
    }
    if (r.processedCount == 0) {
      return '取り込む新しいROOM投稿は見つかりませんでした';
    }
    return 'このバッチでは新しいコレ済の追加はありませんでした（確認のみ）';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.count,
    this.emphasize = false,
    this.emphasizeColor,
  });

  final String label;
  final int count;
  final bool emphasize;
  final Color? emphasizeColor;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    final style = base?.copyWith(
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
      color: emphasize
          ? (emphasizeColor ?? AppColors.accentPrimary)
          : AppColors.textPrimary,
      height: 1.35,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('$count件', style: style),
        ],
      ),
    );
  }
}

class _ImportedProductPreviewTile extends StatelessWidget {
  const _ImportedProductPreviewTile({required this.product});

  final RakutenManagedProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = product.itemName.trim().isEmpty
        ? 'ROOM投稿の商品'
        : product.itemName.trim();
    final sub = _subtitle(product);
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
                      const SizedBox(height: 4),
                      Text(
                        sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
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
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(err)));
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

  static String _subtitle(RakutenManagedProduct p) {
    final shop = p.shopCode.trim();
    final item = p.productId.trim();
    if (shop.isNotEmpty && item.isNotEmpty) {
      return 'shopCode $shop · itemCode $item';
    }
    final itemUrl = p.itemUrl.trim();
    if (itemUrl.isNotEmpty) return itemUrl;
    return item.isNotEmpty ? 'itemCode $item' : '商品コード未取得';
  }
}
