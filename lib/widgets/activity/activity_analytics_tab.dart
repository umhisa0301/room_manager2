import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rakuten_managed_product.dart';
import '../../models/room_colle_list_filters.dart';
import '../../navigation/app_shell_controller.dart';
import '../../navigation/rakuten_search_navigator.dart';
import '../../services/room_kpi_calculator.dart';
import '../../state/activity_log_provider.dart';
import '../../state/rakuten_managed_product_provider.dart';
import '../../state/room_activity_event_provider.dart';
import '../../state/saved_shop_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/room_colle_product_list_card_layout.dart';
import '../../screens/saved_shops_screen.dart';

/// 活動画面「分析」タブ。
class ActivityAnalyticsTab extends StatefulWidget {
  const ActivityAnalyticsTab({
    super.key,
    required this.onRefresh,
    required this.bottomInset,
  });

  final Future<void> Function() onRefresh;
  final double bottomInset;

  @override
  State<ActivityAnalyticsTab> createState() => _ActivityAnalyticsTabState();
}

enum _ReactionFilter {
  all,
  sold,
  liked,
  weak,
  none,
}

class _ActivityAnalyticsTabState extends State<ActivityAnalyticsTab> {
  _ReactionFilter _filter = _ReactionFilter.all;

  @override
  Widget build(BuildContext context) {
    final bottomPad = widget.bottomInset + 24;

    return Consumer4<
        RakutenManagedProductProvider,
        RoomActivityEventProvider,
        SavedShopProvider,
        ActivityLogProvider>(
      builder: (context, managed, act, saved, log, _) {
        final items = managed.items;
        final shell = context.read<AppShellController>();
        final now = DateTime.now();
        final done = items
            .where(
              (e) =>
                  RakutenManagedProduct.isMemberForStatusTab(
                    e,
                    RakutenManagedProductStatus.done,
                  ),
            )
            .toList(growable: false);

        final ranked = List<RakutenManagedProduct>.from(done);
        ranked.sort((a, b) {
          final ra = RoomKpiProductRecord.fromManagedProduct(a);
          final rb = RoomKpiProductRecord.fromManagedProduct(b);
          final s = rb.reactionRankScore.compareTo(ra.reactionRankScore);
          if (s != 0) return s;
          return b.updatedAt.compareTo(a.updatedAt);
        });

        final filtered = ranked.where((p) {
          final r = RoomKpiProductRecord.fromManagedProduct(p);
          return switch (_filter) {
            _ReactionFilter.all => true,
            _ReactionFilter.sold => r.isSold,
            _ReactionFilter.liked => r.isLiked,
            _ReactionFilter.weak => r.isWeak,
            _ReactionFilter.none => !r.isSold && !r.isLiked && !r.isWeak,
          };
        }).toList();

        final insight = _buildInsightLine(
          done: done,
          savedShopIds: saved.shops.map((e) => e.shopId.trim()).where((e) => e.isNotEmpty).toSet(),
          commentCopiesToday: log.getTodayLog()?.commentCount ?? 0,
        );

        final genreRows = _genreAggregation(done);
        final shopRows = _shopAggregation(done);
        final timeBuckets = _timeBuckets(done);

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
              _InsightHeroCard(line: insight.line, hint: insight.hint),
              const SizedBox(height: 14),
              _RankingSection(
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
                products: filtered,
                shell: shell,
              ),
              const SizedBox(height: 14),
              _DistributionCard(
                title: 'ジャンル別の傾向',
                subtitle: 'コレ済ベース',
                rows: genreRows,
              ),
              const SizedBox(height: 14),
              _DistributionCard(
                title: 'ショップ別の傾向',
                subtitle: 'コレ済ベース',
                rows: shopRows,
              ),
              const SizedBox(height: 14),
              _TimeOfDayCard(buckets: timeBuckets),
              const SizedBox(height: 14),
              _ImprovementActionsCard(
                shell: shell,
                staleCandidates: RoomKpiCalculator.calculate(
                  products: items
                      .map(RoomKpiProductRecord.fromManagedProduct)
                      .toList(growable: false),
                  events: act.events,
                  now: now,
                ).staleCandidateCount,
                avgCommentCopyWeek: _avgCommentCopiesWeek(log, now),
                contextForNav: context,
              ),
            ],
          ),
        );
      },
    );
  }

  static ({String line, String hint}) _buildInsightLine({
    required List<RakutenManagedProduct> done,
    required Set<String> savedShopIds,
    required int commentCopiesToday,
  }) {
    if (done.length < 5) {
      return (
        line: 'まだ分析できるデータが少ないです',
        hint: 'コレ済が少し溜まると、傾向が見えてきます',
      );
    }

    var savedN = 0;
    var savedGood = 0;
    var otherN = 0;
    var otherGood = 0;
    final genreReact = <String, ({int n, int good})>{};
    for (final p in done) {
      final g = _genreLabel(p);
      final react = p.feedbackSoldAt != null || p.feedbackLikedAt != null;
      final bucket = genreReact.putIfAbsent(g, () => (n: 0, good: 0));
      genreReact[g] = (
        n: bucket.n + 1,
        good: bucket.good + (react ? 1 : 0),
      );
      final sid = p.shopCode.trim();
      if (sid.isNotEmpty && savedShopIds.contains(sid)) {
        savedN++;
        if (react) savedGood++;
      } else {
        otherN++;
        if (react) otherGood++;
      }
    }

    final savedRate = savedN > 0 ? savedGood / savedN : 0.0;
    final otherRate = otherN > 0 ? otherGood / otherN : 0.0;

    if (savedN >= 3 && savedRate > otherRate + 0.12) {
      return (
        line: '保存ショップの商品が反応しやすい傾向です',
        hint: '既に信頼しているショップから探すと効率が良さそうです',
      );
    }

    String? topGenre;
    var topRate = -1.0;
    genreReact.forEach((name, v) {
      if (v.n < 2) return;
      final r = v.good / v.n;
      if (r > topRate) {
        topRate = r;
        topGenre = name;
      }
    });
    if (topGenre != null &&
        topRate >= 0.35 &&
        topGenre != '未分類') {
      final gLabel = topGenre!.endsWith('ジャンル') ? topGenre! : '${topGenre!}ジャンル';
      return (
        line: '$gLabel の反応が良さそうです',
        hint: '同系統の商品を少し幅を持って試してみましょう',
      );
    }

    if (commentCopiesToday < 2 && done.length >= 8) {
      return (
        line: 'コメントコピーが少なめです',
        hint: 'テンプレを整えておくと投稿がスムーズになります',
      );
    }

    return (
      line: '反応の良い軸を少しずつ伸ばせそうです',
      hint: 'ランキングとジャンル集計を参考に次の一手を決めましょう',
    );
  }

  static String _genreLabel(RakutenManagedProduct p) {
    final n = p.persistedGenreDisplayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return '未分類';
  }

  static List<_AggRow> _genreAggregation(List<RakutenManagedProduct> done) {
    final map = <String, ({int n, int good})>{};
    for (final p in done) {
      final k = _genreLabel(p);
      final react = p.feedbackSoldAt != null || p.feedbackLikedAt != null;
      final cur = map.putIfAbsent(k, () => (n: 0, good: 0));
      map[k] = (n: cur.n + 1, good: cur.good + (react ? 1 : 0));
    }
    final list = map.entries
        .map(
          (e) => _AggRow(
            label: e.key,
            count: e.value.n,
            reactCount: e.value.good,
          ),
        )
        .toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list.take(12).toList();
  }

  static List<_AggRow> _shopAggregation(List<RakutenManagedProduct> done) {
    final map = <String, ({int n, int good})>{};
    for (final p in done) {
      var k = p.shopName.trim();
      if (k.isEmpty) k = '（ショップ名なし）';
      final react = p.feedbackSoldAt != null || p.feedbackLikedAt != null;
      final cur = map.putIfAbsent(k, () => (n: 0, good: 0));
      map[k] = (n: cur.n + 1, good: cur.good + (react ? 1 : 0));
    }
    final list = map.entries
        .map(
          (e) => _AggRow(
            label: e.key,
            count: e.value.n,
            reactCount: e.value.good,
          ),
        )
        .toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list.take(12).toList();
  }

  static List<({String label, int count})> _timeBuckets(
    List<RakutenManagedProduct> done,
  ) {
    final labels = ['朝', '昼', '夕方', '夜', '深夜'];
    final counts = List<int>.filled(5, 0);
    for (final p in done) {
      final h = p.doneAt?.hour;
      if (h == null) continue;
      final b = _bucketIndex(h);
      counts[b]++;
    }
    return [
      for (var i = 0; i < 5; i++)
        (label: labels[i], count: counts[i]),
    ];
  }

  static int _bucketIndex(int hour) {
    if (hour >= 5 && hour < 12) return 0;
    if (hour >= 12 && hour < 17) return 1;
    if (hour >= 17 && hour < 20) return 2;
    if (hour >= 20 && hour <= 23) return 3;
    return 4;
  }

  static double _avgCommentCopiesWeek(ActivityLogProvider log, DateTime now) {
    final keys = <String>[];
    for (var i = 0; i < 7; i++) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      keys.add('${d.year}-$mm-$dd');
    }
    var sum = 0;
    for (final k in keys) {
      sum += log.findByDateKey(k)?.commentCount ?? 0;
    }
    return sum / 7.0;
  }
}

