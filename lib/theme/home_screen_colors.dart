import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ホーム画面の配色役割定義。
///
/// ブランド色は [AppColors] を基準にし、ホーム内だけ階層が伝わるように濃淡・境界を調整する。
///
/// **階層**
/// 1. [canvas] … 画面全体の土台
/// 2. [groupedSectionFill] … ROOM / 最近候補など「セクションのまとまり」
/// 3. [standaloneCardFill] … 楽天検索など単独カード
/// 4. [deckFill] / [deckOutline] … セクション内のデッキ（メトリクス枠・一覧枠）
/// 5. [metricTileFill] / [metricTileOutline] … デッキ内の1タイル
/// 6. [accentPrimary] 系（[AppColors.accentPrimary]）… 主CTA・強調見出し（ボタンは既存ウィジェット）
/// 7. [subActionRowFill] … コレ一覧などサブ導線行
/// 8. テキスト … [titlePrimary] / [leadOnSection] / [bodyOnSection] / [footnoteMuted]
/// 9. 状態 … [statusSuccessIcon] / [statusAccentMuted] / [statusAccentStrong]
abstract final class HomeScreenColors {
  HomeScreenColors._();

  // --- 1. 画面土台 ---
  static Color get canvas => AppColors.background;

  // --- 2. セクションのまとまり（外枠ごと薄く沈める）---
  static Color get groupedSectionFill => Color.alphaBlend(
        AppColors.surfaceVariant.withValues(alpha: 0.58),
        AppColors.background,
      );

  /// 単独カード（検索ブロック）：セクション群より一段明るく浮かせる
  static Color get standaloneCardFill => AppColors.surface;

  // --- 3. 内側デッキ ---
  static Color get deckFill => AppColors.surface;
  static Color get deckOutline => AppColors.divider.withValues(alpha: 0.84);

  // --- 4. メトリクス1枚・リスト行のベース面 ---
  static Color get metricTileFill => AppColors.surface;
  static Color get metricTileOutline => AppColors.divider.withValues(alpha: 0.92);

  // --- 境界 ---
  static Color get sectionOutlineNeutral =>
      AppColors.divider.withValues(alpha: 0.88);
  static Color get sectionOutlineAccent =>
      AppColors.accentPrimary.withValues(alpha: 0.24);
  static Color get inlineDivider => AppColors.divider.withValues(alpha: 0.62);
  static Color get listRowDivider =>
      AppColors.divider.withValues(alpha: 0.56);

  // --- 今日のおすすめ（アクティブ / 完了）---
  static List<Color> get todayActiveGradientColors => [
        AppColors.accentLight.withValues(alpha: 0.92),
        AppColors.surface,
      ];
  static Color get todayActiveBorder =>
      AppColors.accentPrimary.withValues(alpha: 0.28);
  static Color get todayDoneFill => Color.alphaBlend(
        AppColors.surfaceVariant.withValues(alpha: 0.64),
        AppColors.surface,
      );
  static Color get todayDoneBorder => sectionOutlineNeutral;

  // --- 「このアプリについて」ヘッダー ---
  static Color get aboutHeaderGradientStart =>
      AppColors.accentLight.withValues(alpha: 0.96);
  static Color get aboutHeaderGradientEnd => const Color(0xFFFFF0F4);

  // --- テキスト階層（ホーム）---
  static Color get titlePrimary => AppColors.textPrimary;
  static Color get sectionTitleAccent => AppColors.accentPrimary;
  static Color get leadOnSection => const Color(0xFF5C5C5C);
  static Color get bodyOnSection => AppColors.textSecondary;
  static Color get footnoteMuted => const Color(0xFF757575);
  static Color get footerActionLabel => AppColors.accentPrimary;

  // --- サブ導線行 ---
  static Color get subActionRowFill => Color.alphaBlend(
        AppColors.surfaceVariant.withValues(alpha: 0.48),
        AppColors.surface,
      );

  // --- 状態アイコン ---
  static Color get statusSuccessIcon =>
      AppColors.success.withValues(alpha: 0.9);
  static Color get statusAccentMuted =>
      AppColors.accentPrimary.withValues(alpha: 0.6);
  static Color get statusAccentStrong =>
      AppColors.accentPrimary.withValues(alpha: 0.92);

  // --- インタラクション（リップル：疲れない範囲で存在感）---
  static Color get inkAccentSplash => AppColors.accentPrimary.withValues(alpha: 0.12);
  static Color get inkAccentHighlight =>
      AppColors.accentPrimary.withValues(alpha: 0.06);
  static Color get inkNeutralSplash =>
      AppColors.textPrimary.withValues(alpha: 0.07);
  static Color get inkNeutralHighlight =>
      AppColors.textPrimary.withValues(alpha: 0.035);

  // --- 影 ---
  static Color get cardShadowColor => Colors.black.withValues(alpha: 0.065);

  // --- プログレス（10件バーが埋もれないように）---
  static Color get progressTrack => AppColors.divider.withValues(alpha: 0.52);
  static Color get progressValue =>
      AppColors.accentPrimary.withValues(alpha: 0.92);

  // --- 商品サムネプレースホルダ ---
  static Color get candidateThumbPlaceholder =>
      const Color(0xFFD9ECFC);

  /// フローステップの番号バッジ背景
  static Color get flowStepBadgeFill =>
      AppColors.accentPrimary.withValues(alpha: 0.18);
}
