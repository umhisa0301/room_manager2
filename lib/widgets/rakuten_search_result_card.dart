import 'package:flutter/material.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../services/app_action_service.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/room_colle_list_accent.dart';
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
    this.genreDisplayLineOverride,
    this.sourceContextLabel,
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

  /// 指定時はジャンル行にこれを表示（検索結果の API 解決名など）。
  /// null のときは [RakutenProductGenreDisplay.resolve]（API名・マスタ・未分類）。
  final String? genreDisplayLineOverride;

  /// 一覧の出所（例: 保存ショップ）。指定時はアクション行の直前に小さく表示する。
  final String? sourceContextLabel;

  static const double _contentGap = 6;
  static const double _metaGap = 4;
  static const double _buttonGap = 8;
  static const EdgeInsets _rightColumnPadding = EdgeInsets.fromLTRB(
    12,
    10,
    12,
    10,
  );

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
    final genreLineBase =
        shopStyle ?? theme.textTheme.bodySmall ?? const TextStyle();
    final genreLineStyle = genreLineBase.copyWith(
      fontSize: (genreLineBase.fontSize ?? 12) - 1,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
    final reviewCountStyle =
        RoomColleProductListCardLayout.metaTextStyle(theme)?.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: HomeScreenColors.metricTileCaptionColor,
        ) ??
        genreLineStyle;
    final reviewScoreStyle =
        RoomColleProductListCardLayout.metaTextStyle(theme)?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.15,
          color: HomeScreenColors.metricTileTitleColor,
          letterSpacing: -0.2,
        ) ??
        genreLineStyle;

    return RoomColleProductListCardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectionMode)
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 2),
              child: Center(child: _buildSelectionControl(context)),
            ),
          RoomColleProductListCardThumbSlot(child: _heroImage()),
          Expanded(
            child: Padding(
              padding: _rightColumnPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        _safeItemName(item),
                        maxLines: RoomColleProductListCardLayout.titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: _contentGap),
                      Text(
                        RoomColleProductListCardLayout.formatPriceYen(
                          item.itemPrice,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: priceStyle,
                      ),
                      const SizedBox(height: _metaGap),
                      _ratingRow(
                        reviewScoreStyle: reviewScoreStyle,
                        reviewCountStyle: reviewCountStyle,
                      ),
                      const SizedBox(height: _metaGap),
                      Text(
                        _safeShopName(item),
                        maxLines: RoomColleProductListCardLayout.shopMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: shopStyle,
                      ),
                      if (item.genreId.trim().isNotEmpty) ...[
                        const SizedBox(height: _metaGap),
                        Text(
                          genreDisplayLineOverride ??
                              RakutenProductGenreDisplay.resolve(
                                apiGenreName: item.genreName,
                                persistedGenreName: null,
                                prefetchedGenreName: null,
                                genreId: item.genreId,
                                traceItemCode: item.productId,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: genreLineStyle,
                        ),
                      ],
                      if (sourceContextLabel != null &&
                          sourceContextLabel!.trim().isNotEmpty) ...[
                        const SizedBox(height: _metaGap),
                        Text(
                          sourceContextLabel!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: genreLineStyle.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentPrimary.withValues(
                              alpha: 0.92,
                            ),
                          ),
                        ),
                      ],
                      if (localStatus != RakutenManagedProductStatus.none &&
                          !selectionMode) ...[
                        _SearchCardStatusLozenge(status: localStatus),
                      ],
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
                  const SizedBox(height: 10),
                  _searchResultActions(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingRow({
    required TextStyle reviewScoreStyle,
    required TextStyle reviewCountStyle,
  }) {
    final rating = item.reviewAverage;
    final reviewCount = item.reviewCount;
    final scoreText = rating > 0 ? '★${rating.toStringAsFixed(1)}' : '★-';
    final countText = reviewCount > 0 ? 'レビュー $reviewCount件' : 'レビュー 0件';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(scoreText, style: reviewScoreStyle),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            countText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: reviewCountStyle,
          ),
        ),
      ],
    );
  }

  Widget _searchResultActions(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _SearchCardActionButton(
            label: '楽天で見る',
            icon: Icons.open_in_new_rounded,
            onPressed: () =>
                AppActionService.openUrl(context, url: item.browserLaunchUrl),
          ),
        ),
        const SizedBox(width: _buttonGap),
        Expanded(child: _buildRegisterAction(context)),
      ],
    );
  }

  Widget _buildRegisterAction(BuildContext context) {
    final isCandidate = localStatus == RakutenManagedProductStatus.candidate;
    final isDone = localStatus == RakutenManagedProductStatus.done;

    if (isDone) {
      return Tooltip(
        message: 'ROOMコレでコレ済の商品です。再度コレ候補へは登録できません。',
        child: const _SearchCardActionButton(
          label: 'コレ済',
          icon: Icons.check_circle_outline_rounded,
          onPressed: null,
        ),
      );
    }

    if (isCandidate) {
      return Tooltip(
        message: 'コレ候補に登録済みです。重複登録はできません。ROOMコレの候補一覧から確認できます。',
        child: const _SearchCardActionButton(
          label: '候補に登録済',
          icon: Icons.bookmark_added_outlined,
          onPressed: null,
        ),
      );
    }

    return Tooltip(
      message: 'ROOMコレの候補に追加します。あとから候補一覧で比較・整理できます。',
      child: _SearchCardActionButton(
        label: '候補に追加',
        icon: Icons.add_rounded,
        primary: true,
        onPressed: isRegistering ? null : onRegisterCandidate,
        isLoading: isRegistering,
      ),
    );
  }

  Widget _buildSelectionControl(BuildContext context) {
    if (!isSelectionEnabled) {
      final isCandidate = localStatus == RakutenManagedProductStatus.candidate;
      final isDone = localStatus == RakutenManagedProductStatus.done;
      final accent = isDone
          ? RoomColleListAccent.done
          : isCandidate
          ? RoomColleListAccent.candidate
          : AppColors.textTertiary;
      return Icon(
        Icons.block_rounded,
        size: 22,
        color: accent.withValues(alpha: 0.85),
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
        color: isSelected ? AppColors.accentPrimary : AppColors.textSecondary,
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

class _SearchCardActionButton extends StatelessWidget {
  const _SearchCardActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.isLoading = false,
  });

  static const double _height = 48;

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final foreground = primary
        ? AppColors.textOnAccent
        : AppColors.textSecondary;
    final background = primary ? AppColors.accentPrimary : Colors.transparent;
    final border = primary
        ? AppColors.accentPrimary
        : AppColors.divider.withValues(alpha: 0.86);

    return SizedBox(
      width: double.infinity,
      height: _height,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          disabledForegroundColor: primary
              ? AppColors.textOnAccent.withValues(alpha: 0.72)
              : AppColors.textTertiary,
          disabledBackgroundColor: primary
              ? AppColors.accentPrimary.withValues(alpha: 0.34)
              : Colors.transparent,
          side: BorderSide(color: enabled ? border : AppColors.divider),
          elevation: primary && enabled ? 1.2 : 0,
          minimumSize: const Size(0, _height),
          fixedSize: const Size.fromHeight(_height),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(primary ? 14 : 999),
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnAccent.withValues(alpha: 0.9),
                    ),
                  ),
                ] else ...[
                  Icon(icon, size: 17),
                ],
                const SizedBox(width: 5),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w800,
                    color: foreground,
                    height: 1.1,
                    letterSpacing: -0.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ROOM コレのメトリクスバッジと同系の、カード内ミニ状態表示。
class _SearchCardStatusLozenge extends StatelessWidget {
  const _SearchCardStatusLozenge({required this.status});

  final RakutenManagedProductStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == RakutenManagedProductStatus.none) {
      return const SizedBox.shrink();
    }
    final isDone = status == RakutenManagedProductStatus.done;
    final bg = isDone
        ? HomeScreenColors.metricRoleDoneIconBg
        : HomeScreenColors.metricRoleCandidateIconBg;
    final fg = isDone
        ? HomeScreenColors.metricRoleDoneIcon
        : HomeScreenColors.metricRoleCandidateIcon;
    final label = isDone ? 'コレ済' : '候補に登録済';
    final icon = isDone
        ? Icons.verified_outlined
        : Icons.bookmark_added_outlined;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: fg.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  height: 1.1,
                  letterSpacing: -0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
