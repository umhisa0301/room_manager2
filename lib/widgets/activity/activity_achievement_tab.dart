import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/activity_log.dart';
import '../../models/rakuten_managed_product.dart';
import '../../models/room_activity_event.dart';
import '../../models/room_colle_list_filters.dart';
import '../../navigation/app_shell_controller.dart';
import '../../navigation/rakuten_search_navigator.dart';
import '../../screens/today_recommendations_screen.dart';
import '../../services/rakuten_room_home_stats.dart';
import '../../services/room_collect_post_limit.dart';
import '../../services/room_kpi_calculator.dart';
import '../../state/activity_log_provider.dart';
import '../../state/rakuten_managed_product_provider.dart';
import '../../state/room_activity_event_provider.dart';
import '../../state/today_recommendation_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'activity_navigation_helpers.dart';
import 'activity_screen_layout.dart';

/// 活動画面「実績」タブ（達成感・上限・ログ・週次）。
class ActivityAchievementTab extends StatefulWidget {
  const ActivityAchievementTab({
    super.key,
    required this.onRefresh,
    required this.bottomInset,
    required this.fabTrailingPadding,
    required this.leadingTabStrip,
  });

  final Future<void> Function() onRefresh;
  final double bottomInset;
  final double fabTrailingPadding;
  final Widget Function() leadingTabStrip;

  @override
  State<ActivityAchievementTab> createState() => _ActivityAchievementTabState();
}

class _ActivityAchievementTabState extends State<ActivityAchievementTab> {
  static const List<int> _milestones = [10, 50, 100, 200];
  int? _flashMilestone;
  int? _prevTodayPostsForMilestone;

  @override
  Widget build(BuildContext context) {
    return Consumer5<
      RakutenManagedProductProvider,
      RoomActivityEventProvider,
      ActivityLogProvider,
      AppShellController,
      TodayRecommendationProvider
    >(
      builder: (context, room, act, logProv, shell, recProv, _) {
        final items = room.items;
        final events = act.events;
        final now = DateTime.now();
        final collectLimit = RoomCollectPostLimitSnapshot.compute(
          items: items,
          events: events,
          now: now,
        );
        final todayPosts = collectLimit.todayCount;
        _syncMilestones(todayPosts);

        final kpi = RoomKpiCalculator.calculate(
          products: items
              .map(RoomKpiProductRecord.fromManagedProduct)
              .toList(growable: false),
          events: events,
          now: now,
        );
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayCandidatesEvents = activityCountEventsOnLocalDay(
          events,
          todayStart,
          {RoomActivityEventType.candidateAdded},
        );
        final todayCandidatesFallback = _countTodayNewCandidates(items, now);
        final todayCandidates = todayCandidatesEvents > 0
            ? todayCandidatesEvents
            : todayCandidatesFallback;
        final commentCopies = logProv.getTodayLog()?.commentCount ?? 0;
        final streak = kpi.consecutiveActiveDays;

        final bottomPad = widget.bottomInset + 32;

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              ActivityScreenLayout.paddingH,
              8,
              ActivityScreenLayout.paddingH + widget.fabTrailingPadding,
              bottomPad,
            ),
            children: [
              widget.leadingTabStrip(),
              if (_flashMilestone != null) ...[
                _MilestoneToast(
                  milestone: _flashMilestone!,
                  onDismiss: () => setState(() => _flashMilestone = null),
                ),
                const SizedBox(height: ActivityScreenLayout.sectionGap),
              ],
              _AchievementHeroCard(
                shell: shell,
                items: items,
                todayPosts: todayPosts,
                todayCandidates: todayCandidates,
                commentCopies: commentCopies,
                streakDays: streak,
                recPendingCount: recProv.pendingCount,
              ),
              const SizedBox(height: ActivityScreenLayout.sectionGap),
              _RoomPostLimitCard(
                snapshot: collectLimit,
                shell: shell,
              ),
              const SizedBox(height: ActivityScreenLayout.sectionGap),
              _WeekTotalBarsCard(
                items: items,
                events: events,
                activityLogs: logProv.logs,
                anchor: now,
              ),
              const SizedBox(height: ActivityScreenLayout.sectionGap),
              _TodayActivityLogSection(
                events: events,
                items: items,
                now: now,
                shell: shell,
              ),
            ],
          ),
        );
      },
    );
  }

  void _syncMilestones(int todayPosts) {
    final prev = _prevTodayPostsForMilestone;
    _prevTodayPostsForMilestone = todayPosts;
    if (prev == null) return;

    int? crossedMax;
    for (final m in _milestones) {
      if (prev < m && todayPosts >= m) {
        crossedMax = m;
      }
    }
    if (crossedMax != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _flashMilestone = crossedMax);
      });
    }
  }

  static int _countTodayNewCandidates(
    List<RakutenManagedProduct> items,
    DateTime now,
  ) {
    final target = DateTime(now.year, now.month, now.day);
    var count = 0;
    for (final e in items) {
      if (e.status != RakutenManagedProductStatus.candidate) continue;
      final d = DateTime(e.addedAt.year, e.addedAt.month, e.addedAt.day);
      if (d == target) count++;
    }
    return count;
  }
}

