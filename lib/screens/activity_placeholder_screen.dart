import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/app_shell_controller.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/activity_screen_tokens.dart';
import '../widgets/activity/activity_achievement_tab.dart';
import '../widgets/activity/activity_analytics_tab.dart';
import '../widgets/activity/activity_screen_layout.dart';
import '../widgets/activity/activity_segmented_tab_bar.dart';

/// コレ活動：実績と分析の2タブ。
class ActivityPlaceholderScreen extends StatefulWidget {
  const ActivityPlaceholderScreen({
    super.key,
    this.openTodayEditorOnStart = false,
  });

  final bool openTodayEditorOnStart;

  static Route<void> createRecordRoute() {
    return MaterialPageRoute<void>(
      builder: (_) =>
          const ActivityPlaceholderScreen(openTodayEditorOnStart: true),
    );
  }

  @override
  State<ActivityPlaceholderScreen> createState() =>
      _ActivityPlaceholderScreenState();
}

class _ActivityPlaceholderScreenState extends State<ActivityPlaceholderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ScrollController _achievementScroll;
  late final ScrollController _analyticsScroll;
  final GlobalKey _roomReactionSectionKey = GlobalKey();
  late final AppShellController _shellCtrl;
  bool _suppressNextAnalyticsScrollReset = false;

  @override
  void initState() {
    super.initState();
    _achievementScroll = ScrollController();
    _analyticsScroll = ScrollController();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabController);
    _shellCtrl = context.read<AppShellController>();
    _shellCtrl.addListener(_onShellCtrlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RakutenManagedProductProvider>().refreshManagedProductList(
            showLoadingIndicator: false,
          );
      _tryConsumeActivityNavigationIntent();
    });
  }

  @override
  void dispose() {
    _shellCtrl.removeListener(_onShellCtrlChanged);
    _tabController.removeListener(_handleTabController);
    _tabController.dispose();
    _achievementScroll.dispose();
    _analyticsScroll.dispose();
    super.dispose();
  }

  void _onShellCtrlChanged() {
    if (!mounted) return;
    _tryConsumeActivityNavigationIntent();
  }

  void _tryConsumeActivityNavigationIntent() {
    if (!mounted) return;
    if (_shellCtrl.currentIndex != 3) return;
    final intent = _shellCtrl.takePendingActivityIntent();
    if (intent == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_applyActivityNavigationIntent(intent));
    });
  }

  Future<void> _applyActivityNavigationIntent(
    ActivityNavigationIntent intent,
  ) async {
    if (!mounted) return;
    final switched = intent.subTabIndex == 1 && _tabController.index != 1;
    if (switched) {
      if (intent.scrollToRoomReactionSection) {
        _suppressNextAnalyticsScrollReset = true;
      }
      _tabController.animateTo(1);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } else if (intent.scrollToRoomReactionSection) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) return;
    if (intent.scrollToRoomReactionSection) {
      final ctx = _roomReactionSectionKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.06,
        );
      }
    }
  }

  void _handleTabController() {
    if (_tabController.indexIsChanging) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_suppressNextAnalyticsScrollReset && _tabController.index == 1) {
        _suppressNextAnalyticsScrollReset = false;
        return;
      }
      final active =
          _tabController.index == 0 ? _achievementScroll : _analyticsScroll;
      if (active.hasClients) {
        active.jumpTo(0);
      }
    });
  }

  Future<void> _refresh() {
    return context.read<RakutenManagedProductProvider>().refreshManagedProductList(
          showLoadingIndicator: true,
        );
  }

  void _selectMainTab(int index) {
    if (_tabController.index != index) {
      _tabController.animateTo(index);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = index == 0 ? _achievementScroll : _analyticsScroll;
      if (c.hasClients) c.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    const navBarReserve = 56.0;
    final scrollBottomInset = bottomSafe +
        navBarReserve +
        24 +
        ActivityScreenLayout.fabBottomReserve;

    return Scaffold(
      backgroundColor: ActivityScreenUi.background,
      appBar: AppBar(title: const Text('分析')),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ListenableBuilder(
                listenable: _tabController,
                builder: (context, _) {
                  return ActivitySegmentedTabBar(
                    selectedIndex: _tabController.index.clamp(0, 1),
                    onChanged: _selectMainTab,
                  );
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ActivityAchievementTab(
                    onRefresh: _refresh,
                    bottomInset: scrollBottomInset,
                    scrollController: _achievementScroll,
                  ),
                  ActivityAnalyticsTab(
                    onRefresh: _refresh,
                    bottomInset: scrollBottomInset,
                    scrollController: _analyticsScroll,
                    roomReactionSectionKey: _roomReactionSectionKey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
