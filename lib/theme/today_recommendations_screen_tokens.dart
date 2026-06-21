import 'package:flutter/material.dart';

import 'home_screen_colors.dart';

/// 今日のおすすめコレ候補画面の配色（探す・投稿管理と同系のティール基調）。
abstract final class TodayRecommendationsScreenUi {
  TodayRecommendationsScreenUi._();

  static const Color canvas = HomeScreenColors.canvas;
  static const Color primary = HomeScreenColors.homeAccentTeal;
  static const Color primaryLight = HomeScreenColors.homeAccentTealLight;
  static const Color primaryBorder = HomeScreenColors.homeAccentTealBorder;

  static Color get selectionHighlight => primary.withValues(alpha: 0.22);

  static ThemeData overlayTheme(ThemeData base) {
    return base.copyWith(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: selectionHighlight,
        selectionHandleColor: primary,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return null;
          }
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return null;
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle()),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          visualDensity: VisualDensity.compact,
        ),
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

  static ButtonStyle dismissTextButtonStyle() {
    return TextButton.styleFrom(
      foregroundColor: HomeScreenColors.homeMutedText,
      visualDensity: VisualDensity.compact,
    );
  }
}
