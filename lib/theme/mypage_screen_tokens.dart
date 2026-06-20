import 'package:flutter/material.dart';

import 'home_screen_colors.dart';

/// マイページ画面のレイアウト・配色（投稿管理・探す・分析と同系のティール基調）。
abstract final class MyPageScreenUi {
  MyPageScreenUi._();

  static const double screenPadH = 16;
  static const double gapSection = 12;
  static const double cardRadius = 16;
  static const double cardPadding = 16;
  static const double navReserve = 72;

  static const Color canvas = HomeScreenColors.canvas;
  static const Color primary = HomeScreenColors.homeAccentTeal;
  static const Color primaryLight = HomeScreenColors.homeAccentTealLight;
  static const Color primaryBorder = HomeScreenColors.homeAccentTealBorder;

  static const Color textPrimary = HomeScreenColors.homeTextPrimary;
  static const Color textSecondary = HomeScreenColors.homeTextSecondary;
  static const Color cardFill = HomeScreenColors.homeCardFill;
  static const Color cardBorder = HomeScreenColors.homeCardBorder;

  static const Color chipSetFill = primaryLight;
  static const Color chipSetText = primary;
  static const Color chipSetBorder = primaryBorder;

  static const Color chipUnsetFill = Color(0xFFF3F4F6);
  static const Color chipUnsetText = Color(0xFF6B7280);
  static const Color chipUnsetBorder = Color(0xFFE5E7EB);

  static const Color progressTrack = Color(0xFFE5E7EB);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: HomeScreenColors.cardShadowColor,
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ];

  static ButtonStyle primaryButtonStyle({double height = 48}) {
    return FilledButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: primary.withValues(alpha: 0.35),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
      minimumSize: Size(double.infinity, height),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        letterSpacing: -0.1,
      ),
    );
  }

  static ButtonStyle outlineButtonStyle({double height = 48}) {
    return OutlinedButton.styleFrom(
      foregroundColor: primary,
      disabledForegroundColor: primary.withValues(alpha: 0.45),
      minimumSize: Size(double.infinity, height),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      side: const BorderSide(color: primaryBorder, width: 1.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        letterSpacing: -0.1,
      ),
    );
  }

  static ButtonStyle subtleOutlineButtonStyle({double height = 44}) {
    return OutlinedButton.styleFrom(
      foregroundColor: primary,
      minimumSize: Size(double.infinity, height),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      side: BorderSide(color: primary.withValues(alpha: 0.55)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  static ButtonStyle linkTextButtonStyle() {
    return TextButton.styleFrom(
      foregroundColor: primary,
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }

  static ButtonStyle disabledOutlineButtonStyle({double height = 48}) {
    return OutlinedButton.styleFrom(
      foregroundColor: textSecondary,
      disabledForegroundColor: textSecondary,
      minimumSize: Size(double.infinity, height),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      side: const BorderSide(color: chipUnsetBorder, width: 1.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        letterSpacing: -0.1,
      ),
    );
  }

  static Color get selectionHighlight => primary.withValues(alpha: 0.22);

  static ThemeData overlayTheme(ThemeData base) {
    return base.copyWith(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: selectionHighlight,
        selectionHandleColor: primary,
      ),
      textButtonTheme: TextButtonThemeData(style: linkTextButtonStyle()),
    );
  }

  static const Color noticeFill = Color(0xFFF3F4F6);
  static const Color noticeBorder = chipUnsetBorder;
}
