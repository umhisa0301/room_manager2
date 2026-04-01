import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import 'activity_placeholder_screen.dart';
import 'products_placeholder_screen.dart';
import 'rakuten_search_screen.dart';
import 'today_recommendations_screen.dart';
import '../services/rakuten_room_home_stats.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/home_primary_action_button.dart';

/// ホーム（ダッシュボード）。ROOM コレ管理の導線と集計を中心に構成する。
class HomePlaceholderScreen extends StatefulWidget {
  const HomePlaceholderScreen({super.key});

  @override
  State<HomePlaceholderScreen> createState() => _HomePlaceholderScreenState();
}

class _HomePlaceholderScreenState extends State<HomePlaceholderScreen> {
  bool _aboutExpanded = false;
  bool _roomIntroExpanded = false;
  bool _recentIntroExpanded = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RakutenManagedProductProvider>().refreshManagedProductList(
        showLoadingIndicator: false,
      );
    });
  }

  void _openRoomList(BuildContext context, {int initialTabIndex = 0}) {
    final idx = initialTabIndex.clamp(0, 1);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductsPlaceholderScreen(initialTabIndex: idx),
      ),
    );
  }

  void _openActivity(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ActivityPlaceholderScreen(),
      ),
    );
  }

  Future<void> _openTodayRecommendations(BuildContext context) async {
    final recommender = context.read<TodayRecommendationProvider>();
    await recommender.ensureToday(
      profile: context.read<UserProfileProvider>().profile,
      managedItems: context.read<RakutenManagedProductProvider>().items,
      savedShops: context.read<SavedShopProvider>().shops,
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TodayRecommendationsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child:
            Consumer3<
              RakutenManagedProductProvider,
              UserProfileProvider,
              TodayRecommendationProvider
            >(
              builder:
                  (context, roomProvider, userProfileProvider, recProvider, _) {
                    final items = roomProvider.items;
                    final rawName = userProfileProvider.profile.displayName;
                    final displayName = rawName.trim().isEmpty
                        ? null
                        : rawName.trim();
                    final nCandidate = RakutenRoomHomeStats.countCandidates(
                      items,
                    );
                    final nDone = RakutenRoomHomeStats.countDone(items);
                    final now = DateTime.now();
                    final nTodayDone =
                        RakutenRoomHomeStats.countDoneOnLocalCalendarDay(
                          items,
                          now,
                        );
                    final lastDone = RakutenRoomHomeStats.latestDoneAt(items);
                    final recentCandidates =
                        RakutenRoomHomeStats.candidatesNewestFirst(
                          items,
                        ).take(5).toList();
                    final bottomInset = MediaQuery.paddingOf(context).bottom;
                    const navBarReserve = 52.0;

                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        AppDimensions.screenPaddingH,
                        AppDimensions.spacingSm,
                        AppDimensions.screenPaddingH,
                        bottomInset + navBarReserve,
                      ),
                      children: [
                        HomePrimaryActionButton(
                          emphasis: HomePrimaryActionEmphasis.hero,
                          icon: Icons.travel_explore_rounded,
                          label: '楽天で検索',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RakutenSearchScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                        _HomeExpandableSection(
                          chrome: _HomeExpandableChrome.hero,
                          expanded: _aboutExpanded,
                          onToggle: () {
                            setState(() {
                              _aboutExpanded = !_aboutExpanded;
                            });
                          },
                          title: 'このアプリについて',
                          collapsedSummary: '3ステップでROOMコレを進める（詳しく）',
                          leadingIcon: Icons.info_outline_rounded,
                          expandedChild: _AboutAppExpandedBody(
                            displayName: displayName,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                        _TodayRecommendationsEntryCard(
                          totalCount: recProvider.totalCount,
                          pendingCount: recProvider.pendingCount,
                          isCompleted: recProvider.isCompleted,
                          onOpen: () => _openTodayRecommendations(context),
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),
                        _HomeExpandableSection(
                          chrome: _HomeExpandableChrome.plain,
                          expanded: _roomIntroExpanded,
                          onToggle: () {
                            setState(() {
                              _roomIntroExpanded = !_roomIntroExpanded;
                            });
                          },
                          title: 'ROOMコレ管理',
                          collapsedSummary: '',
                          leadingIcon: Icons.collections_bookmark_outlined,
                          expandedChild: Text(
                            '下の数は端末に保存した一覧の集計です。カードをタップで一覧・活動へ移動します。',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        _RoomStatsCardGrid(
                          candidateTotal: nCandidate,
                          doneTotal: nDone,
                          todayDoneCount: nTodayDone,
                          lastDoneAt: lastDone,
                          onCandidateTap: () =>
                              _openRoomList(context, initialTabIndex: 0),
                          onDoneTap: () =>
                              _openRoomList(context, initialTabIndex: 1),
                          onTodayTap: () => _openActivity(context),
                          onLastCollectTap: () => _openActivity(context),
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),
                        _HomeExpandableSection(
                          chrome: _HomeExpandableChrome.plain,
                          expanded: _recentIntroExpanded,
                          onToggle: () {
                            setState(() {
                              _recentIntroExpanded = !_recentIntroExpanded;
                            });
                          },
                          title: '最近追加した候補',
                          collapsedSummary: '',
                          leadingIcon: Icons.bookmark_added_outlined,
                          expandedChild: Text(
                            '直近の候補を最大5件表示。コレ済にすると消えます。行タップでコレ一覧。',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        _RecentCandidatesPanel(
                          candidates: recentCandidates,
                          onOpenList: () => _openRoomList(context),
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),
                        _HomeCollectionListLink(
                          onPressed: () => _openRoomList(context),
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                      ],
                    );
                  },
            ),
      ),
    );
  }
}

/// ホームの折りたたみカードの見た目種別。
enum _HomeExpandableChrome { hero, plain }

/// ホーム共通：ヘッダー全面タップ・スプラッシュ・AnimatedSize で開閉。
class _HomeExpandableSection extends StatelessWidget {
  const _HomeExpandableSection({
    required this.chrome,
    required this.expanded,
    required this.onToggle,
    required this.title,
    required this.collapsedSummary,
    required this.leadingIcon,
    required this.expandedChild,
  });

  final _HomeExpandableChrome chrome;
  final bool expanded;
  final VoidCallback onToggle;
  final String title;
  final String collapsedSummary;
  final IconData leadingIcon;
  final Widget expandedChild;

  static const Duration _animDuration = Duration(milliseconds: 280);
  static const Curve _animCurve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.radiusCard);
    final isHero = chrome == _HomeExpandableChrome.hero;
    final splashColor = isHero
        ? AppColors.accentPrimary.withValues(alpha: 0.14)
        : AppColors.textPrimary.withValues(alpha: 0.09);
    final highlightColor = isHero
        ? AppColors.accentPrimary.withValues(alpha: 0.07)
        : AppColors.textPrimary.withValues(alpha: 0.05);
    final iconColor = isHero
        ? AppColors.accentPrimary
        : AppColors.textSecondary;

    final BoxDecoration decoration;
    if (isHero) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentLight.withValues(alpha: 0.9),
            const Color(0xFFFFF5F9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      );
    } else {
      decoration = BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: radius,
              splashColor: splashColor,
              highlightColor: highlightColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(leadingIcon, size: 22, color: iconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (collapsedSummary.isNotEmpty && !expanded) ...[
                            const SizedBox(height: 6),
                            Text(
                              collapsedSummary,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: _animDuration,
            curve: _animCurve,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: expandedChild,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _AboutAppExpandedBody extends StatelessWidget {
  const _AboutAppExpandedBody({required this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '検索 → 候補 → コレ',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        if (displayName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '$displayNameさん、まずは検索から',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        const _FlowStepLine(
          number: '1',
          title: '商品を探す',
          subtitle: '「楽天で検索」から。',
        ),
        const SizedBox(height: 8),
        const _FlowStepLine(
          number: '2',
          title: '候補に追加',
          subtitle: '検索結果から候補登録。',
        ),
        const SizedBox(height: 8),
        const _FlowStepLine(
          number: '3',
          title: 'ROOMでコレ',
          subtitle: 'コレ一覧のURLからROOMでコレ。',
        ),
      ],
    );
  }
}

class _FlowStepLine extends StatelessWidget {
  const _FlowStepLine({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            number,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 下部のサブ導線：コレ一覧（ROOMコレタブと補完）。
class _HomeCollectionListLink extends StatelessWidget {
  const _HomeCollectionListLink({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        Icons.collections_bookmark_outlined,
        size: 20,
        color: AppColors.accentPrimary,
      ),
      label: Text(
        'コレ一覧を開く',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.accentPrimary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentPrimary,
        side: BorderSide(
          color: AppColors.accentPrimary.withValues(alpha: 0.45),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(double.infinity, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
      ),
    );
  }
}

class _TodayRecommendationsEntryCard extends StatelessWidget {
  const _TodayRecommendationsEntryCard({
    required this.totalCount,
    required this.pendingCount,
    required this.isCompleted,
    required this.onOpen,
  });

  final int totalCount;
  final int pendingCount;
  final bool isCompleted;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final body = totalCount == 0
        ? 'タップで候補を作成'
        : isCompleted
        ? '本日は完了・明日更新'
        : '未処理 $pendingCount / $totalCount';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        splashColor: AppColors.textPrimary.withValues(alpha: 0.06),
        highlightColor: AppColors.textPrimary.withValues(alpha: 0.04),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 22,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日のおすすめコレ候補',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ② 4 枚統一のコンパクトメトリクス（2×2、タップで遷移）。
class _RoomStatsCardGrid extends StatelessWidget {
  const _RoomStatsCardGrid({
    required this.candidateTotal,
    required this.doneTotal,
    required this.todayDoneCount,
    required this.lastDoneAt,
    required this.onCandidateTap,
    required this.onDoneTap,
    required this.onTodayTap,
    required this.onLastCollectTap,
  });

  final int candidateTotal;
  final int doneTotal;
  final int todayDoneCount;
  final DateTime? lastDoneAt;
  final VoidCallback onCandidateTap;
  final VoidCallback onDoneTap;
  final VoidCallback onTodayTap;
  final VoidCallback onLastCollectTap;

  @override
  Widget build(BuildContext context) {
    final lastPrimary = lastDoneAt == null ? '—' : _formatDateTime(lastDoneAt!);

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RoomMetricTile(
                  title: 'コレ候補',
                  valueText: '$candidateTotal',
                  caption: '一覧へ',
                  icon: Icons.bookmark_outline_rounded,
                  accent: const Color(0xFF1565C0),
                  iconBackground: const Color(0xFFE3F2FD),
                  emphasizeValue: true,
                  onTap: onCandidateTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RoomMetricTile(
                  title: 'コレ済',
                  valueText: '$doneTotal',
                  caption: '一覧へ',
                  icon: Icons.task_alt_rounded,
                  accent: const Color(0xFF2E7D32),
                  iconBackground: const Color(0xFFE8F5E9),
                  emphasizeValue: true,
                  onTap: onDoneTap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RoomMetricTile(
                  title: '今日のコレ',
                  valueText: '$todayDoneCount',
                  caption: '活動へ',
                  icon: Icons.today_rounded,
                  accent: AppColors.accentPrimary,
                  iconBackground: AppColors.accentLightest,
                  emphasizeValue: true,
                  onTap: onTodayTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RoomMetricTile(
                  title: '前回コレ',
                  valueText: lastPrimary,
                  caption: '活動へ',
                  icon: Icons.history_rounded,
                  accent: const Color(0xFF5C6BC0),
                  iconBackground: const Color(0xFFE8EAF6),
                  emphasizeValue: false,
                  onTap: onLastCollectTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _RoomMetricTile extends StatelessWidget {
  const _RoomMetricTile({
    required this.title,
    required this.valueText,
    required this.caption,
    required this.icon,
    required this.accent,
    required this.iconBackground,
    required this.emphasizeValue,
    required this.onTap,
  });

  final String title;
  final String valueText;
  final String caption;
  final IconData icon;
  final Color accent;
  final Color iconBackground;
  final bool emphasizeValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                valueText,
                textAlign: TextAlign.right,
                maxLines: emphasizeValue ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: emphasizeValue
                    ? Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.05,
                        fontSize: 30,
                      )
                    : Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.15,
                        fontSize: 18,
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                caption,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentCandidatesPanel extends StatelessWidget {
  const _RecentCandidatesPanel({
    required this.candidates,
    required this.onOpenList,
  });

  final List<RakutenManagedProduct> candidates;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '候補はまだありません',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'まずは「楽天で検索」から追加してください。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < candidates.length; i++) ...[
            _RecentCandidateTile(product: candidates[i], onTap: onOpenList),
            if (i < candidates.length - 1) const Divider(height: 1, indent: 72),
          ],
        ],
      ),
    );
  }
}

class _RecentCandidateTile extends StatelessWidget {
  const _RecentCandidateTile({required this.product, required this.onTap});

  final RakutenManagedProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumb(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.shopName.isEmpty ? 'ショップ名なし' : product.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ExtractionChip(status: product.extractionStatus),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _thumb() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        color: const Color(0xFFE3F2FD),
        child: product.imageUrl.isNotEmpty
            ? Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.image_outlined,
                  size: 22,
                  color: AppColors.textTertiary,
                ),
              )
            : const Icon(
                Icons.image_outlined,
                size: 22,
                color: AppColors.textTertiary,
              ),
      ),
    );
  }
}

class _ExtractionChip extends StatelessWidget {
  const _ExtractionChip({required this.status});

  final RakutenUrlExtractionStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;
    switch (status) {
      case RakutenUrlExtractionStatus.notStarted:
        label = 'URL準備・待機';
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
      case RakutenUrlExtractionStatus.extracting:
        label = 'URL取得中';
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
      case RakutenUrlExtractionStatus.success:
        label = 'URL取得済み';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
      case RakutenUrlExtractionStatus.failed:
        label = 'URL取得失敗';
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
