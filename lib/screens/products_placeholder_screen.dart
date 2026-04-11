import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/room_colle_list_filters.dart';
import '../navigation/app_shell_controller.dart';
import '../repository/genre_master_repository.dart';
import '../repository/room_colle_ui_state_repository.dart';
import '../services/rakuten_genre_master_service.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/room_colle_list_accent.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../utils/room_colle_candidate_stale.dart';
import '../widgets/app_screen_status.dart';
import '../widgets/home_primary_action_button.dart';
import '../widgets/rakuten_managed_product_card.dart';
import 'rakuten_search_screen.dart';

/// ROOMコレ一覧の左右。ホームの 9 に対し **1dp だけ狭め**て一覧優先（違和感を抑える程度）。
const double _kRoomListScreenPadH = 8;
const double _kRoomListCardGap = 5;

/// ROOMコレ画面のレイアウト・面色・装飾（ホーム完成版と同一デザイン言語。ロジックとは分離）。
abstract final class _RoomColleUi {
  const _RoomColleUi._();

  /// ホーム [_HomeUi.gapSection] と同じ 9。
  static const double gapSection = 9;

  /// 上部シェル内の左右。外側 [_kRoomListScreenPadH] と揃え、二重に空きすぎない。
  static const double insetSectionH = 8;

  /// ホーム見出し行と同じ 8。
  static const double gapIconToTitle = 8;
  static const double paddingWellV = 6;
  static const double paddingHeaderBand = 6;
  static const double headerBandBottom = 3;
  static const double chromeTopPadPop = 4;
  static const double chromeTopPadNoPop = 6;
  static const double tabDeckPad = 6;
  static const double tabDeckBottom = 7;
  static const double tabInnerPad = 3;
  static const double gapFieldStack = 5;

  /// キーワード欄と「その他の条件」行の間。
  static const double gapKeywordToFilterRow = 7;

  /// 絞り込みシェル直下〜区切り線まで。
  static const double gapAfterFilterShell = 2;

  /// 区切り線〜一覧の間（検索ブロックとリストの接続を明確に）。
  static const double gapListAfterDivider = 4;
  static const double listBottomPad = 10;

  /// 主ボタンと条件クリアの隙間。
  static const double filterRowGap = 8;
  static const double chipSpacing = 4;

  static double get radiusSectionOuter => AppDimensions.radiusCard;
  static const double radiusSectionInner = 12;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: HomeScreenColors.cardShadowColor,
      offset: const Offset(0, 2),
      blurRadius: 10,
    ),
  ];

  static BoxDecoration outerRoomShellDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.roomGroupedShellFill,
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(color: HomeScreenColors.sectionOutlineNeutral),
      boxShadow: cardShadow,
    );
  }

  static BoxDecoration tabInnerDeckDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.roomContentWellFill,
      borderRadius: BorderRadius.circular(radiusSectionInner),
      border: Border.all(color: HomeScreenColors.deckOutline),
    );
  }

  static TextStyle sectionHeadingAccent(BuildContext context) {
    final base = Theme.of(context).textTheme.titleSmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.12,
      color: HomeScreenColors.accentSectionHeading,
    );
  }
}

