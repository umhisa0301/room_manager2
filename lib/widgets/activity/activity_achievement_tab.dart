import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rakuten_managed_product.dart';
import '../../models/room_activity_event.dart';
import '../../navigation/app_shell_controller.dart';
import '../../navigation/rakuten_search_navigator.dart';
import '../../screens/today_recommendations_screen.dart';
import '../../services/rakuten_room_home_stats.dart';
import '../../services/room_collect_post_limit.dart';
import '../../services/room_kpi_calculator.dart';
import '../../state/rakuten_managed_product_provider.dart';
import '../../state/room_activity_event_provider.dart';
import '../../state/today_recommendation_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import 'activity_navigation_helpers.dart';
import 'activity_screen_layout.dart';

/// 活動画面「実績」タブ（達成感・上限・ログ・週次）。
class ActivityAchievementTab extends StatefulWidget {
  const ActivityAchievementTab({
    super.key,
    required this.onRefresh,
    required this.bottomInset,
    required this.scrollController,
  });

  final Future<void> Function() onRefresh;
  final double bottomInset;
  final ScrollController scrollController;

  @override
  State<ActivityAchievementTab> createState() => _ActivityAchievementTabState();
}

class _ActivityAchievementTabState extends State<ActivityAchievementTab> {
  static const List<int> _milestones = [10, 50, 100, 200];
  int? _flashMilestone;
  int? _prevTodayPostsForMilestone;

