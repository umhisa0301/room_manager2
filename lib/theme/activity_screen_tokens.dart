import 'package:flutter/material.dart';

import 'home_screen_colors.dart';

/// 分析画面（活動タブ）専用の配色・ボタンスタイル。
///
/// 投稿管理・探す画面と同系のティール基調。グローバル [AppColors] は変更しない。
abstract final class ActivityScreenUi {
  ActivityScreenUi._();

  static const Color primary = HomeScreenColors.homeAccentTeal;
  static const Color primaryLight = HomeScreenColors.homeAccentTealLight;
  static const Color primaryBorder = HomeScreenColors.homeAccentTealBorder;
  static const Color background = HomeScreenColors.canvas;
  static const Color surface = HomeScreenColors.homeCardFill;
  static const Color border = HomeScreenColors.homeCardBorder;
  static const Color textPrimary = HomeScreenColors.homeTextPrimary;
  static const Color textSecondary = HomeScreenColors.homeTextSecondary;
  static const Color textMuted = HomeScreenColors.homeMutedText;
  static const Color textOnPrimary = Colors.white;
  static const Color success = HomeScreenColors.homeSuccess;

  /// カード内サブブロック（上限要約・次にやること行など）。
  static Color get subBlockFill => Color.alphaBlend(
        primaryLight.withValues(alpha: 0.42),
        surface,
      );

  static Color get subBlockBorder => border;

  /// メトリクス1枚タイル（今日の実績）。
  static Color get metricTileFill => primaryLight;

  static Color get metricTileBorder => primary.withValues(alpha: 0.18);

  static Color get progressTrack => HomeScreenColors.progressTrack;

  static Color get progressValue => primary;

  static Color get avatarBg => primaryLight;

  static Color get avatarIcon => primary;

  static Color get selectedTabShadow => primary.withValues(alpha: 0.28);

  /// 週次棒グラフ：投稿。
  static const Color chartPostBar = primary;

  /// 週次棒グラフ：候補（スレート系補助色）。
  static const Color chartCandidateBar = Color(0xFF94A3B8);

  static Color get emptyStateIcon => primary.withValues(alpha: 0.42);

  static Color get cardShadowColor => HomeScreenColors.cardShadowColor;

  static ButtonStyle primaryFilledButtonStyle({
    required ThemeData theme,
    double minHeight = 44,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: textOnPrimary,
      minimumSize: Size(double.infinity, minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }

  static ButtonStyle primaryOutlinedButtonStyle({
    required ThemeData theme,
    double minHeight = 44,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: primary,
      backgroundColor: surface,
      side: BorderSide(color: primary.withValues(alpha: 0.72)),
      minimumSize: Size(double.infinity, minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }

  static ButtonStyle compactOutlinedButtonStyle({
    required ThemeData theme,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: primary,
      backgroundColor: surface,
      side: BorderSide(color: primary.withValues(alpha: 0.72)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
