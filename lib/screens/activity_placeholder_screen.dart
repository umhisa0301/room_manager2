import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/activity/activity_achievement_tab.dart';
import '../widgets/activity/activity_analytics_tab.dart';
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

  @override
  void initState() {
    super.initState();
    _achievementScroll = ScrollController();
    _analyticsScroll = ScrollController();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RakutenManagedProductProvider>().refreshManagedProductList(
            showLoadingIndicator: false,
          );
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabController);
    _tabController.dispose();
    _achievementScroll.dispose();
    _analyticsScroll.dispose();
    super.dispose();
  }

  void _handleTabController() {
    if (_tabController.indexIsChanging) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    final scrollBottomInset = bottomSafe + navBarReserve + 24;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('分析')),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
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
