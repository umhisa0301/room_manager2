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

/// 一覧内ボタン（タップ 48dp 確保・コンパクトな内側余白）。
class _RoomListCardActionStyle {
  _RoomListCardActionStyle._();

  /// 視覚はコンパクトでも、Material 推奨の最小タップ領域。
  static const double minTapHeight = 48;
  static const double iconSize = 18;
  static const double labelFontSizeSecondary = 13;
  static const double labelFontSizePrimary = 14;
  static const FontWeight labelWeight = FontWeight.w600;
  static const FontWeight primaryLabelWeight = FontWeight.w800;

  static const EdgeInsets compactPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 10);

  static RoundedRectangleBorder get shape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      );

  /// 主操作：楽天で見る（商品ページ）
  static ButtonStyle primaryViewFilled() {
    return FilledButton.styleFrom(
      foregroundColor: AppColors.textOnAccent,
      backgroundColor: AppColors.accentPrimary,
      minimumSize: const Size.fromHeight(minTapHeight),
      padding: compactPadding,
      elevation: 1,
      shadowColor: AppColors.accentPrimary.withValues(alpha: 0.22),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: shape,
    );
  }

  /// 次操作：コレする（候補・状態色のアウトライン）
  static ButtonStyle secondaryCollectOutline(Color stateAccent) {
    return OutlinedButton.styleFrom(
      foregroundColor: stateAccent,
      backgroundColor: AppColors.surface,
      minimumSize: const Size.fromHeight(minTapHeight),
      padding: compactPadding,
      side: BorderSide(
        color: stateAccent.withValues(alpha: 0.55),
        width: 1.5,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: shape,
    );
  }

  /// 補助：ROOM を開く（コレ済）
  static ButtonStyle auxiliaryRoomOutline(Color stateAccent) {
    return OutlinedButton.styleFrom(
      foregroundColor: stateAccent,
      backgroundColor: AppColors.surface,
      minimumSize: const Size.fromHeight(minTapHeight),
      padding: compactPadding,
      side: BorderSide(
        color: stateAccent.withValues(alpha: 0.42),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: shape,
    );
  }

  /// 補助：削除（控えめな赤アウトライン）
  static ButtonStyle destructiveOutline() {
    const softRed = Color(0xFFB71C1C);
    return OutlinedButton.styleFrom(
      foregroundColor: softRed,
      backgroundColor: AppColors.surface,
      minimumSize: const Size.fromHeight(minTapHeight),
      padding: compactPadding,
      side: BorderSide(
        color: AppColors.error.withValues(alpha: 0.35),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: shape,
    );
  }
}

/// 楽天ROOM管理の保存済み商品カード。
class RakutenManagedProductCard extends StatelessWidget {
  const RakutenManagedProductCard({
    super.key,
    required this.product,
    required this.variant,
    this.onCollectPressed,
    this.emphasizeAsNext = false,
  });

  final RakutenManagedProduct product;
  final RakutenManagedProductCardVariant variant;
  final Future<void> Function(
    BuildContext context,
    RakutenManagedProduct product,
  )? onCollectPressed;
  final bool emphasizeAsNext;

  static const double _thumbExtent = 80;

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
        border: Border.all(
          color: emphasizeAsNext ? AppColors.accentPrimary : AppColors.divider,
          width: emphasizeAsNext ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: emphasizeAsNext
                ? AppColors.accentPrimary.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: emphasizeAsNext ? 12 : 8,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              color: stateAccent.withValues(alpha: 0.88),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _thumb(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (emphasizeAsNext && isCandidate)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _StatusPill(
                                    icon: Icons.navigation_rounded,
                                    label: '次にコレする候補',
                                    backgroundColor:
                                        AppColors.accentPrimary.withValues(alpha: 0.12),
                                    foregroundColor: AppColors.accentPrimary,
                                  ),
                                ),
                              _badgeRow(context, isCandidate, stateAccent),
                              const SizedBox(height: 6),
                              Text(
                                product.itemName,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      height: 1.28,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '¥${product.itemPrice}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: stateAccent
                                          .withValues(alpha: 0.92),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                product.shopName.isEmpty
                                    ? 'ショップ名なし'
                                    : product.shopName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _footerText(isCandidate),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.textTertiary,
                                      height: 1.3,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isCandidate)
                      _candidateActions(context, stateAccent)
                    else
                      _doneActions(context, stateAccent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeRow(
    BuildContext context,
    bool isCandidate,
    Color stateAccent,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _roleBadge(context, isCandidate, stateAccent),
        if (isCandidate) _extractionBadge(context),
      ],
    );
  }

  String _footerText(bool isCandidate) {
    if (!isCandidate && product.doneAt != null) {
      return 'このアプリでコレ済にした日: ${_formatDateTime(product.doneAt!)}';
    }
    return '更新日時: ${_formatDateTime(product.updatedAt)}';
  }

  /// 優先順: ①楽天で見る ②コレする ③削除
  Widget _candidateActions(BuildContext context, Color stateAccent) {
    final provider = context.read<RakutenManagedProductProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: _RoomListCardActionStyle.primaryViewFilled(),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new_rounded,
                size: _RoomListCardActionStyle.iconSize,
                color: AppColors.textOnAccent,
              ),
              const SizedBox(width: 6),
              Text(
                '楽天で見る',
                style: TextStyle(
                  fontSize: _RoomListCardActionStyle.labelFontSizePrimary,
                  fontWeight: _RoomListCardActionStyle.primaryLabelWeight,
                  color: AppColors.textOnAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Tooltip(
          message: _canCollectRoom
              ? 'ROOMのURLを開き、一覧をコレ済に移します。'
              : 'ROOM用のURLが取得できるまでお待ちください',
          child: OutlinedButton(
            style: _RoomListCardActionStyle.secondaryCollectOutline(
              stateAccent,
            ),
            onPressed: _canCollectRoom
                ? () async {
                    if (onCollectPressed != null) {
                      await onCollectPressed!(context, product);
                      return;
                    }
                    await provider.collectRoomAndLaunch(context, product.productId);
                  }
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _canCollectRoom
                      ? Icons.favorite_rounded
                      : Icons.hourglass_top_rounded,
                  size: _RoomListCardActionStyle.iconSize,
                ),
                const SizedBox(width: 6),
                Text(
                  _canCollectRoom ? 'コレする' : 'コレする（URL未取得）',
                  style: TextStyle(
                    fontSize: _RoomListCardActionStyle.labelFontSizePrimary,
                    fontWeight: _RoomListCardActionStyle.primaryLabelWeight,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          style: _RoomListCardActionStyle.destructiveOutline(),
          onPressed: () => _confirmRemoveCandidate(context, provider),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: _RoomListCardActionStyle.iconSize,
              ),
              const SizedBox(width: 6),
              Text(
                '削除',
                style: TextStyle(
                  fontSize: _RoomListCardActionStyle.labelFontSizeSecondary,
                  fontWeight: _RoomListCardActionStyle.labelWeight,
                ),
              ),
            ],
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
        title: const Text('候補から削除'),
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

  /// 優先順: ①楽天で見る ②ROOMを開く
  Widget _doneActions(BuildContext context, Color stateAccent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: _RoomListCardActionStyle.primaryViewFilled(),
          onPressed: () => AppActionService.openUrl(
            context,
            url: product.itemUrl.trim().isNotEmpty
                ? product.itemUrl.trim()
                : product.browserLaunchUrl,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new_rounded,
                size: _RoomListCardActionStyle.iconSize,
                color: AppColors.textOnAccent,
              ),
              const SizedBox(width: 6),
              Text(
                '楽天で見る',
                style: TextStyle(
                  fontSize: _RoomListCardActionStyle.labelFontSizePrimary,
                  fontWeight: _RoomListCardActionStyle.primaryLabelWeight,
                  color: AppColors.textOnAccent,
                ),
              ),
            ],
          ),
        ),
        if (product.extractedUrl.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          OutlinedButton(
            style:
                _RoomListCardActionStyle.auxiliaryRoomOutline(stateAccent),
            onPressed: () => AppActionService.openUrl(
              context,
              url: product.extractedUrl.trim(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: _RoomListCardActionStyle.iconSize,
                ),
                const SizedBox(width: 6),
                Text(
                  'ROOMを開く',
                  style: TextStyle(
                    fontSize: _RoomListCardActionStyle.labelFontSizeSecondary,
                    fontWeight: _RoomListCardActionStyle.labelWeight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

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
        bg = AppColors.error.withValues(alpha: 0.1);
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
      icon: isCandidate
          ? Icons.bookmark_outline_rounded
          : Icons.task_alt_rounded,
      label: label,
      backgroundColor: stateAccent.withValues(alpha: 0.1),
      foregroundColor: stateAccent,
    );
  }

  Widget _thumb() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _thumbExtent,
        height: _thumbExtent,
        child: ColoredBox(
          color: AppColors.surfaceVariant,
          child: product.imageUrl.isNotEmpty
              ? Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Center(child: _thumbPlaceholder()),
                )
              : Center(child: _thumbPlaceholder()),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Icon(
      Icons.image_outlined,
      size: 26,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: foregroundColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.15,
                ),
          ),
        ],
      ),
    );
  }
}
