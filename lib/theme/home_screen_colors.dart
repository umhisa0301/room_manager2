import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ホーム画面の配色役割定義。
///
/// ブランド色は [AppColors] を基準にし、ホーム内だけ階層が伝わるように濃淡・境界を調整する。
///
/// **階層**
/// 1. [canvas] … 画面全体の土台
/// 2. [groupedSectionFill] … 汎用グループの基調（ベース）
/// 3. [roomGroupedShellFill] / [recentGroupedShellFill] … セクションごとのまとまり（微差）
/// 4. [roomSectionHeaderBand] / [recentSectionHeaderBand] … 見出し行（親）
/// 5. [roomContentWellFill] … 見出し直下〜デッキまでの「中身ゾーン」
/// 6. [standaloneCardFill] … 楽天検索など単独カード
/// 7. [deckFill] / [deckOutline] … デッキ枠
/// 8. [roomMetricTileFill] … ROOM メトリクス4枚の共通面／[metricTileFill] は他カード用
/// 9. テキスト … [accentSectionHeading] / [leadOnSection] / [groupedSectionBody] / …
/// 10. [subActionRowFill] … サブ導線行
abstract final class HomeScreenColors {
  HomeScreenColors._();

  // --- 1. 画面土台 ---
  static Color get canvas => AppColors.background;

  // --- 2. セクションのまとまり（基調）---
  static Color get groupedSectionFill => Color.alphaBlend(
        AppColors.surfaceVariant.withValues(alpha: 0.58),
        AppColors.background,
      );

  /// ROOM：ほんの少しピンク寄り（一覧ブロックと「ひとかたまり」に見せる）
  static Color get roomGroupedShellFill => Color.alphaBlend(
        AppColors.accentLight.withValues(alpha: 0.16),
        groupedSectionFill,
      );

  /// 最近候補：ROOM より薄く、別セクションだが同じ世界観
  static Color get recentGroupedShellFill => Color.alphaBlend(
        AppColors.accentLight.withValues(alpha: 0.09),
        groupedSectionFill,
      );

  /// ROOM 見出し帯（タイトル＝親）
  static Color get roomSectionHeaderBand => Color.alphaBlend(
        AppColors.accentLight.withValues(alpha: 0.34),
        roomGroupedShellFill,
      );

  /// 最近候補 見出し帯
  static Color get recentSectionHeaderBand => Color.alphaBlend(
        AppColors.accentLight.withValues(alpha: 0.26),
        recentGroupedShellFill,
      );

  /// ROOM：区切り下〜デッキ手前のわずかな沈み（中身ブロック）
  static Color get roomContentWellFill => Color.alphaBlend(
        AppColors.surface.withValues(alpha: 0.2),
        roomGroupedShellFill,
      );

  /// 最近候補：一覧デッキ周辺
  static Color get recentContentWellFill => Color.alphaBlend(
        AppColors.surface.withValues(alpha: 0.16),
        recentGroupedShellFill,
      );

  /// 単独カード（検索ブロック）：セクション群より一段明るく浮かせる
  static Color get standaloneCardFill => AppColors.surface;

  // --- 3. 内側デッキ ---
  static Color get deckFill => AppColors.surface;
  static Color get deckOutline => AppColors.divider.withValues(alpha: 0.84);

  // --- 4. メトリクス1枚・リスト行のベース面 ---
  static Color get metricTileFill => AppColors.surface;
  static Color get metricTileOutline => AppColors.divider.withValues(alpha: 0.92);

  /// ROOM 集計4タイル：共通のカード面（純白よりほんの少しトーンを載せデッキから分離）
  static Color get roomMetricTileFill => Color.alphaBlend(
        AppColors.accentLightest.withValues(alpha: 0.48),
        Color.alphaBlend(
          AppColors.surfaceVariant.withValues(alpha: 0.22),
          AppColors.surface,
        ),
      );

  /// ROOM メトリクス：縁をわずかに強め、背景に埋もれない
  static Color get roomMetricTileBorder => Color.alphaBlend(
        AppColors.textPrimary.withValues(alpha: 0.07),
        AppColors.divider.withValues(alpha: 0.78),
      );

  /// メトリクス行見出し（4枚で同色・役割はアイコンバッジで）
  static Color get metricTileTitleColor => const Color(0xFF3A3A40);

  /// メトリクス主数値（文字が沈まないよう一段濃く）
  static Color get metricTileValueColor => const Color(0xFF101012);

  /// メトリクス補足（タップ案内：主張しすぎない）
  static Color get metricTileCaptionColor => const Color(0xFF92929A);

  // --- ROOM メトリクス：役割別アクセント（アイコン＋バッジ地面のみ）---
  /// コレ候補：情報系（ブランドから逸れすぎないスレートブルー）
  static Color get metricRoleCandidateIcon => const Color(0xFF4A6B8C);
  static Color get metricRoleCandidateIconBg => const Color(0xFFE8EEF4);

