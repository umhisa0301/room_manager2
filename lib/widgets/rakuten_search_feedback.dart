import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';

BoxDecoration _rakutenSearchFeedbackShellDecoration() {
  return BoxDecoration(
    color: HomeScreenColors.roomGroupedShellFill,
    borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
    border: Border.all(color: HomeScreenColors.sectionOutlineNeutral),
    boxShadow: [
      BoxShadow(
        color: HomeScreenColors.cardShadowColor,
        offset: const Offset(0, 2),
        blurRadius: 10,
      ),
    ],
  );
}

/// ROOM コレの空／エラー／読込と同系の「結果ペイン」ラッパー（スクロール可能・最小高さで縦中央寄せ）。
class _RakutenSearchFeedbackShell extends StatelessWidget {
  const _RakutenSearchFeedbackShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final minH = h.isFinite ? math.max(120.0, h) : 200.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: DecoratedBox(
                  decoration: _rakutenSearchFeedbackShellDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: child,
                  ),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  /// ROOM コレ空状態の [stateFootnote] と同役割（処理は進んでいない旨など短く）。
  final String? stateFootnote;
  final Color? iconTint;

  @override
  Widget build(BuildContext context) {
    final ic = iconTint ??
        HomeScreenColors.statusAccentMuted.withValues(alpha: 0.88);

    return _RakutenSearchFeedbackShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            icon,
            size: 48,
            color: ic,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HomeScreenColors.groupedSectionBody,
                  height: 1.45,
                  fontSize: 13,
                ),
          ),
          if (stateFootnote != null && stateFootnote!.trim().isNotEmpty) ...[
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
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HomeScreenColors.groupedSectionBody,
                  height: 1.45,
                  fontSize: 13,
                ),
          ),
          if (footnote != null && footnote!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              footnote!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HomeScreenColors.footnoteMuted,
                    height: 1.4,
                    fontSize: 12,
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
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: HomeScreenColors.accentSectionHeading,
                  height: 1.3,
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
                  height: 1.35,
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
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: AppColors.textOnAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(retryLabel),
          ),
          if (onAdjustConditions != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAdjustConditions,
              style: _rakutenSearchSecondaryOutlinedStyle(),
              icon: const Icon(Icons.tune_rounded, size: 20),
              label: Text(adjustLabel),
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
    final ic = iconColor ??
        HomeScreenColors.statusAccentStrong.withValues(alpha: 0.38);

    return _RakutenSearchFeedbackShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            icon,
            size: 48,
            color: ic,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HomeScreenColors.groupedSectionBody,
                  height: 1.45,
                  fontSize: 13,
                ),
          ),
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '次に試せること',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: HomeScreenColors.leadOnSection,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
            ),
            const SizedBox(height: 8),
            for (final h in hints)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '・',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: HomeScreenColors.groupedSectionBody,
                          ),
                    ),
                    Expanded(
                      child: Text(
                        h,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: HomeScreenColors.groupedSectionBody,
                              height: 1.4,
                              fontSize: 13,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (onRefine != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRefine,
              style: _rakutenSearchSecondaryOutlinedStyle(),
              icon: const Icon(Icons.tune_rounded, size: 20),
              label: Text(refineLabel),
            ),
          ],
          if (stateFootnote != null && stateFootnote!.trim().isNotEmpty) ...[
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
    );
  }
}
