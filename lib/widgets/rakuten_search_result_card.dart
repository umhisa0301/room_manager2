import 'package:flutter/material.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../services/app_action_service.dart';
import '../theme/app_theme.dart';
import 'room_colle_list_card_action_style.dart';
import 'room_colle_product_list_card_layout.dart';

/// 楽天検索結果の1商品カード（ROOM コレ一覧カードと同一 UI ルール）。
class RakutenSearchResultCard extends StatelessWidget {
  const RakutenSearchResultCard({
    super.key,
    required this.item,
    required this.localStatus,
    required this.isRegistering,
    required this.onRegisterCandidate,
    this.selectionMode = false,
    this.isSelected = false,
    this.isSelectionEnabled = true,
    this.onToggleSelected,
    this.selectionDisabledLabel,
  });

  final RakutenSearchItem item;
  final RakutenManagedProductStatus localStatus;
  final bool isRegistering;
  final VoidCallback onRegisterCandidate;
  final bool selectionMode;
  final bool isSelected;
  final bool isSelectionEnabled;
  final VoidCallback? onToggleSelected;
  final String? selectionDisabledLabel;

  static String _safeItemName(RakutenSearchItem item) {
    try {
      final t = item.itemName.trim();
      return t.isEmpty ? '（商品名なし）' : t;
    } catch (_) {
      return '（商品名なし）';
    }
  }

  static String _safeShopName(RakutenSearchItem item) {
    try {
      final t = item.shopName.trim();
      return t.isEmpty ? 'ショップ名なし' : t;
    } catch (_) {
      return 'ショップ名なし';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = RoomColleProductListCardLayout.titleTextStyle(theme);
    final priceStyle = RoomColleProductListCardLayout.priceTextStyle(theme);
    final shopStyle = RoomColleProductListCardLayout.shopTextStyle(theme);
    final selectionHintStyle =
        RoomColleProductListCardLayout.selectionHintTextStyle(theme);

    return Container(
      height: RoomColleProductListCardLayout.cardHeight,
      decoration: RoomColleProductListCardLayout.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selectionMode)
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 2),
              child: Center(child: _buildSelectionControl(context)),
            ),
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
                          _safeItemName(item),
                          maxLines: RoomColleProductListCardLayout.titleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          RoomColleProductListCardLayout.formatPriceYen(
                            item.itemPrice,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: priceStyle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _safeShopName(item),
                          maxLines: RoomColleProductListCardLayout.shopMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: shopStyle,
                        ),
                        if (selectionMode && !isSelectionEnabled) ...[
                          const SizedBox(height: 4),
                          Text(
                            selectionDisabledLabel ?? 'この商品は選択できません',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: selectionHintStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  _searchResultActions(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchResultActions(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 38,
          child: FilledButton(
            style: RoomColleListCardActionStyle.rakutenFilled(),
            onPressed: () => AppActionService.openUrl(
              context,
              url: item.browserLaunchUrl,
            ),
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
          child: _buildRegisterAction(context),
        ),
      ],
    );
  }

  Widget _buildRegisterAction(BuildContext context) {
    final isCandidate = localStatus == RakutenManagedProductStatus.candidate;
    final isDone = localStatus == RakutenManagedProductStatus.done;

    if (isDone) {
      return OutlinedButton(
        style: RoomColleListCardActionStyle.roomOutlineDisabled(),
        onPressed: null,
        child: RoomColleListCardActionStyle.compactActionLabel(
          icon: Icons.check_circle_outline_rounded,
          label: 'コレ済',
          color: AppColors.textTertiary,
          weight: FontWeight.w600,
        ),
      );
    }

    if (isCandidate) {
      return OutlinedButton(
        style: RoomColleListCardActionStyle.roomOutlineDisabled(),
        onPressed: null,
        child: RoomColleListCardActionStyle.compactActionLabel(
          icon: Icons.bookmark_added_outlined,
          label: 'コレ候補登録済',
          color: AppColors.textTertiary,
          weight: FontWeight.w600,
          fontSize: 10,
        ),
      );
    }

    return FilledButton(
      style: RoomColleListCardActionStyle.collectFilled(),
      onPressed: isRegistering ? null : onRegisterCandidate,
      child: isRegistering
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textOnAccent,
              ),
            )
          : RoomColleListCardActionStyle.compactActionLabel(
              icon: Icons.bookmark_add_outlined,
              label: 'コレ候補へ登録',
              color: AppColors.textOnAccent,
              weight: FontWeight.w700,
              fontSize: RoomColleListCardActionStyle.labelFontCompact,
            ),
    );
  }

  Widget _buildSelectionControl(BuildContext context) {
    if (!isSelectionEnabled) {
      return Icon(
        Icons.block_rounded,
        size: 22,
        color: AppColors.textTertiary,
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onToggleSelected,
      child: Icon(
        isSelected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        size: 24,
        color: isSelected
            ? AppColors.accentPrimary
            : AppColors.textSecondary,
      ),
    );
  }

  Widget _heroImage() {
    Widget child;
    try {
      final url = item.imageUrl.trim();
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