/// 絞り込みブロック：ホーム「ROOMコレ管理」と同じ「見出し帯＋ウェル」の階層。
class _RoomColleFilterShell extends StatelessWidget {
  const _RoomColleFilterShell({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _RoomColleUi.outerRoomShellDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_RoomColleUi.radiusSectionOuter),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredBox(
              color: HomeScreenColors.roomSectionHeaderBand,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  _RoomColleUi.insetSectionH,
                  _RoomColleUi.paddingHeaderBand,
                  _RoomColleUi.insetSectionH,
                  _RoomColleUi.headerBandBottom,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        icon,
                        size: 20,
                        color: HomeScreenColors.statusAccentStrong,
                      ),
                    ),
                    SizedBox(width: _RoomColleUi.gapIconToTitle),
                    Expanded(
                      child: Text(
                        title,
                        style: _RoomColleUi.sectionHeadingAccent(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ColoredBox(
              color: HomeScreenColors.roomContentWellFill,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  _RoomColleUi.insetSectionH,
                  _RoomColleUi.paddingWellV,
                  _RoomColleUi.insetSectionH,
                  _RoomColleUi.paddingWellV,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// タブをレール状に乗せる外周の角丸。
const double _kRoomColleTabTrackRadius = 14;

/// 条件クリアなど、セカンダリ操作の最小タップ高さ（Material 推奨に寄せる）。
const double _kRoomColleSecondaryCtrlMinHeight = 44;

/// 一覧の絞り込み条件をまとめて解除（キーワード・拡張条件・URL条件・日付を初期化）。
class _RoomColleClearFiltersButton extends StatelessWidget {
  const _RoomColleClearFiltersButton({
    required this.onPressed,
    this.compact = false,
    this.inlineSecondary = false,
  });

  final VoidCallback onPressed;

  /// 旧フル幅レイアウト用（現状未使用だが互換のため維持）。
  final bool compact;

  /// 横並び右列：主ボタンより弱い補助操作として見せる。
  final bool inlineSecondary;

  @override
  Widget build(BuildContext context) {
    final iconSize = inlineSecondary ? 16.0 : (compact ? 17.0 : 18.0);
    final fontSize = inlineSecondary ? 12.0 : (compact ? 12.5 : 13.0);
    final padH = inlineSecondary ? 6.0 : (compact ? 8.0 : 12.0);
    final padV = inlineSecondary ? 8.0 : (compact ? 8.0 : 10.0);
    final fg = inlineSecondary
        ? HomeScreenColors.groupedSectionBody
        : HomeScreenColors.leadOnSection;
    final bg = inlineSecondary
        ? Color.alphaBlend(
            HomeScreenColors.subActionRowFill.withValues(alpha: 0.55),
            HomeScreenColors.deckFill,
          )
        : HomeScreenColors.deckFill;
    final borderColor = inlineSecondary
        ? HomeScreenColors.inlineDivider
        : HomeScreenColors.metricTileOutline;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.layers_clear_rounded, size: iconSize, color: fg),
      label: Text(
        '条件クリア',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.15,
          color: fg,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: bg,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(48, _kRoomColleSecondaryCtrlMinHeight),
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: inlineSecondary
            ? VisualDensity.compact
            : (compact ? VisualDensity.compact : VisualDensity.standard),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
      ),
    );
  }
}

/// キーワード以外の条件（主）と条件クリア（補助）を1行に配置。
class _RoomColleInlineMoreFiltersRow extends StatelessWidget {
  const _RoomColleInlineMoreFiltersRow({
    required this.onOpenMoreFilters,
    required this.hasNonKeywordConstraintsBadge,
    required this.onClear,
    this.candidateUrlFilterActive = false,
  });

  final VoidCallback onOpenMoreFilters;
  final bool hasNonKeywordConstraintsBadge;
  final VoidCallback onClear;

  /// 候補タブ：取得済URLのみがONのときシート内フィルタが効いている旨をバッジで示す。
  final bool candidateUrlFilterActive;

  static Color _primaryFilterButtonFill() {
    return Color.alphaBlend(
      AppColors.accentLight.withValues(alpha: 0.20),
      HomeScreenColors.deckFill,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 7,
          child: Tooltip(
            message: '登録日・ジャンル・価格など（キーワード以外）',
            child: OutlinedButton.icon(
              onPressed: onOpenMoreFilters,
              icon: Badge(
                smallSize: 8,
                backgroundColor: AppColors.accentPrimary,
                isLabelVisible:
                    hasNonKeywordConstraintsBadge || candidateUrlFilterActive,
                child: const Icon(Icons.tune_rounded, size: 20),
              ),
              label: Text(
                'キーワード以外の条件',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  height: 1.15,
                  color: HomeScreenColors.accentSectionHeading,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: HomeScreenColors.accentSectionHeading,
                backgroundColor: _primaryFilterButtonFill(),
                alignment: Alignment.centerLeft,
                minimumSize: const Size(0, _kRoomColleSecondaryCtrlMinHeight),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                side: BorderSide(color: HomeScreenColors.sectionOutlineAccent),
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusButton,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: _RoomColleUi.filterRowGap),
        Expanded(
          flex: 4,
          child: Tooltip(
            message: 'キーワード・すべての絞り込み・コレ済の日付をまとめて初期化',
            child: _RoomColleClearFiltersButton(
              compact: true,
              inlineSecondary: true,
              onPressed: onClear,
            ),
          ),
        ),
      ],
    );
  }
}

/// 候補タブ：古い候補の整理導線（ワンタップで経過日数による絞り込み）。
///
/// [onPresetChanged] には [RoomColleStaleCandidatePreset.none] を含む確定値を渡す（トグルオフ含む）。
class _RoomColleStaleOrganizeQuickRow extends StatelessWidget {
  const _RoomColleStaleOrganizeQuickRow({
    required this.preset,
    required this.onPresetChanged,
  });

  final RoomColleStaleCandidatePreset preset;
  final ValueChanged<RoomColleStaleCandidatePreset> onPresetChanged;

  void _commitTap(RoomColleStaleCandidatePreset target) {
    final next = preset == target ? RoomColleStaleCandidatePreset.none : target;
    onPresetChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final o7 = const Color(0xFFE65100);
    final o7Bg = Color.alphaBlend(
      const Color(0xFFFFF3E0).withValues(alpha: 0.92),
      HomeScreenColors.roomContentWellFill,
    );
    final r30 = const Color(0xFFB71C1C);
    final r30Bg = Color.alphaBlend(
      const Color(0xFFFFEBEE).withValues(alpha: 0.92),
      HomeScreenColors.roomContentWellFill,
    );

    final sel3 = preset == RoomColleStaleCandidatePreset.threePlus;
    final sel7 = preset == RoomColleStaleCandidatePreset.sevenPlus;
    final sel30 = preset == RoomColleStaleCandidatePreset.thirtyPlus;

    final blue3 = const Color(0xFF1565C0);
    final blue3Bg = Color.alphaBlend(
      const Color(0xFFE3F2FD).withValues(alpha: 0.92),
      HomeScreenColors.roomContentWellFill,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '古い候補を整理',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: HomeScreenColors.leadOnSection,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '整理対象だけをすぐ表示',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            height: 1.28,
            color: HomeScreenColors.footnoteMuted,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: _RoomColleUi.chipSpacing,
          runSpacing: _RoomColleUi.chipSpacing,
          children: [
            FilterChip(
              label: const Text('3日以上'),
              selected: sel3,
              showCheckmark: false,
              onSelected: (_) =>
                  _commitTap(RoomColleStaleCandidatePreset.threePlus),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: HomeScreenColors.deckFill,
              selectedColor: blue3Bg,
              checkmarkColor: blue3,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: sel3 ? FontWeight.w800 : FontWeight.w600,
                color: sel3 ? blue3 : HomeScreenColors.titlePrimary,
              ),
              side: BorderSide(
                color: sel3
                    ? blue3.withValues(alpha: 0.55)
                    : HomeScreenColors.deckOutline,
                width: sel3 ? 1.25 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            ),
            FilterChip(
              label: const Text('7日以上'),
              selected: sel7,
              showCheckmark: false,
              onSelected: (_) =>
                  _commitTap(RoomColleStaleCandidatePreset.sevenPlus),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: HomeScreenColors.deckFill,
              selectedColor: o7Bg,
              checkmarkColor: o7,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: sel7 ? FontWeight.w800 : FontWeight.w600,
                color: sel7 ? o7 : HomeScreenColors.titlePrimary,
              ),
              side: BorderSide(
                color: sel7
                    ? o7.withValues(alpha: 0.55)
                    : HomeScreenColors.deckOutline,
                width: sel7 ? 1.25 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            ),
            FilterChip(
              label: const Text('30日以上'),
              selected: sel30,
              showCheckmark: false,
              onSelected: (_) =>
                  _commitTap(RoomColleStaleCandidatePreset.thirtyPlus),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: HomeScreenColors.deckFill,
              selectedColor: r30Bg,
              checkmarkColor: r30,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: sel30 ? FontWeight.w800 : FontWeight.w600,
                color: sel30 ? r30 : HomeScreenColors.titlePrimary,
              ),
              side: BorderSide(
                color: sel30
                    ? r30.withValues(alpha: 0.55)
                    : HomeScreenColors.deckOutline,
                width: sel30 ? 1.25 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            ),
          ],
        ),
      ],
    );
  }
}

/// 7日超の候補が一定件数以上のときの整理ナッジ（閉じた状態は永続化）。
class _RoomColleStalePileNoticeBar extends StatelessWidget {
  const _RoomColleStalePileNoticeBar({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE65100);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          const Color(0xFFFFF3E0).withValues(alpha: 0.94),
          HomeScreenColors.roomContentWellFill,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 22,
              color: accent.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '古い候補が溜まっています',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: HomeScreenColors.titlePrimary,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: '閉じる',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(
                Icons.close_rounded,
                size: 22,
                color: HomeScreenColors.leadOnSection.withValues(alpha: 0.85),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

bool _roomColleScreenHasExplicitRouteArgs(ProductsPlaceholderScreen widget) {
  return widget.initialDoneFilterLocalDay != null ||
      (widget.initialFocusCandidateProductId?.isNotEmpty ?? false) ||
      widget.initialTabIndex != 0;
}

/// 登録から 7 暦日以上経過したコレ候補の件数。
int _roomColleStale7PlusCandidateCount(RakutenManagedProductProvider p) {
  final now = DateTime.now();
  var n = 0;
  for (final e in p.sortedItemsForStatus(
    RakutenManagedProductStatus.candidate,
  )) {
    try {
      if (RoomColleCandidateStaleSpec.calendarDaysElapsed(e.addedAt, now) >=
          7) {
        n++;
      }
    } catch (_) {}
  }
  return n;
}

/// 一覧に現れる非空の楽天 genreId 一覧（商品データ由来）。
List<String> _roomColleDistinctGenreIds(List<RakutenManagedProduct> items) {
  final s = <String>{};
  for (final e in items) {
    try {
      final g = e.genreId.trim();
      if (g.isNotEmpty) s.add(g);
    } catch (_) {}
  }
  final out = s.toList()..sort();
  return out;
}

String _roomColleGenreFilterMenuText(String id) {
  final raw = RakutenGenreMasterService.instance.roomColleGenreFilterMenuLabel(
    id,
  );
  if (raw.length > 42) return '${raw.substring(0, 40)}…';
  return raw;
}

List<Widget> _roomColleFilterSummaryChips(RoomColleListFilterCriteria c) {
  final out = <Widget>[];
  switch (c.registeredDatePreset) {
    case RoomColleRegisteredDatePreset.all:
      break;
    case RoomColleRegisteredDatePreset.today:
      out.add(
        Chip(
          label: const Text('登録日: 今日'),
          visualDensity: VisualDensity.compact,
          backgroundColor: HomeScreenColors.roomMetricTileFill,
          side: BorderSide(color: HomeScreenColors.metricTileOutline),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: HomeScreenColors.metricTileTitleColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
      break;
    case RoomColleRegisteredDatePreset.last7Days:
      out.add(
        Chip(
          label: const Text('登録日: 7日以内'),
          visualDensity: VisualDensity.compact,
          backgroundColor: HomeScreenColors.roomMetricTileFill,
          side: BorderSide(color: HomeScreenColors.metricTileOutline),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: HomeScreenColors.metricTileTitleColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
      break;
  }
  final g = c.genreId?.trim();
  if (g != null && g.isNotEmpty) {
    final labelFull = RakutenGenreMasterService.instance
        .roomColleGenreFilterMenuLabel(g);
    final short = labelFull.length > 22
        ? '${labelFull.substring(0, 20)}…'
        : labelFull;
    out.add(
      Chip(
        label: Text('ジャンル: $short'),
        visualDensity: VisualDensity.compact,
        backgroundColor: HomeScreenColors.roomMetricTileFill,
        side: BorderSide(color: HomeScreenColors.metricTileOutline),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: HomeScreenColors.metricTileTitleColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
  if (c.priceMinYen != null || c.priceMaxYen != null) {
    final min = c.priceMinYen;
    final max = c.priceMaxYen;
    final String s;
    if (min != null && max != null) {
      s = '¥$min〜¥$max';
    } else if (min != null) {
      s = '¥$min〜';
    } else {
      s = '〜¥$max';
    }
    out.add(
      Chip(
        label: Text('価格 $s'),
        visualDensity: VisualDensity.compact,
        backgroundColor: HomeScreenColors.roomMetricTileFill,
        side: BorderSide(color: HomeScreenColors.metricTileOutline),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: HomeScreenColors.metricTileTitleColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
  switch (c.staleCandidatePreset) {
    case RoomColleStaleCandidatePreset.none:
      break;
    case RoomColleStaleCandidatePreset.threePlus:
      out.add(
        Chip(
          label: const Text('整理対象: 3日以上'),
          visualDensity: VisualDensity.compact,
          backgroundColor: HomeScreenColors.roomMetricTileFill,
          side: BorderSide(
            color: const Color(0xFF1565C0).withValues(alpha: 0.45),
          ),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1565C0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
      break;
    case RoomColleStaleCandidatePreset.sevenPlus:
      out.add(
        Chip(
          label: const Text('整理対象: 7日以上'),
          visualDensity: VisualDensity.compact,
          backgroundColor: HomeScreenColors.roomMetricTileFill,
          side: BorderSide(
            color: const Color(0xFFE65100).withValues(alpha: 0.45),
          ),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE65100),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
      break;
    case RoomColleStaleCandidatePreset.thirtyPlus:
      out.add(
        Chip(
          label: const Text('整理対象: 30日以上'),
          visualDensity: VisualDensity.compact,
          backgroundColor: HomeScreenColors.roomMetricTileFill,
          side: BorderSide(
            color: const Color(0xFFB71C1C).withValues(alpha: 0.45),
          ),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFB71C1C),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
      break;
  }
  return out;
}

/// 候補タブ：取得済URLフィルタON時のサマリーチップ（検索欄下のチップ列用）。
Chip _roomColleCandidateUrlOnlySummaryChip(VoidCallback onDeleted) {
  return Chip(
    avatar: Icon(
      Icons.link_rounded,
      size: 16,
      color: HomeScreenColors.metricRoleCandidateIcon,
    ),
    label: Text(
      '取得済URLのみ',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: HomeScreenColors.metricTileTitleColor,
      ),
    ),
    deleteIcon: Icon(
      Icons.close_rounded,
      size: 16,
      color: HomeScreenColors.leadOnSection,
    ),
    onDeleted: onDeleted,
    visualDensity: VisualDensity.compact,
    backgroundColor: HomeScreenColors.roomMetricTileFill,
    side: BorderSide(color: HomeScreenColors.metricRoleCandidateIcon),
    padding: const EdgeInsets.symmetric(horizontal: 6),
  );
}

/// 絞り込みシートの適用結果。[includesCandidateUrlOption] が false のときは
/// [candidateExcludeUrlNotReady] を親で無視する（コレ済タブ用シート）。
class _RoomColleFilterSheetApplyResult {
  const _RoomColleFilterSheetApplyResult({
    required this.criteria,
    required this.candidateExcludeUrlNotReady,
    required this.includesCandidateUrlOption,
  });

  final RoomColleListFilterCriteria criteria;
  final bool candidateExcludeUrlNotReady;
  final bool includesCandidateUrlOption;
}

/// キーワード以外の条件をボトムシートで編集。キーワードは [initial] に含め親が保持する。
/// 候補タブ（[isCandidateTab]）では ROOM用URLの絞り込みを同シート内に配置する。
class _RoomColleFilterEditorSheet extends StatefulWidget {
  const _RoomColleFilterEditorSheet({
    required this.sectionTitle,
    required this.initial,
    required this.genreIds,
    required this.isCandidateTab,
    this.initialExcludeUrlNotReady = false,
  });

  final String sectionTitle;
  final RoomColleListFilterCriteria initial;
  final List<String> genreIds;
  final bool isCandidateTab;
  final bool initialExcludeUrlNotReady;

  @override
  State<_RoomColleFilterEditorSheet> createState() =>
      _RoomColleFilterEditorSheetState();
}

class _RoomColleFilterEditorSheetState
    extends State<_RoomColleFilterEditorSheet> {
  late RoomColleRegisteredDatePreset _preset;
  late RoomColleStaleCandidatePreset _staleCandidateDraft;
  String? _genreId;
  late final TextEditingController _minPriceCtrl;
  late final TextEditingController _maxPriceCtrl;
  late bool _excludeUrlNotReadyDraft;

  @override
  void initState() {
    super.initState();
    _preset = widget.initial.registeredDatePreset;
    _staleCandidateDraft = widget.isCandidateTab
        ? widget.initial.staleCandidatePreset
        : RoomColleStaleCandidatePreset.none;
    final g = widget.initial.genreId?.trim();
    _genreId = (g != null && g.isNotEmpty) ? g : null;
    _minPriceCtrl = TextEditingController(
      text: widget.initial.priceMinYen?.toString() ?? '',
    );
    _maxPriceCtrl = TextEditingController(
      text: widget.initial.priceMaxYen?.toString() ?? '',
    );
    _excludeUrlNotReadyDraft = widget.isCandidateTab
        ? widget.initialExcludeUrlNotReady
        : false;
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  void _resetDraftExtended() {
    setState(() {
      _preset = RoomColleRegisteredDatePreset.all;
      _staleCandidateDraft = RoomColleStaleCandidatePreset.none;
      _genreId = null;
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
      if (widget.isCandidateTab) {
        _excludeUrlNotReadyDraft = false;
      }
    });
  }

  int? _tryParseYenField(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  void _apply() {
    var minY = _tryParseYenField(_minPriceCtrl);
    var maxY = _tryParseYenField(_maxPriceCtrl);
    if ((_minPriceCtrl.text.trim().isNotEmpty && minY == null) ||
        (_maxPriceCtrl.text.trim().isNotEmpty && maxY == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('価格は数値で入力してください')));
      return;
    }
    if (minY != null && maxY != null && minY > maxY) {
      final t = minY;
      minY = maxY;
      maxY = t;
    }
    final merged = widget.initial.copyWith(
      registeredDatePreset: _preset,
      staleCandidatePreset: widget.isCandidateTab
          ? _staleCandidateDraft
          : RoomColleStaleCandidatePreset.none,
      genreId: _genreId,
      clearGenreId: _genreId == null || _genreId!.isEmpty,
      priceMinYen: minY,
      priceMaxYen: maxY,
      clearPriceMin: minY == null,
      clearPriceMax: maxY == null,
    );
    Navigator.of(context).pop(
      _RoomColleFilterSheetApplyResult(
        criteria: merged,
        candidateExcludeUrlNotReady: _excludeUrlNotReadyDraft,
        includesCandidateUrlOption: widget.isCandidateTab,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: HomeScreenColors.canvas,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          _kRoomListScreenPadH,
          12,
          _kRoomListScreenPadH,
          16 + bottomInset + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              widget.sectionTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: HomeScreenColors.accentSectionHeading,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isCandidateTab
                  ? 'キーワードは上部の検索欄を使います。登録日・ジャンル・価格に加え、コレ候補タブだけ有効な「ROOMのURL」条件もここで変更できます。'
                  : 'キーワードは上部の検索欄を使います。ここでは登録日・ジャンルID・価格帯のみ変えられます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: HomeScreenColors.groupedSectionBody,
                height: 1.35,
                fontSize: 12,
              ),
            ),
            if (widget.isCandidateTab) ...[
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    AppColors.accentLight.withValues(alpha: 0.12),
                    HomeScreenColors.roomContentWellFill,
                  ),
                  borderRadius: BorderRadius.circular(
                    _RoomColleUi.radiusSectionInner,
                  ),
                  border: Border.all(color: HomeScreenColors.deckOutline),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: HomeScreenColors.metricRoleCandidateIconBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '候補タブのみ',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: HomeScreenColors
                                        .metricRoleCandidateIcon,
                                    height: 1.15,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ROOMのURLで一覧を絞る',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: HomeScreenColors.accentSectionHeading,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'いま開けるROOM用URLがある候補だけ残します（コレ前の整理向け）。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HomeScreenColors.footnoteMuted,
                          fontSize: 11,
                          height: 1.32,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: HomeScreenColors.deckFill,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          splashColor: HomeScreenColors.inkAccentSplash,
                          highlightColor: HomeScreenColors.inkAccentHighlight,
                          onTap: () => setState(
                            () => _excludeUrlNotReadyDraft =
                                !_excludeUrlNotReadyDraft,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  size: 20,
                                  color: HomeScreenColors.statusAccentStrong,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '取得済URLのみ',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: _excludeUrlNotReadyDraft
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          fontSize: 14,
                                          color: _excludeUrlNotReadyDraft
                                              ? HomeScreenColors
                                                    .accentSectionHeading
                                              : HomeScreenColors.titlePrimary,
                                        ),
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _excludeUrlNotReadyDraft,
                                  onChanged: (v) => setState(
                                    () => _excludeUrlNotReadyDraft = v,
                                  ),
                                  activeTrackColor: AppColors.accentPrimary
                                      .withValues(alpha: 0.38),
                                  activeThumbColor: AppColors.accentPrimary,
                                  inactiveTrackColor: AppColors.divider
                                      .withValues(alpha: 0.65),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (widget.isCandidateTab) ...[
              const SizedBox(height: 16),
              Text(
                '古い候補を整理',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: HomeScreenColors.leadOnSection,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '整理対象の経過日数で絞り込み（他の条件と併用可。候補タブの一覧のみに効きます）。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HomeScreenColors.footnoteMuted,
                  fontSize: 11,
                  height: 1.32,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: _RoomColleUi.chipSpacing,
                runSpacing: _RoomColleUi.chipSpacing,
                children: [
                  FilterChip(
                    label: const Text('3日以上'),
                    selected:
                        _staleCandidateDraft ==
                        RoomColleStaleCandidatePreset.threePlus,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        _staleCandidateDraft =
                            _staleCandidateDraft ==
                                RoomColleStaleCandidatePreset.threePlus
                            ? RoomColleStaleCandidatePreset.none
                            : RoomColleStaleCandidatePreset.threePlus;
                      });
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  FilterChip(
                    label: const Text('7日以上'),
                    selected:
                        _staleCandidateDraft ==
                        RoomColleStaleCandidatePreset.sevenPlus,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        _staleCandidateDraft =
                            _staleCandidateDraft ==
                                RoomColleStaleCandidatePreset.sevenPlus
                            ? RoomColleStaleCandidatePreset.none
                            : RoomColleStaleCandidatePreset.sevenPlus;
                      });
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  FilterChip(
                    label: const Text('30日以上'),
                    selected:
                        _staleCandidateDraft ==
                        RoomColleStaleCandidatePreset.thirtyPlus,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        _staleCandidateDraft =
                            _staleCandidateDraft ==
                                RoomColleStaleCandidatePreset.thirtyPlus
                            ? RoomColleStaleCandidatePreset.none
                            : RoomColleStaleCandidatePreset.thirtyPlus;
                      });
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '登録日（端末に保存した日）',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: HomeScreenColors.leadOnSection,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<RoomColleRegisteredDatePreset>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<RoomColleRegisteredDatePreset>>[
                ButtonSegment<RoomColleRegisteredDatePreset>(
                  value: RoomColleRegisteredDatePreset.all,
                  label: Text('すべて'),
                ),
                ButtonSegment<RoomColleRegisteredDatePreset>(
                  value: RoomColleRegisteredDatePreset.today,
                  label: Text('今日'),
                ),
                ButtonSegment<RoomColleRegisteredDatePreset>(
                  value: RoomColleRegisteredDatePreset.last7Days,
                  label: Text('7日'),
                ),
              ],
              selected: <RoomColleRegisteredDatePreset>{_preset},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                setState(() => _preset = selection.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.standard,
                tapTargetSize: MaterialTapTargetSize.padded,
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'ジャンル（楽天 genreId）',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: HomeScreenColors.leadOnSection,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '一覧にないIDは出ません。名称はアプリ内マスタで引き、未登録IDは「未分類」と表示されます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: HomeScreenColors.footnoteMuted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final choices = List<String>.of(widget.genreIds);
                final gCur = _genreId;
                if (gCur != null &&
                    gCur.isNotEmpty &&
                    !choices.contains(gCur)) {
                  choices.add(gCur);
                }
                choices.sort();
                final effectiveGenre = gCur != null && choices.contains(gCur)
                    ? gCur
                    : null;
                return InputDecorator(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: HomeScreenColors.deckFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: HomeScreenColors.deckOutline,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: HomeScreenColors.deckOutline,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: effectiveGenre,
                      isExpanded: true,
                      isDense: true,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('指定なし'),
                        ),
                        ...choices.map(
                          (id) => DropdownMenuItem<String?>(
                            value: id,
                            child: Text(
                              _roomColleGenreFilterMenuText(id),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _genreId = v),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              '価格帯（税込 itemPrice・円）',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: HomeScreenColors.leadOnSection,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '下限',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  child: Text('〜'),
                ),
                Expanded(
                  child: TextField(
                    controller: _maxPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '上限',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(onPressed: _apply, child: const Text('この条件を適用')),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _resetDraftExtended,
              child: const Text('シート内の条件をリセット'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 同一 productId の重複は先勝ち（GlobalKey 衝突・描画クラッシュ防止）。
List<RakutenManagedProduct> _dedupeManagedProductsPreserveOrder(
  List<RakutenManagedProduct> items,
) {
  final seen = <String>{};
  final out = <RakutenManagedProduct>[];
  for (final e in items) {
    final id = e.productId.trim();
    if (id.isEmpty || seen.contains(id)) continue;
    seen.add(id);
    out.add(e);
  }
  return out;
}

/// コレ済の暦日フィルタを安全なローカル日付に正規化（不正値は null）。
DateTime? _normalizeDoneDayFilter(DateTime? raw) {
  if (raw == null) return null;
  try {
    final y = raw.year;
    if (y < 1900 || y > 2100) return null;
    return DateTime(raw.year, raw.month, raw.day);
  } catch (_) {
    return null;
  }
}

/// 一覧タブと同じ管線で表示リストを求める（URL未取得除外はコレ候補タブのみ適用）。
List<RakutenManagedProduct> _roomListVisibleItems({
  required RakutenManagedProductProvider provider,
  required RakutenManagedProductStatus status,
  required RoomColleListFilterCriteria listFilters,
  required bool excludeUrlNotReady,
  DateTime? doneAtLocalDayFilter,
}) {
  final baseList = provider.sortedItemsForStatus(status);
  final day = doneAtLocalDayFilter;
  final scoped = status == RakutenManagedProductStatus.done && day != null
      ? _filterDoneOnLocalCalendarDay(baseList, day)
      : baseList;
  final urlActive =
      status == RakutenManagedProductStatus.candidate && excludeUrlNotReady;
  final urlScoped = _filterExcludeUrlNotReady(scoped, urlActive);
  final queried = applyRoomColleListFilters(urlScoped, listFilters);
  final deduped = _dedupeManagedProductsPreserveOrder(queried);
  if (deduped.isEmpty && baseList.isNotEmpty) {
    final urlHidAll =
        status == RakutenManagedProductStatus.candidate &&
        excludeUrlNotReady &&
        scoped.isNotEmpty &&
        _filterExcludeUrlNotReady(scoped, true).isEmpty;
    final reducingActive = listFilters.hasAnyReducingFilter;
    final searchHidAll = reducingActive && scoped.isNotEmpty;
    if (!urlHidAll && !searchHidAll) {
      final rawScoped =
          status == RakutenManagedProductStatus.done && day != null
          ? _filterDoneOnLocalCalendarDay(baseList, day)
          : baseList;
      final fallback = _dedupeManagedProductsPreserveOrder(rawScoped);
      if (fallback.isNotEmpty) return fallback;
    }
  }
  return deduped;
}

/// タブ表示件数を [_roomListVisibleItems] に揃える。
int _roomColleVisibleCount({
  required RakutenManagedProductProvider provider,
  required RakutenManagedProductStatus status,
  required RoomColleListFilterCriteria listFilters,
  required bool excludeUrlNotReady,
  DateTime? doneAtLocalDayFilter,
}) {
  return _roomListVisibleItems(
    provider: provider,
    status: status,
    listFilters: listFilters,
    excludeUrlNotReady: excludeUrlNotReady,
    doneAtLocalDayFilter: doneAtLocalDayFilter,
  ).length;
}

/// [anchor] のローカル暦日と同一日の [doneAt] をもつコレ済のみ。
List<RakutenManagedProduct> _filterDoneOnLocalCalendarDay(
  List<RakutenManagedProduct> items,
  DateTime anchor,
) {
  try {
    final target = DateTime(anchor.year, anchor.month, anchor.day);
    return items.where((e) {
      final d = e.doneAt;
      if (d == null) return false;
      try {
        final localDay = DateTime(d.year, d.month, d.day);
        return localDay == target;
      } catch (_) {
        return false;
      }
    }).toList();
  } catch (_) {
    return <RakutenManagedProduct>[];
  }
}

/// ON のとき、URL が取得済みで開ける商品だけ残す（コレ前の絞り込み用）。
List<RakutenManagedProduct> _filterExcludeUrlNotReady(
  List<RakutenManagedProduct> items,
  bool enabled,
) {
  if (!enabled) return items;
  return items.where((e) {
    if (e.extractionStatus != RakutenUrlExtractionStatus.success) {
      return false;
    }
    return e.extractedUrl.trim().isNotEmpty ||
        e.affiliateUrl.trim().isNotEmpty ||
        e.itemUrl.trim().isNotEmpty;
  }).toList();
}

/// 各タブ一覧エリアの表面状態（読込 / 表示成功の内訳 / 失敗）。デバッグは [debugLabel]。
enum _RoomColleListSurface {
  loading,
  loadError,
  readyEmptyNoData,
  readyEmptyFilteredByDay,
  readyEmptyFilteredByUrl,
  readyEmptyFilteredBySearch,
  readyEmptyAnomaly,
  readyList,
}

extension on _RoomColleListSurface {
  String get debugLabel {
    switch (this) {
      case _RoomColleListSurface.loading:
        return 'loading';
      case _RoomColleListSurface.loadError:
        return 'load_error';
      case _RoomColleListSurface.readyEmptyNoData:
        return 'ok_empty_no_data';
      case _RoomColleListSurface.readyEmptyFilteredByDay:
        return 'ok_empty_filter_day';
      case _RoomColleListSurface.readyEmptyFilteredByUrl:
        return 'ok_empty_filter_url';
      case _RoomColleListSurface.readyEmptyFilteredBySearch:
        return 'ok_empty_filter_search';
      case _RoomColleListSurface.readyEmptyAnomaly:
        return 'ok_empty_anomaly';
      case _RoomColleListSurface.readyList:
        return 'ok_list';
    }
  }
}

/// [idle] / [ready] はここでは表示可能として扱い、[loading] / [error] と 0件の内訳を返す。
_RoomColleListSurface _resolveRoomColleListSurface({
  required RakutenManagedProductListUiStatus ui,
  required List<RakutenManagedProduct> baseList,
  required List<RakutenManagedProduct> scoped,
  required List<RakutenManagedProduct> list,
  required List<RakutenManagedProduct> urlScoped,
  required bool urlActive,
  required RoomColleListFilterCriteria listFilters,
  required bool hasDayFilter,
  required bool canShowDayEmptyMessage,
}) {
  if (ui == RakutenManagedProductListUiStatus.loading) {
    return _RoomColleListSurface.loading;
  }
  if (ui == RakutenManagedProductListUiStatus.error) {
    return _RoomColleListSurface.loadError;
  }

  if (baseList.isEmpty) {
    return _RoomColleListSurface.readyEmptyNoData;
  }

  if (hasDayFilter && scoped.isEmpty && canShowDayEmptyMessage) {
    return _RoomColleListSurface.readyEmptyFilteredByDay;
  }

  if (list.isEmpty) {
    if (urlActive && scoped.isNotEmpty && urlScoped.isEmpty) {
      return _RoomColleListSurface.readyEmptyFilteredByUrl;
    }
    if (scoped.isNotEmpty && listFilters.hasAnyReducingFilter) {
      return _RoomColleListSurface.readyEmptyFilteredBySearch;
    }
    return _RoomColleListSurface.readyEmptyAnomaly;
  }

  return _RoomColleListSurface.readyList;
}

Widget _roomColleRefreshableScroll(
  RakutenManagedProductProvider provider, {
  required Widget child,
}) {
  return RefreshIndicator(
    onRefresh: () =>
        provider.refreshManagedProductList(showLoadingIndicator: true),
    child: child,
  );
}

/// ROOMコレ管理画面。楽天検索で登録したコレ候補・コレ済をタブで表示する。
class ProductsPlaceholderScreen extends StatefulWidget {
  const ProductsPlaceholderScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialDoneFilterLocalDay,
    this.initialFocusCandidateProductId,
  });

  /// 0: コレ候補、1: コレ済
  final int initialTabIndex;

  /// 指定したローカル暦日に [doneAt] があるコレ済のみ表示（コレ済タブ向け）。
  final DateTime? initialDoneFilterLocalDay;

  /// コレ候補タブで、この商品IDの行へスクロールし、約1秒ハイライトする。
  final String? initialFocusCandidateProductId;

  @override
  State<ProductsPlaceholderScreen> createState() =>
      _ProductsPlaceholderScreenState();
}

class _ProductsPlaceholderScreenState extends State<ProductsPlaceholderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _candidateSearchController;
  late final TextEditingController _doneSearchController;
  final ScrollController _candidateScrollController = ScrollController();
  final Map<String, GlobalKey> _candidateRowKeys = <String, GlobalKey>{};
  // 一覧絞り込み（キーワード＋拡張条件）。永続化は [RoomColleUiStateSnapshot] 経由。
  RoomColleListFilterCriteria _candidateListFilters =
      RoomColleListFilterCriteria.defaults;
  RoomColleListFilterCriteria _doneListFilters =
      RoomColleListFilterCriteria.defaults;
  DateTime? _doneLocalDayFilter;
  Timer? _flashTimer;
  String? _flashProductId;
  bool _candidateFocusHandled = false;
  String? _shellFocusCandidateProductId;
  late final AppShellController _shellCtrl;
  late final RoomColleUiStateRepository _roomColleUiRepo;
  bool _candidateExcludeUrlNotReady = false;

  /// [RoomColleUiStateSnapshot.staleCandidatePileBannerDismissed] と同期。
  bool _stalePileBannerDismissed = false;
  Timer? _persistSearchDebounce;

  String? get _focusCandidateTargetId {
    final w = widget.initialFocusCandidateProductId;
    if (w != null && w.isNotEmpty) return w;
    final s = _shellFocusCandidateProductId;
    if (s != null && s.isNotEmpty) return s;
    return null;
  }

  GlobalKey _keyForCandidateRow(String productId) =>
      _candidateRowKeys.putIfAbsent(productId, GlobalKey.new);

  void _onCandidateFocusListReady() {
    if (_candidateFocusHandled) return;
    final id = _focusCandidateTargetId;
    if (id == null || id.isEmpty) return;
    _candidateFocusHandled = true;
    setState(() => _shellFocusCandidateProductId = null);
    _runScrollToCandidate(id, 0);
  }

  void _onCandidateFocusProductMissing() {
    if (_candidateFocusHandled) return;
    _candidateFocusHandled = true;
    setState(() => _shellFocusCandidateProductId = null);
  }

  void _runScrollToCandidate(String productId, int attempt) {
    if (!mounted || attempt > 16) return;
    // コレ済タブ表示中やレイアウト中に ensureVisible すると sliver 整合が崩れる。
    // 候補タブ選択時のみ、2フレーム後に実行する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tabController.index != 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tabController.index != 0) return;
        final ctx = _candidateRowKeys[productId]?.currentContext;
        if (ctx == null) {
          _runScrollToCandidate(productId, attempt + 1);
          return;
        }
        final ro = ctx.findRenderObject();
        if (ro is! RenderBox || !ro.hasSize || !ro.attached) {
          _runScrollToCandidate(productId, attempt + 1);
          return;
        }
        try {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.12,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        } catch (e, st) {
          assert(() {
            debugPrint('[ROOMコレ] ensureVisible 失敗: $e\n$st');
            return true;
          }());
        }
        if (!mounted || _tabController.index != 0) return;
        setState(() => _flashProductId = productId);
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) setState(() => _flashProductId = null);
        });
      });
    });
  }

  void _setCandidateStalePreset(RoomColleStaleCandidatePreset v) {
    if (!mounted) return;
    setState(() {
      _candidateListFilters = _candidateListFilters.copyWith(
        staleCandidatePreset: v,
      );
    });
    _persistRoomColleUiNow();
  }

  void _resetRoomColleFilters() {
    if (!mounted) return;
    _persistSearchDebounce?.cancel();
    setState(() {
      _candidateExcludeUrlNotReady = false;
      _candidateListFilters = RoomColleListFilterCriteria.defaults;
      _doneListFilters = RoomColleListFilterCriteria.defaults;
      _candidateSearchController.clear();
      _doneSearchController.clear();
      _doneLocalDayFilter = null;
      _stalePileBannerDismissed = false;
    });
    _persistRoomColleUiNow();
  }

  RoomColleUiStateSnapshot _snapshotForPersist() {
    return RoomColleUiStateSnapshot(
      tabIndex: _tabController.index.clamp(0, 1),
      candidateListFilters: _candidateListFilters,
      doneListFilters: _doneListFilters,
      candidateExcludeUrlNotReady: _candidateExcludeUrlNotReady,
      doneLocalDay: _doneLocalDayFilter,
      staleCandidatePileBannerDismissed: _stalePileBannerDismissed,
    );
  }

  Future<void> _openRoomColleFilterEditor({required bool isCandidate}) async {
    final managed = context.read<RakutenManagedProductProvider>();
    final status = isCandidate
        ? RakutenManagedProductStatus.candidate
        : RakutenManagedProductStatus.done;
    final base = managed.sortedItemsForStatus(status);
    final genreIds = _roomColleDistinctGenreIds(base);
    final current = isCandidate ? _candidateListFilters : _doneListFilters;
    final title = isCandidate ? '候補一覧の条件（キーワード以外）' : 'コレ済一覧の条件（キーワード以外）';
    final result = await showModalBottomSheet<_RoomColleFilterSheetApplyResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _RoomColleFilterEditorSheet(
        sectionTitle: title,
        initial: current,
        genreIds: genreIds,
        isCandidateTab: isCandidate,
        initialExcludeUrlNotReady: isCandidate
            ? _candidateExcludeUrlNotReady
            : false,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (isCandidate) {
        _candidateListFilters = result.criteria;
        if (result.includesCandidateUrlOption) {
          _candidateExcludeUrlNotReady = result.candidateExcludeUrlNotReady;
        }
      } else {
        _doneListFilters = result.criteria;
      }
    });
    _persistRoomColleUiNow();
  }

  void _persistRoomColleUiNow() {
    unawaited(_roomColleUiRepo.saveSanitized(_snapshotForPersist()));
  }

  void _schedulePersistRoomColleSearch() {
    _persistSearchDebounce?.cancel();
    _persistSearchDebounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      _persistRoomColleUiNow();
    });
  }

  int _resolveInitialTabIndex(RoomColleUiStateSnapshot persisted) {
    if (widget.initialTabIndex != 0) {
      return widget.initialTabIndex.clamp(0, 1);
    }
    return persisted.tabIndex.clamp(0, 1);
  }

  Future<void> _recoverRoomColleListAndFilters() async {
    if (!mounted) return;
    if (kDebugMode) {
      debugPrint('[ROOMコレ] recover: filters + list UI (user)');
    }
    _persistSearchDebounce?.cancel();
    setState(() {
      _candidateExcludeUrlNotReady = false;
      _candidateListFilters = RoomColleListFilterCriteria.defaults;
      _doneListFilters = RoomColleListFilterCriteria.defaults;
      _candidateSearchController.clear();
      _doneSearchController.clear();
      _doneLocalDayFilter = null;
    });
    await _roomColleUiRepo.clearPersisted();
    await _roomColleUiRepo.saveSanitized(RoomColleUiStateSnapshot.defaults);
    if (!mounted) return;
    final managed = context.read<RakutenManagedProductProvider>();
    managed.recoverListUiSilently();
    await managed.refreshManagedProductList(showLoadingIndicator: true);
  }

  @override
  void initState() {
    super.initState();
    _candidateSearchController = TextEditingController();
    _doneSearchController = TextEditingController();
    _roomColleUiRepo = context.read<RoomColleUiStateRepository>();
    final persisted = _roomColleUiRepo.loadSanitized();

    if (_roomColleScreenHasExplicitRouteArgs(widget)) {
      _doneLocalDayFilter = _normalizeDoneDayFilter(
        widget.initialDoneFilterLocalDay,
      );
    } else {
      _candidateListFilters = persisted.candidateListFilters;
      _candidateSearchController.text = persisted.candidateListFilters.keyword;
      _doneListFilters = persisted.doneListFilters;
      _doneSearchController.text = persisted.doneListFilters.keyword;
      _candidateExcludeUrlNotReady = persisted.candidateExcludeUrlNotReady;
      _doneLocalDayFilter = _normalizeDoneDayFilter(persisted.doneLocalDay);
    }
    _stalePileBannerDismissed = persisted.staleCandidatePileBannerDismissed;

    final focusId = widget.initialFocusCandidateProductId;
    final idx0 = widget.initialTabIndex.clamp(0, 1);
    if (focusId != null && focusId.isNotEmpty && idx0 == 0) {
      _candidateSearchController.clear();
      _candidateListFilters = _candidateListFilters.copyWith(keyword: '');
    }
    final initialIndex = _resolveInitialTabIndex(persisted);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (mounted) {
        setState(() {});
        _persistRoomColleUiNow();
      }
    });
    _shellCtrl = context.read<AppShellController>();
    _shellCtrl.addListener(_onShellCtrlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final managed = context.read<RakutenManagedProductProvider>();
      if (managed.listUiStatus == RakutenManagedProductListUiStatus.error) {
        if (kDebugMode) {
          debugPrint('[ROOMコレ] init_post_frame: recover list UI from error');
        }
        managed.recoverListUiSilently();
      }
      _tryConsumeRoomCollectIntent();
      await managed.refreshManagedProductList(showLoadingIndicator: false);
      if (!mounted) return;
      if (kDebugMode) {
        final m = context.read<RakutenManagedProductProvider>();
        final nCand = m
            .sortedItemsForStatus(RakutenManagedProductStatus.candidate)
            .length;
        final nDone = m
            .sortedItemsForStatus(RakutenManagedProductStatus.done)
            .length;
        debugPrint(
          '[ROOMコレ診断] ROOMコレ画面起動後 total=${m.items.length} candidate=$nCand '
          'done=$nDone listUi=${m.listUiStatus} tabIdx=${_tabController.index}',
        );
      }
    });
  }

  void _onShellCtrlChanged() {
    if (!mounted) return;
    // IndexedStack 維持のため initState は1回のみ。タブ再表示時に一覧とエラー状態を復旧する。
    if (_shellCtrl.currentIndex == 1) {
      final managed = context.read<RakutenManagedProductProvider>();
      if (managed.listUiStatus == RakutenManagedProductListUiStatus.error) {
        if (kDebugMode) {
          debugPrint('[ROOMコレ] shell_tab_focus: recover list UI from error');
        }
        managed.recoverListUiSilently();
      }
      _tryConsumeRoomCollectIntent();
      managed.refreshManagedProductList(showLoadingIndicator: false);
    } else {
      _tryConsumeRoomCollectIntent();
    }
  }

  /// ホーム等からの [openRoomCollect] のインテントのみ消費する。
  /// 適用は次フレームへ逃がし、シェル通知中の同期的 setState 連鎖を避ける。
  void _tryConsumeRoomCollectIntent() {
    if (!mounted) return;
    final intent = _shellCtrl.takePendingRoomCollectIntent();
    if (intent == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyRoomCollectIntent(intent);
    });
  }

  void _applyRoomCollectIntent(RoomCollectNavigationIntent intent) {
    final idx = intent.initialTabIndex.clamp(0, 1);
    var focusRaw = intent.focusCandidateProductId?.trim();
    if (focusRaw != null && focusRaw.isEmpty) focusRaw = null;
    final focusId = (focusRaw != null && focusRaw.isNotEmpty && idx == 0)
        ? focusRaw
        : null;

    _persistSearchDebounce?.cancel();
    final staleFromIntent = intent.candidateStalePreset;
    setState(() {
      _candidateExcludeUrlNotReady = false;
      _candidateSearchController.clear();
      _doneSearchController.clear();
      _candidateListFilters = RoomColleListFilterCriteria.defaults.copyWith(
        staleCandidatePreset:
            idx == 0 &&
                staleFromIntent != null &&
                staleFromIntent != RoomColleStaleCandidatePreset.none
            ? staleFromIntent
            : RoomColleStaleCandidatePreset.none,
      );
      _doneListFilters = RoomColleListFilterCriteria.defaults;
      if (idx == 0) {
        _doneLocalDayFilter = null;
      } else {
        _doneLocalDayFilter = _normalizeDoneDayFilter(
          intent.doneFilterLocalDay,
        );
      }
      _shellFocusCandidateProductId = focusId;
      _candidateFocusHandled = false;
    });

    if (_tabController.index != idx) {
      _tabController.animateTo(
        idx,
        duration: Duration.zero,
        curve: Curves.linear,
      );
    }
    _persistRoomColleUiNow();
  }

  @override
  void dispose() {
    _persistSearchDebounce?.cancel();
    _persistRoomColleUiNow();
    _shellCtrl.removeListener(_onShellCtrlChanged);
    _flashTimer?.cancel();
    _candidateScrollController.dispose();
    _tabController.dispose();
    _candidateSearchController.dispose();
    _doneSearchController.dispose();
    super.dispose();
  }

  InputDecoration _roomColleKeywordDecoration(BuildContext context) {
    return InputDecoration(
      hintText: 'キーワード検索',
      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        color: HomeScreenColors.footnoteMuted,
      ),
      isDense: true,
      filled: true,
      fillColor: HomeScreenColors.deckFill,
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 2, 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSearchBar),
        borderSide: BorderSide(color: HomeScreenColors.deckOutline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSearchBar),
        borderSide: BorderSide(color: HomeScreenColors.deckOutline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSearchBar),
        borderSide: BorderSide(
          color: AppColors.accentPrimary.withValues(alpha: 0.92),
          width: 1.5,
        ),
      ),
      suffixIcon: Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Icon(
          Icons.search_rounded,
          color: HomeScreenColors.leadOnSection,
          size: 22,
        ),
      ),
      suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: HomeScreenColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                _kRoomListScreenPadH,
                _RoomColleUi.gapSection,
                _kRoomListScreenPadH,
                0,
              ),
              child: DecoratedBox(
                decoration: _RoomColleUi.outerRoomShellDecoration(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    _RoomColleUi.radiusSectionOuter,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /// ① 主導線：楽天検索（候補を増やす）
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          _RoomColleUi.insetSectionH,
                          canPop
                              ? _RoomColleUi.chromeTopPadPop
                              : _RoomColleUi.chromeTopPadNoPop,
                          _RoomColleUi.insetSectionH,
                          2,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (canPop)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 4,
                                  top: 2,
                                ),
                                child: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 22,
                                  ),
                                  color: HomeScreenColors.titlePrimary,
                                  tooltip: '戻る',
                                ),
                              ),
                            Expanded(
                              child: HomePrimaryActionButton(
                                emphasis: HomePrimaryActionEmphasis.hero,
                                icon: Icons.travel_explore_rounded,
                                label: '楽天でコレ候補を検索する',
                                onPressed: () {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const RakutenSearchScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: HomeScreenColors.inlineDivider,
                      ),

                      /// ② タブ（キーワード・URL 除外は各タブ内の絞り込み領域へ）
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          _RoomColleUi.insetSectionH,
                          _RoomColleUi.tabDeckPad,
                          _RoomColleUi.insetSectionH,
                          _RoomColleUi.tabDeckBottom,
                        ),
                        child: DecoratedBox(
                          decoration: _RoomColleUi.tabInnerDeckDecoration(),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              _RoomColleUi.tabInnerPad,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Consumer<RakutenManagedProductProvider>(
                                    builder: (context, managed, _) {
                                      final nCand = _roomColleVisibleCount(
                                        provider: managed,
                                        status: RakutenManagedProductStatus
                                            .candidate,
                                        listFilters: _candidateListFilters,
                                        excludeUrlNotReady:
                                            _candidateExcludeUrlNotReady,
                                        doneAtLocalDayFilter: null,
                                      );
                                      final nDone = _roomColleVisibleCount(
                                        provider: managed,
                                        status:
                                            RakutenManagedProductStatus.done,
                                        listFilters: _doneListFilters,
                                        excludeUrlNotReady: false,
                                        doneAtLocalDayFilter:
                                            _doneLocalDayFilter,
                                      );
                                      final idx = _tabController.index;
                                      final selectedAccent = idx == 0
                                          ? RoomColleListAccent.candidate
                                          : RoomColleListAccent.done;
                                      final segmentShape =
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              _kRoomColleTabTrackRadius - 4,
                                            ),
                                          );
                                      return SegmentedButton<int>(
                                        showSelectedIcon: false,
                                        expandedInsets: EdgeInsets.zero,
                                        segments: <ButtonSegment<int>>[
                                          ButtonSegment<int>(
                                            value: 0,
                                            label: Text(
                                              'コレ候補 ($nCand)',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                            tooltip: 'コレ候補の一覧',
                                          ),
                                          ButtonSegment<int>(
                                            value: 1,
                                            label: Text(
                                              'コレ済 ($nDone)',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                            tooltip: 'コレ済の一覧',
                                          ),
                                        ],
                                        selected: <int>{_tabController.index},
                                        onSelectionChanged:
                                            (Set<int> selection) {
                                              if (selection.isEmpty) return;
                                              final v = selection.first;
                                              if (v != _tabController.index) {
                                                _tabController.animateTo(v);
                                              }
                                            },
                                        style: ButtonStyle(
                                          visualDensity: VisualDensity.standard,
                                          tapTargetSize:
                                              MaterialTapTargetSize.padded,
                                          minimumSize: WidgetStateProperty.all(
                                            const Size(48, 46),
                                          ),
                                          side: WidgetStateProperty.resolveWith(
                                            (states) {
                                              if (states.contains(
                                                WidgetState.selected,
                                              )) {
                                                return BorderSide(
                                                  color: selectedAccent,
                                                  width: 1.75,
                                                );
                                              }
                                              return BorderSide(
                                                color: HomeScreenColors
                                                    .deckOutline,
                                              );
                                            },
                                          ),
                                          padding: WidgetStateProperty.all(
                                            const EdgeInsets.symmetric(
                                              vertical: 10,
                                              horizontal: 10,
                                            ),
                                          ),
                                          shape: WidgetStateProperty.all(
                                            segmentShape,
                                          ),
                                          foregroundColor:
                                              WidgetStateProperty.resolveWith((
                                                states,
                                              ) {
                                                if (states.contains(
                                                  WidgetState.selected,
                                                )) {
                                                  return selectedAccent;
                                                }
                                                return HomeScreenColors
                                                    .leadOnSection;
                                              }),
                                          backgroundColor:
                                              WidgetStateProperty.resolveWith((
                                                states,
                                              ) {
                                                if (states.contains(
                                                  WidgetState.selected,
                                                )) {
                                                  return selectedAccent
                                                      .withValues(alpha: 0.18);
                                                }
                                                return HomeScreenColors
                                                    .deckFill;
                                              }),
                                          textStyle:
                                              WidgetStateProperty.resolveWith((
                                                states,
                                              ) {
                                                final base = Theme.of(
                                                  context,
                                                ).textTheme.labelLarge;
                                                final selected = states
                                                    .contains(
                                                      WidgetState.selected,
                                                    );
                                                return base?.copyWith(
                                                  fontSize: 14,
                                                  fontWeight: selected
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  height: 1.2,
                                                  letterSpacing: selected
                                                      ? 0.15
                                                      : 0,
                                                );
                                              }),
                                          overlayColor:
                                              WidgetStateProperty.resolveWith((
                                                states,
                                              ) {
                                                if (states.contains(
                                                  WidgetState.selected,
                                                )) {
                                                  return selectedAccent
                                                      .withValues(alpha: 0.1);
                                                }
                                                return HomeScreenColors
                                                    .inkNeutralSplash;
                                              }),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: _RoomColleUi.gapSection),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Consumer<RakutenManagedProductProvider>(
                        builder: (context, managed, _) {
                          final pile = _roomColleStale7PlusCandidateCount(
                            managed,
                          );
                          if (pile < 5 && _stalePileBannerDismissed) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted || !_stalePileBannerDismissed) {
                                return;
                              }
                              setState(() => _stalePileBannerDismissed = false);
                              _persistRoomColleUiNow();
                            });
                          }
                          if (pile < 5 || _stalePileBannerDismissed) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              _kRoomListScreenPadH,
                              0,
                              _kRoomListScreenPadH,
                              _RoomColleUi.gapFieldStack,
                            ),
                            child: _RoomColleStalePileNoticeBar(
                              onDismiss: () {
                                setState(
                                  () => _stalePileBannerDismissed = true,
                                );
                                _persistRoomColleUiNow();
                              },
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _kRoomListScreenPadH,
                        ),
                        child: _RoomColleFilterShell(
                          title: '候補の絞り込み',
                          icon: Icons.filter_alt_outlined,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _candidateSearchController,
                                onChanged: (v) {
                                  if (!mounted) return;
                                  setState(
                                    () => _candidateListFilters =
                                        _candidateListFilters.copyWith(
                                          keyword: v,
                                        ),
                                  );
                                  _schedulePersistRoomColleSearch();
                                },
                                textInputAction: TextInputAction.search,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontSize: 14,
                                      height: 1.22,
                                      color: HomeScreenColors.titlePrimary,
                                    ),
                                decoration: _roomColleKeywordDecoration(
                                  context,
                                ),
                              ),
                              SizedBox(
                                height: _RoomColleUi.gapKeywordToFilterRow,
                              ),
                              _RoomColleStaleOrganizeQuickRow(
                                preset:
                                    _candidateListFilters.staleCandidatePreset,
                                onPresetChanged: _setCandidateStalePreset,
                              ),
                              SizedBox(height: _RoomColleUi.gapFieldStack),
                              _RoomColleInlineMoreFiltersRow(
                                onOpenMoreFilters: () =>
                                    _openRoomColleFilterEditor(
                                      isCandidate: true,
                                    ),
                                hasNonKeywordConstraintsBadge:
                                    _candidateListFilters
                                        .hasNonKeywordConstraints,
                                candidateUrlFilterActive:
                                    _candidateExcludeUrlNotReady,
                                onClear: _resetRoomColleFilters,
                              ),
                              Builder(
                                builder: (context) {
                                  final chips = _roomColleFilterSummaryChips(
                                    _candidateListFilters,
                                  );
                                  if (_candidateExcludeUrlNotReady) {
                                    chips.add(
                                      _roomColleCandidateUrlOnlySummaryChip(() {
                                        if (!mounted) return;
                                        setState(
                                          () => _candidateExcludeUrlNotReady =
                                              false,
                                        );
                                        _persistRoomColleUiNow();
                                      }),
                                    );
                                  }
                                  if (chips.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        height: _RoomColleUi.gapFieldStack,
                                      ),
                                      Wrap(
                                        spacing: _RoomColleUi.chipSpacing,
                                        runSpacing: _RoomColleUi.chipSpacing,
                                        children: chips,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: _RoomColleUi.gapAfterFilterShell),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _kRoomListScreenPadH,
                        ),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: HomeScreenColors.inlineDivider,
                        ),
                      ),
                      SizedBox(height: _RoomColleUi.gapListAfterDivider),
                      Expanded(
                        child: _RoomManagedProductListTab(
                          status: RakutenManagedProductStatus.candidate,
                          variant: RakutenManagedProductCardVariant.candidate,
                          listFilters: _candidateListFilters,
                          excludeUrlNotReady: _candidateExcludeUrlNotReady,
                          candidateFocusHandled: _candidateFocusHandled,
                          onRecoverFromListError:
                              _recoverRoomColleListAndFilters,
                          emptyTitle: 'コレ候補はまだありません',
                          emptySubtitle: '保存データでは、このタブに該当する商品はまだありません。',
                          emptyHint: '',
                          accentColor: RoomColleListAccent.candidate,
                          listScrollController: _candidateScrollController,
                          flashHighlightProductId: _flashProductId,
                          rowKeyFor: _keyForCandidateRow,
                          focusCandidateProductId: _focusCandidateTargetId,
                          onCandidateFocusListReady:
                              _focusCandidateTargetId != null &&
                                  _focusCandidateTargetId!.isNotEmpty
                              ? _onCandidateFocusListReady
                              : null,
                          onCandidateFocusProductMissing:
                              _focusCandidateTargetId != null &&
                                  _focusCandidateTargetId!.isNotEmpty
                              ? _onCandidateFocusProductMissing
                              : null,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _kRoomListScreenPadH,
                        ),
                        child: _RoomColleFilterShell(
                          title: 'コレ済の絞り込み',
                          icon: Icons.task_alt_outlined,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _doneSearchController,
                                onChanged: (v) {
                                  if (!mounted) return;
                                  setState(
                                    () => _doneListFilters = _doneListFilters
                                        .copyWith(keyword: v),
                                  );
                                  _schedulePersistRoomColleSearch();
                                },
                                textInputAction: TextInputAction.search,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontSize: 14,
                                      height: 1.22,
                                      color: HomeScreenColors.titlePrimary,
                                    ),
                                decoration: _roomColleKeywordDecoration(
                                  context,
                                ),
                              ),
                              SizedBox(
                                height: _RoomColleUi.gapKeywordToFilterRow,
                              ),
                              _RoomColleInlineMoreFiltersRow(
                                onOpenMoreFilters: () =>
                                    _openRoomColleFilterEditor(
                                      isCandidate: false,
                                    ),
                                hasNonKeywordConstraintsBadge:
                                    _doneListFilters.hasNonKeywordConstraints,
                                onClear: _resetRoomColleFilters,
                              ),
                              if (_doneListFilters
                                  .hasNonKeywordConstraints) ...[
                                SizedBox(height: _RoomColleUi.gapFieldStack),
                                Wrap(
                                  spacing: _RoomColleUi.chipSpacing,
                                  runSpacing: _RoomColleUi.chipSpacing,
                                  children: _roomColleFilterSummaryChips(
                                    _doneListFilters,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: _RoomColleUi.gapAfterFilterShell),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _kRoomListScreenPadH,
                        ),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: HomeScreenColors.inlineDivider,
                        ),
                      ),
                      SizedBox(height: _RoomColleUi.gapListAfterDivider),
                      Expanded(
                        child: _RoomManagedProductListTab(
                          status: RakutenManagedProductStatus.done,
                          variant: RakutenManagedProductCardVariant.done,
                          listFilters: _doneListFilters,
                          excludeUrlNotReady: false,
                          candidateFocusHandled: true,
                          onRecoverFromListError:
                              _recoverRoomColleListAndFilters,
                          doneAtLocalDayFilter: _doneLocalDayFilter,
                          onClearDoneDayFilter: _doneLocalDayFilter == null
                              ? null
                              : () {
                                  setState(() => _doneLocalDayFilter = null);
                                  _persistRoomColleUiNow();
                                },
                          emptyTitle: 'コレ済の商品はまだありません',
                          emptySubtitle: '保存データでは、このタブに該当する商品はまだありません。',
                          emptyHint: '',
                          dayFilterEmptyTitle: 'この日にコレした商品はありません',
                          dayFilterEmptySubtitle:
                              '表示は端末の日付（このアプリでコレ済にした日時）に基づきます。',
                          accentColor: RoomColleListAccent.done,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomManagedProductListTab extends StatefulWidget {
  const _RoomManagedProductListTab({
    required this.status,
    required this.variant,
    required this.listFilters,
    this.excludeUrlNotReady = false,
    this.candidateFocusHandled = true,
    this.onRecoverFromListError,
    this.doneAtLocalDayFilter,
    this.onClearDoneDayFilter,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyHint,
    this.dayFilterEmptyTitle,
    this.dayFilterEmptySubtitle,
    required this.accentColor,
    this.listScrollController,
    this.flashHighlightProductId,
    this.rowKeyFor,
    this.focusCandidateProductId,
    this.onCandidateFocusListReady,
    this.onCandidateFocusProductMissing,
  });

  final RakutenManagedProductStatus status;
  final RakutenManagedProductCardVariant variant;
  final RoomColleListFilterCriteria listFilters;
  final bool excludeUrlNotReady;

  /// 親が候補フォーカス意図を消化済みなら true（build 内での post-frame 連発を止める）。
  final bool candidateFocusHandled;

  /// 一覧エラー時にフィルタ初期化＋再読込で復旧する。
  final Future<void> Function()? onRecoverFromListError;

  final DateTime? doneAtLocalDayFilter;
  final VoidCallback? onClearDoneDayFilter;
  final String emptyTitle;
  final String emptySubtitle;
  final String emptyHint;
  final String? dayFilterEmptyTitle;
  final String? dayFilterEmptySubtitle;
  final Color accentColor;
  final ScrollController? listScrollController;
  final String? flashHighlightProductId;
  final GlobalKey Function(String productId)? rowKeyFor;
  final String? focusCandidateProductId;
  final VoidCallback? onCandidateFocusListReady;
  final VoidCallback? onCandidateFocusProductMissing;

  @override
  State<_RoomManagedProductListTab> createState() =>
      _RoomManagedProductListTabState();
}

class _RoomManagedProductListTabState
    extends State<_RoomManagedProductListTab> {
  bool _candidateFocusCallbackEnqueued = false;
  String? _lastSeenFocusProductId;
  _RoomColleListSurface? _lastDebugSurface;

  /// [GenreMasterRepository] プリフェッチ結果（genreId 文字列キー）。
  Map<String, String> _genrePrefetchLabels = const {};

  String? _lastGenrePrefetchSig;

  @override
  void initState() {
    super.initState();
    _lastSeenFocusProductId = widget.focusCandidateProductId;
  }

  @override
  void didUpdateWidget(covariant _RoomManagedProductListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newId = widget.focusCandidateProductId;
    if (newId != _lastSeenFocusProductId) {
      _lastSeenFocusProductId = newId;
      _candidateFocusCallbackEnqueued = false;
    }
    if (oldWidget.candidateFocusHandled && !widget.candidateFocusHandled) {
      _candidateFocusCallbackEnqueued = false;
    }
  }

  void _scheduleCandidateFocusKickOnce(BuildContext context) {
    if (widget.status != RakutenManagedProductStatus.candidate) return;
    if (widget.candidateFocusHandled) return;
    final fid = widget.focusCandidateProductId;
    if (fid == null || fid.isEmpty) return;
    if (widget.onCandidateFocusListReady == null ||
        widget.onCandidateFocusProductMissing == null) {
      return;
    }
    if (_candidateFocusCallbackEnqueued) return;
    _candidateFocusCallbackEnqueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _candidateFocusCallbackEnqueued = false;
      if (!mounted) {
        return;
      }
      try {
        final p = context.read<RakutenManagedProductProvider>();
        if (p.listUiStatus == RakutenManagedProductListUiStatus.loading ||
            p.listUiStatus == RakutenManagedProductListUiStatus.error) {
          return;
        }
        if (widget.candidateFocusHandled) return;

        final listNow = _roomListVisibleItems(
          provider: p,
          status: RakutenManagedProductStatus.candidate,
          listFilters: widget.listFilters,
          excludeUrlNotReady: widget.excludeUrlNotReady,
          doneAtLocalDayFilter: null,
        );
        final baseCand = p.sortedItemsForStatus(
          RakutenManagedProductStatus.candidate,
        );

        if (listNow.any((e) => e.productId == fid)) {
          widget.onCandidateFocusListReady!();
        } else if (baseCand.isNotEmpty) {
          widget.onCandidateFocusProductMissing!();
        }
      } catch (e, st) {
        assert(() {
          debugPrint('[ROOMコレ] 候補フォーカス処理エラー: $e\n$st');
          return true;
        }());
      }
    });
  }

  void _scheduleGenrePrefetchIfNeeded(List<RakutenManagedProduct> list) {
    final sig = list.map((e) => '${e.productId}:${e.genreId}').join('|');
    if (sig == _lastGenrePrefetchSig) return;
    _lastGenrePrefetchSig = sig;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ids = <int>{};
      for (final p in list) {
        final n = int.tryParse(p.genreId.trim());
        if (n != null && n > 0) ids.add(n);
      }
      if (ids.isEmpty) {
        if (mounted) {
          setState(() => _genrePrefetchLabels = const {});
        }
        return;
      }
      try {
        final repo = context.read<GenreMasterRepository>();
        await repo.prefetchGenreMasters(ids);
        final next = <String, String>{};
        for (final id in ids) {
          final idStr = '$id';
          final raw = await repo.getGenreName(id);
          if (raw.isNotEmpty && raw != idStr) {
            next[idStr] = raw;
          }
        }
        if (mounted) {
          setState(() => _genrePrefetchLabels = next);
        }
        if (kDebugMode && list.isNotEmpty) {
          final e = list.first;
          RakutenProductGenreDisplay.debugLogResolution(
            itemCode: e.productId,
            genreId: e.genreId,
            apiGenreName: e.genreName,
            finalLabel: RakutenProductGenreDisplay.resolve(
              apiGenreName: null,
              persistedGenreName: e.genreName,
              prefetchedGenreName: next[e.genreId.trim()],
              genreId: e.genreId,
            ),
          );
        }
      } catch (_) {}
    });
  }

  void _debugLogSurface(_RoomColleListSurface surface) {
    assert(() {
      if (_lastDebugSurface != surface) {
        final tabName = widget.status == RakutenManagedProductStatus.candidate
            ? 'candidate'
            : 'done';
        debugPrint(
          '[ROOMコレ][surface] tab=$tabName surface=${surface.debugLabel}',
        );
        _lastDebugSurface = surface;
      }
      return true;
    }());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RakutenManagedProductProvider>(
      builder: (context, provider, _) {
        final ui = provider.listUiStatus;

        final list = _roomListVisibleItems(
          provider: provider,
          status: widget.status,
          listFilters: widget.listFilters,
          excludeUrlNotReady: widget.excludeUrlNotReady,
          doneAtLocalDayFilter: widget.doneAtLocalDayFilter,
        );

        final baseList = provider.sortedItemsForStatus(widget.status);
        final day = widget.doneAtLocalDayFilter;
        final scoped =
            widget.status == RakutenManagedProductStatus.done && day != null
            ? _filterDoneOnLocalCalendarDay(baseList, day)
            : baseList;
        final urlActive =
            widget.status == RakutenManagedProductStatus.candidate &&
            widget.excludeUrlNotReady;
        final urlScoped = _filterExcludeUrlNotReady(scoped, urlActive);

        final canShowDayEmpty =
            widget.dayFilterEmptyTitle != null &&
            widget.dayFilterEmptySubtitle != null;

        final surface = _resolveRoomColleListSurface(
          ui: ui,
          baseList: baseList,
          scoped: scoped,
          list: list,
          urlScoped: urlScoped,
          urlActive: urlActive,
          listFilters: widget.listFilters,
          hasDayFilter: widget.doneAtLocalDayFilter != null,
          canShowDayEmptyMessage: canShowDayEmpty,
        );
        _debugLogSurface(surface);
        if (kDebugMode) {
          debugPrint(
            '[ROOMコレ診断] 一覧直前 tab=${widget.status.name} kw="${widget.listFilters.keyword}" '
            'more=${widget.listFilters.hasNonKeywordConstraints} '
            'urlExcl=${widget.excludeUrlNotReady} day=${widget.doneAtLocalDayFilter != null} '
            'baseLen=${baseList.length} afterFilterLen=${list.length} '
            'surface=${surface.debugLabel} ui=${ui.name}',
          );
          if (list.isNotEmpty) {
            final f = list.first;
            debugPrint(
              '[ROOMコレ診断] 描画リスト先頭 productId=${f.productId} title=${f.itemName} '
              'status=${f.status.name} len=${list.length}',
            );
          }
        }

        switch (surface) {
          case _RoomColleListSurface.loading:
            return const AppScreenLoadingCenter(
              title: '一覧を読み込み中',
              subtitle: '端末に保存した一覧を読み込んでいます。しばらくお待ちください。',
            );

          case _RoomColleListSurface.loadError:
            return _RoomCollectionErrorState(
              message: provider.listUiErrorMessage ?? '一覧データの読み込みに失敗しました。',
              onRetry: () => provider.refreshManagedProductList(
                showLoadingIndicator: true,
              ),
              onResetFiltersAndRetry: widget.onRecoverFromListError,
            );

          case _RoomColleListSurface.readyEmptyNoData:
            return _roomColleRefreshableScroll(
              provider,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RoomCollectionEmptyState(
                    title: widget.emptyTitle,
                    subtitle: widget.emptySubtitle,
                    hint: widget.emptyHint,
                    accentColor: widget.accentColor,
                    stateFootnote: '読み込みは完了していますが、このタブに該当するデータは0件です。',
                    embedInListView: false,
                  ),
                ],
              ),
            );

          case _RoomColleListSurface.readyEmptyFilteredByDay:
            return _roomColleRefreshableScroll(
              provider,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RoomCollectionEmptyState(
                    title: widget.dayFilterEmptyTitle!,
                    subtitle: widget.dayFilterEmptySubtitle!,
                    hint: '',
                    accentColor: widget.accentColor,
                    actionLabel: widget.onClearDoneDayFilter != null
                        ? 'すべて表示'
                        : null,
                    onAction: widget.onClearDoneDayFilter,
                    stateFootnote:
                        '読み込みは完了しています。日付条件に一致する商品は0件です。「すべて表示」で解除できます。',
                    embedInListView: false,
                  ),
                ],
              ),
            );

          case _RoomColleListSurface.readyEmptyFilteredByUrl:
            return _roomColleRefreshableScroll(
              provider,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RoomCollectionUrlFilterEmptyState(
                    accentColor: widget.accentColor,
                    embedInListView: false,
                  ),
                ],
              ),
            );

