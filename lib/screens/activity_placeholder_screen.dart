import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../services/rakuten_room_home_stats.dart';
import '../state/rakuten_managed_product_provider.dart';
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

class _ActivityPlaceholderScreenState extends State<ActivityPlaceholderScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ROOM運用ダッシュボード'),
      ),
      body: SafeArea(
        child: Consumer3<RakutenManagedProductProvider, SavedShopProvider,
            TodayRecommendationProvider>(
          builder: (context, room, saved, rec, _) {
            final items = room.items;
            final now = DateTime.now();
            final todayCount =
                RakutenRoomHomeStats.countDoneOnLocalCalendarDay(items, now);
            final totalDone = RakutenRoomHomeStats.countDone(items);
            final lastDone = RakutenRoomHomeStats.latestDoneAt(items);
            final series =
                RakutenRoomHomeStats.doneCountsRollingDays(items, now, 7);
            final savedShopCount = saved.shops.length;
            final recommendPending = rec.pendingCount;
            final recommendTotal = rec.totalCount;
            final recentCandidateCount = _countTodayCandidates(items, now);
            final maxInWeek = series
                .map((e) => e.count)
                .fold<int>(0, (a, b) => a > b ? a : b);

            return RefreshIndicator(
              onRefresh: () => room.refreshManagedProductList(
                    showLoadingIndicator: true,
                  ),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.screenPaddingH,
                  AppDimensions.spacingMd,
                  AppDimensions.screenPaddingH,
                  100,
                ),
                children: [
                  _ActivityPurposeBanner(),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _BigMetricCard(
                          icon: Icons.today_rounded,
                          iconColor: const Color(0xFF1565C0),
                          title: '今日のコレ',
                          valueText: '$todayCount',
                          unit: '件',
                          caption: '今日（0:00〜）にコレ済へ移した件数',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BigMetricCard(
                          icon: Icons.stacked_line_chart_rounded,
                          iconColor: const Color(0xFF2E7D32),
                          title: '累計コレ',
                          valueText: '$totalDone',
                          unit: '件',
                          caption: 'これまでにコレ済になった商品の総数',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  _SevenDayTrendCard(
                    series: series,
                    maxCount: maxInWeek,
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
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
                          valueText: recommendTotal == 0
                              ? '未生成'
                              : '$recommendPending件',
                          caption: recommendTotal == 0
                              ? '今日のおすすめ未作成'
                              : '今日のおすすめ未処理件数',
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
                  const SizedBox(height: AppDimensions.spacingMd),
                  _LastCollectCard(lastDoneAt: lastDone),
                ],
              ),
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

class _ActivityPurposeBanner extends StatelessWidget {
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
                  'ROOM運用の進捗が見える',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '候補管理とコレ済実績を1画面で確認できます。今日の動きと中長期の傾向を見ながら運用を調整できます。',
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

class _BigMetricCard extends StatelessWidget {
  const _BigMetricCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.valueText,
    required this.unit,
    required this.caption,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String valueText;
  final String unit;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valueText,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1,
                      fontSize: 36,
                    ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _SevenDayTrendCard extends StatelessWidget {
  const _SevenDayTrendCard({
    required this.series,
    required this.maxCount,
  });

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
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
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
                            height: chartHeight *
                                0.72 *
                                (e.count / denom),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.accentPrimary
                                      .withValues(alpha: 0.85),
                                  AppColors.accentSecondary
                                      .withValues(alpha: 0.55),
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

