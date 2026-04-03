import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../services/app_action_service.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../utils/room_colle_card_time_format.dart';

/// 一覧カードの見た目バリアント（候補 / コレ済）。
enum RakutenManagedProductCardVariant { candidate, done }

/// ROOM 管理一覧用の共通アクセント（状態差のみに使用。カード下地は共通）。
abstract final class RoomListAccent {
  static const Color candidate = Color(0xFF1565C0);
  static const Color done = Color(0xFF2E7D32);
}

/// カード内アクション：1行に収めつつタップ領域を確保。
class _RoomListCardActionStyle {
  _RoomListCardActionStyle._();

  static const double minTap = 48;

  static const double iconSizeCompact = 14;
  static const double labelFontCompact = 10.5;
  static const double labelFontDelete = 10;

  static const EdgeInsets paddingMain = EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 6,
  );

  static const EdgeInsets paddingDelete = EdgeInsets.symmetric(
    horizontal: 4,
    vertical: 6,
  );

  static RoundedRectangleBorder get _shapeCompact =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

  static ButtonStyle rakutenFilled() {
    const blue = Color(0xFF1565C0);
    return FilledButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: blue,
      disabledForegroundColor: Color(0xFFE3F2FD),
      disabledBackgroundColor: Color(0xFF90CAF9),
      minimumSize: const Size(0, minTap),
      padding: paddingMain,
      elevation: 0,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: _shapeCompact,
    );
  }

  static ButtonStyle collectFilled() {
    return FilledButton.styleFrom(
      foregroundColor: AppColors.textOnAccent,
      backgroundColor: AppColors.accentPrimary,
      disabledForegroundColor: AppColors.textTertiary,
      disabledBackgroundColor: AppColors.surfaceVariant,
      minimumSize: const Size(0, minTap),
      padding: paddingMain,
      elevation: 0,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: _shapeCompact,
    );
  }

  static ButtonStyle deleteOutlined() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.textSecondary,
      backgroundColor: AppColors.surface,
      minimumSize: const Size(0, minTap),
      padding: paddingDelete,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: HomeScreenColors.metricTileOutline, width: 1),
      shape: _shapeCompact,
    );
  }

  static ButtonStyle roomOutline(Color stateAccent) {
    return OutlinedButton.styleFrom(
      foregroundColor: stateAccent,
      backgroundColor: AppColors.surface,
      minimumSize: const Size(0, minTap),
      padding: paddingMain,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: stateAccent.withValues(alpha: 0.45), width: 1),
      shape: _shapeCompact,
    );
  }

  static ButtonStyle roomOutlineDisabled() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.textTertiary,
      backgroundColor: AppColors.surface,
      disabledForegroundColor: AppColors.textTertiary,
      disabledBackgroundColor: AppColors.surface,
      minimumSize: const Size(0, minTap),
      padding: paddingMain,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: AppColors.divider.withValues(alpha: 0.95)),
      shape: _shapeCompact,
    );
  }
}