          case _RoomColleListSurface.readyEmptyFilteredBySearch:
            return _roomColleRefreshableScroll(
              provider,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RoomCollectionSearchEmptyState(
                    accentColor: widget.accentColor,
                    embedInListView: false,
                  ),
                ],
              ),
            );

          case _RoomColleListSurface.readyEmptyAnomaly:
            return _roomColleRefreshableScroll(
              provider,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RoomCollectionRenderOrDataEmptyState(
                    accentColor: widget.accentColor,
                    embedInListView: false,
                    onResetFilters: widget.onRecoverFromListError,
                  ),
                ],
              ),
            );

          case _RoomColleListSurface.readyList:
            _scheduleGenrePrefetchIfNeeded(list);
            break;
        }

        _scheduleCandidateFocusKickOnce(context);

        final showDayBanner =
            widget.status == RakutenManagedProductStatus.done &&
            widget.doneAtLocalDayFilter != null &&
            widget.onClearDoneDayFilter != null;

        return RefreshIndicator(
          onRefresh: () =>
              provider.refreshManagedProductList(showLoadingIndicator: true),
          child: ListView(
            controller: widget.listScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              _kRoomListScreenPadH,
              0,
              _kRoomListScreenPadH,
              _RoomColleUi.listBottomPad,
            ),
            children: [
              if (showDayBanner) ...[
                _DoneDayFilterBanner(
                  filterDay: widget.doneAtLocalDayFilter!,
                  onClear: widget.onClearDoneDayFilter!,
                ),
                const SizedBox(height: _kRoomListCardGap),
              ],
              for (var i = 0; i < list.length; i++) ...[
                _KeyedCandidateProductRow(
                  product: list[i],
                  variant: widget.variant,
                  genrePrefetchLabels: _genrePrefetchLabels,
                  rowKey: widget.rowKeyFor?.call(list[i].productId),
                  flash: widget.flashHighlightProductId == list[i].productId,
                ),
                if (i != list.length - 1)
                  const SizedBox(height: _kRoomListCardGap),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _KeyedCandidateProductRow extends StatelessWidget {
  const _KeyedCandidateProductRow({
    required this.product,
    required this.variant,
    required this.genrePrefetchLabels,
    this.rowKey,
    this.flash = false,
  });

  final RakutenManagedProduct product;
  final RakutenManagedProductCardVariant variant;
  final Map<String, String> genrePrefetchLabels;
  final GlobalKey? rowKey;
  final bool flash;

  @override
  Widget build(BuildContext context) {
    try {
      Widget card = RakutenManagedProductCard(
        product: product,
        variant: variant,
        genrePrefetchLabels: genrePrefetchLabels,
      );
      if (flash) {
        card = AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              AppColors.accentLight.withValues(alpha: 0.35),
              HomeScreenColors.roomContentWellFill,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: HomeScreenColors.sectionOutlineAccent,
              width: 1.5,
            ),
          ),
          child: card,
        );
      }
      if (rowKey != null) {
        return KeyedSubtree(key: rowKey, child: card);
      }
      return card;
    } catch (e, st) {
      assert(() {
        debugPrint('[ROOMコレ] 行描画エラー productId=${product.productId}: $e\n$st');
        return true;
      }());
      final fallback = _RoomColleBrokenProductRow(productId: product.productId);
      if (rowKey != null) {
        return KeyedSubtree(key: rowKey, child: fallback);
      }
      return fallback;
    }
  }
}

