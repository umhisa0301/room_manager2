import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../services/app_action_service.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/room_colle_candidate_stale.dart';
import '../utils/room_colle_card_time_format.dart';
import 'room_colle_list_card_action_style.dart';
import 'room_colle_product_list_card_layout.dart';

/// 一覧カードの見た目バリアント（候補 / コレ済）。
enum RakutenManagedProductCardVariant { candidate, done }

/// ROOM 管理一覧用の共通アクセント（状態差のみに使用。カード下地は共通）。
abstract final class RoomListAccent {
  static const Color candidate = Color(0xFF1565C0);
  static const Color done = Color(0xFF2E7D32);
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
      return RoomColleProductListCardLayout.formatPriceYen(product.itemPrice);
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

    final theme = Theme.of(context);
    final titleStyle = RoomColleProductListCardLayout.titleTextStyle(theme);
    final priceStyle = RoomColleProductListCardLayout.priceTextStyle(theme);
    final shopStyle = RoomColleProductListCardLayout.shopTextStyle(theme);
    final tsInstant =
        isCandidate ? product.addedAt : product.doneAt;
    final timestampStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: const Color(0xFF888888),
      height: 1.15,
      fontSize: 10,
      fontWeight: FontWeight.w400,
    );
    final staleSpec = isCandidate
        ? RoomColleCandidateStaleSpec.resolve(
            product.addedAt,
            DateTime.now(),
          )
        : null;

    return Container(
      height: RoomColleProductListCardLayout.cardHeight,
      decoration: RoomColleProductListCardLayout.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RoomColleProductListCardThumbSlot(child: _heroImage()),
          Expanded(
            child: Padding(
              padding: RoomColleProductListCardLayout.rightColumnPadding,
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
                          maxLines: RoomColleProductListCardLayout.titleMaxLines,
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
                          maxLines: RoomColleProductListCardLayout.shopMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: shopStyle,
                        ),
                        if (staleSpec != null) ...[
                          const SizedBox(height: 4),
                          RoomColleCandidateStaleChip(spec: staleSpec),
                        ],
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

  Widget _candidateActions(BuildContext context) {
    final provider = context.read<RakutenManagedProductProvider>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 38,
          child: FilledButton(
            style: RoomColleListCardActionStyle.rakutenFilled(),
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
            child: RoomColleListCardActionStyle.compactActionLabel(
              icon: Icons.open_in_new_rounded,
              label: '楽天で見る',
              color: Colors.white,
              weight: FontWeight.w700,
              fontSize: RoomColleListCardActionStyle.labelFontCompact,
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
              style: RoomColleListCardActionStyle.collectFilled(),
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
              child: RoomColleListCardActionStyle.compactActionLabel(
                icon: _canCollectRoom
                    ? Icons.favorite_rounded
                    : Icons.hourglass_top_rounded,
                label: 'コレする',
                color: _canCollectRoom
                    ? AppColors.textOnAccent
                    : AppColors.textTertiary,
                weight: FontWeight.w700,
                fontSize: RoomColleListCardActionStyle.labelFontCompact,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 22,
          child: OutlinedButton(
            style: RoomColleListCardActionStyle.deleteOutlined(),
            onPressed: () => _confirmRemoveCandidate(context, provider),
            child: RoomColleListCardActionStyle.compactActionLabel(
              icon: Icons.delete_outline_rounded,
              label: '削除',
              color: AppColors.textSecondary,
              weight: FontWeight.w600,
              fontSize: RoomColleListCardActionStyle.labelFontDelete,
            ),
          ),
        ),
      ],
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
            style: RoomColleListCardActionStyle.rakutenFilled(),
            onPressed: () => AppActionService.openUrl(
              context,
              url: product.itemUrl.trim().isNotEmpty
                  ? product.itemUrl.trim()
                  : product.browserLaunchUrl,
            ),
            child: RoomColleListCardActionStyle.compactActionLabel(
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
                  ? RoomColleListCardActionStyle.roomOutline(stateAccent)
                  : RoomColleListCardActionStyle.roomOutlineDisabled(),
              onPressed: _hasRoomUrl
                  ? () => AppActionService.openUrl(
                      context,
                      url: product.extractedUrl.trim(),
                    )
                  : null,
              child: RoomColleListCardActionStyle.compactActionLabel(
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
            style: RoomColleListCardActionStyle.deleteOutlined(),
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
            child: RoomColleListCardActionStyle.compactActionLabel(
              icon: Icons.copy_rounded,
              label: 'ID',
              color: AppColors.textSecondary,
              weight: FontWeight.w600,
              fontSize: RoomColleListCardActionStyle.labelFontDelete,
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
