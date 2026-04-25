import 'package:flutter/material.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../services/app_action_service.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/room_colle_list_accent.dart';
import 'app_button.dart';
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
                          maxLines:
                              RoomColleProductListCardLayout.titleMaxLines,
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
                        _ratingRow(
                          reviewScoreStyle: reviewScoreStyle,
                          reviewCountStyle: reviewCountStyle,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _safeShopName(item),
                          maxLines: RoomColleProductListCardLayout.shopMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: shopStyle,
                        ),
                        if (item.genreId.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
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
                  ),
                  const SizedBox(height: 6),
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
          flex: 34,
          child: AppSecondaryButton(
            // 共通AppSecondaryButtonへ置換: 楽天確認用の副導線。
            label: '楽天で見る',
            icon: const Icon(Icons.open_in_new_rounded),
            height: 44,
            expand: true,
            onPressed: () =>
                AppActionService.openUrl(context, url: item.browserLaunchUrl),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(flex: 42, child: _buildRegisterAction(context)),
      ],
    );
  }

  Widget _buildRegisterAction(BuildContext context) {
    final isCandidate = localStatus == RakutenManagedProductStatus.candidate;
    final isDone = localStatus == RakutenManagedProductStatus.done;

    if (isDone) {
      return Tooltip(
        message: 'ROOMコレでコレ済の商品です。再度コレ候補へは登録できません。',
        child: AppSecondaryButton(
          // 共通AppSecondaryButtonへ置換: コレ済状態の非活性表示。
          label: 'コレ済',
          icon: const Icon(Icons.check_circle_outline_rounded),
          height: 44,
          expand: true,
          onPressed: null,
        ),
      );
    }

    if (isCandidate) {
      return Tooltip(
        message: 'コレ候補に登録済みです。重複登録はできません。ROOMコレの候補一覧から確認できます。',
        child: AppSecondaryButton(
          // 共通AppSecondaryButtonへ置換: 候補登録済み状態の非活性表示。
          label: '候補に登録済',
          icon: const Icon(Icons.bookmark_added_outlined),
          height: 44,
          expand: true,
          onPressed: null,
        ),
      );
    }

    return Tooltip(
      message: 'ROOMコレの「コレ候補」に追加します。あとからROOMコレタブの候補一覧で比較・整理できます。',
      child: AppPrimaryButton(
        // 共通AppPrimaryButtonへ置換: コレ候補追加の主CTA。
        label: 'コレ候補に追加',
        icon: const Icon(Icons.bookmark_add_rounded),
        height: 46,
        expand: true,
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
