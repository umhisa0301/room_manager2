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

/// 一覧内ボタン（EC一覧向け・横並び時はタップ域を保ちつつ詰める）。
class _RoomListCardActionStyle {
  _RoomListCardActionStyle._();

  static const double minTapHeight = 48;
  static const double iconSize = 17;
  static const double labelFontSizeSecondary = 12;
  static const double labelFontSizePrimary = 13;
  static const FontWeight labelWeight = FontWeight.w600;
  static const FontWeight primaryLabelWeight = FontWeight.w800;

  static const EdgeInsets compactPadding =
      EdgeInsets.symmetric(horizontal: 10, vertical: 8);

  /// 横3分割時の内側余白（情報密度優先）。
  static const EdgeInsets rowTightPadding =
      EdgeInsets.symmetric(horizontal: 6, vertical: 8);

  static RoundedRectangleBorder get shape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      );

  static ButtonStyle primaryViewFilled({EdgeInsetsGeometry? padding}) {
    return FilledButton.styleFrom(
      foregroundColor: AppColors.textOnAccent,
      backgroundColor: AppColors.accentPrimary,
      minimumSize: const Size.fromHeight(minTapHeight),
      padding: padding ?? compactPadding,
      elevation: 0.5,
      shadowColor: AppColors.accentPrimary.withValues(alpha: 0.2),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: shape,
    );
  }

  static ButtonStyle secondaryCollectOutline(
    Color stateAccent, {
    EdgeInsetsGeometry? padding,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: stateAccent,
      backgroundColor: AppColors.surface,
      minimumSize: const Size.fromHeight(minTapHeight),
      padding: padding ?? compactPadding,
      side: BorderSide(
        color: stateAccent.withValues(alpha: 0.5),
        width: 1,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: shape,
    );
  }

  static ButtonStyle auxiliaryRoomOutline(
    Color stateAccent, {
    EdgeInsetsGeometry? padding,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: stateAccent,
      backgroundColor: AppColors.surface,
      minimumSize: const Size.fromHeight(minTapHeight),
      padding: padding ?? compactPadding,
      side: BorderSide(
        color: stateAccent.withValues(alpha: 0.45),
        width: 1,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: shape,
    );
  }

  static ButtonStyle destructiveOutline({EdgeInsetsGeometry? padding}) {
    const softRed = Color(0xFFB71C1C);
    return OutlinedButton.styleFrom(
      foregroundColor: softRed,
      backgroundColor: AppColors.surface,
      minimumSize: const Size.fromHeight(minTapHeight),
      padding: padding ?? compactPadding,
      side: BorderSide(
        color: AppColors.error.withValues(alpha: 0.32),
        width: 1,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: shape,
    );
  }
}

/// 楽天ROOM管理の保存済み商品カード（画像主役・縦型・高密度）。
class RakutenManagedProductCard extends StatelessWidget {
  const RakutenManagedProductCard({
    super.key,
    required this.product,
    required this.variant,
    this.onCollectPressed,
  });

  final RakutenManagedProduct product;
  final RakutenManagedProductCardVariant variant;
  final Future<void> Function(
    BuildContext context,
    RakutenManagedProduct product,
  )? onCollectPressed;

  static const double _radius = 12;

  /// 72dp 相当の約1.5〜2倍に相当する「一覧上での印象スケール」を
  /// アスペクト比と組み合わせて確保（幅いっぱいのヒーロー）。
  static const double _imageAspect = 1;

  /// 商品名は常に2行分の枠を確保しカード間で揃える。
  static const int _titleMaxLines = 2;

  /// ショップ名・フッターは1行で統一（高さブレ抑制）。
  static const int _shopMaxLines = 1;
  static const int _footerMaxLines = 1;

  static const double _badgeRowHeight = 30;

  bool get _canCollectRoom =>
      product.extractionStatus == RakutenUrlExtractionStatus.success &&
      product.extractedUrl.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isCandidate = variant == RakutenManagedProductCardVariant.candidate;
    final stateAccent =
        isCandidate ? RoomListAccent.candidate : RoomListAccent.done;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.textPrimary,
          height: 1.25,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        );
    final priceStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: stateAccent.withValues(alpha: 0.92),
          fontWeight: FontWeight.w800,
          fontSize: 15,
          height: 1.2,
        );
    final shopStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          height: 1.2,
          fontSize: 12,
        );
    final footerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textTertiary,
          height: 1.2,
          fontSize: 10.5,
        );

    final titleLineHeight =
        (titleStyle?.fontSize ?? 14) * (titleStyle?.height ?? 1.25);
    final titleFixedHeight = titleLineHeight * _titleMaxLines;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 2.5,
            color: stateAccent.withValues(alpha: 0.9),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: _imageAspect,
                  child: _heroImage(topRightRadius: _radius),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: _badgeRowHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _badgeRow(
                              context,
                              isCandidate,
                              stateAccent,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: titleFixedHeight,
                        width: double.infinity,
                        child: Text(
                          product.itemName,
                          maxLines: _titleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¥${product.itemPrice}',
                        style: priceStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product.shopName.isEmpty
                            ? 'ショップ名なし'
                            : product.shopName,
                        maxLines: _shopMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: shopStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _footerText(isCandidate),
                        maxLines: _footerMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: footerStyle,
                      ),
                      const SizedBox(height: 8),
                      if (isCandidate)
                        _candidateActions(context, stateAccent)
                      else
                        _doneActions(context, stateAccent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeRow(
    BuildContext context,
    bool isCandidate,
    Color stateAccent,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _roleBadge(context, isCandidate, stateAccent),
        if (isCandidate) ...[
          const SizedBox(width: 6),
          _extractionBadge(context),
        ],
      ],
    );
  }

  String _footerText(bool isCandidate) {
    if (!isCandidate && product.doneAt != null) {
      return 'このアプリでコレ済にした日: ${_formatDateTime(product.doneAt!)}';
    }
    return '更新日時: ${_formatDateTime(product.updatedAt)}';
  }

  Widget _candidateActions(BuildContext context, Color stateAccent) {
    final provider = context.read<RakutenManagedProductProvider>();
    final tight = _RoomListCardActionStyle.rowTightPadding;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FilledButton(
            style: _RoomListCardActionStyle.primaryViewFilled(padding: tight),
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
            child: _actionContent(
              icon: Icons.open_in_new_rounded,
              label: '楽天で見る',
              foreground: AppColors.textOnAccent,
              primary: true,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Tooltip(
            message: _canCollectRoom
                ? 'ROOMのURLを開き、一覧をコレ済に移します。'
                : 'ROOM用のURLが取得できるまでお待ちください',
            child: OutlinedButton(
              style: _RoomListCardActionStyle.secondaryCollectOutline(
                stateAccent,
                padding: tight,
              ),
              onPressed: _canCollectRoom
                  ? () async {
                      if (onCollectPressed != null) {
                        await onCollectPressed!(context, product);
                        return;
                      }
                      await provider.collectRoomAndLaunch(
                        context,
                        product.productId,
                      );
                    }
                  : null,
              child: _actionContent(
                icon: _canCollectRoom
                    ? Icons.favorite_rounded
                    : Icons.hourglass_top_rounded,
                label:
                    _canCollectRoom ? 'コレする' : 'コレする（URL未取得）',
                primary: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton(
            style: _RoomListCardActionStyle.destructiveOutline(
              padding: tight,
            ),
            onPressed: () => _confirmRemoveCandidate(context, provider),
            child: _actionContent(
              icon: Icons.delete_outline_rounded,
              label: '削除',
              primary: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionContent({
    required IconData icon,
    required String label,
    required bool primary,
    Color? foreground,
  }) {
    final fs = primary
        ? _RoomListCardActionStyle.labelFontSizePrimary
        : _RoomListCardActionStyle.labelFontSizeSecondary;
    final fw = primary
        ? _RoomListCardActionStyle.primaryLabelWeight
        : _RoomListCardActionStyle.labelWeight;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: _RoomListCardActionStyle.iconSize,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: fs,
              fontWeight: fw,
              color: foreground,
            ),
          ),
        ],
      ),
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

  Widget _doneActions(BuildContext context, Color stateAccent) {
    final hasRoom = product.extractedUrl.trim().isNotEmpty;
    final tight = _RoomListCardActionStyle.rowTightPadding;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FilledButton(
            style: _RoomListCardActionStyle.primaryViewFilled(padding: tight),
            onPressed: () => AppActionService.openUrl(
              context,
              url: product.itemUrl.trim().isNotEmpty
                  ? product.itemUrl.trim()
                  : product.browserLaunchUrl,
            ),
            child: _actionContent(
              icon: Icons.open_in_new_rounded,
              label: '楽天で見る',
              foreground: AppColors.textOnAccent,
              primary: true,
            ),
          ),
        ),
        if (hasRoom) ...[
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton(
              style: _RoomListCardActionStyle.auxiliaryRoomOutline(
                stateAccent,
                padding: tight,
              ),
              onPressed: () => AppActionService.openUrl(
                context,
                url: product.extractedUrl.trim(),
              ),
              child: _actionContent(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'ROOMを開く',
                primary: false,
              ),
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

  Widget _heroImage({required double topRightRadius}) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topRight: Radius.circular(topRightRadius),
      ),
      child: ColoredBox(
        color: AppColors.surfaceVariant,
        child: product.imageUrl.isNotEmpty
            ? Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) =>
                    Center(child: _thumbPlaceholder()),
              )
            : Center(child: _thumbPlaceholder()),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Icon(
      Icons.image_outlined,
      size: 40,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: foregroundColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foregroundColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.12,
                  height: 1.15,
                ),
          ),
        ],
      ),
    );
  }
}
