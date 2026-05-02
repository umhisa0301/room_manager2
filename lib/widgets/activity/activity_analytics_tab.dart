import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rakuten_managed_product.dart';
import '../../models/room_colle_list_filters.dart';
import '../../navigation/app_shell_controller.dart';
import '../../screens/today_recommendations_screen.dart';
import '../../services/room_kpi_calculator.dart';
import '../../state/activity_log_provider.dart';
import '../../state/rakuten_managed_product_provider.dart';
import '../../state/room_activity_event_provider.dart';
import '../../state/saved_shop_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/room_colle_product_list_card_layout.dart';
import 'activity_screen_layout.dart';

/// 活動画面「分析」タブ。
class ActivityAnalyticsTab extends StatefulWidget {
  const ActivityAnalyticsTab({
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
  State<ActivityAnalyticsTab> createState() => _ActivityAnalyticsTabState();
}

enum _ReactionFilter {
  all,
  sold,
  liked,
  weak,
  none,
}

enum _TrendSubTab { genre, shop, time }

class _ActivityAnalyticsTabState extends State<ActivityAnalyticsTab> {
  _ReactionFilter _filter = _ReactionFilter.all;
  bool _rankingExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bottomPad = widget.bottomInset + 36;

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
              ActivityScreenLayout.paddingH,
              0,
              ActivityScreenLayout.paddingH + widget.fabTrailingPadding,
              bottomPad,
            ),
            children: [
              widget.leadingTabStrip(),
              _InsightHeroCard(line: insight.line, hint: insight.hint),
              const SizedBox(height: ActivityScreenLayout.sectionGap),
              _RankingSection(
                doneCount: doneCount,
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
                products: filtered,
                shell: shell,
                expanded: _rankingExpanded,
                onToggleExpanded: () =>
                    setState(() => _rankingExpanded = !_rankingExpanded),
                chipTrailingPadding: widget.fabTrailingPadding,
              ),
              const SizedBox(height: ActivityScreenLayout.sectionGap),
              _TrendSummaryCard(
                doneCount: doneCount,
                genreRows: genreRows,
                shopRows: shopRows,
                timeBuckets: timeBuckets,
              ),
              const SizedBox(height: ActivityScreenLayout.sectionGap),
              _ImprovementActionsCard(
                shell: shell,
                staleCandidates: kpi.staleCandidateCount,
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
        line: '今はデータが少ないため、あと数件コレすると傾向が見えます',
        hint: 'まずは評価しながらコレ済を増やすと、「反応が良かった商品」と傾向サマリーが効いてきます',
      );
    }

    var soldN = 0;
    var likedN = 0;
    for (final p in done) {
      if (p.feedbackSoldAt != null) soldN++;
      if (p.feedbackLikedAt != null) likedN++;
    }

    if (soldN >= 1) {
      return (
        line: '売れた商品があるので、似たジャンルを少し増やすのがおすすめです',
        hint: '傾向サマリーのジャンルとランキングを見て、近い見立ての候補を2〜3件ストックに足しましょう',
      );
    }

    if (likedN >= 1) {
      return (
        line: 'まずは反応が出た商品に近い候補を増やしましょう',
        hint: '価格帯や見た目が近い商品をROOMコレの候補に追加し、「反応あり」パターンを増やします',
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
        line: '保存しているショップからの投稿比率が高いので、まずはお店の近くから探すのが近道です',
        hint: 'ROOMコレで候補を足すとき、いつも買う店の新着・おすすめから当たりを探しましょう',
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
        line: '$gLabel 周りの当たりが出やすそうです。幅を少し持たせて試せます',
        hint: '同じ売場イメージの商品を候補に追加し、反応が再現するか確かめましょう',
      );
    }

    if (commentCopiesToday < 2 && done.length >= 8) {
      return (
        line: 'コメントの下書きをそろえると、投稿の流れが速くなります',
        hint: 'コメントタブでテンプレを2つ作り、コピーしてROOMに貼る練習をしてみましょう',
      );
    }

    return (
      line: 'このあと伸ばす軸を1つに決めると、改善が早くなります',
      hint: '傾向サマリーと「反応が良かった商品」を見比べて、ジャンル・時間帯・ショップのどれを厚くするか選びましょう',
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
    final labels = ['朝', '昼', '夕', '夜', '深夜'];
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

  static String _genreSectionCopy(List<_AggRow> rows, int doneCount) {
    if (rows.isEmpty || doneCount < 4) {
      return 'まだどのジャンルに寄るかはっきりしません。しばらく続けると傾向が見えます';
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
      padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
      elevated: true,
      radius: ActivityScreenLayout.cardRadius,
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
                  line,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                        fontSize: 22,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  hint,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
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
    required this.doneCount,
    required this.filter,
    required this.onFilterChanged,
    required this.products,
    required this.shell,
    required this.expanded,
    required this.onToggleExpanded,
    required this.chipTrailingPadding,
  });

  final int doneCount;
  final _ReactionFilter filter;
  final ValueChanged<_ReactionFilter> onFilterChanged;
  final List<RakutenManagedProduct> products;
  final AppShellController shell;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final double chipTrailingPadding;

  @override
  Widget build(BuildContext context) {
    final visibleCount =
        expanded ? products.length.clamp(0, 5) : products.length.clamp(0, 3);
    final hasMore = products.length > 3;
    final emptyBecauseNoDone = doneCount == 0;

    return AppCard(
      padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
      elevated: true,
      radius: ActivityScreenLayout.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '反応が良かった商品',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'コレ済の中強い反応順です。次に似た商品を足す材料にしてください。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontSize: 15,
                ),
          ),
          if (!emptyBecauseNoDone) ...[
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Padding(
                padding: EdgeInsets.only(
                  right: ActivityScreenLayout.paddingH + chipTrailingPadding,
                  left: 2,
                ),
                child: Row(
                  children: [
                    _chip(context, 'すべて', _ReactionFilter.all),
                    _chip(context, '売れた', _ReactionFilter.sold),
                    _chip(context, '反応あり', _ReactionFilter.liked),
                    _chip(context, '微妙', _ReactionFilter.weak),
                    _chip(context, '未評価', _ReactionFilter.none),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (emptyBecauseNoDone)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'まだ判断材料が少ないです',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'まずは数件コレして、反応を集めましょう',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            )
          else if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
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
        backgroundColor: AppColors.surface,
        side: BorderSide(
          color: sel ? AppColors.accentPrimary : AppColors.divider,
          width: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SizedBox(
            height: 100,
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                      price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.shopName.trim().isEmpty
                          ? 'ショップ名なし'
                          : product.shopName.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 12,
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
        width: 60,
        height: 60,
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

class _TrendSummaryCard extends StatefulWidget {
  const _TrendSummaryCard({
    required this.doneCount,
    required this.genreRows,
    required this.shopRows,
    required this.timeBuckets,
  });

  final int doneCount;
  final List<_AggRow> genreRows;
  final List<_AggRow> shopRows;
  final List<({String label, int count})> timeBuckets;

  @override
  State<_TrendSummaryCard> createState() => _TrendSummaryCardState();
}

class _TrendSummaryCardState extends State<_TrendSummaryCard> {
  /// 分析タブを開いたときは常にジャンルから（タブ間の期待を揃える）。
  late _TrendSubTab _tab = _TrendSubTab.genre;
  bool _rowsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = widget.doneCount < 6;

    return AppCard(
      padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
      elevated: true,
      radius: ActivityScreenLayout.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '傾向サマリー',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _tabIntro(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.42,
              fontSize: 14,
            ),
          ),
          if (reference) ...[
            const SizedBox(height: 6),
            Text(
              '※ 件数が少ないため参考値として見てください',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SegmentedButton<_TrendSubTab>(
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            segments: const [
              ButtonSegment(
                value: _TrendSubTab.genre,
                label: Text('ジャンル'),
              ),
              ButtonSegment(
                value: _TrendSubTab.shop,
                label: Text('ショップ'),
              ),
              ButtonSegment(
                value: _TrendSubTab.time,
                label: Text('時間帯'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) {
              setState(() {
                _tab = s.first;
                _rowsExpanded = false;
              });
            },
          ),
          const SizedBox(height: 16),
          switch (_tab) {
            _TrendSubTab.genre => _genreShopBody(context, widget.genreRows),
            _TrendSubTab.shop => _genreShopBody(context, widget.shopRows),
            _TrendSubTab.time => _timeBody(context),
          },
        ],
      ),
    );
  }

  String _tabIntro() {
    return switch (_tab) {
      _TrendSubTab.genre =>
        _ActivityAnalyticsTabState._genreSectionCopy(
          widget.genreRows,
          widget.doneCount,
        ),
      _TrendSubTab.shop =>
        _ActivityAnalyticsTabState._shopSectionCopy(
          widget.shopRows,
          widget.doneCount,
        ),
      _TrendSubTab.time =>
        _ActivityAnalyticsTabState._timeSectionCopy(
          widget.timeBuckets,
          widget.doneCount,
        ),
    };
  }

  Widget _genreShopBody(BuildContext context, List<_AggRow> rows) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return Text(
        'まだデータがありません',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    final denomTotal = widget.doneCount > 0 ? widget.doneCount : 1;
    final cap = _rowsExpanded ? 5 : 3;
    final visible = rows.take(cap).toList();
    final maxShare = visible.fold<double>(
      0,
      (m, r) => (r.count / denomTotal) > m ? (r.count / denomTotal) : m,
    );
    final barDenom = maxShare > 0 ? maxShare : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'コレ済の件数シェア（相対）',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        for (final r in visible) ...[
          _trendDistRow(context, r, barDenom, denomTotal),
          const SizedBox(height: 14),
        ],
        if (rows.length > 3)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _rowsExpanded = !_rowsExpanded),
              child: Text(
                _rowsExpanded ? '閉じる' : 'もっと見る（上位5件まで）',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }

  Widget _trendDistRow(
    BuildContext context,
    _AggRow r,
    double barDenom,
    int denomTotal,
  ) {
    final theme = Theme.of(context);
    final share = (r.count / denomTotal).clamp(0.0, 1.0);
    final progress = (share / barDenom).clamp(0.0, 1.0);
    final mutedReact = r.reactCount == 0;
    final reactLabel = widget.doneCount < 6
        ? '${r.count}件中${r.reactCount}件に反応'
        : '反応あり ${r.reactCount}件（${(r.rate * 100).round()}%）';

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
                style: theme.textTheme.bodyLarge?.copyWith(
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
                style: theme.textTheme.labelMedium?.copyWith(
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
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: r.count <= 0 ? 0.0 : progress.clamp(0.06, 1.0),
            backgroundColor: AppColors.surfaceVariant,
            color: AppColors.accentPrimary.withValues(
              alpha: mutedReact ? 0.35 : 0.95,
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeBody(BuildContext context) {
    final theme = Theme.of(context);
    const chartTotalH = 150.0;
    const labelBlockH = 40.0;
    final buckets = widget.timeBuckets;
    final sum = buckets.fold<int>(0, (a, b) => a + b.count);
    final sparse = sum < 3 || widget.doneCount < 4;
    final maxC = buckets.fold<int>(0, (a, b) => a > b.count ? a : b.count);
    final denom = maxC > 0 ? maxC : 1;
    final barBand = chartTotalH - labelBlockH;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'コレ済にした時刻（端末の日時）',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (sparse) ...[
          const SizedBox(height: 8),
          Text(
            '※ まだ参考値です',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: chartTotalH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final b in buckets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: LayoutBuilder(
                              builder: (context, inner) {
                                final w =
                                    (inner.maxWidth * 0.78).clamp(24.0, 32.0);
                                if (b.count <= 0) {
                                  return Container(
                                    width: w,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppColors.divider
                                          .withValues(alpha: 0.55),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6),
                                        bottom: Radius.circular(4),
                                      ),
                                    ),
                                  );
                                }
                                final rawH = barBand *
                                    ((b.count / denom).clamp(0.0, 1.0));
                                final h = rawH.clamp(18.0, barBand * 0.95);
                                return Container(
                                  width: w,
                                  height: h,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentPrimary
                                        .withValues(alpha: 0.92),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(10),
                                      bottom: Radius.circular(4),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          height: labelBlockH,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                '${b.count}',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                b.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
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
          ),
        ),
      ],
    );
  }
}

typedef _ActSpec = ({String title, String body, String label, VoidCallback onTap});

class _ImprovementActionsCard extends StatelessWidget {
  const _ImprovementActionsCard({
    required this.shell,
    required this.staleCandidates,
    required this.contextForNav,
  });

  final AppShellController shell;
  final int staleCandidates;
  final BuildContext contextForNav;

  @override
  Widget build(BuildContext context) {
    final specs = <_ActSpec>[];

    if (staleCandidates > 0) {
      specs.add((
        title: '放置候補を整理する',
        body: 'ストックが軽くなると、次の判断が速くなります',
        label: '放置候補を開く',
        onTap: () => shell.openRoomCollect(
          initialTabIndex: 0,
          candidateStalePreset: RoomColleStaleCandidatePreset.threePlus,
        ),
      ));
    }
    specs.add((
      title: '反応に近い候補を足す',
      body: 'おすすめコレから、すぐストックに追加できます',
      label: 'おすすめコレを開く',
      onTap: () {
        Navigator.of(contextForNav).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const TodayRecommendationsScreen(),
          ),
        );
      },
    ));
    specs.add((
      title: 'コレ済で評価を振り返る',
      body: '売れた・反応ありを見直すと次の方針が立てやすいです',
      label: 'ROOMコレ（コレ済）を開く',
      onTap: () => shell.openRoomCollect(initialTabIndex: 1),
    ));

    final picked = specs.take(3).toList();

    return AppCard(
      padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
      elevated: true,
      radius: ActivityScreenLayout.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '次にやること',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '優先度の高い順に最大3つです。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < picked.length; i++) ...[
            if (i > 0)
              Divider(
                height: 20,
                color: AppColors.divider.withValues(alpha: 0.6),
              ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 4,
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.38,
                    fontSize: 14,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: AppSecondaryButton(
            label: label,
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          ),
        ),
      ],
    );
  }
}
