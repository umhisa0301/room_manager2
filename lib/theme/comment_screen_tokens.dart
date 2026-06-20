import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'home_screen_colors.dart';

/// コメント画面のレイアウト・配色（ホーム/投稿/探す/分析/マイページと同系のティール基調）。
abstract final class CommentScreenUi {
  CommentScreenUi._();

  static const Color canvas = HomeScreenColors.canvas;
  static const Color primary = HomeScreenColors.homeAccentTeal;
  static const Color primaryLight = HomeScreenColors.homeAccentTealLight;
  static const Color primaryBorder = HomeScreenColors.homeAccentTealBorder;

  static const Color textPrimary = HomeScreenColors.homeTextPrimary;
  static const Color textSecondary = HomeScreenColors.homeTextSecondary;
  static const Color cardBorder = HomeScreenColors.homeCardBorder;

  static Color get selectionHighlight => primary.withValues(alpha: 0.22);

  static ThemeData overlayTheme(ThemeData base) {
    return base.copyWith(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: selectionHighlight,
        selectionHandleColor: primary,
      ),
    );
  }

  static ButtonStyle primaryButtonStyle({double height = 48}) {
    return FilledButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: primary.withValues(alpha: 0.35),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
      minimumSize: Size(double.infinity, height),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
        letterSpacing: -0.1,
      ),
    );
  }

  static ButtonStyle copyButtonStyle() {
    return FilledButton.styleFrom(
      foregroundColor: AppColors.textOnAccent,
      backgroundColor: primary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
