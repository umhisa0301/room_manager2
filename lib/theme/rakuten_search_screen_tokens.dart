import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'home_screen_colors.dart';
import '../widgets/app_text_field.dart';

/// 楽天検索画面のレイアウト・配色（ROOMコレ [_RoomColleUi] と同一数値・同系色）。
///
/// 画面ロジックとは分離し、見た目の単一情報源とする。
abstract final class RakutenSearchScreenUi {
  const RakutenSearchScreenUi._();

  /// 投稿管理 [_kRoomListScreenPadH] と同じ 16。
  static const double screenPadH = 16;

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

  /// 一括選択バーのボタン高さ（[AppPrimaryButton] height と揃える）。
  static const double bulkSelectionBarButtonHeight = 48;

  /// 検索欄・条件ボタンの高さ（投稿管理 [_RoomColleUi.searchRowHeight] と同一）。
  static const double searchRowHeight = 48;

  /// 条件ボタンの固定幅（横 overflow 防止）。
  static const double filterButtonWidth = 92;

  /// 探す画面 Primary（投稿管理 [HomeScreenColors.homeAccentTeal] と同一）。
  static const Color primary = HomeScreenColors.homeAccentTeal;

  /// Primary の淡い背景（選択チップ・バナー・ナビ選択背景）。
  static const Color primaryLight = HomeScreenColors.homeAccentTealLight;

  /// Primary の枠線（アウトラインボタン・チップ）。
  static const Color primaryBorder = HomeScreenColors.homeAccentTealBorder;

  /// Primary 上の文字色。
  static const Color textOnPrimary = Colors.white;

  /// テキスト選択ハイライト（淡いティール）。
  static Color get selectionHighlight =>
      primary.withValues(alpha: 0.22);

  /// ランキングバッジ背景（#1 / #2 等）。
  static Color get rankBadgeFill => primary.withValues(alpha: 0.14);

  /// ランキングバッジ文字・スコア系チップ文字。
  static Color get rankBadgeText => primary;

  /// スコア系チップ背景（売れ筋度など）。
  static Color get scoreChipFill => primaryLight;

  /// 探す画面スコープ用 Theme（カーソル・選択・チェックボックス）。
  static ThemeData overlayTheme(ThemeData base) {
    return base.copyWith(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: selectionHighlight,
        selectionHandleColor: primary,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return null;
          }
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return null;
        }),
      ),
    );
  }

  /// BottomSheet 等の通常リンク（クリア・変更・一覧など）。
  static ButtonStyle linkTextButtonStyle() {
    return TextButton.styleFrom(
      foregroundColor: primary,
      visualDensity: VisualDensity.compact,
    );
  }

  /// 閉じる・キャンセルなど非強調リンク。
  static ButtonStyle dismissTextButtonStyle() {
    return TextButton.styleFrom(
      foregroundColor: HomeScreenColors.homeMutedText,
      visualDensity: VisualDensity.compact,
    );
  }

  /// 条件シート下部の「閉じる」アウトライン。
  static ButtonStyle sheetDismissOutlineStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: HomeScreenColors.homeMutedText,
      side: BorderSide(color: HomeScreenColors.homeCardBorder),
    );
  }

  /// ジャンル選択チップ・選択中 InputChip。
  static ChipThemeData chipTheme(ChipThemeData base) {
    return base.copyWith(
      selectedColor: primaryLight,
      checkmarkColor: primary,
      deleteIconColor: primary,
      labelStyle: base.labelStyle?.copyWith(
        color: HomeScreenColors.titlePrimary,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: primaryBorder.withValues(alpha: 0.55)),
    );
  }

  /// 検索欄の通常枠線。
  static const Color searchFieldBorder = Color(0xFFCBD5E1);

  /// 検索欄プレースホルダー。
  static const Color searchFieldHint = Color(0xFF94A3B8);

  /// リストが Column 内の一括バーと重ならないよう確保する下余白の目安
  /// （バーはリスト外に配置するため、通常は [listBottomPad] のみで足りる）。
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
      color: Colors.black.withValues(alpha: 0.03),
      offset: const Offset(0, 1),
      blurRadius: 4,
    ),
  ];

  /// 空状態・エラーなど結果ペインのカード外観（[outerSectionShellDecoration] と同系）。
  static BoxDecoration feedbackShellDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.homeCardFill,
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(color: HomeScreenColors.homeCardBorder),
      boxShadow: cardShadow,
    );
  }

  static BoxDecoration outerSectionShellDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.homeCardFill,
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(color: HomeScreenColors.homeCardBorder),
      boxShadow: cardShadow,
    );
  }

  static BoxDecoration modeTabDeckDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.homeCardFill,
      borderRadius: BorderRadius.circular(radiusSectionInner),
      border: Border.all(color: HomeScreenColors.homeCardBorder),
    );
  }

  /// 一覧フィルタ帯（投稿管理と同系の白カード）。
  static BoxDecoration listFilterStripDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.homeCardFill,
      borderRadius: BorderRadius.circular(searchFieldBorderRadius),
      border: Border.all(color: HomeScreenColors.homeCardBorder),
      boxShadow: cardShadow,
    );
  }

  static TextStyle sectionHeadingAccent(BuildContext context) {
    final base = Theme.of(context).textTheme.titleSmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.12,
      color: HomeScreenColors.homeTextPrimary,
    );
  }

  /// 画面上部タイトル（投稿管理と同系）。
  static TextStyle screenTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: HomeScreenColors.homeTextPrimary,
          letterSpacing: -0.15,
        ) ??
        const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: HomeScreenColors.homeTextPrimary,
        );
  }

  /// 画面上部サブタイトル。
  static TextStyle screenSubtitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: HomeScreenColors.homeTextSecondary,
          height: 1.35,
        ) ??
        TextStyle(
          fontSize: 14,
          color: HomeScreenColors.homeTextSecondary,
          height: 1.35,
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
    horizontal: 12,
    vertical: 10,
  );

  /// 先頭アイコンサイズ（未指定の [Icon] に [IconTheme] で適用）。
  static const double searchFieldPrefixIconSize = 20;

  /// 先頭／末尾アイコンのタップ領域（縦位置を揃える）。
  static const BoxConstraints searchFieldIconConstraints = BoxConstraints(
    minWidth: 40,
    minHeight: 40,
  );

  /// 並び替え帯など、一覧ヘッダ行の内側パディング（楽天結果帯と同一）。
  static EdgeInsets get listFilterStripInnerPadding => EdgeInsets.symmetric(
    horizontal: AppDimensions.spacingSm + 2,
    vertical: AppDimensions.spacingSm,
  );

  /// 探すグループ：一覧行・補助ブロック。
  static BoxDecoration exploreGroupFlatCardDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.homeCardFill,
      borderRadius: BorderRadius.circular(radiusSectionInner),
      border: Border.all(color: HomeScreenColors.homeCardBorder),
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
    // 入力欄は補助要素として薄いグレー面・1px枠に抑える。
    final normal = OutlineInputBorder(
      borderRadius: r,
      borderSide: const BorderSide(color: searchFieldBorder, width: 1),
    );
    return InputDecoration(
      filled: true,
      fillColor: HomeScreenColors.homeCardFill,
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
      hintStyle: const TextStyle(color: searchFieldHint, fontSize: 14),
      border: normal,
      enabledBorder: normal,
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: RakutenSearchScreenUi.primary, width: 1.2),
      ),
      contentPadding: searchFieldContentPadding,
      prefixIconConstraints: searchFieldIconConstraints,
      suffixIconConstraints: searchFieldIconConstraints,
    );
  }
}

