import 'package:flutter/material.dart';

/// 楽天ROOM風のアプリ用カラーパレット。
/// 背景は白〜薄グレー、アクセントはピンク〜マゼンタ系。
class AppColors {
  AppColors._();

  // --- 背景・サーフェス ---
  /// アプリ全体のベース背景（ごく薄いグレー）
  static const Color background = Color(0xFFFAFAFA);
  /// カード・AppBar・ナビなどの表面
  static const Color surface = Color(0xFFFFFFFF);
  /// カードやチップのホバー/押下時の薄い背景
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // --- アクセント（ピンク〜マゼンタ）---
  /// メインアクセント（ボタン・選択・リンク）
  static const Color accentPrimary = Color(0xFFE91E8C);
  /// サブアクセント（グラデーション・ハイライト）
  static const Color accentSecondary = Color(0xFFFF6090);
  /// アクセントの薄い背景（チップ・バッジ背景）
  static const Color accentLight = Color(0xFFFFE5F0);
  /// アクセントのさらに薄い背景（ホバー等）
  static const Color accentLightest = Color(0xFFFFF0F5);

  // --- テキスト ---
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // --- その他 ---
  static const Color divider = Color(0xFFEEEEEE);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
}
