import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/room_activity_event.dart';
import '../models/room_colle_list_filters.dart';
import '../navigation/app_shell_controller.dart';
import '../services/rakuten_room_home_stats.dart';
import '../services/room_kpi_calculator.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/room_activity_event_provider.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../theme/app_theme.dart';

/// コレ活動のダッシュボード（アプリ内のコレ済データを集計して可視化）。
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RakutenManagedProductProvider>().refreshManagedProductList(
        showLoadingIndicator: false,
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.read<AppShellController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ROOM運用ダッシュボード'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '今日'),
            Tab(text: 'ダッシュボード'),
            Tab(text: '振り返り'),
          ],
        ),
      ),
      body: SafeArea(
        child:
            Consumer4<
              RakutenManagedProductProvider,
              RoomActivityEventProvider,
              SavedShopProvider,
              TodayRecommendationProvider
            >(
              builder: (context, room, act, saved, rec, _) {
                final items = room.items;
                final now = DateTime.now();
                final kpiProducts = items
                    .map(RoomKpiProductRecord.fromManagedProduct)
                    .toList(growable: false);
                final kpi = RoomKpiCalculator.calculate(
                  products: kpiProducts,
                  events: act.events,
                  now: now,
                );
                final candidateCount = RakutenRoomHomeStats.countCandidates(
                  items,
                );
                final doneCount = RakutenRoomHomeStats.countDone(items);
                final todayDoneCount =
                    RakutenRoomHomeStats.countDoneOnLocalCalendarDay(items, now);
                final weeklyDoneTotal = RakutenRoomHomeStats
                    .doneCountsRollingDays(items, now, 7)
                    .fold<int>(0, (a, b) => a + b.count);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.screenPaddingH,
                        10,
                        AppDimensions.screenPaddingH,
                        8,
                      ),
                      child: _ActivityPurposeBanner(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.screenPaddingH,
                      ),
                      child: _ActivityKpiSummaryBar(
                        summary: kpi,
                        todayDoneCount: todayDoneCount,
                        weeklyDoneCount: weeklyDoneTotal,
                        candidateCount: candidateCount,
                        doneCount: doneCount,
                        savedShopCount: saved.shops.length,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _ActivityTodayEventsTab(
                            events: act.events,
                            now: now,
                            onRefresh: () => room.refreshManagedProductList(
                              showLoadingIndicator: true,
                            ),
                          ),
                          _ActivityWeekOverviewTab(
                            items: items,
                            kpi: kpi,
                            todayDoneCount: todayDoneCount,
                            weeklyDoneCount: weeklyDoneTotal,
                            candidateCount: candidateCount,
                            doneCount: doneCount,
                            savedShopCount: saved.shops.length,
                            recommendPending: rec.pendingCount,
                            recommendTotal: rec.totalCount,
                            recentCandidateCount: _countTodayCandidates(
                              items,
                              now,
                            ),
                            now: now,
                            onRefresh: () => room.refreshManagedProductList(
                              showLoadingIndicator: true,
                            ),
                          ),
                          _ActivityProductRankingTab(
                            items: items,
                            onRefresh: () => room.refreshManagedProductList(
                              showLoadingIndicator: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.screenPaddingH,
                        6,
                        AppDimensions.screenPaddingH,
                        72,
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              shell.openRoomCollect(initialTabIndex: 0);
                            },
                            icon: const Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                            ),
                            label: const Text('コレ候補'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              shell.openRoomCollect(
                                candidateStalePreset:
                                    RoomColleStaleCandidatePreset.threePlus,
                              );
                            },
                            icon: const Icon(Icons.schedule_rounded, size: 18),
                            label: const Text('放置整理'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              shell.openRoomCollect(initialTabIndex: 1);
                            },
                            icon: const Icon(Icons.task_alt_rounded, size: 18),
                            label: const Text('コレ済'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }

  int _countTodayCandidates(List<RakutenManagedProduct> items, DateTime now) {
    final target = DateTime(now.year, now.month, now.day);
    var count = 0;
    for (final e in items) {
      if (e.status != RakutenManagedProductStatus.candidate) continue;
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      if (d == target) count++;
    }
    return count;
  }
}

String _activityEventCaption(RoomActivityEvent e) {
  switch (e.type) {
    case RoomActivityEventType.candidateAdded:
      return '候補を登録';
    case RoomActivityEventType.movedToCored:
      return 'コレ済に移動';
    case RoomActivityEventType.openedRakuten:
      return '楽天ページを開く';
    case RoomActivityEventType.feedbackLiked:
      return '反応よかった';
    case RoomActivityEventType.feedbackSold:
      return '売れた';
    case RoomActivityEventType.feedbackWeak:
      return '微妙';
    case RoomActivityEventType.deleted:
      return '候補から削除';
  }
}

String _formatHm(DateTime d) {
  String t(int n) => n.toString().padLeft(2, '0');
  return '${t(d.hour)}:${t(d.minute)}';
}

class _ActivityKpiSummaryBar extends StatelessWidget {
  const _ActivityKpiSummaryBar({
    required this.summary,
    required this.todayDoneCount,
    required this.weeklyDoneCount,
    required this.candidateCount,
    required this.doneCount,
    required this.savedShopCount,
  });

  final RoomKpiSummary summary;
  final int todayDoneCount;
  final int weeklyDoneCount;
  final int candidateCount;
  final int doneCount;
  final int savedShopCount;

  @override
  Widget build(BuildContext context) {
    Widget chip(String k, String v, String hint, IconData icon, Color iconColor) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    k,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              v,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 1),
            Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '活動サマリー',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip(
              '今日のコレ数',
              '$todayDoneCount件',
              '今日処理できた件数',
              Icons.today_rounded,
              const Color(0xFF1565C0),
            ),
            chip(
              '週間コレ数',
              '$weeklyDoneCount件',
              '直近7日合計',
              Icons.show_chart_rounded,
              const Color(0xFF5C6BC0),
            ),
            chip(
              '候補ストック',
              '$candidateCount件',
              '次に処理できる候補',
              Icons.inventory_2_outlined,
              const Color(0xFFE65100),
            ),
            chip(
              'コレ済累計',
              '$doneCount件',
              '積み上げ済みの成果',
              Icons.task_alt_rounded,
              const Color(0xFF2E7D32),
            ),
            chip(
              '保存ショップ',
              '$savedShopCount件',
              '次回探索の土台',
              Icons.bookmarks_outlined,
              const Color(0xFF6A1B9A),
            ),
            chip(
              '放置候補(3日+)',
              '${summary.staleCandidateCount}件',
              '整理優先の候補',
              Icons.schedule_rounded,
              const Color(0xFFEF6C00),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivityTodayEventsTab extends StatelessWidget {
  const _ActivityTodayEventsTab({
    required this.events,
    required this.now,
    required this.onRefresh,
  });

  final List<RoomActivityEvent> events;
  final DateTime now;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final list =
        events
            .where(
              (e) =>
                  !e.createdAt.isBefore(todayStart) &&
                  e.createdAt.isBefore(tomorrowStart),
            )
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  '今日のログはまだありません。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '商品登録・コレ済移行・楽天を開く・評価ボタンなどがここに積み上がります。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.4,
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenPaddingH,
                8,
                AppDimensions.screenPaddingH,
                100,
              ),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = list[i];
                return ListTile(
                  dense: true,
                  title: Text(
                    _activityEventCaption(e),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${e.productId}  ·  ${_formatHm(e.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
    );
  }
}

class _ActivityWeekOverviewTab extends StatelessWidget {
  const _ActivityWeekOverviewTab({
    required this.items,
    required this.kpi,
    required this.todayDoneCount,
    required this.weeklyDoneCount,
    required this.candidateCount,
    required this.doneCount,
    required this.savedShopCount,
    required this.recommendPending,
    required this.recommendTotal,
    required this.recentCandidateCount,
    required this.now,
    required this.onRefresh,
  });

  final List<RakutenManagedProduct> items;
  final RoomKpiSummary kpi;
  final int todayDoneCount;
  final int weeklyDoneCount;
  final int candidateCount;
  final int doneCount;
  final int savedShopCount;
  final int recommendPending;
  final int recommendTotal;
  final int recentCandidateCount;
  final DateTime now;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final series = RakutenRoomHomeStats.doneCountsRollingDays(items, now, 7);
    final maxInWeek = series
        .map((e) => e.count)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final lastDone = RakutenRoomHomeStats.latestDoneAt(items);
    final story = kpi.weeklyActivityCount == 0
        ? 'まだ動きが少ない週です。まず1件コレすると、週間推移が伸び始めます。'
        : '今週は ${kpi.weeklyActivityCount} 件の活動があり、反応スコアは ${kpi.weeklyReactionScore} です。';
    final doneGoal = 5;
    final doneProgress = weeklyDoneCount > doneGoal ? doneGoal : weeklyDoneCount;
    final hint = recommendTotal == 0
        ? '今日のおすすめを作成して、今日の1件目を進めましょう。'
        : recommendPending > 0
            ? '今日のおすすめ残り $recommendPending 件から進めると、週目標に近づきます。'
            : '今日のおすすめは完了済みです。次は候補ストック整理がおすすめです。';

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.screenPaddingH,
          8,
          AppDimensions.screenPaddingH,
          100,
        ),
        children: [
          Text(
            '今週のまとめ',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            story,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          _ActivityGoalCard(
            title: '今週の進捗',
            progressLabel: '$weeklyDoneCount / $doneGoal 件',
            progressValue: doneGoal == 0 ? 0 : doneProgress / doneGoal,
            body: hint,
          ),
          const SizedBox(height: 16),
          _SevenDayTrendCard(series: series, maxCount: maxInWeek),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SmallMetricCard(
                  icon: Icons.bookmarks_outlined,
                  iconColor: const Color(0xFF6A1B9A),
                  title: '保存ショップ',
                  valueText: '$savedShopCount件',
                  caption: '発掘から再訪する基盤',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SmallMetricCard(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.accentPrimary,
                  title: 'おすすめ残件',
                  valueText: recommendTotal == 0 ? '未生成' : '$recommendPending件',
                  caption: recommendTotal == 0 ? '今日のおすすめ未作成' : '今日のおすすめ未処理件数',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SmallMetricCard(
                  icon: Icons.bookmark_add_outlined,
                  iconColor: const Color(0xFF1565C0),
                  title: '最近候補追加',
                  valueText: '$recentCandidateCount件',
                  caption: '今日追加した候補数',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ActivityActionHintsCard(
            todayDoneCount: todayDoneCount,
            candidateCount: candidateCount,
            doneCount: doneCount,
            staleCandidateCount: kpi.staleCandidateCount,
          ),
          const SizedBox(height: 16),
          _LastCollectCard(lastDoneAt: lastDone),
        ],
      ),
    );
  }
}

class _ActivityProductRankingTab extends StatelessWidget {
  const _ActivityProductRankingTab({
    required this.items,
    required this.onRefresh,
  });

  final List<RakutenManagedProduct> items;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final sorted = List<RakutenManagedProduct>.from(items);
    sorted.sort((a, b) {
      final ra = RoomKpiProductRecord.fromManagedProduct(a).reactionRankScore;
      final rb = RoomKpiProductRecord.fromManagedProduct(b).reactionRankScore;
      final c = rb.compareTo(ra);
      if (c != 0) return c;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: sorted.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [Text('まだ商品データがありません。')],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenPaddingH,
                8,
                AppDimensions.screenPaddingH,
                100,
              ),
              itemCount: sorted.length.clamp(0, 40),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = sorted[i];
                final r = RoomKpiProductRecord.fromManagedProduct(p);
                final flags = <String>[];
                if (r.isSold) flags.add('売れた');
                if (r.isLiked) flags.add('反応');
                if (r.isWeak) flags.add('微妙');
                final flagStr = flags.isEmpty ? '評価なし' : flags.join(' / ');
                return ListTile(
                  dense: true,
                  title: Text(
                    p.itemName.trim().isEmpty ? p.productId : p.itemName.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'スコア ${r.reactionRankScore}  ·  $flagStr',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
    );
  }
}

class _ActivityPurposeBanner extends StatelessWidget {
  const _ActivityPurposeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.insights_rounded,
            size: 28,
            color: AppColors.accentPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日の進み具合と次アクションを確認',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'この画面では「どれだけ進んだか」と「次に何をすると良いか」をまとめて確認できます。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityGoalCard extends StatelessWidget {
  const _ActivityGoalCard({
    required this.title,
    required this.progressLabel,
    required this.progressValue,
    required this.body,
  });

  final String title;
  final String progressLabel;
  final double progressValue;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            progressLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progressValue.clamp(0, 1),
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.accentPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(height: 1.35, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ActivityActionHintsCard extends StatelessWidget {
  const _ActivityActionHintsCard({
    required this.todayDoneCount,
    required this.candidateCount,
    required this.doneCount,
    required this.staleCandidateCount,
  });

  final int todayDoneCount;
  final int candidateCount;
  final int doneCount;
  final int staleCandidateCount;

  @override
  Widget build(BuildContext context) {
    final hints = <String>[
      if (todayDoneCount == 0) '今日はまず1件コレ済にすると、継続の流れを作れます。',
      if (staleCandidateCount > 0) '放置候補が$staleCandidateCount件あります。先に整理すると候補管理が軽くなります。',
      if (candidateCount < 3) '候補ストックが少なめです。検索画面から候補追加しておくと次が楽になります。',
      if (doneCount >= 10) 'コレ済が$doneCount件まで積み上がっています。この調子で維持しましょう。',
    ];
    final list = hints.isEmpty ? const <String>['次の候補を1件追加して、明日の作業を軽くしましょう。'] : hints;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '次にやることのヒント',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in list) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _SmallMetricCard extends StatelessWidget {
  const _SmallMetricCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.valueText,
    required this.caption,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String valueText;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valueText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SevenDayTrendCard extends StatelessWidget {
  const _SevenDayTrendCard({required this.series, required this.maxCount});

  final List<({DateTime day, int count})> series;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final denom = maxCount > 0 ? maxCount : 1;
    const chartHeight = 112.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 22,
                color: AppColors.accentPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                '直近7日の推移',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '1日あたりのコレ済件数（端末の日付・0:00区切り）',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final e in series)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (e.count > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${e.count}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.accentPrimary,
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            height: chartHeight * 0.72 * (e.count / denom),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.accentPrimary.withValues(
                                    alpha: 0.85,
                                  ),
                                  AppColors.accentSecondary.withValues(
                                    alpha: 0.55,
                                  ),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final e in series)
                Expanded(
                  child: Text(
                    _weekdayShort(e.day),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              for (final e in series)
                Expanded(
                  child: Text(
                    '${e.day.month}/${e.day.day}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _weekdayShort(DateTime d) {
    const w = ['月', '火', '水', '木', '金', '土', '日'];
    return w[d.weekday - 1];
  }
}

class _LastCollectCard extends StatelessWidget {
  const _LastCollectCard({required this.lastDoneAt});

  final DateTime? lastDoneAt;

  @override
  Widget build(BuildContext context) {
    final label = lastDoneAt == null
        ? 'まだコレ済の記録がありません'
        : _formatDateTime(lastDoneAt!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 22,
                color: const Color(0xFF5C6BC0),
              ),
              const SizedBox(width: 8),
              Text(
                '最終コレ日時',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'アプリで最後にコレ済へ移した日時です。\n最近いつコレしたかを振り返る目安になります。',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: lastDoneAt == null
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
              height: 1.2,
              fontSize: lastDoneAt == null ? 16 : 26,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}年${d.month}月${d.day}日 ${two(d.hour)}:${two(d.minute)}';
  }
}
