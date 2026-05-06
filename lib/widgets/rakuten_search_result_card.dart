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
    this.sourceContextLabel,
    this.compactListLayout = false,
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

  /// 保存ショップの商品一覧など、縦幅を抑えたいとき。既定は通常の検索結果と同じ見え方。
  final bool compactListLayout;

  static const double _compactThumbWidth = 88;

  static const double _contentGap = 6;
  static const double _metaGap = 4;
  static const double _buttonGapB = 8;
  static const EdgeInsets _rightColumnPadding = EdgeInsets.fromLTRB(
    12,
    10,
    12,
    10,
  );
  static const EdgeInsets _rightColumnPaddingCompact = EdgeInsets.fromLTRB(
    8,
    8,
    10,
    8,
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
    final compact = compactListLayout && !selectionMode;
    final contentGap = compact ? 4.0 : _contentGap;
    final metaGap = compact ? 2.0 : _metaGap;
    final rightPad = compact ? _rightColumnPaddingCompact : _rightColumnPadding;
    final titleMaxLines = RoomColleProductListCardLayout.titleMaxLines;
    final thumbW = compact ? _compactThumbWidth : null;

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
      minHeight: thumbW,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectionMode)
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 2),
              child: Center(child: _buildSelectionControl(context)),
            ),
          RoomColleProductListCardThumbSlot(
            slotWidth: thumbW,
            child: _heroImage(compact: compact),
          ),
          Expanded(
            child: Padding(
              padding: rightPad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (compact &&
                          sourceContextLabel != null &&
                          sourceContextLabel!.trim().isNotEmpty) ...[
                        _SourceContextChip(label: sourceContextLabel!.trim()),
                        SizedBox(height: metaGap + 1),
                      ],
                      Text(
                        _safeItemName(item),
                        maxLines: titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      SizedBox(height: contentGap),
                      Text(
                        RoomColleProductListCardLayout.formatPriceYen(
                          item.itemPrice,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: priceStyle,
                      ),
                      SizedBox(height: metaGap),
                      _ratingRow(
                        reviewScoreStyle: reviewScoreStyle,
                        reviewCountStyle: reviewCountStyle,
                      ),
                      SizedBox(height: metaGap),
                      Text(
                        _safeShopName(item),
                        maxLines: RoomColleProductListCardLayout.shopMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: shopStyle,
                      ),
                      if (item.genreId.trim().isNotEmpty) ...[
                        SizedBox(height: metaGap),
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
                      if (!compact &&
                          sourceContextLabel != null &&
                          sourceContextLabel!.trim().isNotEmpty) ...[
                        SizedBox(height: metaGap),
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
                  SizedBox(height: compact ? 6 : 10),
                  _searchResultActions(context, compact: compact),
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

  Widget _searchResultActions(BuildContext context, {required bool compact}) {
    final h = compact ? 40.0 : 48.0;
    final rakuten = AppOutlineButton(
      label: '楽天で見る',
      icon: Icon(Icons.open_in_new, size: compact ? 16.0 : 18.0),
      height: h,
      expand: true,
      onPressed: () =>
          AppActionService.openUrl(context, url: item.browserLaunchUrl),
    );
    final register = _buildRegisterAction(context, compact: compact, height: h);
    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 5, child: register),
          SizedBox(width: compact ? 6 : _buttonGapB),
          Expanded(flex: 3, child: rakuten),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: rakuten),
        SizedBox(width: _buttonGapB),
        Expanded(child: register),
      ],
    );
  }

  Widget _buildRegisterAction(
    BuildContext context, {
    bool compact = false,
    required double height,
  }) {
    final isCandidate = localStatus == RakutenManagedProductStatus.candidate;
    final isDone = localStatus == RakutenManagedProductStatus.done;

    if (isDone) {
      return Tooltip(
        message: 'ROOMコレでコレ済の商品です。再度コレ候補へは登録できません。',
        child: AppOutlineButton(
          label: 'コレ済',
          icon: Icon(Icons.check_circle_outline, size: compact ? 16.0 : 18.0),
          height: height,
          expand: true,
          onPressed: null,
        ),
      );
    }

    if (isCandidate) {
      return Tooltip(
        message: 'コレ候補に登録済みです。重複登録はできません。ROOMコレの候補一覧から確認できます。',
        child: AppOutlineButton(
          label: '候補に登録済み',
          icon: Icon(Icons.bookmark_added_outlined, size: compact ? 16.0 : 18.0),
          height: height,
          expand: true,
          onPressed: null,
        ),
      );
    }

    return Tooltip(
      message: 'ROOMコレの候補に追加します。あとから候補一覧で比較・整理できます。',
      child: AppPrimaryButton(
        label: '候補に追加',
        icon: Icon(Icons.add, size: compact ? 16.0 : 18.0),
        height: height,
        expand: true,
        isLoading: isRegistering,
        onPressed: isRegistering ? null : onRegisterCandidate,
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

  Widget _heroImage({bool compact = false}) {
    Widget child;
    try {
      final url = item.imageUrl.trim();
      if (url.isNotEmpty) {
        child = Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Center(child: _thumbPlaceholder(compact: compact)),
        );
      } else {
        child = Center(child: _thumbPlaceholder(compact: compact));
      }
    } catch (_) {
      child = Center(child: _thumbPlaceholder(compact: compact));
    }
    return ColoredBox(color: AppColors.surfaceVariant, child: child);
  }

  Widget _thumbPlaceholder({bool compact = false}) {
    return Icon(
      Icons.image_outlined,
      size: compact ? 24 : 30,
      color: AppColors.textTertiary.withValues(alpha: 0.65),
    );
  }
}

class _SourceContextChip extends StatelessWidget {
  const _SourceContextChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.textTertiary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.55),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
            fontSize: 10,
            height: 1.15,
            letterSpacing: 0.02,
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
    final label = isDone ? 'コレ済' : '候補に登録済み';
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
