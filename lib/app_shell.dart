import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'navigation/app_shell_controller.dart';
import 'navigation/rakuten_search_navigator.dart';
import 'theme/app_theme.dart';
import 'screens/home_placeholder_screen.dart';
import 'screens/products_placeholder_screen.dart';
import 'screens/comments_placeholder_screen.dart';
import 'screens/activity_placeholder_screen.dart';
import 'screens/mypage_placeholder_screen.dart';
import 'screens/saved_shops_screen.dart';
import 'screens/comment_template_edit_screen.dart';
import 'widgets/add_candidate_entry_sheet.dart';
import 'widgets/common_draggable_edge_fab.dart';

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

  Future<void> _openRakutenSearchFromSheet(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await openRakutenSearchScreen(context);
  }

  Future<void> _openSavedShopsFromSheet(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SavedShopsScreen()),
    );
  }

  Future<void> _openShopDiscoveryFromSheet(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await openRakutenSearchScreen(
      context,
      initialMode: RakutenSearchInitialMode.shopDiscovery,
    );
  }

  Future<void> _showAddCandidateSheet() {
    return showAddCandidateEntryBottomSheet(
      context: context,
      onTapRakutenProductSearch: _openRakutenSearchFromSheet,
      onTapSavedShops: _openSavedShopsFromSheet,
      onTapShopDiscovery: _openShopDiscoveryFromSheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<AppShellController>();
    final idx = shell.currentIndex;
    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          IndexedStack(index: idx, children: _screens),
          if (idx != 2)
            CommonDraggableEdgeFab(
              shellTabIndex: idx,
              onCommentTap: () =>
                  context.read<AppShellController>().selectTab(2),
            ),
          if (idx == 2)
            CommentTabPlusFab(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const CommentTemplateEditScreen(
                      initialTemplate: null,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
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
                    onTap: () =>
                        context.read<AppShellController>().selectTab(0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.travel_explore_outlined,
                    selectedIcon: Icons.travel_explore_rounded,
                    label: '探す',
                    tooltip: '楽天検索',
                    isSelected: false,
                    onTap: () {
                      openRakutenSearchScreen(context);
                    },
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.add_circle_outline_rounded,
                    selectedIcon: Icons.add_circle_rounded,
                    label: '＋',
                    tooltip: null,
                    isSelected: false,
                    onTap: () {
                      _showAddCandidateSheet();
                    },
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.collections_bookmark_outlined,
                    selectedIcon: Icons.collections_bookmark,
                    label: 'ROOMコレ',
                    tooltip: null,
                    isSelected: idx == 1,
                    onTap: () =>
                        context.read<AppShellController>().selectTab(1),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'マイページ',
                    tooltip: null,
                    isSelected: idx == 4,
                    onTap: () =>
                        context.read<AppShellController>().selectTab(4),
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
