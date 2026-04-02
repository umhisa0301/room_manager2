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

/// 候補・コレ済で共通の左端レール（タブ色に依存させず一覧の連続性を保つ）。
const Color _kCardLeftRail = Color(0xFF90A4AE);

/// カード内アクション：見た目はコンパクト、タップ最小 48×48 を維持。
class _RoomListCardActionStyle {
  _RoomListCardActionStyle._();

  /// アクセシビリティ／操作性の下限（見た目より広くヒットさせる）。
  static const double minTap = 48;

  static const double iconSizeCompact = 15;
  static const double labelFontCompact = 11;

  static const EdgeInsets paddingCompact =
      EdgeInsets.symmetric(horizontal: 5, vertical: 4);

  static const EdgeInsets paddingDelete =
      EdgeInsets.symmetric(horizontal: 2, vertical: 4);

  static RoundedRectangleBorder get _shapeCompact =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      );

  /// 楽天：青系（他ボタンと色分離）。
  static ButtonStyle rakutenFilled() {
    const blue = Color(0xFF1565C0);
    return FilledButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: blue,
      disabledForegroundColor: Color(0xFFE3F2FD),
      disabledBackgroundColor: Color(0xFF90CAF9),
      minimumSize: const Size(minTap, minTap),
      padding: paddingCompact,
      elevation: 0,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: _shapeCompact,
    );
  }

  /// コレ：アプリ強調色（フィルで一段目立たせる）。
  static ButtonStyle collectFilled() {
    return FilledButton.styleFrom(
      foregroundColor: AppColors.textOnAccent,
      backgroundColor: AppColors.accentPrimary,
      disabledForegroundColor: AppColors.textTertiary,
      disabledBackgroundColor: AppColors.surfaceVariant,
      minimumSize: const Size(minTap, minTap),
      padding: paddingCompact,
      elevation: 0,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: _shapeCompact,
    );
  }

  /// 削除：薄いグレー枠（視覚ノイズ低・サブアクション）。
  static ButtonStyle deleteOutlined() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.textSecondary,
      backgroundColor: AppColors.surface,
      minimumSize: const Size(minTap, minTap),
      padding: paddingDelete,
      side: const BorderSide(color: Color(0xFFBDBDBD), width: 1),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: _shapeCompact,
    );
  }

  /// ROOM 開く（アウトライン・完了色）。
  static ButtonStyle roomOutline(Color stateAccent) {
    return OutlinedButton.styleFrom(
      foregroundColor: stateAccent,
      backgroundColor: AppColors.surface,
      minimumSize: const Size(minTap, minTap),
      padding: paddingCompact,
      side: BorderSide(
        color: stateAccent.withValues(alpha: 0.45),
        width: 1,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: _shapeCompact,
    );
  }

  /// ROOM 非活性（コレ済でリンク未取得時 — レイアウトは ROOM ボタンと同一枠）。
  static ButtonStyle roomOutlineDisabled() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.textTertiary,
      backgroundColor: AppColors.surface,
      disabledForegroundColor: AppColors.textTertiary,
      disabledBackgroundColor: AppColors.surface,
      minimumSize: const Size(minTap, minTap),
      padding: paddingCompact,
      side: BorderSide(color: AppColors.divider.withValues(alpha: 0.95)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: _shapeCompact,
    );
  }
}

