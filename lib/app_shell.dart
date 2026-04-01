import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'navigation/app_shell_controller.dart';
import 'theme/app_theme.dart';
import 'screens/home_placeholder_screen.dart';
import 'screens/products_placeholder_screen.dart';
import 'screens/comments_placeholder_screen.dart';
import 'screens/activity_placeholder_screen.dart';
import 'screens/mypage_placeholder_screen.dart';

/// 下部ナビゲーション＋5タブのメインシェル（2番目は ROOMコレ管理）。
/// 選択中はアクセント色＋背景ピルで視覚的に明確にする。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const List<Widget> _screens = [
    HomePlaceholderScreen(),
    ProductsPlaceholderScreen(),
    CommentsPlaceholderScreen(),
    ActivityPlaceholderScreen(),
    MypagePlaceholderScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<AppShellController>();
    final idx = shell.currentIndex;
    return Scaffold(
      body: IndexedStack(index: idx, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.divider.withValues(alpha: 0.85),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -1),
              blurRadius: 6,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingSm,
              vertical: 4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    label: 'ホーム',
                    tooltip: null,
                    isSelected: idx == 0,
                    onTap: () => context.read<AppShellController>().selectTab(0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.collections_bookmark_outlined,
                    selectedIcon: Icons.collections_bookmark,
                    label: 'ROOMコレ',
                    tooltip: 'ROOMコレ管理',
                    isSelected: idx == 1,
                    onTap: () => context.read<AppShellController>().selectTab(1),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.chat_bubble_outline,
                    selectedIcon: Icons.chat_bubble,
                    label: 'コメント',
                    tooltip: null,
                    isSelected: idx == 2,
                    onTap: () => context.read<AppShellController>().selectTab(2),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.analytics_outlined,
                    selectedIcon: Icons.analytics,
                    label: '活動',
                    tooltip: null,
                    isSelected: idx == 3,
                    onTap: () => context.read<AppShellController>().selectTab(3),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'マイページ',
                    tooltip: null,
                    isSelected: idx == 4,
                    onTap: () => context.read<AppShellController>().selectTab(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentLight : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: AppDimensions.iconNav,
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: isSelected
                      ? AppTextStyles.navLabelSelected
                      : AppTextStyles.navLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}
