import 'package:flutter/material.dart';
import 'app_colors.dart';

/// アプリ共通のテキストスタイル。
/// スマホ向けに見やすいサイズを基準に定義。
class AppTextStyles {
  AppTextStyles._();

  // --- 見出し ---
  /// 画面タイトル・大見出し（18sp, 太字）
  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  /// セクション見出し（16sp, 中太）
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
  );

  /// 小見出し・カードタイトル（14sp, 中太）
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // --- 本文 ---
  /// 本文（15sp）スマホで読みやすい基準サイズ
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.45,
  );

  /// 本文・補足（14sp）
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  /// キャプション・補助（12sp）
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.35,
  );

  // --- 補足・ラベル ---
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// ナビ・タブのラベル（選択時は accent で上書き）
  static const TextStyle navLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const TextStyle navLabelSelected = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.accentPrimary,
  );

  // --- ボタン ---
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnAccent,
  );

  static const TextStyle buttonSecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.accentPrimary,
  );
}
