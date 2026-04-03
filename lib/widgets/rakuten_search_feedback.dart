import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';

/// 楽天検索エリア：未検索（アイドル）状態。
class RakutenSearchIdleView extends StatelessWidget {
  const RakutenSearchIdleView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: HomeScreenColors.footnoteMuted,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: HomeScreenColors.titlePrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HomeScreenColors.groupedSectionBody,
                    height: 1.45,
                  ),
            ),
          ],
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: HomeScreenColors.statusAccentStrong,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: HomeScreenColors.titlePrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HomeScreenColors.groupedSectionBody,
                    height: 1.45,
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
                    ),
              ),
            ],
          ],
        ),
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
    this.retryLabel = 'もう一度試す',
    this.adjustLabel = '条件を調整',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onAdjustConditions;
  final String retryLabel;
  final String adjustLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_tethering_error_rounded,
              size: 44,
              color: AppColors.error.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: HomeScreenColors.titlePrimary,
                    fontWeight: FontWeight.w700,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: Text(retryLabel),
                ),
                if (onAdjustConditions != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onAdjustConditions,
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    label: Text(adjustLabel),
                  ),
                ],
              ],
            ),
          ],
        ),
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
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> hints;
  final VoidCallback? onRefine;
  final String refineLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: HomeScreenColors.footnoteMuted,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: HomeScreenColors.titlePrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HomeScreenColors.groupedSectionBody,
                    height: 1.45,
                  ),
            ),
            if (hints.isNotEmpty) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '次の方法を試せます',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: HomeScreenColors.leadOnSection,
                            fontWeight: FontWeight.w700,
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: HomeScreenColors.groupedSectionBody,
                                  ),
                            ),
                            Expanded(
                              child: Text(
                                h,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: HomeScreenColors.groupedSectionBody,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (onRefine != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRefine,
                icon: const Icon(Icons.tune_rounded, size: 20),
                label: Text(refineLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
