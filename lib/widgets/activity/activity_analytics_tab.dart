import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rakuten_managed_product.dart';
import '../../models/room_colle_list_filters.dart';
import '../../navigation/app_shell_controller.dart';
import '../../navigation/rakuten_search_navigator.dart';
import '../../screens/saved_shops_screen.dart';
import '../../services/room_kpi_calculator.dart';
import '../../state/activity_log_provider.dart';
import '../../state/rakuten_managed_product_provider.dart';
import '../../state/room_activity_event_provider.dart';
import '../../state/saved_shop_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/room_colle_product_list_card_layout.dart';

/// 活動画面「分析」タブ。
class ActivityAnalyticsTab extends StatefulWidget {
  const ActivityAnalyticsTab({
    super.key,
    required this.onRefresh,
    required this.bottomInset,
    required this.leadingTabStrip,
  });

  final Future<void> Function() onRefresh;
  final double bottomInset;
  final Widget Function() leadingTabStrip;

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
  bool _genreExpanded = false;
  bool _shopExpanded = false;
  bool _rankingExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bottomPad = widget.bottomInset + 28;

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

        final doneCount = done.length;

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
          savedShopIds: saved.shops
              .map((e) => e.shopId.trim())
              .where((e) => e.isNotEmpty)
              .toSet(),
          commentCopiesToday: log.getTodayLog()?.commentCount ?? 0,
        );

        final genreRows = _genreAggregation(done);
        final shopRows = _shopAggregation(done);
        final timeBuckets = _timeBuckets(done);

        final genreIntro = _genreSectionCopy(genreRows, doneCount);
        final shopIntro = _shopSectionCopy(shopRows, doneCount);
        final timeIntro = _timeSectionCopy(timeBuckets, doneCount);

        final kpi = RoomKpiCalculator.calculate(
          products: items
              .map(RoomKpiProductRecord.fromManagedProduct)
              .toList(growable: false),
          events: act.events,
          now: now,
        );

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppDimensions.screenPaddingH,
              0,
              AppDimensions.screenPaddingH,
              bottomPad,
            ),
            children: [
              widget.leadingTabStrip(),
              _InsightHeroCard(line: insight.line, hint: insight.hint),
              const SizedBox(height: 18),
              _RankingSection(
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
                products: filtered,
                shell: shell,
                expanded: _rankingExpanded,
                onToggleExpanded: () =>
                    setState(() => _rankingExpanded = !_rankingExpanded),
              ),
              const SizedBox(height: 18),
              _ExpandableDistributionCard(
                title: 'ジャンル別の傾向',
                sectionIntro: genreIntro,
                referenceNote:
                    doneCount < 6 ? '件数が少ないため参考程度に見てください' : null,
                totalDone: doneCount,
                rows: genreRows,
                expanded: _genreExpanded,
                onToggleExpanded: () =>
                    setState(() => _genreExpanded = !_genreExpanded),
              ),
              const SizedBox(height: 18),
              _ExpandableDistributionCard(
                title: 'ショップ別の傾向',
                sectionIntro: shopIntro,
                referenceNote:
                    doneCount < 6 ? '件数が少ないため参考程度に見てください' : null,
                totalDone: doneCount,
                rows: shopRows,
                expanded: _shopExpanded,
                onToggleExpanded: () =>
                    setState(() => _shopExpanded = !_shopExpanded),
              ),
              const SizedBox(height: 18),
              _TimeOfDayCard(
                buckets: timeBuckets,
                sectionIntro: timeIntro,
                totalDone: doneCount,
              ),
              const SizedBox(height: 18),
              _ImprovementActionsCard(
                shell: shell,
                staleCandidates: kpi.staleCandidateCount,
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
        hint: 'コレ済商品が少し増えると、傾向が読みやすくなります',
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
        hint: '信頼しているショップから探すと、当たりが付きやすいようです',
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
    if (topGenre != null && topRate >= 0.35 && topGenre != '未分類') {
      final gLabel =
          topGenre!.endsWith('ジャンル') ? topGenre! : '${topGenre!}ジャンル';
      return (
        line: '$gLabel の反応が良さそうです',
        hint: '似た系統の商品を少し幅を持って試すと改善のヒントになります',
      );
    }

    if (commentCopiesToday < 2 && done.length >= 8) {
      return (
        line: 'コメントコピーが少なめです',
        hint: 'テンプレを用意しておくと投稿の負担が下がります',
      );
    }

    return (
      line: '反応の良い軸を少しずつ伸ばせそうです',
      hint: '下のランキングと傾向を見て、次の一手を決めましょう',
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
    return list;
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
    return list;
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

  static String _genreSectionCopy(List<_AggRow> rows, int doneCount) {
    if (rows.isEmpty || doneCount < 4) {
      return 'コレ済商品の件数がまだ少ないので、ジャンルは参考値として見てください';
    }
    final top = rows.first;
    if (top.count <= 1) {
      return 'まだどのジャンルに寄るかはっきりしません。しばらく続けると傾向が見えます';
    }
    return '「${top.label}」の比率がやや多めです（根拠：投稿済み商品の件数構成）';
  }

  static String _shopSectionCopy(List<_AggRow> rows, int doneCount) {
    if (rows.isEmpty || doneCount < 4) {
      return 'ショップ別は、件数が積み上がるほど意味が出てきます';
    }
    final top = rows.first;
    return '「${_shortShopLabel(top.label)}」での投稿が多めです';
  }

  static String _shortShopLabel(String raw) {
    final t = raw.trim();
    if (t.length <= 18) return t;
    return '${t.substring(0, 16)}…';
  }

  static String _timeSectionCopy(
    List<({String label, int count})> buckets,
    int doneCount,
  ) {
    final sum = buckets.fold<int>(0, (a, b) => a + b.count);
    if (sum == 0 || doneCount < 4) {
      return 'コレ済の時刻データが少ないため、参考値です';
    }
    var bestI = 0;
    var bestC = -1;
    for (var i = 0; i < buckets.length; i++) {
      if (buckets[i].count > bestC) {
        bestC = buckets[i].count;
        bestI = i;
      }
    }
    return '${buckets[bestI].label}の時間帯にコレ済が集まりやすいようです';
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      elevated: true,
      radius: 20,
      borderColor: AppColors.accentPrimary.withValues(alpha: 0.2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded,
              size: 30, color: AppColors.accentPrimary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日の気づき',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '結論',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  line,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                        fontSize: 18,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  '理由',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                        fontSize: 15,
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
    required this.expanded,
    required this.onToggleExpanded,
  });

  final _ReactionFilter filter;
  final ValueChanged<_ReactionFilter> onFilterChanged;
  final List<RakutenManagedProduct> products;
  final AppShellController shell;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final visibleCount =
        expanded ? products.length.clamp(0, 5) : products.length.clamp(0, 3);
    final hasMore = products.length > 3;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      elevated: true,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '反応が良かった商品',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'コレ済商品の中から、評価の状況をもとに並べています。次にどれを増やすかの材料にしてください。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, left: 2),
              child: Row(
                children: [
                  _chip(context, 'すべて', _ReactionFilter.all),
                  _chip(context, '売れた', _ReactionFilter.sold),
                  _chip(context, '反応あり', _ReactionFilter.liked),
                  _chip(context, '微妙', _ReactionFilter.weak),
                  _chip(context, '未評価', _ReactionFilter.none),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'この条件に合うコレ済商品がありません',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
              ),
            )
          else ...[
            for (var i = 0; i < visibleCount; i++) ...[
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
            if (hasMore)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: onToggleExpanded,
                  icon: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.accentPrimary,
                  ),
                  label: Text(
                    expanded ? '閉じる' : 'もっと見る（最大5件）',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                ),
              ),
          ],
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
            fontSize: 13,
            color: sel ? AppColors.textOnAccent : AppColors.textSecondary,
          ),
        ),
        selected: sel,
        onSelected: (_) => onFilterChanged(f),
        selectedColor: AppColors.accentPrimary,
        checkmarkColor: AppColors.textOnAccent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        visualDensity: VisualDensity.compact,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$rank',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.accentPrimary,
                        fontSize: 18,
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
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$price ・ ${product.shopName.trim().isEmpty ? 'ショップ名なし' : product.shopName.trim()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.accentPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 22),
            ],
          ),
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