class _MilestoneToast extends StatelessWidget {
  const _MilestoneToast({
    required this.milestone,
    required this.onDismiss,
  });

  final int milestone;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      onEnd: () {
        Future<void>.delayed(const Duration(milliseconds: 2200), onDismiss);
      },
      builder: (context, t, child) {
        return Transform.scale(
          scale: 0.92 + 0.08 * t,
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );
      },
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        elevated: true,
        radius: ActivityScreenLayout.cardRadius,
        borderColor: AppColors.accentPrimary.withValues(alpha: 0.35),
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.accentPrimary,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ROOM投稿 $milestone 件',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'いいペースです。この調子で続けましょう',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.check_circle_rounded, color: AppColors.accentSecondary),
          ],
        ),
      ),
    );
  }
}

class _AchievementHeroCard extends StatelessWidget {
  const _AchievementHeroCard({
    required this.shell,
    required this.items,
    required this.todayPosts,
    required this.todayCandidates,
    required this.commentCopies,
    required this.streakDays,
    required this.recPendingCount,
  });

  final AppShellController shell;
  final List<RakutenManagedProduct> items;
  final int todayPosts;
  final int todayCandidates;
  final int commentCopies;
  final int streakDays;
  final int recPendingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emptyDay =
        todayPosts == 0 && todayCandidates == 0 && commentCopies == 0;
    final primaryLine = emptyDay
        ? '今日はこれからROOM運用を始めましょう'
        : '今日もROOM運用できています';
    final subLine = emptyDay
        ? 'まずはおすすめコレを1件確認すると、流れが作れます'
        : '小さな積み上げが次の反応につながります';

    final candStock = items
        .where((e) => e.status == RakutenManagedProductStatus.candidate)
        .length;
    final showSearchSecondary = candStock == 0 && recPendingCount == 0;