  @override
  Widget build(BuildContext context) {
    return Consumer4<
      RakutenManagedProductProvider,
      RoomActivityEventProvider,
      AppShellController,
      TodayRecommendationProvider
    >(
      builder: (context, room, act, shell, recProv, _) {
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
        final todayCalendarPosts =
            RakutenRoomHomeStats.countDoneOnLocalCalendarDay(
          items,
          todayStart,
        );
        final todayCandidatesEvents = activityCountEventsOnLocalDay(
          events,
          todayStart,
          {RoomActivityEventType.candidateAdded},
        );
        final todayCandidatesFallback = _countTodayNewCandidates(items, now);
        final todayCandidates = todayCandidatesEvents > 0
            ? todayCandidatesEvents
            : todayCandidatesFallback;
        final streak = kpi.consecutiveActiveDays;

        final bottomPad = widget.bottomInset;

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            controller: widget.scrollController,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              ActivityScreenLayout.paddingH,
              8,
              ActivityScreenLayout.paddingH,
              bottomPad,
            ),
            children: [
              if (_flashMilestone != null) ...[
                _MilestoneToast(
                  milestone: _flashMilestone!,
                  onDismiss: () => setState(() => _flashMilestone = null),
                ),
                const SizedBox(height: ActivityScreenLayout.sectionGap),
              ],
              _AchievementHeroCard(
                items: items,
                todayCalendarPosts: todayCalendarPosts,
                todayCandidates: todayCandidates,
                streakDays: streak,
                recPendingCount: recProv.pendingCount,
                collectLimit: collectLimit,
              ),
              const SizedBox(height: ActivityScreenLayout.sectionGap),
              _WeekTotalBarsCard(
                items: items,
                events: events,
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
    required this.items,
    required this.todayCalendarPosts,
    required this.todayCandidates,
    required this.streakDays,
    required this.recPendingCount,
    required this.collectLimit,
  });

  final List<RakutenManagedProduct> items;
  final int todayCalendarPosts;
  final int todayCandidates;
  final int streakDays;
  final int recPendingCount;
  final RoomCollectPostLimitSnapshot collectLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final postGoal = ActivityScreenLayout.dailyPostProgressGoal;
    final candGoal = ActivityScreenLayout.dailyCandidateProgressGoal;
    final emptyDay = todayCalendarPosts == 0 && todayCandidates == 0;
    final statusLine = emptyDay
        ? '今日0時〜 まだ動きがありません'
        : '今日0時〜現在の集計（上限の詳細はホーム）';

    final candStock = items
        .where((e) => e.status == RakutenManagedProductStatus.candidate)
        .length;
    final lowCandidates = todayCandidates < 3;

    final postPct = postGoal <= 0
        ? 0.0
        : (todayCalendarPosts / postGoal * 100).clamp(0.0, 100.0);
    final candPct = candGoal <= 0
        ? 0.0
        : (todayCandidates / candGoal * 100).clamp(0.0, 100.0);
    final todayProgressPct = ((postPct + candPct) / 2).round().clamp(0, 100);

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
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            statusLine,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROOM上限（要約）',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '24h ${collectLimit.todayCount}/${RoomCollectPostLimitSnapshot.dailyLimit}件　'
                  '1h ${collectLimit.hourCount}/${RoomCollectPostLimitSnapshot.hourlyLimit}件',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _compactTodayMetricTile(
                  context,
                  label: '投稿',
                  valueTop: '$todayCalendarPosts',
                  valueBottom: '/ $postGoal',
                  caption: '${postPct.round()}%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactTodayMetricTile(
                  context,
                  label: '候補',
                  valueTop: '$todayCandidates',
                  valueBottom: '/ $candGoal',
                  caption: '${candPct.round()}%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactTodayMetricTile(
                  context,
                  label: '連続',
                  valueTop: '${streakDays <= 0 ? 0 : streakDays}',
                  valueBottom: '日',
                  caption: '活動',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: todayProgressPct / 100.0,
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.accentPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '今日の目標まで 約$todayProgressPct%（投稿・候補の平均）',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'すぐできること',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const TodayRecommendationsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 22),
                  label: const Text('おすすめコレ'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: AppColors.textOnAccent,
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (lowCandidates &&
                  (candStock == 0 || recPendingCount == 0)) ...[
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  child: OutlinedButton.icon(
                    onPressed: () => openRakutenSearchScreen(context),
                    icon: const Icon(Icons.travel_explore_rounded, size: 22),
                    label: const Text('候補を探す'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size(double.infinity, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static Widget _compactTodayMetricTile(
    BuildContext context, {
    required String label,
    required String valueTop,
    required String valueBottom,
    required String caption,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valueTop,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  height: 1.05,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                valueBottom,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

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
                    maxLines: 2,
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
      RoomActivityEventType.feedbackWeak => '評価を変更：その他',
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

class _WeekTotalBarsCard extends StatefulWidget {
  const _WeekTotalBarsCard({
    required this.items,
    required this.events,
    required this.anchor,
  });

  final List<RakutenManagedProduct> items;
  final List<RoomActivityEvent> events;
  final DateTime anchor;

  static const Color _candBarColor = Color(0xFF5C6BC0);

  @override
  State<_WeekTotalBarsCard> createState() => _WeekTotalBarsCardState();
}

class _WeekTotalBarsCardState extends State<_WeekTotalBarsCard> {
  static const double _plotHeight = 168.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime(widget.anchor.year, widget.anchor.month, widget.anchor.day);
    final series = <({DateTime day, int posts, int cand})>[];

    for (var i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final posts = RakutenRoomHomeStats.countDoneOnLocalCalendarDay(
        widget.items,
        day,
      );
      var cand = activityCountEventsOnLocalDay(
        widget.events,
        day,
        {RoomActivityEventType.candidateAdded},
      );
      final candFallback = activityCountCandidatesAddedOnLocalCalendarDay(
        widget.items,
        day,
      );
      if (candFallback > cand) cand = candFallback;
      series.add((day: day, posts: posts, cand: cand));
    }

    var weekPosts = 0;
    var weekCand = 0;
    for (final e in series) {
      weekPosts += e.posts;
      weekCand += e.cand;
    }

    var maxVal = 0;
    for (final e in series) {
      final t = e.posts + e.cand;
      if (t > maxVal) maxVal = t;
    }
    final denom = maxVal <= 0 ? 1 : maxVal;

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
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今週合計',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '投稿：$weekPosts件　候補：$weekCand件',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '棒の高さは投稿＋候補の合計。真ん中の一行がその日内訳です。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _plotHeight,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 720),
              curve: Curves.easeOutCubic,
              builder: (context, anim, _) {
                return LayoutBuilder(
                  builder: (context, c) {
                    final narrow = c.maxWidth < 340;
                    final barBand = _plotHeight * 0.62;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final e in series)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: Column(
                                children: [
                                  const SizedBox(height: 2),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: LayoutBuilder(
                                        builder: (context, inner) {
                                          final maxW = inner.maxWidth;
                                          final barW = (maxW * 0.82)
                                              .clamp(22.0, 32.0);
                                          final total = e.posts + e.cand;
                                          final targetH = total <= 0
                                              ? 8.0
                                              : (barBand * (total / denom))
                                                  .clamp(20.0, barBand);
                                          final barH = targetH * anim;
                                          if (total <= 0) {
                                            return Container(
                                              width: barW,
                                              height: barH.clamp(4.0, 8.0),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: AppColors.divider
                                                    .withValues(alpha: 0.5),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '0',
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.textTertiary,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          return SizedBox(
                                            width: barW,
                                            height: barH,
                                            child: ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                top: Radius.circular(10),
                                                bottom: Radius.circular(4),
                                              ),
                                              child: Column(
                                                verticalDirection:
                                                    VerticalDirection.up,
                                                children: [
                                                  if (e.posts > 0)
                                                    Expanded(
                                                      flex: e.posts,
                                                      child: Container(
                                                        width:
                                                            double.infinity,
                                                        color: AppColors
                                                            .accentPrimary,
                                                      ),
                                                    ),
                                                  if (e.cand > 0)
                                                    Expanded(
                                                      flex: e.cand,
                                                      child: Container(
                                                        width:
                                                            double.infinity,
                                                        color:
                                                            _WeekTotalBarsCard
                                                                ._candBarColor,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '投稿${e.posts}・候補${e.cand}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9.5,
                                      height: 1.15,
                                      color: e.posts + e.cand == 0
                                          ? AppColors.textTertiary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 36,
                                    child: Column(
                                      children: [
                                        if (!narrow)
                                          Text(
                                            '${e.day.day}日',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        Text(
                                          _weekdayJa(e.day.weekday),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            fontSize: 10,
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
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legendDot(theme, AppColors.accentPrimary, '投稿'),
              _legendDot(theme, _WeekTotalBarsCard._candBarColor, '候補'),
            ],
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