/// 楽天ROOM管理の保存済み商品カード（候補／コレ済でレイアウト規格を完全一致）。
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

  static const double _imageAspect = 1;

  static const int _titleMaxLines = 2;

  static const int _shopMaxLines = 1;
  static const int _footerMaxLines = 1;

  static const double _badgeRowHeight = 30;

  /// コンテンツ内側余白（候補・コレ済で同一）。
  static const EdgeInsets _contentPadding =
      EdgeInsets.fromLTRB(10, 8, 10, 8);

  bool get _canCollectRoom =>
      product.extractionStatus == RakutenUrlExtractionStatus.success &&
      product.extractedUrl.trim().isNotEmpty;

  bool get _hasRoomUrl => product.extractedUrl.trim().isNotEmpty;

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
          color: AppColors.textPrimary,
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
            color: _kCardLeftRail,
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
                  padding: _contentPadding,
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
                        _candidateActions(context)
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
        const SizedBox(width: 6),
        if (isCandidate)
          _extractionBadge(context)
        else
          _roomLinkBadge(stateAccent),
      ],
    );
  }

  String _footerText(bool isCandidate) {
    if (!isCandidate && product.doneAt != null) {
      return 'このアプリでコレ済にした日: ${_formatDateTime(product.doneAt!)}';
    }
    return '更新日時: ${_formatDateTime(product.updatedAt)}';
  }

  /// 3 スロット（5+5+2）・同一ギャップ。コレ済は右端をスペーサで埋める。
  Widget _candidateActions(BuildContext context) {
    final provider = context.read<RakutenManagedProductProvider>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: FilledButton(
            style: _RoomListCardActionStyle.rakutenFilled(),
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
            child: _compactActionLabel(
              icon: Icons.open_in_new_rounded,
              label: '楽天',
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          flex: 5,
          child: Tooltip(
            message: _canCollectRoom
                ? 'ROOMのURLを開き、一覧をコレ済に移します。'
                : 'ROOM用のURLが取得できるまでお待ちください',
            child: FilledButton(
              style: _RoomListCardActionStyle.collectFilled(),
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
              child: _compactActionLabel(
                icon: _canCollectRoom
                    ? Icons.favorite_rounded
                    : Icons.hourglass_top_rounded,
                label: 'コレ',
                color: _canCollectRoom
                    ? AppColors.textOnAccent
                    : AppColors.textTertiary,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          flex: 2,
          child: OutlinedButton(
            style: _RoomListCardActionStyle.deleteOutlined(),
            onPressed: () => _confirmRemoveCandidate(context, provider),
            child: _compactActionLabel(
              icon: Icons.delete_outline_rounded,
              label: '削除',
              color: AppColors.textSecondary,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactActionLabel({
    required IconData icon,
    required String label,
    required Color color,
    required FontWeight weight,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: _RoomListCardActionStyle.iconSizeCompact,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: _RoomListCardActionStyle.labelFontCompact,
              fontWeight: weight,
              color: color,
              height: 1.1,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: FilledButton(
            style: _RoomListCardActionStyle.rakutenFilled(),
            onPressed: () => AppActionService.openUrl(
              context,
              url: product.itemUrl.trim().isNotEmpty
                  ? product.itemUrl.trim()
                  : product.browserLaunchUrl,
            ),
            child: _compactActionLabel(
              icon: Icons.open_in_new_rounded,
              label: '楽天',
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          flex: 5,
          child: Tooltip(
            message: _hasRoomUrl
                ? 'ROOMの画面を開きます'
                : 'ROOM用のリンクが取得されていません',
            child: OutlinedButton(
              style: _hasRoomUrl
                  ? _RoomListCardActionStyle.roomOutline(stateAccent)
                  : _RoomListCardActionStyle.roomOutlineDisabled(),
              onPressed: _hasRoomUrl
                  ? () => AppActionService.openUrl(
                        context,
                        url: product.extractedUrl.trim(),
                      )
                  : null,
              child: _compactActionLabel(
                icon: _hasRoomUrl
                    ? Icons.chat_bubble_outline_rounded
                    : Icons.link_off_rounded,
                label: 'ROOM',
                color:
                    _hasRoomUrl ? stateAccent : AppColors.textTertiary,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          flex: 2,
          child: Center(
            child: Container(
              height: _RoomListCardActionStyle.minTap,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFBDBDBD).withValues(alpha: 0.4),
                  width: 1,
                ),
                color: AppColors.surface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roomLinkBadge(Color stateAccent) {
    if (_hasRoomUrl) {
      return _StatusPill(
        icon: Icons.link_rounded,
        label: 'ROOMリンク',
        backgroundColor: stateAccent.withValues(alpha: 0.1),
        foregroundColor: stateAccent,
      );
    }
    return _StatusPill(
      icon: Icons.link_off_rounded,
      label: 'ROOMなし',
      backgroundColor: AppColors.surfaceVariant,
      foregroundColor: AppColors.textTertiary,
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
        break;
      case RakutenUrlExtractionStatus.success:
        shortLabel = '取得済';
        bg = const Color(0xFFE8F5E9);
        fg = RoomListAccent.done;
        icon = Icons.check_circle_outline_rounded;
        break;
      case RakutenUrlExtractionStatus.failed:
        shortLabel = '失敗';
        bg = AppColors.error.withValues(alpha: 0.1);
        fg = AppColors.error;
        icon = Icons.error_outline_rounded;
        break;
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