/// 1件のデータ／ウィジェット失敗時もリスト全体を落とさないためのプレースホルダ。
class _RoomColleBrokenProductRow extends StatelessWidget {
  const _RoomColleBrokenProductRow({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeScreenColors.roomMetricTileFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: HomeScreenColors.roomMetricTileBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: HomeScreenColors.inkNeutralSplash,
        highlightColor: HomeScreenColors.inkNeutralHighlight,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                productId.trim().isEmpty
                    ? 'この行の商品データを表示できませんでした'
                    : '商品ID $productId の表示に失敗しました',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  productId.trim().isEmpty
                      ? '表示できない商品行があります（タップで詳細）'
                      : '表示エラー: $productId',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HomeScreenColors.metricTileTitleColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneDayFilterBanner extends StatelessWidget {
  const _DoneDayFilterBanner({required this.filterDay, required this.onClear});

  final DateTime filterDay;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeScreenColors.subActionRowFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: HomeScreenColors.sectionOutlineNeutral),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: HomeScreenColors.statusAccentStrong,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '本日（${filterDay.month}/${filterDay.day}）コレした分のみ表示中',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: HomeScreenColors.leadOnSection,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('すべて表示'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCollectionSearchEmptyState extends StatelessWidget {
  const _RoomCollectionSearchEmptyState({
    required this.accentColor,
    this.embedInListView = true,
  });

  final Color accentColor;
  final bool embedInListView;

  @override
  Widget build(BuildContext context) {
    final pane = SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.35,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kRoomListScreenPadH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_outlined,
                size: 44,
                color: accentColor.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 10),
              Text(
                '一致する商品がありません',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'キーワードを変えるか、絞り込みを解除してください。読み込み自体は成功しています。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HomeScreenColors.groupedSectionBody,
                  height: 1.35,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (embedInListView) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [pane],
      );
    }
    return pane;
  }
}

/// 「取得済みURLのみ表示」により表示対象が0件（データは存在する）。候補タブ専用。
class _RoomCollectionUrlFilterEmptyState extends StatelessWidget {
  const _RoomCollectionUrlFilterEmptyState({
    required this.accentColor,
    this.embedInListView = true,
  });

  final Color accentColor;
  final bool embedInListView;

  @override
  Widget build(BuildContext context) {
    final pane = SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.35,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kRoomListScreenPadH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.link_off_rounded,
                size: 44,
                color: accentColor.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 10),
              Text(
                '「取得済URLのみ」では一覧に出せる商品がありません',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '「キーワード以外の条件」で「取得済URLのみ」をオフにすると、URL未準備の候補も表示されます。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HomeScreenColors.groupedSectionBody,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'データの読み込みは成功しています（コレ候補をURL条件で絞り込んだ結果が0件です）。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HomeScreenColors.footnoteMuted,
                  height: 1.35,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (embedInListView) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [pane],
      );
    }
    return pane;
  }
}