/// 探す画面向け TextField（フォーカス枠・カーソル・選択色をティールに統一）。
class RakutenSearchTextField extends StatelessWidget {
  const RakutenSearchTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.minHeight = 46,
    this.fixedHeight,
    this.semanticLabel,
    this.fillColor,
    this.enabledBorderColor,
    this.hintColor,
    this.focusedBorderColor,
    this.validator,
    this.autovalidateMode,
    this.errorText,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final double minHeight;
  final double? fixedHeight;
  final String? semanticLabel;
  final Color? fillColor;
  final Color? enabledBorderColor;
  final Color? hintColor;
  final Color? focusedBorderColor;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RakutenSearchScreenUi.overlayTheme(Theme.of(context)),
      child: AppTextField(
        controller: controller,
        focusNode: focusNode,
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        readOnly: readOnly,
        enabled: enabled,
        autofocus: autofocus,
        obscureText: obscureText,
        maxLines: maxLines,
        maxLength: maxLength,
        minHeight: minHeight,
        fixedHeight: fixedHeight,
        semanticLabel: semanticLabel,
        fillColor: fillColor,
        enabledBorderColor: enabledBorderColor,
        hintColor: hintColor,
        focusedBorderColor: focusedBorderColor ?? RakutenSearchScreenUi.primary,
        validator: validator,
        autovalidateMode: autovalidateMode,
        errorText: errorText,
      ),
    );
  }
}

/// 探す画面向け Primary CTA（ティール系。[AppPrimaryButton] の探す版）。
class RakutenSearchPrimaryButton extends StatelessWidget {
  const RakutenSearchPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 52,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final primary = RakutenSearchScreenUi.primary;
    final button = SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: RakutenSearchScreenUi.textOnPrimary,
          backgroundColor: primary,
          disabledForegroundColor: RakutenSearchScreenUi.textOnPrimary.withValues(
            alpha: 0.72,
          ),
          disabledBackgroundColor: primary.withValues(alpha: 0.34),
          elevation: 1.2,
          shadowColor: primary.withValues(alpha: 0.22),
          minimumSize: Size(0, height),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RakutenSearchScreenUi.textOnPrimary.withValues(
                    alpha: 0.9,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    IconTheme.merge(
                      data: const IconThemeData(size: 16),
                      child: icon!,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.visible,
                      softWrap: true,
                      style: AppTextStyles.button.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        letterSpacing: -0.15,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    return Semantics(button: true, label: label, child: button);
  }
}

/// 探す画面向けアウトラインボタン（白背景 + ティール枠 + ティール文字）。
class RakutenSearchOutlineButton extends StatelessWidget {
  const RakutenSearchOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final primary = RakutenSearchScreenUi.primary;
    final button = SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: AppColors.textTertiary,
          side: BorderSide(
            color: enabled
                ? primary.withValues(alpha: 0.75)
                : AppColors.divider,
          ),
          elevation: 0,
          minimumSize: Size(0, height),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              IconTheme.merge(
                data: IconThemeData(
                  size: 16,
                  color: enabled ? primary : AppColors.textTertiary,
                ),
                child: icon!,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible,
                softWrap: true,
                style: AppTextStyles.button.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: -0.15,
                  height: 1.15,
                  color: enabled ? primary : AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(button: true, label: label, child: button);
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
                        color: RakutenSearchScreenUi.primary,
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
