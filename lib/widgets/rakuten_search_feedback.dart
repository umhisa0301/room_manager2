import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import 'app_button.dart';
import 'app_loading.dart';

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
      RakutenSearchScreenUi.insetSectionH + 8,
      RakutenSearchScreenUi.paddingWellV + 10,
      RakutenSearchScreenUi.insetSectionH + 8,
      RakutenSearchScreenUi.paddingWellV + 10,
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
        iconTint ?? HomeScreenColors.homeAccentTeal.withValues(alpha: 0.55);
    final iconSize = compactLayout ? 30.0 : 36.0;

    return _RakutenSearchFeedbackShell(
      stretchToFillViewport: !compactLayout,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: iconSize, color: ic),
          SizedBox(height: compactLayout ? 8 : 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HomeScreenColors.titlePrimary,
              fontWeight: FontWeight.w800,
              fontSize: compactLayout ? 14.5 : 15,
              height: 1.22,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: compactLayout ? 4 : 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.groupedSectionBody,
              height: compactLayout ? 1.32 : 1.36,
              fontSize: compactLayout ? 11.5 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (stateFootnote != null && stateFootnote!.trim().isNotEmpty) ...[
            SizedBox(height: compactLayout ? 8 : 10),
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
    this.compactLayout = false,
  });

  final String title;
  final String subtitle;
  final String? footnote;
  final bool compactLayout;

  @override
  Widget build(BuildContext context) {
    if (compactLayout) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: RakutenSearchScreenUi.screenPadH,
            vertical: RakutenSearchScreenUi.gapSection,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLoadingView(message: title, inline: false),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: HomeScreenColors.homeTextSecondary,
                      height: 1.32,
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return _RakutenSearchFeedbackShell(
      stretchToFillViewport: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppLoadingView(message: title, inline: false),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.groupedSectionBody,
              height: 1.32,
              fontSize: 11.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (footnote != null && footnote!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              footnote!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: HomeScreenColors.footnoteMuted,
                height: 1.28,
                fontSize: 10.5,
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
    this.compactLayout = false,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onAdjustConditions;
  final String retryLabel;
  final String adjustLabel;

  /// ROOM コレ [_RoomCollectionErrorState] の「状態: …」行に相当。
  final String stateLine;

  /// キーボード表示中など縦スペースが狭いとき、大カードではなくコンパクトバナー表示。
  final bool compactLayout;

  @override
  Widget build(BuildContext context) {
    if (compactLayout) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            RakutenSearchScreenUi.screenPadH,
            RakutenSearchScreenUi.gapSection * 0.5,
            RakutenSearchScreenUi.screenPadH,
            RakutenSearchScreenUi.gapSection * 0.5,
          ),
          child: Material(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 20,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: HomeScreenColors.titlePrimary,
                                height: 1.25,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HomeScreenColors.groupedSectionBody,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(retryLabel),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: RakutenSearchScreenUi.primary,
                          ),
                        ),
                      ),
                      if (onAdjustConditions != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onAdjustConditions,
                            icon: const Icon(Icons.tune_rounded, size: 16),
                            label: Text(adjustLabel),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _RakutenSearchFeedbackShell(
      stretchToFillViewport: true,
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
              color: HomeScreenColors.titlePrimary,
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
          RakutenSearchPrimaryButton(
            label: retryLabel,
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (onAdjustConditions != null) ...[
            const SizedBox(height: 10),
            AppSecondaryButton(
              label: adjustLabel,
              onPressed: onAdjustConditions,
              icon: const Icon(Icons.tune_rounded),
              expand: true,
              height: 48,
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
    this.refineLabel = '条件を変更',
    this.onClear,
    this.clearLabel = '検索をクリア',
    this.stateFootnote,
    this.iconColor,
    this.compactLayout = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> hints;
  final VoidCallback? onRefine;
  final String refineLabel;
  final VoidCallback? onClear;
  final String clearLabel;

  /// ROOM コレの「読み込みは完了していますが…」に相当。
  final String? stateFootnote;
  final Color? iconColor;
  final bool compactLayout;

  @override
  Widget build(BuildContext context) {
    final ic =
        iconColor ??
        HomeScreenColors.homeAccentTeal.withValues(alpha: 0.38);
    final iconSize = compactLayout ? 28.0 : 32.0;

    return _RakutenSearchFeedbackShell(
      stretchToFillViewport: !compactLayout,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: iconSize, color: ic),
          SizedBox(height: compactLayout ? 8 : 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HomeScreenColors.homeTextPrimary,
              fontWeight: FontWeight.w800,
              fontSize: compactLayout ? 14 : 15,
              height: 1.22,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: compactLayout ? 4 : 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.homeTextSecondary,
              height: 1.34,
              fontSize: compactLayout ? 11.5 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final h in hints)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  h,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HomeScreenColors.homeTextSecondary,
                    height: 1.35,
                    fontSize: 11.5,
                  ),
                ),
              ),
          ],
          if (onRefine != null) ...[
            SizedBox(height: compactLayout ? 12 : 14),
            RakutenSearchPrimaryButton(
              label: refineLabel,
              onPressed: onRefine,
              icon: const Icon(Icons.tune_rounded),
              height: 48,
            ),
          ],
          if (onClear != null) ...[
            const SizedBox(height: 8),
            AppSecondaryButton(
              label: clearLabel,
              onPressed: onClear,
              icon: const Icon(Icons.restart_alt_rounded),
              expand: true,
              height: 48,
            ),
          ],
          if (stateFootnote != null && stateFootnote!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
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