/// 本当の0件ではなく、想定外で一覧が空になったとき（真っ白防止）。
class _RoomCollectionRenderOrDataEmptyState extends StatelessWidget {
  const _RoomCollectionRenderOrDataEmptyState({
    required this.accentColor,
    this.embedInListView = true,
    this.onResetFilters,
  });

  final Color accentColor;
  final bool embedInListView;
  final Future<void> Function()? onResetFilters;

  @override
  Widget build(BuildContext context) {
    final pane = SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.35,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kRoomListScreenPadH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 44,
                color: accentColor.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 10),
              Text(
                '一覧を描画できませんでした',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '読み込みエラーではなく、画面上の整合が取れていない可能性（描画・データの不整合）があります。下に引っ張って再読み込みするか、フィルタを初期化してください。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HomeScreenColors.groupedSectionBody,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              if (onResetFilters != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => onResetFilters!(),
                  child: const Text('フィルタを初期化'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (embedInListView) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [pane],
      );
    }
    return pane;
  }
}

class _RoomCollectionEmptyState extends StatelessWidget {
  const _RoomCollectionEmptyState({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.accentColor,
    this.actionLabel,
    this.onAction,
    this.stateFootnote,
    this.embedInListView = true,
  });

  final String title;
  final String subtitle;
  final String hint;
  final Color accentColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? stateFootnote;
  final bool embedInListView;

  @override
  Widget build(BuildContext context) {
    final pane = SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.4,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kRoomListScreenPadH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: accentColor.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HomeScreenColors.groupedSectionBody,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
              if (hint.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HomeScreenColors.footnoteMuted,
                    height: 1.35,
                  ),
                ),
              ],
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
              if (stateFootnote != null &&
                  stateFootnote!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  stateFootnote!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: HomeScreenColors.footnoteMuted,
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (embedInListView) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [pane],
      );
    }
    return pane;
  }
}

class _RoomCollectionErrorState extends StatelessWidget {
  const _RoomCollectionErrorState({
    required this.message,
    required this.onRetry,
    this.onResetFiltersAndRetry,
  });

  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function()? onResetFiltersAndRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: _kRoomListScreenPadH,
            vertical: 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(
                    '一覧を表示できませんでした',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: HomeScreenColors.accentSectionHeading,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '状態: データの読み込みに失敗しました',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: HomeScreenColors.footnoteMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HomeScreenColors.groupedSectionBody,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => onRetry(),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('もう一度読み込む'),
                  ),
                  if (onResetFiltersAndRetry != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => onResetFiltersAndRetry!(),
                      child: const Text('フィルタを初期化して再開'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
