import 'package:flutter/material.dart';

import '../../theme/activity_screen_tokens.dart';
import 'activity_screen_layout.dart';

/// 活動画面用：実績／分析を 50:50 で均等配置するセグメント。
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

  @override
  Widget build(BuildContext context) {
    assert(labels.length >= 2);
    final n = labels.length;
    final idx = selectedIndex.clamp(0, n - 1);

    return SizedBox(
      height: ActivityScreenLayout.mainTabBarHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ActivityScreenUi.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ActivityScreenUi.border),
          boxShadow: [
            BoxShadow(
              color: ActivityScreenUi.cardShadowColor,
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < n; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _ActivityMainTabCell(
                    label: labels[i],
                    selected: i == idx,
                    onTap: () => onChanged(i),
                    roundedLeft: i == 0,
                    roundedRight: i == n - 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityMainTabCell extends StatelessWidget {
  const _ActivityMainTabCell({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.roundedLeft,
    required this.roundedRight,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool roundedLeft;
  final bool roundedRight;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.horizontal(
      left: roundedLeft ? const Radius.circular(20) : Radius.zero,
      right: roundedRight ? const Radius.circular(20) : Radius.zero,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: r,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? ActivityScreenUi.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? null
                : Border.all(
                    color: ActivityScreenUi.border.withValues(alpha: 0.85),
                  ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: ActivityScreenUi.selectedTabShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: selected ? 0.2 : 0,
                    color: selected
                        ? ActivityScreenUi.textOnPrimary
                        : ActivityScreenUi.textPrimary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
