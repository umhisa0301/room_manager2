import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/app_shell_controller.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/activity/activity_achievement_tab.dart';
import '../widgets/activity/activity_analytics_tab.dart';
import '../widgets/app_button.dart';
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

  @override
  Widget build(BuildContext context) {
    final shell = context.read<AppShellController>();
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    // フッターナビ＋コメントFABが重ならないよう余白（活動タブは FAB 表示あり）
    final fabReserve = 72.0;
    final scrollBottomInset = bottomSafe + fabReserve;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('活動')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenPaddingH,
                12,
                AppDimensions.screenPaddingH,
                0,
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
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ActivityAchievementTab(
                    onRefresh: _refresh,
                    bottomInset: scrollBottomInset,
                  ),
                  ActivityAnalyticsTab(
                    onRefresh: _refresh,
                    bottomInset: scrollBottomInset,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.screenPaddingH,
                8,
                AppDimensions.screenPaddingH,
                10 + bottomSafe,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  AppSecondaryButton(
                    label: 'ROOMコレ',
                    onPressed: () {
                      shell.openRoomCollect(initialTabIndex: 0);
                    },
                    icon: const Icon(Icons.collections_bookmark_outlined),
                  ),
                  AppSecondaryButton(
                    label: 'コメント',
                    onPressed: () => shell.selectTab(2),
                    icon: const Icon(Icons.chat_bubble_outline),
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
