import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import 'app_card.dart';

/// ROOM コレ一覧と検索結果の商品行カードで共有するレイアウト・タイポの単一情報源。
abstract final class RoomColleProductListCardLayout {
  RoomColleProductListCardLayout._();

  static const double minCardHeight = 0;

  /// 左スロット幅（その中で 1:1 サムネを配置）。
  static const double thumbSlotWidth = 104;

  static const double radius = 18;

  static const int titleMaxLines = 2;
  static const int shopMaxLines = 1;

  static Color get cardBackgroundColor => HomeScreenColors.roomMetricTileFill;
  static Color get cardBorderColor => HomeScreenColors.roomMetricTileBorder;

  static List<BoxShadow> get cardBoxShadow => [
    ...HomeScreenColors.roomMetricTileShadow,
    BoxShadow(
      color: HomeScreenColors.cardShadowColor.withValues(alpha: 0.32),
      offset: const Offset(0, 3),
      blurRadius: 12,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      offset: const Offset(0, 1),
      blurRadius: 3,
    ),
  ];

  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: cardBackgroundColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: cardBorderColor),
      boxShadow: cardBoxShadow,
    );
  }

  static EdgeInsets get rightColumnPadding =>
      const EdgeInsets.fromLTRB(10, 8, 12, 8);

  static String formatPriceYen(int n) {
    if (n < 0) return '価格 —';
    return '¥${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  static TextStyle? titleTextStyle(ThemeData theme) {
    return theme.textTheme.titleSmall?.copyWith(
      color: HomeScreenColors.metricTileTitleColor,
      height: 1.28,
      fontWeight: FontWeight.w700,
      fontSize: 14,
      letterSpacing: -0.15,
    );
  }

  static TextStyle? priceTextStyle(ThemeData theme) {
    return theme.textTheme.titleSmall?.copyWith(
      color: HomeScreenColors.metricTileValueColor,
      fontWeight: FontWeight.w800,
      fontSize: 16,
      height: 1.12,
      letterSpacing: -0.25,
    );
  }

  static TextStyle? shopTextStyle(ThemeData theme) {
    return theme.textTheme.bodySmall?.copyWith(
      color: HomeScreenColors.metricTileCaptionColor,
      height: 1.22,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );
  }

  static TextStyle? metaTextStyle(ThemeData theme) {
    return theme.textTheme.bodySmall?.copyWith(
      color: HomeScreenColors.metricTileCaptionColor,
      height: 1.22,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );
  }

  static TextStyle? selectionHintTextStyle(ThemeData theme) {
    return theme.textTheme.bodySmall?.copyWith(
      color: const Color(0xFF888888),
      height: 1.15,
      fontSize: 10,
      fontWeight: FontWeight.w400,
    );
  }
}

/// ROOMコレ一覧と楽天検索結果で共有する商品カードの外枠。
class RoomColleProductListCardShell extends StatelessWidget {
  const RoomColleProductListCardShell({
    super.key,
    required this.child,
    this.minHeight,
  });

  final Widget child;

  /// 左サムネ幅に合わせる場合など。未指定時は [RoomColleProductListCardLayout.thumbSlotWidth]。
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight:
            minHeight ?? RoomColleProductListCardLayout.thumbSlotWidth,
      ),
      child: AppCard(
        padding: EdgeInsets.zero,
        backgroundColor: RoomColleProductListCardLayout.cardBackgroundColor,
        borderColor: RoomColleProductListCardLayout.cardBorderColor,
        radius: RoomColleProductListCardLayout.radius,
        elevated: true,
        child: child,
      ),
    );
  }
}

/// 左列：ROOM コレと同一のサムネスロット（1:1・角丸 8・右境界線）。
class RoomColleProductListCardThumbSlot extends StatelessWidget {
  const RoomColleProductListCardThumbSlot({
    super.key,
    required this.child,
    this.slotWidth,
  });

  final Widget child;

  /// 未指定時は [RoomColleProductListCardLayout.thumbSlotWidth]。
  final double? slotWidth;

  @override
  Widget build(BuildContext context) {
    final w = slotWidth ?? RoomColleProductListCardLayout.thumbSlotWidth;
    return Container(
      width: w,
      constraints: const BoxConstraints(
        minHeight: RoomColleProductListCardLayout.minCardHeight,
      ),
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
            borderRadius: BorderRadius.circular(10),
            child: child,
          ),
        ),
      ),
    );
  }
}
