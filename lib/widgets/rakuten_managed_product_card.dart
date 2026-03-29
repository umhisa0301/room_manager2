import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../services/app_action_service.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';

/// 一覧カードの見た目バリアント（候補 / コレ済）。
enum RakutenManagedProductCardVariant {
  candidate,
  done,
}

/// ROOM 管理一覧用の共通アクセント（状態差のみに使用。カード下地は共通）。
abstract final class RoomListAccent {
  static const Color candidate = Color(0xFF1565C0);
  static const Color done = Color(0xFF2E7D32);
}

/// 楽天ROOM管理の保存済み商品カード。
class RakutenManagedProductCard extends StatelessWidget {
  const RakutenManagedProductCard({
    super.key,
    required this.product,
    required this.variant,
  });

  final RakutenManagedProduct product;
  final RakutenManagedProductCardVariant variant;

  static const double _actionButtonHeight = 48;

  bool get _canCollectRoom =>
      product.extractionStatus == RakutenUrlExtractionStatus.success &&
      product.extractedUrl.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isCandidate = variant == RakutenManagedProductCardVariant.candidate;
    final stateAccent =
        isCandidate ? RoomListAccent.candidate : RoomListAccent.done;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              color: stateAccent,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isCandidate) _doneCompletionStrip(context),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _thumb(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _roleBadge(context, isCandidate, stateAccent),
                                  if (isCandidate)
                                    _extractionBadge(context),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                product.itemName,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '¥${product.itemPrice}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product.shopName.isEmpty
                                    ? 'ショップ名なし'
                                    : product.shopName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _footerLine(isCandidate),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isCandidate)
                      _candidateActions(context)
                    else
                      _doneActions(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _doneCompletionStrip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.verified_rounded,
                  color: RoomListAccent.done, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'このアプリではコレ済です',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: RoomListAccent.done,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '一覧の整理用です。ROOMでの投稿完了は別途ご確認ください。',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.25,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _footerLine(bool isCandidate) {
    if (!isCandidate && product.doneAt != null) {
      return 'コレ済（このアプリ）: ${_formatDateTime(product.doneAt!)}';
    }
    return '更新: ${_formatDateTime(product.updatedAt)}';
  }

  Widget _candidateActions(BuildContext context) {
    final provider = context.read<RakutenManagedProductProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: _canCollectRoom
              ? 'ROOMのURLを開き、一覧をコレ済に移します。完了のお知らせはアプリに戻ったときに表示されます。'
              : 'ROOM用のURLが取得できるまでお待ちください',
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              foregroundColor: AppColors.textOnAccent,
              backgroundColor: AppColors.accentPrimary,
              disabledForegroundColor: AppColors.textTertiary,
              disabledBackgroundColor: AppColors.surfaceVariant,
              minimumSize: const Size.fromHeight(_actionButtonHeight),
              elevation: _canCollectRoom ? 2 : 0,
              shadowColor: AppColors.accentPrimary.withValues(alpha: 0.35),
            ),
            onPressed: _canCollectRoom
                ? () =>
                    provider.collectRoomAndLaunch(context, product.productId)
                : null,
            icon: Icon(
              _canCollectRoom
                  ? Icons.favorite_rounded
                  : Icons.hourglass_top_rounded,
              size: 22,
            ),
            label: Text(
              _canCollectRoom ? 'コレする' : 'コレする（URL未取得）',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            backgroundColor: AppColors.surface,
            minimumSize: const Size.fromHeight(_actionButtonHeight),
            side: BorderSide(
              color: AppColors.textSecondary.withValues(alpha: 0.35),
            ),
          ),
          onPressed: () async {
            final err = await provider.openRakutenItemPage(
              context,
              product.productId,
            );
            if (!context.mounted) return;
            if (err != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err)),
              );
            }
          },
          icon: Icon(
            Icons.open_in_new_rounded,
            size: 20,
            color: RoomListAccent.candidate.withValues(alpha: 0.9),
          ),
          label: const Text(
            '楽天で見る',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            backgroundColor: AppColors.surface,
            minimumSize: const Size.fromHeight(_actionButtonHeight),
            side: BorderSide(
              color: AppColors.error.withValues(alpha: 0.45),
            ),
          ),
          onPressed: () => _confirmRemoveCandidate(context, provider),
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          label: const Text(
            '候補から外す',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRemoveCandidate(
    BuildContext context,
    RakutenManagedProductProvider provider,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('候補から外す'),
        content: Text(
          '「${product.itemName}」をコレ候補から削除します。よろしいですか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await provider.removeCandidate(context, product.productId);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  Widget _doneActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            backgroundColor: AppColors.surface,
            minimumSize: const Size.fromHeight(_actionButtonHeight),
            side: BorderSide(
              color: AppColors.textSecondary.withValues(alpha: 0.35),
            ),
          ),
          onPressed: () => AppActionService.openUrl(
            context,
            url: product.itemUrl.trim().isNotEmpty
                ? product.itemUrl.trim()
                : product.browserLaunchUrl,
          ),
          icon: Icon(
            Icons.open_in_new_rounded,
            size: 20,
            color: RoomListAccent.done.withValues(alpha: 0.9),
          ),
          label: const Text(
            '楽天で見る',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        if (product.extractedUrl.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: RoomListAccent.done,
              backgroundColor: AppColors.surface,
              minimumSize: const Size.fromHeight(_actionButtonHeight),
              side: BorderSide(
                color: RoomListAccent.done.withValues(alpha: 0.45),
              ),
            ),
            onPressed: () => AppActionService.openUrl(
              context,
              url: product.extractedUrl.trim(),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
            label: const Text(
              'ROOMを開く',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }

  /// 抽出状態をコンパクトなバッジで表示（URL準備中 / 取得済 / 失敗）。
  Widget _extractionBadge(BuildContext context) {
    final s = product.extractionStatus;
    late final String shortLabel;
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    switch (s) {
      case RakutenUrlExtractionStatus.notStarted:
      case RakutenUrlExtractionStatus.extracting:
        shortLabel = 'URL準備中';
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFE65100);
        icon = Icons.hourglass_empty_rounded;
      case RakutenUrlExtractionStatus.success:
        shortLabel = '取得済';
        bg = const Color(0xFFE8F5E9);
        fg = RoomListAccent.done;
        icon = Icons.check_circle_outline_rounded;
      case RakutenUrlExtractionStatus.failed:
        shortLabel = '失敗';
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
        icon = Icons.error_outline_rounded;
    }
    return _StatusPill(
      icon: icon,
      label: shortLabel,
      backgroundColor: bg,
      foregroundColor: fg,
    );
  }

  Widget _roleBadge(
    BuildContext context,
    bool isCandidate,
    Color stateAccent,
  ) {
    final label = isCandidate ? 'コレ候補' : 'コレ済';
    return _StatusPill(
      icon: isCandidate ? Icons.bookmark_outline_rounded : Icons.task_alt_rounded,
      label: label,
      backgroundColor: stateAccent.withValues(alpha: 0.12),
      foregroundColor: stateAccent,
    );
  }

  Widget _thumb() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 88,
        height: 88,
        color: AppColors.surfaceVariant,
        child: product.imageUrl.isNotEmpty
            ? Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbPlaceholder(),
              )
            : _thumbPlaceholder(),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Icon(
      Icons.image_outlined,
      size: 28,
      color: AppColors.textTertiary.withValues(alpha: 0.7),
    );
  }

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}
