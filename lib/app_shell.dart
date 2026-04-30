import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navigation/app_shell_controller.dart';
import 'navigation/rakuten_search_navigator.dart';
import 'theme/app_theme.dart';
import 'screens/home_placeholder_screen.dart';
import 'screens/products_placeholder_screen.dart';
import 'screens/comments_placeholder_screen.dart';
import 'screens/activity_placeholder_screen.dart';
import 'screens/mypage_placeholder_screen.dart';
import 'screens/saved_shops_screen.dart';
import 'widgets/add_candidate_entry_sheet.dart';

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

  bool _showCommentFabCoachmark = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final seen = p.getBool('ui_hint_comment_fab_seen_v1') ?? false;
      if (!seen && mounted) {
        setState(() => _showCommentFabCoachmark = true);
      }
    });
  }

  Future<void> _consumeCommentFabCoachmark() async {
    if (!_showCommentFabCoachmark) return;
    setState(() => _showCommentFabCoachmark = false);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('ui_hint_comment_fab_seen_v1', true);
    } catch (_) {}
  }

  Future<void> _openCommentsTab() async {
    await _consumeCommentFabCoachmark();
    if (!mounted) return;
    context.read<AppShellController>().selectTab(2);
  }

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
    final bottomLift = MediaQuery.paddingOf(context).bottom + 56;
    final showGlobalCommentFab = idx != 2;
    return Scaffold(
      body: IndexedStack(index: idx, children: _screens),
      floatingActionButton: showGlobalCommentFab
          ? Padding(
              padding: EdgeInsets.only(bottom: bottomLift.clamp(52.0, 92.0)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_showCommentFabCoachmark)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 10),
                      child: Material(
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        color: AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 220,
                                ),
                                child: Text(
                                  '投稿コメントを作れます',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: '閉じる',
                                onPressed: _consumeCommentFabCoachmark,
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Tooltip(
                    message: '投稿コメントを作れます',
                    child: FloatingActionButton(
                      heroTag: 'app_shell_comment_fab',
                      elevation: 3.5,
                      highlightElevation: 6,
                      backgroundColor: AppColors.accentPrimary,
                      foregroundColor: AppColors.textOnAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      onPressed: _openCommentsTab,
                      child: const Icon(Icons.chat_bubble_rounded, size: 26),
                    ),
                  ),
                ],
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
