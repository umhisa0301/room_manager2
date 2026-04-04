import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';

/// ROOM コレ一覧と検索結果の商品行カードで共有するレイアウト・タイポの単一情報源。
abstract final class RoomColleProductListCardLayout {
  RoomColleProductListCardLayout._();

  static const double cardHeight = 196;

  /// 左スロット幅（その中で 1:1 サムネを配置）。
  static const double thumbSlotWidth = 98;

  static const double radius = 12;

  static const int titleMaxLines = 2;
  static const int shopMaxLines = 1;

  static List<BoxShadow> get cardBoxShadow => [
    ...HomeScreenColors.roomMetricTileShadow,
    BoxShadow(
      color: HomeScreenColors.cardShadowColor.withValues(alpha: 0.38),
      offset: const Offset(0, 2),
      blurRadius: 9,
    ),
  ];

  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.roomMetricTileFill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: HomeScreenColors.roomMetricTileBorder),
      boxShadow: cardBoxShadow,
    );
  }

  static EdgeInsets get rightColumnPadding =>
      const EdgeInsets.fromLTRB(7, 7, 9, 6);

  static String formatPriceYen(int n) {
    if (n < 0) return '価格 —';
    return '¥${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  static TextStyle? titleTextStyle(ThemeData theme) {
    return theme.textTheme.titleSmall?.copyWith(
      color: HomeScreenColors.metricTileTitleColor,
      height: 1.22,
      fontWeight: FontWeight.w600,
      fontSize: 13.5,
    );
  }

  static TextStyle? priceTextStyle(ThemeData theme) {
    return theme.textTheme.titleSmall?.copyWith(
      color: HomeScreenColors.metricTileValueColor,
      fontWeight: FontWeight.w800,
      fontSize: 15,
      height: 1.15,
    );
  }

  static TextStyle? shopTextStyle(ThemeData theme) {
    return theme.textTheme.bodySmall?.copyWith(
      color: HomeScreenColors.metricTileCaptionColor,
      height: 1.2,
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

/// 左列：ROOM コレと同一のサムネスロット（1:1・角丸 8・右境界線）。
class RoomColleProductListCardThumbSlot extends StatelessWidget {
  const RoomColleProductListCardThumbSlot({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: RoomColleProductListCardLayout.thumbSlotWidth,
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
            child: child,
          ),
        ),
      ),
    );
  }
}
