import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/activity_log.dart';
import '../../models/rakuten_managed_product.dart';
import '../../models/room_activity_event.dart';
import '../../models/room_colle_list_filters.dart';
import '../../navigation/app_shell_controller.dart';
import '../../services/rakuten_room_home_stats.dart';
import '../../services/room_collect_post_limit.dart';
import '../../services/room_kpi_calculator.dart';
import '../../state/activity_log_provider.dart';
import '../../state/rakuten_managed_product_provider.dart';
import '../../state/room_activity_event_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'activity_navigation_helpers.dart';

/// 活動画面「実績」タブ（達成感・上限・ログ・週次）。
class ActivityAchievementTab extends StatefulWidget {
  const ActivityAchievementTab({
    super.key,
    required this.onRefresh,
    required this.bottomInset,
  });

  final Future<void> Function() onRefresh;
  final double bottomInset;

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
      ActivityLogProvider,
      AppShellController
    >(
      builder: (context, room, act, logProv, shell, _) {
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

        final bottomPad = widget.bottomInset + 24;

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppDimensions.screenPaddingH,
              8,
              AppDimensions.screenPaddingH,
              bottomPad,
            ),
            children: [
              if (_flashMilestone != null) ...[
                _MilestoneToast(
                  milestone: _flashMilestone!,
                  onDismiss: () => setState(() => _flashMilestone = null),
                ),
                const SizedBox(height: 10),
              ],
              _AchievementHeroCard(
                todayPosts: todayPosts,
                todayCandidates: todayCandidates,
                commentCopies: commentCopies,
                streakDays: streak,
              ),
              const SizedBox(height: 14),
              _RoomPostLimitCard(
                snapshot: collectLimit,
                shell: shell,
              ),
              const SizedBox(height: 14),
              _TodayActivityLogSection(
                events: events,
                items: items,
                now: now,
              ),
              const SizedBox(height: 14),
              _WeekStackedBarsCard(
                items: items,
                events: events,
                activityLogs: logProv.logs,
                anchor: now,
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
    required this.todayPosts,
    required this.todayCandidates,
    required this.commentCopies,
    required this.streakDays,
  });

  final int todayPosts;
  final int todayCandidates;
  final int commentCopies;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryLine = _primaryNarrative();
    final subLines = _subNarratives();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      elevated: true,
      borderColor: AppColors.accentPrimary.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.celebration_rounded,
                  color: AppColors.accentPrimary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '今日の実績',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            primaryLine,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.25,
              color: AppColors.textPrimary,
              fontSize: 22,
            ),
          ),
          if (subLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              subLines.join('\n'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 340;
              final chips = <Widget>[
                _metricChip(
                  context,
                  'ROOM投稿',
                  '$todayPosts',
                  Icons.rocket_launch_rounded,
                ),
                _metricChip(
                  context,
                  '候補に追加',
                  '$todayCandidates',
                  Icons.add_circle_outline_rounded,
                ),
                _metricChip(
                  context,
                  'コメントコピー',
                  '$commentCopies',
                  Icons.content_copy_rounded,
                ),
                _metricChip(
                  context,
                  '連続活動',
                  streakDays <= 0 ? '—' : '$streakDays日',
                  Icons.local_fire_department_rounded,
                ),
              ];
              if (narrow) {
                return Column(
                  children: [
                    for (var i = 0; i < chips.length; i += 2)
                      Padding(
                        padding:
                            EdgeInsets.only(bottom: i + 2 < chips.length ? 8 : 0),
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
        ],
      ),
    );
  }

  String _primaryNarrative() {
    if (todayPosts == 0 && todayCandidates == 0 && commentCopies == 0) {
      return '今日はまだROOM投稿がありません';
    }
    if (todayPosts > 0) {
      return '今日は $todayPosts 件ROOM投稿しました';
    }
    if (todayCandidates > 0) {
      return '今日は候補を $todayCandidates 件追加しました';
    }
    return '今日はコメントを $commentCopies 回コピーしました';
  }

  List<String> _subNarratives() {
    final out = <String>[];
    if (todayPosts > 0) {
      if (todayCandidates > 0) {
        out.add('候補を $todayCandidates 件追加しました');
      }
      if (commentCopies > 0) {
        out.add('コメントを $commentCopies 回コピーしました');
      }
    } else if (todayCandidates > 0 && commentCopies > 0) {
      out.add('コメントを $commentCopies 回コピーしました');
    }
    if (streakDays >= 2) {
      out.add('連続 $streakDays 日ムーブしています');
    }
    return out;
  }

  Widget _metricChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accentPrimary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
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
    final agg = _aggregateState(snapshot);

    return AppCard(
      padding: const EdgeInsets.all(18),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, color: _stateColor(agg), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ROOM投稿の上限',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '楽天ROOMの目安：1日 200件・1時間 100件',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _limitGaugeRow(
            context,
            label: '今日の投稿数',
            used: snapshot.todayCount,
            limit: RoomCollectPostLimitSnapshot.dailyLimit,
            state: snapshot.dailyBarState,
            remainingLabel: '本日あと ${snapshot.dailyRemaining} 件',
          ),
          const SizedBox(height: 12),
          _limitGaugeRow(
            context,
            label: 'この1時間の投稿数',
            used: snapshot.hourCount,
            limit: RoomCollectPostLimitSnapshot.hourlyLimit,
            state: snapshot.hourlyBarState,
            remainingLabel: 'この1時間あと ${snapshot.hourlyRemaining} 件',
            footnote: snapshot.isHourlyReached
                ? snapshot.recoveryFootnote(DateTime.now())
                : null,
          ),
          if (snapshot.isAnyLimitReached) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
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
                    snapshot.isDailyReached
                        ? '今日はROOM投稿を控えましょう'
                        : 'いまは1時間の上限に達しています',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '今は候補整理やコメント準備がおすすめです',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        label: 'コメントを準備',
                        onPressed: () => shell.selectTab(2),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      ),
                      AppSecondaryButton(
                        label: 'コレ済を振り返る',
                        onPressed: () =>
                            shell.openRoomCollect(initialTabIndex: 1),
                        icon: const Icon(Icons.task_alt_rounded, size: 18),
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
              child: Text.rich(
                TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  children: [
                    TextSpan(text: '$label：'),
                    TextSpan(
                      text: '$used / $limit',
                      style: TextStyle(color: color),
                    ),
                    const TextSpan(text: ' 件'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                remainingLabel,
                textAlign: TextAlign.end,
                maxLines: 2,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: state == RoomCollectPostLimitBarState.normal
                      ? AppColors.textSecondary
                      : color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            backgroundColor: AppColors.surfaceVariant,
            color: color,
          ),
        ),
        if (footnote != null && footnote.isNotEmpty) ...[
          const SizedBox(height: 4),
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

class _TodayActivityLogSection extends StatelessWidget {
  const _TodayActivityLogSection({
    required this.events,
    required this.items,
    required this.now,
  });

  final List<RoomActivityEvent> events;
  final List<RakutenManagedProduct> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final list = events
        .where(
          (e) =>
              !e.createdAt.isBefore(todayStart) &&
              e.createdAt.isBefore(tomorrowStart),
        )
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日のログ',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'リアルタイムに近い活動の履歴です',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '今日のログはまだありません',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < list.length && i < 60; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.divider.withValues(alpha: 0.5),
                    ),
                  _ActivityLogTile(
                    event: list[i],
                    product: activityFindProduct(items, list[i].productId),
                  ),
                ],
              ],
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

class _WeekStackedBarsCard extends StatelessWidget {
  const _WeekStackedBarsCard({
    required this.items,
    required this.events,
    required this.activityLogs,
    required this.anchor,
  });

  final List<RakutenManagedProduct> items;
  final List<RoomActivityEvent> events;
  final List<ActivityLog> activityLogs;
  final DateTime anchor;

  @override
  Widget build(BuildContext context) {
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

    var maxVal = 1;
    for (final e in series) {
      var m = e.posts;
      if (e.cand > m) m = e.cand;
      if (e.comments > m) m = e.comments;
      if (m > maxVal) maxVal = m;
    }

    const barH = 118.0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今週の積み上げ',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'ROOM投稿・候補に追加・コメントコピー（7日）',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: barH + 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final e in series)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _miniBar(
                                  e.posts / maxVal,
                                  barH,
                                  AppColors.accentPrimary,
                                ),
                                const SizedBox(width: 2),
                                _miniBar(
                                  e.cand / maxVal,
                                  barH,
                                  const Color(0xFF5C6BC0),
                                ),
                                const SizedBox(width: 2),
                                _miniBar(
                                  e.comments / maxVal,
                                  barH,
                                  const Color(0xFF2E7D32),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${e.day.month}/${e.day.day}',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            _weekdayJa(e.day.weekday),
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      color: AppColors.textTertiary,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legendDot(AppColors.accentPrimary, 'ROOM投稿'),
              _legendDot(const Color(0xFF5C6BC0), '候補に追加'),
              _legendDot(const Color(0xFF2E7D32), 'コメントコピー'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) {
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _miniBar(double ratio, double maxH, Color color) {
    final h = (maxH * ratio.clamp(0.0, 1.0)).clamp(4.0, maxH);
    return Container(
      width: 5,
      height: h,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }

  static String _weekdayJa(int weekday) {
    const w = ['月', '火', '水', '木', '金', '土', '日'];
    return w[weekday - 1];
  }
}
