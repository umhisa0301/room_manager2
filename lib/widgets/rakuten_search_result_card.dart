import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../utils/product_card_rakuten_open.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../utils/shop_display_resolve.dart';
import '../theme/app_theme.dart';
import '../utils/search_tab_ui_audit_log.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
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

  /// 検索結果カードの標準サムネ幅（従来104より約15%拡大）。
  static const double _searchThumbWidth = 118;

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
      return ShopDisplayResolve.resolveDisplayShopName(
        shopName: item.shopName,
        shopCode: item.shopCode,
        screen: 'rakutenSearchResult',
      );
    } catch (_) {
      return ShopDisplayResolve.unknownShopLabel;
    }
  }

  void _openRakuten(BuildContext context, String source) {
    ProductCardRakutenOpen.open(
      context: context,
      affiliateUrl: item.affiliateUrl,
      itemUrl: item.itemUrl,
      screen: 'rakutenSearchResult',
      productId: item.productId,
      source: source,
    );
  }

  @override
  Widget build(BuildContext context) {
    ProductCardRakutenOpen.auditCard(
      screen: 'rakutenSearchResult',
      cardType: 'RakutenSearchResultCard',
    );
    final compact = compactListLayout && !selectionMode;
    final contentGap = compact ? 4.0 : _contentGap;
    final metaGap = compact ? 2.0 : _metaGap;
    final rightPad = compact ? _rightColumnPaddingCompact : _rightColumnPadding;
    final titleMaxLines = RoomColleProductListCardLayout.titleMaxLines;
    final thumbW = compact ? _compactThumbWidth : _searchThumbWidth;
    final buttonH = 44.0;

    searchProductCardLayoutAuditLog(
      'imageSize=$thumbW titleMaxLines=$titleMaxLines '
      'priceReviewSameLine=${!compact} buttonHeight=$buttonH cardHeight=auto overflowDetected=false',
    );

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
          fontSize: 12,
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: thumbW,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    RoomColleProductListCardThumbSlot(
                      slotWidth: thumbW,
                      child: _heroImage(context, compact: compact),
                    ),
                    if (selectionMode)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(4),
                          child: _buildSelectionCheckbox(context),
                        ),
                      ),
                  ],
                ),
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
                          InkWell(
                            onTap: () => _openRakuten(context, 'title'),
                            borderRadius: BorderRadius.circular(6),
                            child: Text(
                              _safeItemName(item),
                              maxLines: titleMaxLines,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                          ),
                          SizedBox(height: contentGap),
                          _priceAndRatingRow(
                            priceStyle: priceStyle,
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
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: HomeScreenColors.homeAccentTeal.withValues(
                                  alpha: 0.92,
                                ),
                              ),
                            ),
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
                      _searchResultActions(
                        context,
                        compact: compact,
                        buttonHeight: buttonH,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!selectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: _SearchCardStatusLozenge(status: localStatus),
            ),
        ],
      ),
    );
  }

  Widget _priceAndRatingRow({
    required TextStyle? priceStyle,
    required TextStyle reviewScoreStyle,
    required TextStyle reviewCountStyle,
  }) {
    final rating = item.reviewAverage;
    final reviewCount = item.reviewCount;
    final scoreText = rating > 0 ? '★${rating.toStringAsFixed(1)}' : '★-';
    final countText = reviewCount > 0 ? 'レビュー$reviewCount件' : 'レビュー0件';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          RoomColleProductListCardLayout.formatPriceYen(item.itemPrice),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: priceStyle,
        ),
        const SizedBox(width: 8),
        Text(scoreText, style: reviewScoreStyle),
        const SizedBox(width: 4),
        Flexible(
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

  Widget _searchResultActions(
    BuildContext context, {
    required bool compact,
    required double buttonHeight,
  }) {
    final h = buttonHeight;
    final isCandidate = localStatus == RakutenManagedProductStatus.candidate;
    final isDone = localStatus == RakutenManagedProductStatus.done;
    final rakuten = RakutenSearchOutlineButton(
      label: '楽天で見る',
      icon: Icon(Icons.open_in_new, size: compact ? 16.0 : 18.0),
      height: h,
      expand: true,
      onPressed: () => _openRakuten(context, 'button'),
    );

    if (isDone || isCandidate) {
      return rakuten;
    }

    final register = _buildRegisterAction(context, compact: compact, height: h);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: rakuten),
        SizedBox(width: compact ? 6 : _buttonGapB),
        Expanded(child: register),
      ],
    );
  }

  Widget _buildRegisterAction(
    BuildContext context, {
    bool compact = false,
    required double height,
  }) {
    return Tooltip(
      message: 'ROOMコレの候補に追加します。あとから候補一覧で比較・整理できます。',
      child: RakutenSearchPrimaryButton(
        label: '候補に追加',
        icon: Icon(Icons.add, size: compact ? 16.0 : 18.0),
        height: height,
        expand: true,
        isLoading: isRegistering,
        onPressed: isRegistering ? null : onRegisterCandidate,
      ),
    );
  }

  Widget _buildSelectionCheckbox(BuildContext context) {
    return Checkbox(
      value: isSelected,
      onChanged: !isSelectionEnabled ? null : (_) => onToggleSelected?.call(),
      activeColor: RakutenSearchScreenUi.primary,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _heroImage(BuildContext context, {bool compact = false}) {
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
    return Material(
      color: AppColors.surfaceVariant,
      child: InkWell(
        onTap: () => _openRakuten(context, 'image'),
        child: child,
      ),
    );
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
            fontSize: 12,
            height: 1.15,
            letterSpacing: 0.02,
          ),
        ),
      ),
    );
  }
}

/// 商品カード右上の状態ピル。
class _SearchCardStatusLozenge extends StatelessWidget {
  const _SearchCardStatusLozenge({required this.status});

  final RakutenManagedProductStatus status;

  @override
  Widget build(BuildContext context) {
    final isDone = status == RakutenManagedProductStatus.done;
    final isCandidate = status == RakutenManagedProductStatus.candidate;
    final label = isDone
        ? 'コレ済'
        : isCandidate
        ? '登録済'
        : '未登録';
    final bg = isDone
        ? HomeScreenColors.homeAccentTealLight
        : isCandidate
        ? HomeScreenColors.homeAccentTealLight
        : const Color(0xFFF1F5F9);
    final fg = isDone || isCandidate
        ? HomeScreenColors.homeAccentTeal
        : const Color(0xFF64748B);
    if (kDebugMode && isCandidate) {
      registeredLabelCopyAuditLog(
        'screen=searchResultCard oldLabel=候補に登録済み newLabel=$label '
        'isDisabledButton=false isChip=true productId=-',
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          height: 1.1,
        ),
      ),
    );
  }
}