class _ExpandableDistributionCard extends StatelessWidget {
  const _ExpandableDistributionCard({
    required this.title,
    required this.sectionIntro,
    required this.referenceNote,
    required this.totalDone,
    required this.rows,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final String title;
  final String sectionIntro;
  final String? referenceNote;
  final int totalDone;
  final List<_AggRow> rows;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        radius: 20,
        child: Text(
          '$title：データがまだありません',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
        ),
      );
    }

    final denomTotal = totalDone > 0 ? totalDone : 1;
    final visible = expanded ? rows : rows.take(5).toList();
    final maxShare = visible.fold<double>(
      0,
      (m, r) => (r.count / denomTotal) > m ? (r.count / denomTotal) : m,
    );
    final barDenom = maxShare > 0 ? maxShare : 1.0;

    return AppCard(
      padding: const EdgeInsets.all(20),
      elevated: true,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            sectionIntro,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.42,
                  fontSize: 14,
                ),
          ),
          if (referenceNote != null) ...[
            const SizedBox(height: 6),
            Text(
              referenceNote!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '投稿済み商品の傾向（件数シェア）',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 14),
          for (final r in visible) ...[
            _distRow(context, r, barDenom, denomTotal),
            const SizedBox(height: 12),
          ],
          if (rows.length > 5)
            Center(
              child: TextButton(
                onPressed: onToggleExpanded,
                child: Text(
                  expanded ? '閉じる' : 'もっと見る',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _distRow(
    BuildContext context,
    _AggRow r,
    double barDenom,
    int denomTotal,
  ) {
    final share = (r.count / denomTotal).clamp(0.0, 1.0);
    final progress = (share / barDenom).clamp(0.0, 1.0);
    final mutedReact = r.reactCount == 0;
    final reactLabel = '反応あり ${r.reactCount}件（${(r.rate * 100).round()}%）';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(
                r.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Text(
                '${r.count}件 ・ $reactLabel',
                maxLines: 2,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: mutedReact
                          ? AppColors.textTertiary.withValues(alpha: 0.75)
                          : AppColors.textSecondary,
                      fontWeight: mutedReact ? FontWeight.w500 : FontWeight.w600,
                      fontSize: 12,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: progress,
            backgroundColor: AppColors.surfaceVariant,
            color: AppColors.accentPrimary.withValues(
              alpha: mutedReact ? 0.45 : 0.9,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeOfDayCard extends StatelessWidget {
  const _TimeOfDayCard({
    required this.buckets,
    required this.sectionIntro,
    required this.totalDone,
  });

  final List<({String label, int count})> buckets;
  final String sectionIntro;
  final int totalDone;

  static const double _chartH = 88;

  @override
  Widget build(BuildContext context) {
    final sum = buckets.fold<int>(0, (a, b) => a + b.count);
    final sparse = sum < 3 || totalDone < 4;
    final maxC = buckets.fold<int>(0, (a, b) => a > b.count ? a : b.count);
    final denom = maxC > 0 ? maxC : 1;

    return AppCard(
      padding: const EdgeInsets.all(20),
      elevated: true,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '時間帯の傾向',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            sectionIntro,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.42,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'コレ済にした時刻（端末の日時）',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
          if (sparse) ...[
            const SizedBox(height: 10),
            Text(
              'まだ参考値です',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: _chartH + 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final b in buckets)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        children: [
                          SizedBox(
                            height: _chartH,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: double.infinity,
                                constraints:
                                    const BoxConstraints(maxWidth: 28),
                                height: _chartH *
                                    ((b.count / denom).clamp(0.0, 1.0)),
                                decoration: BoxDecoration(
                                  color: AppColors.accentPrimary
                                      .withValues(alpha: 0.85),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            b.count > 0 ? '${b.count}' : '—',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          Text(
                            b.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontSize: 11,
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
        ],
      ),
    );
  }
}

typedef _ActSpec = ({String title, String body, String label, VoidCallback onTap});

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
    final specs = <_ActSpec>[];

    if (staleCandidates > 0) {
      specs.add((
        title: '放置候補を先に整理する',
        body: 'ストックが軽くなると、次の判断が速くなります',
        label: '放置候補を開く',
        onTap: () => shell.openRoomCollect(
          initialTabIndex: 0,
          candidateStalePreset: RoomColleStaleCandidatePreset.threePlus,
        ),
      ));
    }
    if (avgCommentCopyWeek < 2) {
      specs.add((
        title: 'コメントテンプレを育てる',
        body: 'コピー回数が増えると、投稿のハードルが下がります',
        label: 'コメントを開く',
        onTap: () => shell.selectTab(2),
      ));
    }
    specs.add((
      title: '候補のストックを補充する',
      body: '検索から候補を足すと、継続しやすくなります',
      label: '候補を探す',
      onTap: () => openRakutenSearchScreen(contextForNav),
    ));
    specs.add((
      title: '保存ショップを見直す',
      body: 'よく買う店の近くから探すと当たりが付きやすいです',
      label: '保存ショップを見る',
      onTap: () {
        Navigator.of(contextForNav).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const SavedShopsScreen(),
          ),
        );
      },
    ));
    specs.add((
      title: 'コレ済一覧で評価を振り返る',
      body: '売れた・反応ありを見直すと次の方針が立てやすいです',
      label: 'ROOMコレ（コレ済）を開く',
      onTap: () => shell.openRoomCollect(initialTabIndex: 1),
    ));

    final picked = specs.take(3).toList();

    return AppCard(
      padding: const EdgeInsets.all(20),
      elevated: true,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '次にやる改善アクション',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '優先度の高い順に最大3つだけ出しています。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < picked.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _actionTile(
              context,
              title: picked[i].title,
              body: picked[i].body,
              label: picked[i].label,
              onTap: picked[i].onTap,
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required String title,
    required String body,
    required String label,
    required VoidCallback onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 12),
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
    );
  }
}