/// 楽天ROOM管理の保存済み商品カード（左画像・右情報の横並び一覧向け）。
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
  )?
  onCollectPressed;

  static const double _radius = 12;

  /// キャンバス上でカード面が埋もれないよう、ホームのセクション影に近い補助影を重ねる。
  static List<BoxShadow> get _listCardShadow => [
    ...HomeScreenColors.roomMetricTileShadow,
    BoxShadow(
      color: HomeScreenColors.cardShadowColor.withValues(alpha: 0.38),
      offset: const Offset(0, 2),
      blurRadius: 9,
    ),
  ];

  /// 一覧でカード高さを揃え、行間のリズムを一定にする。
  /// 登録/コレ日時1行を右カラムに入れるため従来よりわずかに確保。
  static const double _cardHeight = 142;

  /// 左スロット幅（その中で正方形サムネを配置）。
  static const double _thumbSlotWidth = 98;
  static const int _titleMaxLines = 2;
  static const int _shopMaxLines = 1;

  bool get _canCollectRoom =>
      product.extractionStatus == RakutenUrlExtractionStatus.success &&
      product.extractedUrl.trim().isNotEmpty;

  bool get _hasRoomUrl => product.extractedUrl.trim().isNotEmpty;

  static String _safeItemName(RakutenManagedProduct product) {
    try {
      final t = product.itemName.trim();
      return t.isEmpty ? '（商品名なし）' : t;
    } catch (_) {
      return '（商品名なし）';
    }
  }

  static String _safeShopName(RakutenManagedProduct product) {
    try {
      final t = product.shopName.trim();
      return t.isEmpty ? 'ショップ名なし' : t;
    } catch (_) {
      return 'ショップ名なし';
    }
  }

  static String _safePriceYen(RakutenManagedProduct product) {
    try {
      final n = product.itemPrice;
      if (n < 0) return '価格 —';
      return '¥${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    } catch (_) {
      return '価格 —';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCandidate = variant == RakutenManagedProductCardVariant.candidate;
    final stateAccent = isCandidate
        ? RoomListAccent.candidate
        : RoomListAccent.done;

    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: HomeScreenColors.metricTileTitleColor,
      height: 1.22,
      fontWeight: FontWeight.w600,
      fontSize: 13.5,
    );
    final priceStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: HomeScreenColors.metricTileValueColor,
      fontWeight: FontWeight.w800,
      fontSize: 15,
      height: 1.15,
    );
    final shopStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: HomeScreenColors.metricTileCaptionColor,
      height: 1.2,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );
    final tsInstant =
        isCandidate ? product.addedAt : product.doneAt;
    final timestampStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: const Color(0xFF888888),
      height: 1.15,
      fontSize: 10,
      fontWeight: FontWeight.w400,
    );

    return Container(
      height: _cardHeight,
      decoration: BoxDecoration(
        color: HomeScreenColors.roomMetricTileFill,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: HomeScreenColors.roomMetricTileBorder),
        boxShadow: _listCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _thumbColumn(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 7, 9, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          _safeItemName(product),
                          maxLines: _titleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _safePriceYen(product),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: priceStyle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _safeShopName(product),
                          maxLines: _shopMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: shopStyle,
                        ),
                        RoomColleCardTimestampText(
                          instant: tsInstant,
                          style: timestampStyle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (isCandidate)
                    _candidateActions(context)
                  else
                    _doneActions(context, stateAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 左：正方形に近いサムネ（縦中央）。ListView 内で無限高さにならないよう固定幅のみ。
  Widget _thumbColumn() {
    return Container(
      width: _thumbSlotWidth,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.surfaceVariant.withValues(alpha: 0.45),
          HomeScreenColors.roomMetricTileFill,
        ),
        border: Border(right: BorderSide(color: HomeScreenColors.deckOutline)),
      ),
      padding: const EdgeInsets.all(6),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _heroImage(),
          ),
        ),
      ),
    );
  }

  Widget _candidateActions(BuildContext context) {
    final provider = context.read<RakutenManagedProductProvider>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 38,
          child: FilledButton(
            style: _RoomListCardActionStyle.rakutenFilled(),
            onPressed: () async {
              final err = await provider.openRakutenItemPage(
                context,
                product.productId,
              );
              if (!context.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(err)));
              }
            },
            child: _compactActionLabel(
              icon: Icons.open_in_new_rounded,
              label: '楽天で見る',
              color: Colors.white,
              weight: FontWeight.w700,
              fontSize: _RoomListCardActionStyle.labelFontCompact,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 38,
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
                label: 'コレする',
                color: _canCollectRoom
                    ? AppColors.textOnAccent
                    : AppColors.textTertiary,
                weight: FontWeight.w700,
                fontSize: _RoomListCardActionStyle.labelFontCompact,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 22,
          child: OutlinedButton(
            style: _RoomListCardActionStyle.deleteOutlined(),
            onPressed: () => _confirmRemoveCandidate(context, provider),
            child: _compactActionLabel(
              icon: Icons.delete_outline_rounded,
              label: '削除',
              color: AppColors.textSecondary,
              weight: FontWeight.w600,
              fontSize: _RoomListCardActionStyle.labelFontDelete,
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
    double fontSize = _RoomListCardActionStyle.labelFontCompact,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
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
              fontSize: fontSize,
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
    final name = _safeItemName(product);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('候補から削除'),
        content: Text('「$name」をコレ候補から削除します。よろしいですか？'),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Widget _doneActions(BuildContext context, Color stateAccent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 38,
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
              label: '楽天で見る',
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 38,
          child: Tooltip(
            message: _hasRoomUrl ? 'ROOMの画面を開きます' : 'ROOM用のリンクが取得されていません',
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
                color: _hasRoomUrl ? stateAccent : AppColors.textTertiary,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 22,
          child: OutlinedButton(
            style: _RoomListCardActionStyle.deleteOutlined(),
            onPressed: product.productId.trim().isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: product.productId.trim()),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('商品IDをコピーしました'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
            child: _compactActionLabel(
              icon: Icons.copy_rounded,
              label: 'ID',
              color: AppColors.textSecondary,
              weight: FontWeight.w600,
              fontSize: _RoomListCardActionStyle.labelFontDelete,
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroImage() {
    Widget child;
    try {
      final url = product.imageUrl.trim();
      if (url.isNotEmpty) {
        child = Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(child: _thumbPlaceholder()),
        );
      } else {
        child = Center(child: _thumbPlaceholder());
      }
    } catch (_) {
      child = Center(child: _thumbPlaceholder());
    }
    return ColoredBox(color: AppColors.surfaceVariant, child: child);
  }

  Widget _thumbPlaceholder() {
    return Icon(
      Icons.image_outlined,
      size: 30,
      color: AppColors.textTertiary.withValues(alpha: 0.65),
    );
  }
}