class _AggRow {
  const _AggRow({
    required this.label,
    required this.count,
    required this.reactCount,
  });

  final String label;
  final int count;
  final int reactCount;

  double get rate => count <= 0 ? 0 : reactCount / count;
}

class _InsightHeroCard extends StatelessWidget {
  const _InsightHeroCard({required this.line, required this.hint});

  final String line;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      elevated: true,
      borderColor: AppColors.accentPrimary.withValues(alpha: 0.22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded,
              size: 30, color: AppColors.accentPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日の気づき',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  line,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  hint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
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

class _RankingSection extends StatelessWidget {
  const _RankingSection({
    required this.filter,
    required this.onFilterChanged,
    required this.products,
    required this.shell,
  });

  final _ReactionFilter filter;
  final ValueChanged<_ReactionFilter> onFilterChanged;
  final List<RakutenManagedProduct> products;
  final AppShellController shell;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '反応が良かった商品',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(context, 'すべて', _ReactionFilter.all),
                _chip(context, '売れた', _ReactionFilter.sold),
                _chip(context, '反応あり', _ReactionFilter.liked),
                _chip(context, '微妙', _ReactionFilter.weak),
                _chip(context, '未評価', _ReactionFilter.none),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '該当するコレ済がありません',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < products.length && i < 25; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.divider.withValues(alpha: 0.45),
                    ),
                  _RankingTile(
                    rank: i + 1,
                    product: products[i],
                    onTap: () => shell.openRoomCollect(initialTabIndex: 1),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, _ReactionFilter f) {
    final sel = filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
            color: sel ? AppColors.textOnAccent : AppColors.textSecondary,
          ),
        ),
        selected: sel,
        onSelected: (_) => onFilterChanged(f),
        selectedColor: AppColors.accentPrimary,
        checkmarkColor: AppColors.textOnAccent,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.rank,
    required this.product,
    required this.onTap,
  });

  final int rank;
  final RakutenManagedProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = RoomKpiProductRecord.fromManagedProduct(product);
    final badge = _feedbackBadge(r);
    final price =
        RoomColleProductListCardLayout.formatPriceYen(product.itemPrice);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.accentPrimary,
                    ),
              ),
            ),
            _Thumb(url: product.imageUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.itemName.trim().isEmpty
                        ? '商品名なし'
                        : product.itemName.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$price ・ ${product.shopName.trim().isEmpty ? 'ショップ名なし' : product.shopName.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.accentPrimary,
                            fontWeight: FontWeight.w800,
                          ),
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

  String _feedbackBadge(RoomKpiProductRecord r) {
    if (r.isSold) return '売れた';
    if (r.isLiked) return '反応あり';
    if (r.isWeak) return '微妙';
    return '未評価';
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final u = url.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
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

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  final String title;
  final String subtitle;
  final List<_AggRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          '$title：データがまだありません',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      );
    }
    final maxC = rows.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return AppCard(
      padding: const EdgeInsets.all(16),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          for (final r in rows) ...[
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    r.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    '${r.count}件・反応あり ${r.reactCount}件（${(r.rate * 100).round()}%）',
                    maxLines: 2,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: maxC <= 0 ? 0 : (r.count / maxC).clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceVariant,
                color: AppColors.accentPrimary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _TimeOfDayCard extends StatelessWidget {
  const _TimeOfDayCard({required this.buckets});

  final List<({String label, int count})> buckets;

  @override
  Widget build(BuildContext context) {
    final maxC =
        buckets.map((e) => e.count).fold<int>(0, (a, b) => a > b ? a : b);
    final denom = maxC > 0 ? maxC : 1;
    const h = 112.0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '時間帯の傾向',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'コレ済にした時刻（端末ローカル）',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: h + 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final b in buckets)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (b.count > 0)
                            Text(
                              '${b.count}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accentPrimary,
                                  ),
                            ),
                          const SizedBox(height: 4),
                          Container(
                            height: h * (b.count / denom),
                            decoration: BoxDecoration(
                              color: AppColors.accentPrimary
                                  .withValues(alpha: 0.85),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            b.label,
                            style: Theme.of(context).textTheme.labelSmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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

class _ImprovementActionsCard extends StatelessWidget {
  const _ImprovementActionsCard({
    required this.shell,
    required this.staleCandidates,
    required this.avgCommentCopyWeek,
    required this.contextForNav,
  });

  final AppShellController shell;
  final int staleCandidates;
  final double avgCommentCopyWeek;
  final BuildContext contextForNav;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '次にやる改善アクション',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          _actionRow(
            context,
            title: '反応が良いジャンルを少し増やす',
            body: '得意ジャンルの周辺も試してみましょう',
            label: '候補を探す',
            onTap: () => openRakutenSearchScreen(contextForNav),
          ),
          if (staleCandidates > 0)
            _actionRow(
              context,
              title: '放置候補を整理する',
              body: '優先して片付けるとストックが軽くなります',
              label: '放置候補を開く',
              onTap: () => shell.openRoomCollect(
                initialTabIndex: 0,
                candidateStalePreset: RoomColleStaleCandidatePreset.threePlus,
              ),
            ),
          if (avgCommentCopyWeek < 2)
            _actionRow(
              context,
              title: 'コメントを増やす',
              body: 'テンプレを育てると投稿が速くなります',
              label: 'コメントを開く',
              onTap: () => shell.selectTab(2),
            ),
          _actionRow(
            context,
            title: '保存ショップをもう少し探す',
            body: '信頼できるショップを増やすと探索が楽になります',
            label: '保存ショップを見る',
            onTap: () {
              Navigator.of(contextForNav).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedShopsScreen(),
                ),
              );
            },
          ),
          _actionRow(
            context,
            title: 'ROOMコレで一覧を確認',
            body: 'コレ済の評価を見直して次の判断材料に',
            label: 'ROOMコレを開く',
            onTap: () => shell.openRoomCollect(initialTabIndex: 1),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(
    BuildContext context, {
    required String title,
    required String body,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        radius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: AppSecondaryButton(
                label: label,
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
