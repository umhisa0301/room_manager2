import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';

/// ROOM コレ一覧・検索結果リストで共有するコンパクトアクションボタンのスタイル。
class RoomColleListCardActionStyle {
  RoomColleListCardActionStyle._();

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

  static Widget compactActionLabel({
    required IconData icon,
    required String label,
    required Color color,
    required FontWeight weight,
    double fontSize = labelFontCompact,
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
            size: iconSizeCompact,
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
}
