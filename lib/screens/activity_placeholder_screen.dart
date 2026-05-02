import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/activity/activity_achievement_tab.dart';
import '../widgets/activity/activity_analytics_tab.dart';
import '../widgets/app_tab.dart';

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
  int _mainTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_syncMainTabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RakutenManagedProductProvider>().refreshManagedProductList(
            showLoadingIndicator: false,
          );
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_syncMainTabIndex);
    _tabController.dispose();
    super.dispose();
  }

  void _syncMainTabIndex() {
    if (!mounted || _mainTabIndex == _tabController.index) return;
    setState(() => _mainTabIndex = _tabController.index);
  }

  Future<void> _refresh() {
    return context.read<RakutenManagedProductProvider>().refreshManagedProductList(
          showLoadingIndicator: true,
        );
  }

  /// タブ切替を各タブのスクロール先頭に置き、本文カードと重ならないようにする。
  Widget _tabStripInScroll() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenPaddingH,
        4,
        AppDimensions.screenPaddingH,
        16,
      ),
      child: AppTabBar(
        height: 50,
        items: const [
          AppTabItem(label: '実績', icon: Icons.emoji_events_outlined),
          AppTabItem(label: '分析', icon: Icons.analytics_outlined),
        ],
        selectedIndex: _mainTabIndex,
        onChanged: (index) {
          setState(() => _mainTabIndex = index);
          _tabController.animateTo(index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final fabReserve = 72.0;
    final navBarReserve = 56.0;
    final scrollBottomInset = bottomSafe + fabReserve + navBarReserve;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('活動')),
      body: SafeArea(
        bottom: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            ActivityAchievementTab(
              onRefresh: _refresh,
              bottomInset: scrollBottomInset,
              leadingTabStrip: _tabStripInScroll,
            ),
            ActivityAnalyticsTab(
              onRefresh: _refresh,
              bottomInset: scrollBottomInset,
              leadingTabStrip: _tabStripInScroll,
            ),
          ],
        ),
      ),
    );
  }
}
