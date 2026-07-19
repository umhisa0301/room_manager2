import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'navigation/app_shell_controller.dart';
import 'navigation/rakuten_search_navigator.dart';
import 'theme/app_theme.dart';
import 'theme/home_screen_colors.dart';
import 'screens/home_placeholder_screen.dart';
import 'screens/products_placeholder_screen.dart';
import 'screens/comments_placeholder_screen.dart';
import 'screens/activity_placeholder_screen.dart';
import 'screens/add_candidate_from_url_screen.dart';
import 'screens/mypage_placeholder_screen.dart';
import 'screens/comment_template_edit_screen.dart';
import 'widgets/add_candidate_entry_sheet.dart';
import 'state/bulk_operation_state_controller.dart';
import 'state/room_import_controller.dart';
import 'state/operation_tutorial_controller.dart';
import 'utils/room_sync_log.dart';
import 'widgets/common_draggable_edge_fab.dart';
import 'widgets/tutorial/tutorial_overlay_host.dart';

/// 下部ナビ表示は ホーム・探す・ROOMコレ・分析・マイページ。
/// [IndexedStack] は 0=ホーム, 1=ROOMコレ, 2=コメント（フッター非表示）, 3=分析, 4=マイページ。
/// コメントはフッター外・[CommonDraggableEdgeFab] / コメントタブ内 FAB から遷移。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _mypageTabOpenedOnce = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode && const bool.fromEnvironment('LAYOUT_AUDIT_SEED')) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await openRakutenSearchScreen(context);
      });
    }
  }

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

  Future<void> _openGenreSearchFromSheet(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await openRakutenSearchScreen(
      context,
      initialMode: RakutenSearchInitialMode.genre,
    );
  }

  Future<void> _openAddFromUrlFromSheet(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AddCandidateFromUrlScreen(),
      ),
    );
  }

  Future<void> _openSavedShopsFromSheet(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await openRakutenSearchScreen(context, savedShopKeywordEntry: true);
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
      onTapGenreSearch: _openGenreSearchFromSheet,
      onTapSavedShops: _openSavedShopsFromSheet,
      onTapAddFromUrl: _openAddFromUrlFromSheet,
      onTapShopDiscovery: _openShopDiscoveryFromSheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<AppShellController>();
    final idx = shell.currentIndex;
    if (idx == 4 && !_mypageTabOpenedOnce) {
      _mypageTabOpenedOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<OperationTutorialController>()
            .maybeAutoStartProfileTutorial();
      });
    }
    return TutorialOverlayHost(
      child: Scaffold(
        body: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            IndexedStack(index: idx, children: _screens),
            if (idx != 2)
              Consumer2<RoomImportController, BulkOperationStateController>(
                builder: (context, importCtl, bulk, _) {
                  final syncBusy =
                      importCtl.isRunning ||
                      bulk.isMetadataEnriching ||
                      bulk.isRoomReactionSyncRunning;
                  if (idx == 0 && syncBusy) {
                    unknownFloatingButtonHideLog(
                      screen: 'home',
                      widget: 'CommonDraggableEdgeFab',
                      reason: 'hiddenDuringRoomSync',
                    );
                    return const SizedBox.shrink();
                  }
                  unknownFloatingButtonAuditLog(
                    screen: idx == 0 ? 'home' : 'tab$idx',
                    widget: 'CommonDraggableEdgeFab',
                    file: 'lib/widgets/common_draggable_edge_fab.dart',
                    visible: true,
                    reason: 'commentEdgeFabRightSideNotMenu',
                  );
                  return CommonDraggableEdgeFab(
                    shellTabIndex: idx,
                    onCommentTap: () =>
                        context.read<AppShellController>().selectTab(2),
                  );
                },
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
                      key: const Key('app_shell_nav_home'),
                      icon: Icons.dashboard_outlined,
                      selectedIcon: Icons.dashboard,
                      label: 'ホーム',
                      tooltip: null,
                      semanticsLabel: 'ホーム',
                      isTab: true,
                      isSelected: idx == 0,
                      onTap: () =>
                          context.read<AppShellController>().selectTab(0),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      key: const Key('app_shell_nav_search'),
                      icon: Icons.add_circle_outline_rounded,
                      selectedIcon: Icons.add_circle_rounded,
                      label: '探す',
                      tooltip: '候補を追加',
                      semanticsLabel: '候補を追加',
                      isTab: false,
                      isSelected: false,
                      onTap: _showAddCandidateSheet,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      key: const Key('app_shell_nav_managed'),
                      icon: Icons.collections_bookmark_outlined,
                      selectedIcon: Icons.collections_bookmark,
                      label: '投稿',
                      tooltip: null,
                      semanticsLabel: '投稿',
                      isTab: true,
                      isSelected: idx == 1,
                      onTap: () =>
                          context.read<AppShellController>().selectTab(1),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      key: const Key('app_shell_nav_analytics'),
                      icon: Icons.insights_outlined,
                      selectedIcon: Icons.insights_rounded,
                      label: '分析',
                      tooltip: null,
                      semanticsLabel: '分析',
                      isTab: true,
                      isSelected: idx == 3,
                      onTap: () =>
                          context.read<AppShellController>().selectTab(3),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      key: const Key('app_shell_nav_mypage'),
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person,
                      label: 'マイページ',
                      tooltip: null,
                      semanticsLabel: 'マイページ',
                      isTab: true,
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
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.tooltip,
    required this.semanticsLabel,
    required this.isTab,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? tooltip;
  final String semanticsLabel;
  final bool isTab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Semantics(
      button: true,
      selected: isTab ? isSelected : null,
      enabled: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: AppDimensions.iconNav,
                  color: isSelected
                      ? HomeScreenColors.homeAccentTeal
                      : HomeScreenColors.homeNavInactive,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: isSelected
                        ? AppTextStyles.navLabelSelected.copyWith(
                            color: HomeScreenColors.homeAccentTeal,
                          )
                        : AppTextStyles.navLabel.copyWith(
                            color: HomeScreenColors.homeNavInactive,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        excludeFromSemantics: true,
        child: child,
      );
    }
    return child;
  }
}
