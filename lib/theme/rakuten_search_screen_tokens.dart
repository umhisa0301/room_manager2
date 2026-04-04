import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'home_screen_colors.dart';

/// 楽天検索画面のレイアウト・配色（ROOMコレ [_RoomColleUi] と同一数値・同系色）。
///
/// 画面ロジックとは分離し、見た目の単一情報源とする。
abstract final class RakutenSearchScreenUi {
  const RakutenSearchScreenUi._();

  /// ROOMコレ一覧と同じ左右 8。
  static const double screenPadH = 8;

  /// ホーム [_HomeUi.gapSection] / ROOM [_RoomColleUi.gapSection] と同じ 9。
  static const double gapSection = 9;

  /// ROOM [_RoomColleUi.gapFieldStack] と同じ 5。
  static const double gapFieldStack = 5;

  /// ROOM [_RoomColleUi.gapKeywordToFilterRow] に相当（主入力〜次行の呼吸）。
  static const double gapKeywordToControls = 7;

  /// ROOM [_RoomColleUi.gapListAfterDivider] と同じ 4（区切り〜一覧ヘッダの接続）。
  static const double gapListAfterDivider = 4;

  static const double listBottomPad = 10;

  /// ROOM [_kRoomListCardGap] と同じ 5。
  static const double listCardGap = 5;

  /// ジャンル結果リストの下余白 = [listBottomPad] + この値。
  static const double listScrollExtraPadGenre = 12;

  /// ショップ発掘リストの下余白 = [listBottomPad] + この値。
  static const double listScrollExtraPadDiscovery = 14;

  /// キーワード結果で選択モード時のフローティングバー用。
  static const double listBottomPadWithSelectionBar = 88;

  /// リスト先頭の微余白（カード密度を ROOM 一覧に寄せる）。
  static const double listScrollTopPad = 2;

  /// 「検索完了」行の下側（次ブロックまでの締め）。
  static const double gapResultStatusRowBottom = 4;

  /// 発掘フロー完了行の下（メトリクスカードとの間を少し広めに）。
  static const double gapDiscoveryStatusRowBottom = 6;

  /// 下部フローティング一括操作バーの下パディング。
  static const double gapFloatingBarPad = 12;

  /// 検索入力デッキ内側（ウェル密度は ROOM の well に近づけつつタップしやすく）。
  static const double inputDeckPadding = 10;

  /// モーダルシートの左右（本文の読みやすさ用。外側 [screenPadH] よりやや広く）。
  static const double sheetPadH = 12;

  static const double insetSectionH = 8;
  static const double paddingWellV = 6;
  static const double paddingHeaderBand = 6;
  static const double headerBandBottom = 3;
  static const double gapIconToTitle = 8;

  static double get radiusSectionOuter => AppDimensions.radiusCard;
  static const double radiusSectionInner = 12;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: HomeScreenColors.cardShadowColor,
      offset: const Offset(0, 2),
      blurRadius: 10,
    ),
  ];

  static BoxDecoration outerSectionShellDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.roomGroupedShellFill,
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(color: HomeScreenColors.sectionOutlineNeutral),
      boxShadow: cardShadow,
    );
  }

  static BoxDecoration modeTabDeckDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.roomContentWellFill,
      borderRadius: BorderRadius.circular(radiusSectionInner),
      border: Border.all(color: HomeScreenColors.deckOutline),
    );
  }

  /// 一覧フィルタ帯（ROOM 補助行〜チップ帯と同系：主シェルより一段弱い）。
  static BoxDecoration listFilterStripDecoration() {
    return BoxDecoration(
      color: Color.alphaBlend(
        HomeScreenColors.subActionRowFill.withValues(alpha: 0.92),
        HomeScreenColors.roomContentWellFill,
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: HomeScreenColors.sectionOutlineNeutral),
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

  static TextStyle bodyCaption(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          color: HomeScreenColors.groupedSectionBody,
          height: 1.4,
        ) ??
        TextStyle(color: HomeScreenColors.groupedSectionBody, height: 1.4);
  }

  static TextStyle labelStrong(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          color: HomeScreenColors.titlePrimary,
          fontWeight: FontWeight.w700,
        ) ??
        const TextStyle(fontWeight: FontWeight.w700);
  }

  static InputDecoration searchField({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final r = BorderRadius.circular(10);
    final normal = OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(color: HomeScreenColors.deckOutline),
    );
    return InputDecoration(
      filled: true,
      fillColor: HomeScreenColors.deckFill,
      isDense: true,
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      labelStyle: TextStyle(
        color: HomeScreenColors.leadOnSection,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      hintStyle: TextStyle(color: HomeScreenColors.footnoteMuted, fontSize: 14),
      border: normal,
      enabledBorder: normal,
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(
          color: HomeScreenColors.sectionOutlineAccent,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

/// ROOMコレの [ _RoomColleFilterShell ] と同型の「見出し帳＋ウェル」。
class RakutenSearchSectionShell extends StatelessWidget {
  const RakutenSearchSectionShell({
    super.key,
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
      decoration: RakutenSearchScreenUi.outerSectionShellDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          RakutenSearchScreenUi.radiusSectionOuter,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredBox(
              color: HomeScreenColors.roomSectionHeaderBand,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  RakutenSearchScreenUi.insetSectionH,
                  RakutenSearchScreenUi.paddingHeaderBand,
                  RakutenSearchScreenUi.insetSectionH,
                  RakutenSearchScreenUi.headerBandBottom,
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
                    SizedBox(width: RakutenSearchScreenUi.gapIconToTitle),
                    Expanded(
                      child: Text(
                        title,
                        style: RakutenSearchScreenUi.sectionHeadingAccent(
                          context,
                        ),
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
                  RakutenSearchScreenUi.insetSectionH,
                  RakutenSearchScreenUi.paddingWellV,
                  RakutenSearchScreenUi.insetSectionH,
                  RakutenSearchScreenUi.paddingWellV,
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
