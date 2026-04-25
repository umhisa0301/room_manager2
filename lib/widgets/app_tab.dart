import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppTabItem {
  const AppTabItem({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// Compact segmented tab bar. Only the selected tab may use the brand color.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 46,
  });

  final List<AppTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    assert(items.isNotEmpty, 'AppTabBar requires at least one item.');

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _AppTabButton(
                item: items[i],
                selected: i == selectedIndex,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppTabButton extends StatelessWidget {
  const _AppTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.textOnAccent : AppColors.textSecondary;
    final bg = selected ? AppColors.accentPrimary : Colors.transparent;

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 16, color: fg),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12.5,
                    height: 1.1,
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
