import 'package:flutter/material.dart';

/// 楽天ROOM風のアプリテーマ定義。
/// 明るい背景・白〜薄グレー、アクセントはピンク〜マゼンタ系。
class AppTheme {
  AppTheme._();

  /// ベース背景（白〜ごく薄いグレー）
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceColor = Color(0xFFFFFFFF);

  /// アクセント（楽天ROOM風ピンク〜マゼンタ）
  static const Color accentPrimary = Color(0xFFE91E8C);
  static const Color accentSecondary = Color(0xFFFF6090);
  static const Color accentLight = Color(0xFFFFE5F0);

  /// テキスト
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);

  /// 角丸（大きめのカード・チップ用）
  static const double radiusCard = 16.0;
  static const double radiusChip = 20.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.light(
        primary: accentPrimary,
        secondary: accentSecondary,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: accentPrimary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