  /// コレ済：完了系（ブランド success をわずかに明るくしてキツさを抑える）
  static Color get metricRoleDoneIcon => Color.alphaBlend(
        Colors.white.withValues(alpha: 0.14),
        AppColors.success,
      );
  static Color get metricRoleDoneIconBg => Color.alphaBlend(
        AppColors.success.withValues(alpha: 0.13),
        AppColors.surface,
      );

  /// 今日のコレ：当日アクション（ブランドアクセント）
  static Color get metricRoleTodayIcon =>
      AppColors.accentPrimary.withValues(alpha: 0.95);
  static Color get metricRoleTodayIconBg => Color.alphaBlend(
        AppColors.accentLight.withValues(alpha: 0.85),
        AppColors.surface,
      );

  /// 前回コレ日時：中立・メタ情報
  static Color get metricRoleHistoryIcon => const Color(0xFF6C6770);
  static Color get metricRoleHistoryIconBg => const Color(0xFFECECEF);

  /// ROOM メトリクス（デッキ内）：ごく弱い影で面の存在感を補助
  static List<BoxShadow> get roomMetricTileShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.042),
          offset: const Offset(0, 1),
          blurRadius: 6,
        ),
      ];

  // --- 境界 ---
  static Color get sectionOutlineNeutral =>
      AppColors.divider.withValues(alpha: 0.88);
  static Color get sectionOutlineAccent =>
      AppColors.accentPrimary.withValues(alpha: 0.24);
  static Color get inlineDivider => AppColors.divider.withValues(alpha: 0.62);
  static Color get listRowDivider =>
      AppColors.divider.withValues(alpha: 0.56);

  // --- 今日のおすすめ（独立セクション・グラデでまとまり）---
  static List<Color> get todayActiveGradientColors => [
        AppColors.accentLight.withValues(alpha: 0.94),
        Color.alphaBlend(
          AppColors.accentLight.withValues(alpha: 0.32),
          AppColors.surface,
        ),
      ];
  static Color get todayActiveBorder =>
      AppColors.accentPrimary.withValues(alpha: 0.32);
  static Color get todayDoneFill => Color.alphaBlend(
        AppColors.accentLight.withValues(alpha: 0.1),
        Color.alphaBlend(
          AppColors.surfaceVariant.withValues(alpha: 0.58),
          AppColors.surface,
        ),
      );
  static Color get todayDoneBorder => sectionOutlineNeutral;

  // --- 「このアプリについて」（見出し〜本文が同カード内の塊）---
  static Color get aboutHeaderGradientStart =>
      AppColors.accentLight.withValues(alpha: 0.96);
  static Color get aboutHeaderGradientEnd =>
      Color.alphaBlend(AppColors.accentLight.withValues(alpha: 0.2), canvas);

  static List<Color> get aboutSectionGradientColors => [
        aboutHeaderGradientStart,
        aboutHeaderGradientEnd,
      ];

  /// 展開本文エリア（ヘッダーより一段沈めて「中身」）
  static Color get aboutExpandedWellFill => Color.alphaBlend(
        AppColors.accentLightest.withValues(alpha: 0.72),
        canvas,
      );

  // --- テキスト階層（ホーム）---
  static Color get titlePrimary => AppColors.textPrimary;

  /// アクセントセクション見出し（ROOM・最近候補）：ブランドより一段濃く
  static Color get accentSectionHeading => Color.alphaBlend(
        const Color(0xFF240010).withValues(alpha: 0.14),
        AppColors.accentPrimary,
      );

  static Color get sectionTitleAccent => AppColors.accentPrimary;
  static Color get leadOnSection => const Color(0xFF6E6E6E);
  static Color get bodyOnSection => AppColors.textSecondary;

  /// グループセクション内の説明文（中身：読みやすさ）
  static Color get groupedSectionBody => const Color(0xFF565656);
  static Color get footnoteMuted => const Color(0xFF7A7A7A);
  static Color get footerActionLabel =>
      AppColors.accentPrimary.withValues(alpha: 0.92);

  /// 補助アイコン（シェブロン等）
  static Color get chevronOnSection => leadOnSection;

  // --- サブ導線行 ---
  static Color get subActionRowFill => Color.alphaBlend(
        AppColors.surfaceVariant.withValues(alpha: 0.48),
        AppColors.surface,
      );

  /// 最近候補セクション末尾の「コレ一覧を開く」（シェルと同色味で親子関係を補助）
  static Color get recentFooterRowFill => Color.alphaBlend(
        recentGroupedShellFill.withValues(alpha: 0.42),
        subActionRowFill,
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
