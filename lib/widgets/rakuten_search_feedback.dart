import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';

/// ROOM コレの空／エラー／読込と同系の「結果ペイン」ラッパー（スクロール可能・最小高さで縦中央寄せ）。
class _RakutenSearchFeedbackShell extends StatelessWidget {
  const _RakutenSearchFeedbackShell({
    required this.child,
    this.stretchToFillViewport = true,
  });

  final Widget child;

  /// true のときビューポート高さまで [minHeight] を取り中央寄せ（従来どおり）。
  /// false のときはコンテンツ高さのみ・上寄せで余白を抑える。
  final bool stretchToFillViewport;

  @override
  Widget build(BuildContext context) {
    final padH = RakutenSearchScreenUi.screenPadH;
    final padV = RakutenSearchScreenUi.gapSection;
    final innerPad = EdgeInsets.fromLTRB(
      RakutenSearchScreenUi.insetSectionH + 10,
      RakutenSearchScreenUi.paddingWellV + 16,
      RakutenSearchScreenUi.insetSectionH + 10,
      RakutenSearchScreenUi.paddingWellV + 16,
    );

    if (!stretchToFillViewport) {
      final innerTight = EdgeInsets.fromLTRB(
        RakutenSearchScreenUi.insetSectionH + 8,
        RakutenSearchScreenUi.paddingWellV + 10,
        RakutenSearchScreenUi.insetSectionH + 8,
        RakutenSearchScreenUi.paddingWellV + 10,
      );
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(padH, padV * 0.55, padH, padV),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: DecoratedBox(
              decoration: RakutenSearchScreenUi.feedbackShellDecoration(),
              child: Padding(padding: innerTight, child: child),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final minH = h.isFinite ? math.max(120.0, h) : 200.0;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: DecoratedBox(
                  decoration: RakutenSearchScreenUi.feedbackShellDecoration(),
                  child: Padding(padding: innerPad, child: child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

ButtonStyle _rakutenSearchSecondaryOutlinedStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: HomeScreenColors.accentSectionHeading,
    backgroundColor: Color.alphaBlend(
      AppColors.accentLight.withValues(alpha: 0.14),
      HomeScreenColors.deckFill,
    ),
    side: BorderSide(color: HomeScreenColors.sectionOutlineAccent),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    minimumSize: const Size(0, 48),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
    ),
    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
  );
}

/// 楽天検索エリア：未検索（アイドル）状態。
class RakutenSearchIdleView extends StatelessWidget {
  const RakutenSearchIdleView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.stateFootnote,
    this.iconTint,
    this.compactLayout = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// ROOM コレ空状態の [stateFootnote] と同役割（処理は進んでいない旨など短く）。
  final String? stateFootnote;
  final Color? iconTint;

  /// true のときビューポート全体を埋めず、上寄せ・控えめな余白（キーワード検索の検索前など）。
  final bool compactLayout;

  @override
  Widget build(BuildContext context) {
    final ic =
        iconTint ?? HomeScreenColors.statusAccentMuted.withValues(alpha: 0.88);
    final iconSize = compactLayout ? 34.0 : 42.0;

    return _RakutenSearchFeedbackShell(
      stretchToFillViewport: !compactLayout,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: iconSize, color: ic),
          SizedBox(height: compactLayout ? 10 : 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HomeScreenColors.titlePrimary,
              fontWeight: FontWeight.w800,
              fontSize: compactLayout ? 15 : 16,
              height: 1.22,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: compactLayout ? 6 : 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.groupedSectionBody,
              height: compactLayout ? 1.38 : 1.42,
              fontSize: compactLayout ? 12 : 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (stateFootnote != null && stateFootnote!.trim().isNotEmpty) ...[
            SizedBox(height: compactLayout ? 10 : 12),
            Text(
              stateFootnote!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: HomeScreenColors.footnoteMuted,
                fontSize: compactLayout ? 10.5 : 11,
                height: 1.32,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 楽天検索エリア：読み込み中。
class RakutenSearchLoadingView extends StatelessWidget {
  const RakutenSearchLoadingView({
    super.key,
    required this.title,
    required this.subtitle,
    this.footnote,
  });

  final String title;
  final String subtitle;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return _RakutenSearchFeedbackShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: HomeScreenColors.statusAccentStrong,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HomeScreenColors.titlePrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              height: 1.22,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.groupedSectionBody,
              height: 1.4,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (footnote != null && footnote!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              footnote!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: HomeScreenColors.footnoteMuted,
                height: 1.35,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 楽天検索エリア：失敗。
class RakutenSearchErrorView extends StatelessWidget {
  const RakutenSearchErrorView({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.onAdjustConditions,
    this.retryLabel = 'もう一度検索する',
    this.adjustLabel = '条件を調整',
    this.stateLine = '状態: 通信または楽天APIの応答に失敗しました',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onAdjustConditions;
  final String retryLabel;
  final String adjustLabel;

  /// ROOM コレ [_RoomCollectionErrorState] の「状態: …」行に相当。
  final String stateLine;

  @override
  Widget build(BuildContext context) {
    return _RakutenSearchFeedbackShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.error_outline_rounded, size: 44, color: AppColors.error),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomeScreenColors.accentSectionHeading,
              height: 1.28,
              letterSpacing: -0.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stateLine,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: HomeScreenColors.footnoteMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.groupedSectionBody,
              height: 1.42,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            style: RakutenSearchScreenUi.sheetPrimaryFilledButtonStyle(),
            icon: const Icon(Icons.refresh_rounded, size: 21),
            label: Text(
              retryLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (onAdjustConditions != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onAdjustConditions,
              style: _rakutenSearchSecondaryOutlinedStyle(),
              icon: const Icon(Icons.tune_rounded, size: 20),
              label: Text(
                adjustLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 楽天検索エリア：成功だが表示できる結果がない／0件。
class RakutenSearchEmptyView extends StatelessWidget {
  const RakutenSearchEmptyView({
    super.key,
    this.icon = Icons.search_off_outlined,
    required this.title,
    required this.body,
    this.hints = const [],
    this.onRefine,
    this.refineLabel = '条件を調整',
    this.stateFootnote,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> hints;
  final VoidCallback? onRefine;
  final String refineLabel;

  /// ROOM コレの「読み込みは完了していますが…」に相当。
  final String? stateFootnote;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final ic =
        iconColor ??
        HomeScreenColors.statusAccentStrong.withValues(alpha: 0.38);

    return _RakutenSearchFeedbackShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 42, color: ic),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HomeScreenColors.titlePrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              height: 1.22,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.groupedSectionBody,
              height: 1.4,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'ヒント',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: HomeScreenColors.leadOnSection,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            for (final h in hints)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '・',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HomeScreenColors.groupedSectionBody,
                        height: 1.35,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        h,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HomeScreenColors.groupedSectionBody,
                          height: 1.38,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (onRefine != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRefine,
              style: _rakutenSearchSecondaryOutlinedStyle(),
              icon: const Icon(Icons.tune_rounded, size: 20),
              label: Text(
                refineLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (stateFootnote != null && stateFootnote!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              stateFootnote!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: HomeScreenColors.footnoteMuted,
                fontSize: 10.5,
                height: 1.32,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