    return AppCard(
      padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
      elevated: true,
      radius: ActivityScreenLayout.cardRadius,
      borderColor: AppColors.accentPrimary.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日の実績',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            primaryLine,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.25,
              color: AppColors.textPrimary,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subLine,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 340;
              final chips = <Widget>[
                _metricChip(
                  context,
                  labelPrimary: 'ROOM',
                  labelSecondary: '投稿',
                  value: '$todayPosts',
                  icon: Icons.rocket_launch_rounded,
                  twoLineLabel: narrow,
                ),
                _metricChip(
                  context,
                  labelPrimary: '候補に',
                  labelSecondary: '追加',
                  value: '$todayCandidates',
                  icon: Icons.add_circle_outline_rounded,
                  twoLineLabel: true,
                ),
                _metricChip(
                  context,
                  labelPrimary: 'コメント',
                  labelSecondary: 'コピー',
                  value: '$commentCopies',
                  icon: Icons.content_copy_rounded,
                  twoLineLabel: true,
                ),
                _metricChip(
                  context,
                  labelPrimary: '連続',
                  labelSecondary: '活動',
                  value: streakDays <= 0 ? '0' : '$streakDays',
                  valueSuffix: narrow ? '' : '日',
                  icon: Icons.local_fire_department_rounded,
                  twoLineLabel: narrow,
                ),
              ];
              if (narrow) {
                return Column(
                  children: [
                    for (var i = 0; i < chips.length; i += 2)
                      Padding(
                        padding: EdgeInsets.only(
                            bottom: i + 2 < chips.length ? 8 : 0),
                        child: Row(
                          children: [
                            Expanded(child: chips[i]),
                            if (i + 1 < chips.length) ...[
                              const SizedBox(width: 8),
                              Expanded(child: chips[i + 1]),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: chips[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'すぐできること',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const TodayRecommendationsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: const Text('おすすめコレ'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: AppColors.textOnAccent,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: showSearchSecondary
                    ? OutlinedButton.icon(
                        onPressed: () => openRakutenSearchScreen(context),
                        icon: const Icon(Icons.travel_explore_rounded, size: 20),
                        label: const Text('候補を探す'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => shell.selectTab(2),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 20,
                        ),
                        label: const Text('コメント準備'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(
    BuildContext context, {
    required String labelPrimary,
    required String labelSecondary,
    required String value,
    String valueSuffix = '',
    required IconData icon,
    required bool twoLineLabel,
  }) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.accentPrimary),
              const SizedBox(width: 6),
              Expanded(
                child: twoLineLabel
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labelPrimary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                          ),
                          Text(
                            labelSecondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      )
                    : Text(
                        '$labelPrimary$labelSecondary',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$value$valueSuffix',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  height: 1.1,
                ),
          ),
        ],
      ),
    );
  }
}

class _RoomPostLimitCard extends StatelessWidget {
  const _RoomPostLimitCard({
    required this.snapshot,
    required this.shell,
  });

  final RoomCollectPostLimitSnapshot snapshot;
  final AppShellController shell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snap = snapshot;
    final agg = _aggregateState(snap);

    return AppCard(
      padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
      elevated: true,
      radius: ActivityScreenLayout.cardRadius,
      borderColor: AppColors.divider.withValues(alpha: 0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, color: _stateColor(agg), size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ROOM投稿の上限',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '楽天ROOMの目安：1日200件・1時間100件',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '今日 ${snap.todayCount} / ${RoomCollectPostLimitSnapshot.dailyLimit}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'この1時間 ${snap.hourCount} / ${RoomCollectPostLimitSnapshot.hourlyLimit}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          _limitGaugeRow(
            context,
            label: '今日の投稿',
            used: snap.todayCount,
            limit: RoomCollectPostLimitSnapshot.dailyLimit,
            state: snap.dailyBarState,
            remainingLabel: '本日あと ${snap.dailyRemaining} 件',
            paceHint: _paceHint(
              reached: snap.isDailyReached,
              used: snap.todayCount,
              limit: RoomCollectPostLimitSnapshot.dailyLimit,
            ),
          ),
          const SizedBox(height: 14),
          _limitGaugeRow(
            context,
            label: 'この1時間の投稿',
            used: snap.hourCount,
            limit: RoomCollectPostLimitSnapshot.hourlyLimit,
            state: snap.hourlyBarState,
            remainingLabel: 'この1時間あと ${snap.hourlyRemaining} 件',
            paceHint: _paceHint(
              reached: snap.isHourlyReached,
              used: snap.hourCount,
              limit: RoomCollectPostLimitSnapshot.hourlyLimit,
            ),
            footnote: snap.isHourlyReached
                ? snap.recoveryFootnote(DateTime.now())
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            '上限に近い画面では、投稿操作が無効になり、この時間帯の上限メッセージが表示されます。',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              height: 1.35,
              fontSize: 12,
            ),
          ),
          if (snap.isAnyLimitReached) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snap.isDailyReached
                        ? '本日の上限です。時間を空けましょう'
                        : 'この時間帯の上限に達しています。少し時間を空けましょう',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppSecondaryButton(
                        label: '候補を整理',
                        onPressed: () => shell.openRoomCollect(
                          initialTabIndex: 0,
                          candidateStalePreset:
                              RoomColleStaleCandidatePreset.threePlus,
                        ),
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                      ),
                      AppSecondaryButton(
                        label: 'コメント',
                        onPressed: () => shell.selectTab(2),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _paceHint({
    required bool reached,
    required int used,
    required int limit,
  }) {
    if (reached) return '上限に達しました。時間を空けましょう';
    if (limit <= 0) return null;
    final ratio = used / limit;
    if (ratio >= 0.8) return '少しペースを落としましょう';
    return null;
  }

  Color _stateColor(_AggState s) {
    return switch (s) {
      _AggState.calm => AppColors.accentPrimary,
      _AggState.caution => const Color(0xFFE67E22),
      _AggState.danger => AppColors.error,
    };
  }

  _AggState _aggregateState(RoomCollectPostLimitSnapshot s) {
    if (s.isAnyLimitReached) return _AggState.danger;
    if (s.isDailyWarning || s.isHourlyWarning) return _AggState.caution;
    return _AggState.calm;
  }

  Widget _limitGaugeRow(
    BuildContext context, {
    required String label,
    required int used,
    required int limit,
    required RoomCollectPostLimitBarState state,
    required String remainingLabel,
    String? paceHint,
    String? footnote,
  }) {
    final color = switch (state) {
      RoomCollectPostLimitBarState.normal => AppColors.accentPrimary,
      RoomCollectPostLimitBarState.warning => const Color(0xFFE67E22),
      RoomCollectPostLimitBarState.reached => AppColors.error,
    };
    final progress = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                remainingLabel,
                textAlign: TextAlign.end,
                maxLines: 2,
                softWrap: true,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: state == RoomCollectPostLimitBarState.normal
                      ? AppColors.textSecondary
                      : color,
                ),
              ),
            ),
          ],
        ),
        if (paceHint != null) ...[
          const SizedBox(height: 4),
          Text(
            paceHint,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: progress,
            backgroundColor: AppColors.surfaceVariant,
            color: color,
          ),
        ),
        if (footnote != null && footnote.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            footnote,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

enum _AggState { calm, caution, danger }

class _TodayActivityLogSection extends StatefulWidget {
  const _TodayActivityLogSection({
    required this.events,
    required this.items,
    required this.now,
    required this.shell,
  });

  final List<RoomActivityEvent> events;
  final List<RakutenManagedProduct> items;
  final DateTime now;
  final AppShellController shell;

  @override
  State<_TodayActivityLogSection> createState() =>
      _TodayActivityLogSectionState();
}

class _TodayActivityLogSectionState extends State<_TodayActivityLogSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final todayStart =
        DateTime(widget.now.year, widget.now.month, widget.now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final list = widget.events
        .where(
          (e) =>
              !e.createdAt.isBefore(todayStart) &&
              e.createdAt.isBefore(tomorrowStart),
        )
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (list.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
        elevated: true,
        radius: ActivityScreenLayout.cardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日のログ',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'まだログはありません',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'ROOMコレで商品を動かすと、ここに活動が積み上がります',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                    fontSize: 15,
                  ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => widget.shell.openRoomCollect(initialTabIndex: 0),
              icon: const Icon(Icons.collections_bookmark_outlined),
              label: const Text('ROOMコレを開く'),
            ),
          ],
        ),
      );
    }

    final cap = _expanded ? list.length : list.length.clamp(0, 3);
    final hasMore = list.length > 3;

    return AppCard(
      padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
      elevated: true,
      radius: ActivityScreenLayout.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日のログ',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '最新の活動です',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < cap; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
            _ActivityLogTile(
              event: list[i],
              product: activityFindProduct(widget.items, list[i].productId),
            ),
          ],
          if (hasMore)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.accentPrimary,
                ),
                label: Text(
                  _expanded ? '閉じる' : 'もっと見る',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityLogTile extends StatelessWidget {
  const _ActivityLogTile({
    required this.event,
    required this.product,
  });

  final RoomActivityEvent event;
  final RakutenManagedProduct? product;

  @override
  Widget build(BuildContext context) {
    final caption = _caption(event.type);
    final time =
        '${event.createdAt.hour.toString().padLeft(2, '0')}:${event.createdAt.minute.toString().padLeft(2, '0')}';

    final leading = _usesProductVisual(event.type)
        ? _ProductThumb(url: product?.imageUrl ?? '')
        : CircleAvatar(
            backgroundColor: AppColors.accentLight,
            child: Icon(Icons.notes_rounded, color: AppColors.accentPrimary),
          );

    return InkWell(
      onTap: () => activityNavigateForProductId(
        context,
        productId: event.productId,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  bool _usesProductVisual(RoomActivityEventType t) {
    return t != RoomActivityEventType.openedRakuten;
  }

  String _caption(RoomActivityEventType t) {
    return switch (t) {
      RoomActivityEventType.candidateAdded => '候補に追加',
      RoomActivityEventType.movedToCored => 'ROOM投稿（コレ済）',
      RoomActivityEventType.openedRakuten => '楽天ページを開く',
      RoomActivityEventType.feedbackLiked => '評価を変更：反応あり',
      RoomActivityEventType.feedbackSold => '評価を変更：売れた',
      RoomActivityEventType.feedbackWeak => '評価を変更：微妙',
      RoomActivityEventType.deleted => '候補から削除',
    };
  }

  String _subtitle() {
    final name = product?.itemName.trim() ?? '';
    switch (event.type) {
      case RoomActivityEventType.openedRakuten:
        return name.isEmpty ? '商品ページへ遷移' : name;
      default:
        return name.isEmpty ? '商品情報を取得できませんでした' : name;
    }
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final u = url.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        color: AppColors.surfaceVariant,
        child: u.isEmpty
            ? Icon(Icons.image_not_supported_outlined,
                color: AppColors.textTertiary)
            : Image.network(
                u,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
      ),
    );
  }
}

class _WeekTotalBarsCard extends StatelessWidget {
  const _WeekTotalBarsCard({
    required this.items,
    required this.events,
    required this.activityLogs,
    required this.anchor,
  });

  final List<RakutenManagedProduct> items;
  final List<RoomActivityEvent> events;
  final List<ActivityLog> activityLogs;
  final DateTime anchor;

  static const double _chartOuterHeight = 150;
  static const double _labelBlockHeight = 40;
  static const double _barMaxFraction = 0.8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime(anchor.year, anchor.month, anchor.day);
    final series = <({
      DateTime day,
      int posts,
      int cand,
      int comments,
    })>[];
    final logMap = {for (final l in activityLogs) l.dateKey: l};
    for (var i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final posts = RakutenRoomHomeStats.countDoneOnLocalCalendarDay(
        items,
        day,
      );
      final cand = activityCountEventsOnLocalDay(
        events,
        day,
        {RoomActivityEventType.candidateAdded},
      );
      final key = activityLogDateKey(day);
      final comments = logMap[key]?.commentCount ?? 0;
      series.add((day: day, posts: posts, cand: cand, comments: comments));
    }

    var maxVal = 0;
    for (final e in series) {
      final t = e.posts + e.cand + e.comments;
      if (t > maxVal) maxVal = t;
    }
    final denom = maxVal <= 0 ? 1 : maxVal;
    final barBand = _chartOuterHeight * _barMaxFraction;

    return AppCard(
      padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
      elevated: true,
      radius: ActivityScreenLayout.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今週の積み上げ',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '7日間の1日あたりの合計アクションです',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: _chartOuterHeight,
            child: LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 340;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in series)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: LayoutBuilder(
                                    builder: (context, inner) {
                                      final maxW = inner.maxWidth;
                                      final barW =
                                          (maxW * 0.72).clamp(18.0, 24.0);
                                      final total =
                                          e.posts + e.cand + e.comments;
                                      final barH = total <= 0
                                          ? 5.0
                                          : (barBand * (total / denom))
                                              .clamp(14.0, barBand);
                                      final fill = total <= 0
                                          ? AppColors.divider
                                              .withValues(alpha: 0.55)
                                          : AppColors.accentPrimary;
                                      return Container(
                                        width: barW,
                                        height: barH,
                                        decoration: BoxDecoration(
                                          color: fill,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(9),
                                            bottom: Radius.circular(4),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: _labelBlockHeight,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    if (!narrow)
                                      Text(
                                        '${e.day.day}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    Text(
                                      _weekdayJa(e.day.weekday),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        fontSize: 11,
                                        color: AppColors.textTertiary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legendDot(theme, AppColors.accentPrimary, '投稿'),
              _legendDot(theme, const Color(0xFF5C6BC0), '候補'),
              _legendDot(theme, const Color(0xFF2E7D32), 'コメント'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '棒は1日の合計アクションです',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _legendDot(ThemeData theme, Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  static String _weekdayJa(int weekday) {
    const w = ['月', '火', '水', '木', '金', '土', '日'];
    return w[weekday - 1];
  }
}
