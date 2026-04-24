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
  static const double gapListAfterDivider = 6;

  static const double listBottomPad = 12;

  /// 結果カード間（一覧の「呼吸」）。
  static const double listCardGap = 8;

  /// 入力デッキ外周（画面上端〜シェル）。
  static const double gapDeckOuterTop = 6;
  static const double gapDeckOuterBottom = 6;

  /// 副操作行〜主CTAの前後。
  static const double gapBeforePrimaryCta = 8;

  /// モードタブ〜説明文。
  static const double gapTabToBody = 6;

  /// モーダル内フィールドの縦リズム（8〜10px帯）。
  static const double sheetBlockGap = 10;

  /// 並び替え行〜主入力ブロック。
  static const double gapSortToFields = 6;

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

  /// 探すグループ共通シェルの内側余白。
  static const EdgeInsets searchGroupShellContentPadding = EdgeInsets.symmetric(
    horizontal: screenPadH,
    vertical: AppDimensions.spacingSm,
  );

  /// 入口3択シート本文の外側余白（見出し〜3択までの共通間隔）。
  static const EdgeInsets addCandidateSheetContentPadding = EdgeInsets.fromLTRB(
    screenPadH,
    AppDimensions.spacingSm,
    screenPadH,
    AppDimensions.spacingMd,
  );

  /// 入口3択シート内の行カード余白。
  static const EdgeInsets addCandidateSheetItemPadding = EdgeInsets.symmetric(
    horizontal: AppDimensions.spacingMd,
    vertical: inputDeckPadding,
  );

  static const double insetSectionH = 8;
  static const double paddingWellV = 6;
  static const double paddingHeaderBand = 6;
  static const double headerBandBottom = 3;
  static const double gapIconToTitle = 8;

  static double get radiusSectionOuter => AppDimensions.radiusCard;
  static const double radiusSectionInner = 12;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: HomeScreenColors.cardShadowColor.withValues(alpha: 0.45),
      offset: const Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      offset: const Offset(0, 1),
      blurRadius: 4,
    ),
  ];

  /// 空状態・エラーなど結果ペインのカード外観（[outerSectionShellDecoration] と同系）。
  static BoxDecoration feedbackShellDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.roomGroupedShellFill,
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(color: HomeScreenColors.sectionOutlineNeutral),
      boxShadow: cardShadow,
    );
  }

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
      borderRadius: BorderRadius.circular(searchFieldBorderRadius),
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

  /// モーダル先頭の説明1段落（主見出しの直下）。
  static TextStyle sheetIntroBody(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          color: HomeScreenColors.groupedSectionBody,
          height: 1.38,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ) ??
        TextStyle(
          color: HomeScreenColors.groupedSectionBody,
          height: 1.38,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        );
  }

  /// モードタブ下の短いガイド文。
  static TextStyle modeTabGuideBody(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          color: HomeScreenColors.groupedSectionBody,
          height: 1.35,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ) ??
        TextStyle(
          color: HomeScreenColors.groupedSectionBody,
          height: 1.35,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
  }

  /// 詳細シートの主CTA（画面下部の主ボタンと同系）。
  static ButtonStyle sheetPrimaryFilledButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.accentPrimary,
      foregroundColor: AppColors.textOnAccent,
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      elevation: 1,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
        letterSpacing: -0.2,
        height: 1.15,
      ),
    );
  }

  static TextStyle labelStrong(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          color: HomeScreenColors.titlePrimary,
          fontWeight: FontWeight.w700,
        ) ??
        const TextStyle(fontWeight: FontWeight.w700);
  }

  /// 検索欄の入力値・擬似欄の表示文字（TextField [style] と揃える）。
  static TextStyle searchFieldValueStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w500,
          color: HomeScreenColors.titlePrimary,
        ) ??
        const TextStyle(
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w500,
        );
  }

  /// 検索バー系 TextField の角丸（探すグループ共通）。
  static const double searchFieldBorderRadius = 12;

  /// 検索バー内の余白（高さ・左右位置の基準）。
  static const EdgeInsets searchFieldContentPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 13,
  );

  /// 先頭アイコンサイズ（未指定の [Icon] に [IconTheme] で適用）。
  static const double searchFieldPrefixIconSize = 20;

  /// 先頭／末尾アイコンのタップ領域（縦位置を揃える）。
  static const BoxConstraints searchFieldIconConstraints = BoxConstraints(
    minWidth: 44,
    minHeight: 44,
  );

  /// 並び替え帯など、一覧ヘッダ行の内側パディング（楽天結果帯と同一）。
  static EdgeInsets get listFilterStripInnerPadding => EdgeInsets.symmetric(
    horizontal: AppDimensions.spacingSm + 2,
    vertical: AppDimensions.spacingSm,
  );

  /// 探すグループ：一覧行・補助ブロック（検索デッキ内ウェルと同系の外枠）。
  static BoxDecoration exploreGroupFlatCardDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.deckFill,
      borderRadius: BorderRadius.circular(radiusSectionInner),
      border: Border.all(color: HomeScreenColors.deckOutline),
      boxShadow: cardShadow,
    );
  }

  static InputDecoration searchField({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final r = BorderRadius.circular(searchFieldBorderRadius);
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
      prefixIcon: prefixIcon == null
          ? null
          : IconTheme(
              data: IconThemeData(
                size: searchFieldPrefixIconSize,
                color: HomeScreenColors.leadOnSection,
              ),
              child: prefixIcon,
            ),
      suffixIcon: suffixIcon == null
          ? null
          : IconTheme(
              data: IconThemeData(
                size: searchFieldPrefixIconSize,
                color: HomeScreenColors.leadOnSection,
              ),
              child: suffixIcon,
            ),
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
      contentPadding: searchFieldContentPadding,
      prefixIconConstraints: searchFieldIconConstraints,
      suffixIconConstraints: searchFieldIconConstraints,
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
