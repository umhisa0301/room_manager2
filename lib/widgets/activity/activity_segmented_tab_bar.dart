import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 活動画面用：ホーム／マイページに馴染むセグメント切替（上部固定想定）。
class ActivitySegmentedTabBar extends StatelessWidget {
  const ActivitySegmentedTabBar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    this.labels = const ['実績', '分析'],
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<String> labels;

  static const double tabBarHeight = 50;

  @override
  Widget build(BuildContext context) {
    assert(labels.length >= 2);
    final n = labels.length;
    final idx = selectedIndex.clamp(0, n - 1);

    return SizedBox(
      height: tabBarHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.65),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(
                    2 * (idx + 0.5) / n - 1,
                    0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1 / n,
                    heightFactor: 1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onChanged(i),
                          customBorder: const RoundedRectangleBorder(),
                          child: SizedBox(
                            height: tabBarHeight,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: i == idx
                                              ? AppColors.textOnAccent
                                              : AppColors.textSecondary,
                                        ) ??
                                    TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: i == idx
                                          ? AppColors.textOnAccent
                                          : AppColors.textSecondary,
                                    ),
                                child: Text(labels[i]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
