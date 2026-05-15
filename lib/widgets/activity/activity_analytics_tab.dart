import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rakuten_managed_product.dart';
import '../../models/room_activity_event.dart';
import '../../models/room_reaction_sync_history_entry.dart';
import '../../models/room_reaction_sync_top_product.dart';
import '../../navigation/app_shell_controller.dart';
import '../../navigation/rakuten_search_navigator.dart';
import '../../screens/today_recommendations_screen.dart';
import '../../services/app_action_service.dart';
import '../../services/room_kpi_calculator.dart';
import '../../services/room_reaction_sync_history_store.dart';
import '../../state/rakuten_managed_product_provider.dart';
import '../../state/room_activity_event_provider.dart';
import '../../state/saved_shop_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/room_reaction_analytics.dart';
import '../../utils/room_sync_log.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/room_colle_product_list_card_layout.dart';
import 'activity_navigation_helpers.dart';
import 'activity_screen_layout.dart';

/// 活動画面「分析」タブ。
class ActivityAnalyticsTab extends StatefulWidget {
  const ActivityAnalyticsTab({
    super.key,
    required this.onRefresh,
    required this.bottomInset,
    required this.scrollController,
    this.roomReactionSectionKey,
  });

  final Future<void> Function() onRefresh;
  final double bottomInset;
  final ScrollController scrollController;

  /// ホーム等から [Scrollable.ensureVisible] するアンカー。
  final Key? roomReactionSectionKey;

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

enum _OutcomeLens { combined, sold, likedOnly }

enum _TrendSubTab { genre, shop, time }

class _ActivityAnalyticsTabState extends State<ActivityAnalyticsTab> {
  _ReactionFilter _filter = _ReactionFilter.all;
  bool _rankingExpanded = false;
  _OutcomeLens _outcomeLens = _OutcomeLens.combined;

  @override
  Widget build(BuildContext context) {
    final bottomPad = widget.bottomInset;

    return Consumer3<
        RakutenManagedProductProvider,
        RoomActivityEventProvider,
        SavedShopProvider>(
      builder: (context, managed, act, saved, _) {
        final items = managed.items;
        final shell = context.read<AppShellController>();
        if (kDebugMode) {
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final candidateCount = items
              .where(
                (e) => RakutenManagedProduct.isMemberForStatusTab(
                  e,
                  RakutenManagedProductStatus.candidate,
                ),
              )
              .length;
          final allDoneCount = items
              .where(
                (e) => RakutenManagedProduct.isMemberForStatusTab(
                  e,
                  RakutenManagedProductStatus.done,
                ),
              )
              .length;
          final roomImportedDoneCount = items
              .where(
                (e) =>
                    RakutenManagedProduct.isMemberForStatusTab(
                      e,
                      RakutenManagedProductStatus.done,
                    ) &&
                    e.coredActivitySource ==
                        RakutenCoredActivitySource.roomImport,
              )
              .length;
          final todayCollectedByApp = activityCountEventsOnLocalDay(
            act.events,
            todayStart,
            {RoomActivityEventType.movedToCored},
          );
          final todayImportedFromRoom = activityCountEventsOnLocalDay(
            act.events,
            todayStart,
            {RoomActivityEventType.importedFromRoom},
          );
          analyticsCountSourceLog(
            'screen=analysis candidateCount=$candidateCount '
            'doneCount=$allDoneCount roomImportedDoneCount=$roomImportedDoneCount '
            'todayCollectedByApp=$todayCollectedByApp '
            'todayImportedFromRoom=$todayImportedFromRoom '
            'reason=excludeRoomImportFromCandidate',
          );
          final importedFromRoomCount = act.events
              .where((e) => e.type == RoomActivityEventType.importedFromRoom)
              .length;
          final appCollectedCount = act.events
              .where((e) => e.type == RoomActivityEventType.movedToCored)
              .length;
          roomImportAnalyticsSeparationLog(
            'importedFromRoomCount=$importedFromRoomCount '
            'appCollectedCount=$appCollectedCount '
            'todayRoomImportCount=$todayImportedFromRoom '
            'todayAppCollectCount=$todayCollectedByApp '
            'excludedFromTodayCollect=true',
          );
        }
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
            _ReactionFilter.weak => !r.isSold && !r.isLiked,
            _ReactionFilter.none => !r.isSold && !r.isLiked && !r.isWeak,
          };
        }).toList();

        final outcomeSubset = _outcomeSubset(done, _outcomeLens);
        final genreRows = _genreOutcomeAggregation(outcomeSubset);
        final shopRows = _shopOutcomeAggregation(outcomeSubset);
        final timeBuckets = _postedHourBuckets8(outcomeSubset, act.events);

        final insight = _buildDecisionBrief(
          context: context,
          shell: shell,
          done: done,
          outcomeSubset: outcomeSubset,
          outcomeLens: _outcomeLens,
          genreRows: genreRows,
          shopRows: shopRows,
          timeBuckets: timeBuckets,
          savedShopIds: saved.shops
              .map((e) => e.shopId.trim())
              .where((e) => e.isNotEmpty)
              .toSet(),
        );

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
              _DecisionInsightCard(brief: insight),
              const SizedBox(height: ActivityScreenLayout.sectionGap),
              KeyedSubtree(
                key: widget.roomReactionSectionKey,
                child: _RoomReactionAnalyticsSection(
                  allItems: items,
                ),
              ),
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
              ),
              const SizedBox(height: ActivityScreenLayout.sectionGap),
              _TrendSummaryCard(
                outcomeLens: _outcomeLens,
                onOutcomeLensChanged: (o) => setState(() => _outcomeLens = o),
                outcomeSubsetCount: outcomeSubset.length,
                genreRows: genreRows,
                shopRows: shopRows,
                timeBuckets: timeBuckets,
              ),
            ],
          ),
        );
      },
    );
  }

  static List<RakutenManagedProduct> _outcomeSubset(
    List<RakutenManagedProduct> done,
    _OutcomeLens lens,
  ) {
    return switch (lens) {
      _OutcomeLens.combined => done
          .where(
            (p) => p.feedbackSoldAt != null || p.feedbackLikedAt != null,
          )
          .toList(growable: false),
      _OutcomeLens.sold => done
          .where((p) => p.feedbackSoldAt != null)
          .toList(growable: false),
      _OutcomeLens.likedOnly => done
          .where(
            (p) =>
                p.feedbackLikedAt != null && p.feedbackSoldAt == null,
          )
          .toList(growable: false),
    };
  }

  static List<String> get _threeHourLabels => const [
        '0–3',
        '3–6',
        '6–9',
        '9–12',
        '12–15',
        '15–18',
        '18–21',
        '21–24',
      ];

  static List<_AggRow> _genreOutcomeAggregation(
    List<RakutenManagedProduct> subset,
  ) {
    final map = <String, int>{};
    for (final p in subset) {
      final k = _genreLabel(p);
      map[k] = (map[k] ?? 0) + 1;
    }
    final list = map.entries
        .map(
          (e) => _AggRow(
            label: e.key,
            count: e.value,
            reactCount: e.value,
          ),
        )
        .toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  static List<_AggRow> _shopOutcomeAggregation(
    List<RakutenManagedProduct> subset,
  ) {
    final map = <String, int>{};
    for (final p in subset) {
      var k = p.shopName.trim();
      if (k.isEmpty) k = '（ショップ名なし）';
      map[k] = (map[k] ?? 0) + 1;
    }
    final list = map.entries
        .map(
          (e) => _AggRow(
            label: e.key,
            count: e.value,
            reactCount: e.value,
          ),
        )
        .toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  static List<({String label, int count})> _postedHourBuckets8(
    List<RakutenManagedProduct> subset,
    List<RoomActivityEvent> events,
  ) {
    final counts = List<int>.filled(8, 0);
    for (final p in subset) {
      final t = _postedInstantForProduct(p, events);
      if (t == null) continue;
      final bin = t.hour.clamp(0, 23) ~/ 3;
      if (bin >= 0 && bin < 8) {
        counts[bin]++;
      }
    }
    final labels = _threeHourLabels;
    return [
      for (var i = 0; i < 8; i++) (label: labels[i], count: counts[i]),
    ];
  }

  static DateTime? _postedInstantForProduct(
    RakutenManagedProduct p,
    List<RoomActivityEvent> events,
  ) {
    if (!p.countsTowardPostedCollectMetrics) return null;
    final doneAt = p.doneAt;
    if (doneAt != null) return doneAt;
    final id = p.productId.trim();
    if (id.isEmpty) return null;
    DateTime? earliest;
    for (final e in events) {
      if (e.type != RoomActivityEventType.movedToCored) continue;
      if (e.productId.trim() != id) continue;
      if (earliest == null || e.createdAt.isBefore(earliest)) {
        earliest = e.createdAt;
      }
    }
    return earliest;
  }

  static _DecisionBrief _buildDecisionBrief({
    required BuildContext context,
    required AppShellController shell,
    required List<RakutenManagedProduct> done,
    required List<RakutenManagedProduct> outcomeSubset,
    required _OutcomeLens outcomeLens,
    required List<_AggRow> genreRows,
    required List<_AggRow> shopRows,
    required List<({String label, int count})> timeBuckets,
    required Set<String> savedShopIds,
  }) {
    final navCtx = context;
    void navRec() {
      Navigator.of(navCtx).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const TodayRecommendationsScreen(),
        ),
      );
    }

    void navDone() {
      shell.openRoomCollect(initialTabIndex: 1);
    }

    if (outcomeSubset.isEmpty) {
      return _DecisionBrief(
        conclusion:
            'まだ「売れた／反応あり」の商品が${done.isEmpty ? 'コレ済にありません' : '足りません'}。',
        rationale:
            '分析は成果が付いたコレ済だけを使います。まずコレして評価を付けましょう。',
        footnote: 'コレ済：${done.length}件　成果対象：0件',
        nextSteps: [
          _NextStepAction(
            title: 'おすすめコレから候補を2件追加する',
            basis: '候補があればコレして、成果ラベルを付けられる状態を作れます',
            buttonLabel: 'おすすめコレを開く',
            onPressed: navRec,
          ),
          _NextStepAction(
            title: 'コレ済に移して「売れた／反応あり」を付ける',
            basis: '分析の「次の一手」はこの成果ログからだけ組み立てます',
            buttonLabel: 'コレ済一覧を開く',
            onPressed: navDone,
          ),
        ],
      );
    }

    final n = outcomeSubset.length;
    final topGenre = genreRows.isEmpty ? null : genreRows.first;
    final topShop = shopRows.isEmpty ? null : shopRows.first;

    var bestBi = 0;
    var bestBc = -1;
    var sumT = 0;
    for (var i = 0; i < timeBuckets.length; i++) {
      sumT += timeBuckets[i].count;
      if (timeBuckets[i].count > bestBc) {
        bestBc = timeBuckets[i].count;
        bestBi = i;
      }
    }
    final bestLabel = timeBuckets[bestBi].label;
    final bestCount = timeBuckets[bestBi].count;
    final pct = sumT <= 0 ? 0 : ((bestCount / sumT) * 100).round();

    final lensJa = switch (outcomeLens) {
      _OutcomeLens.combined => '売れた＋反応あり',
      _OutcomeLens.sold => '売れた商品',
      _OutcomeLens.likedOnly => '反応あり・売れ以外',
    };

    final genreLine = topGenre != null && topGenre.count >= 1
        ? '最多ジャンルは「${topGenre.label}」の${topGenre.count}件です。'
        : '';
    final shopLine = topShop != null && topShop.count >= 1
        ? '最多ショップは「${_shortShopLabel(topShop.label)}」の${topShop.count}件です。'
        : '';

    final rationale = StringBuffer()
      ..write('$n件のコレ済から読み取れること（$lensJa）：')
      ..write('\n');
    if (sumT > 0 && bestCount > 0) {
      rationale.write(
        '・投稿時刻（アプリ記録）が「$bestLabel」に集中：$bestCount件（全体の$pct%）\n',
      );
    } else {
      rationale.write('・時間帯の偏りはまだ読み取れません（記録時刻が少ない）\n');
    }
    if (genreLine.isNotEmpty) {
      rationale.write('・$genreLine\n');
    }
    if (shopLine.isNotEmpty) {
      rationale.write('・$shopLine\n');
    }
    if (savedShopIds.isNotEmpty && topShop != null) {
      final sid = outcomeSubset
          .where((p) => p.shopCode.trim().isNotEmpty)
          .map((p) => p.shopCode.trim())
          .where(savedShopIds.contains)
          .length;
      if (sid >= 2) {
        rationale.write('・保存ショップ由来の成果が$sid件あります\n');
      }
    }

    final nextSteps = <_NextStepAction>[];
    if (sumT > 0 && bestCount > 0) {
      nextSteps.add(
        _NextStepAction(
          title: '$bestLabel前後にROOM投稿する',
          basis: '成果の投稿記録が「$bestLabel」に$bestCount件集中しています（全体の$pct%）',
          buttonLabel: '$bestLabel向け候補を見る',
          onPressed: () => shell.openRoomCollect(initialTabIndex: 0),
        ),
      );
    }
    if (topGenre != null && topGenre.count >= 2) {
      final genreCta = switch (outcomeLens) {
        _OutcomeLens.sold => '売れたジャンルの商品を探す',
        _OutcomeLens.likedOnly => '「${topGenre.label}」の商品を探す',
        _OutcomeLens.combined => '成果の出たジャンルの商品を探す',
      };
      nextSteps.add(
        _NextStepAction(
          title: '「${topGenre.label}」系をあと3件候補に追加する',
          basis: '最多ジャンルは「${topGenre.label}」の${topGenre.count}件です',
          buttonLabel: genreCta,
          onPressed: navRec,
        ),
      );
    }
    if (topShop != null && topShop.count >= 2) {
      nextSteps.add(
        _NextStepAction(
          title: '「${_shortShopLabel(topShop.label)}」から類似商品を探す',
          basis: '最多ショップは「${_shortShopLabel(topShop.label)}」の${topShop.count}件です',
          buttonLabel: '反応が良かったショップを見る',
          onPressed: () => openRakutenSearchScreen(navCtx),
        ),
      );
    }
    if (nextSteps.isEmpty) {
      nextSteps.add(
        _NextStepAction(
          title: '候補を増やして成果のサンプルを厚くする',
          basis: '成果は$n件ありますが、時間帯・ジャンル・ショップの偏りがまだはっきりしません',
          buttonLabel: 'おすすめコレを開く',
          onPressed: navRec,
        ),
      );
      nextSteps.add(
        _NextStepAction(
          title: 'コレ済の評価を最新に保つ',
          basis: '「売れた／反応あり」が増えると、次の一手の根拠が強くなります',
          buttonLabel: 'コレ済一覧を開く',
          onPressed: navDone,
        ),
      );
    }

    final conclusion = sumT > 0 && bestCount > 0
        ? '「$bestLabel」に成果が寄っています。'
        : '成果は出ていますが、次はサンプルを増やして傾向を固めましょう。';

    return _DecisionBrief(
      conclusion: conclusion,
      rationale: rationale.toString().trim(),
      footnote: '※ 時刻はコレ済の記録（端末時刻）。ROOMの実投稿と一致しない場合があります。',
      nextSteps: nextSteps.take(3).toList(growable: false),
    );
  }

  static String _genreLabel(RakutenManagedProduct p) {
    final n = p.persistedGenreDisplayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return '未分類';
  }

  static String _shortShopLabel(String raw) {
    final t = raw.trim();
    if (t.length <= 18) return t;
    return '${t.substring(0, 16)}…';
  }

  /// 傾向サマリー（ジャンル）— 成果サブセットのみを対象にする。
  static String _outcomeGenreSectionCopy(List<_AggRow> rows, int n) {
    if (n < 4 || rows.isEmpty) {
      return '成果（売れた／反応あり）がまだ少ないです。あと数件で傾向が読みやすくなります。';
    }
    final top = rows.first;
    if (top.count < 2) {
      return 'ジャンル間の差はまだ小さいです。同系統を増やすと差が出やすいです。';
    }
    return '「${top.label}」が${top.count}件で最多です（分析対象：$n件）。';
  }

  /// 傾向サマリー（ショップ）— 成果サブセットのみ。
  static String _outcomeShopSectionCopy(List<_AggRow> rows, int n) {
    if (n < 4 || rows.isEmpty) {
      return '成果データがまだ少ないです。あと数件でショップ差が見えます。';
    }
    final top = rows.first;
    return '「${_shortShopLabel(top.label)}」が${top.count}件で最多です（分析対象：$n件）。';
  }

  /// 傾向サマリー（時間帯）— 3時間単位・成果のみ。
  static String _outcomeTimeSectionCopy(
    List<({String label, int count})> buckets,
    int n,
  ) {
    final sum = buckets.fold<int>(0, (a, b) => a + b.count);
    if (n < 4 || sum == 0) {
      return '記録された投稿時刻がまだ少ないため、時間帯の結論は出しません。';
    }
    var bestI = 0;
    var bestC = -1;
    for (var i = 0; i < buckets.length; i++) {
      if (buckets[i].count > bestC) {
        bestC = buckets[i].count;
        bestI = i;
      }
    }
    final pct = ((bestC / sum) * 100).round();
    return '「${buckets[bestI].label}」に$bestC件集中（$pct%）。';
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

class _NextStepAction {
  const _NextStepAction({
    required this.title,
    required this.basis,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String basis;
  final String buttonLabel;
  final VoidCallback onPressed;
}

class _DecisionBrief {
  const _DecisionBrief({
    required this.conclusion,
    required this.rationale,
    required this.footnote,
    required this.nextSteps,
  });

  final String conclusion;
  final String rationale;
  final String footnote;
  final List<_NextStepAction> nextSteps;
}

class _DecisionInsightCard extends StatelessWidget {
  const _DecisionInsightCard({required this.brief});

  final _DecisionBrief brief;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
      elevated: true,
      radius: ActivityScreenLayout.cardRadius,
      borderColor: AppColors.accentPrimary.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.bolt_rounded, size: 28, color: AppColors.accentPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '今日の気づき',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '① 結論',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            brief.conclusion,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.3,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '次の一手（最大3件）',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < brief.nextSteps.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Text(
              '${i + 1}. ${brief.nextSteps[i].title}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.35,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              brief.nextSteps[i].basis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            AppSecondaryButton(
              label: brief.nextSteps[i].buttonLabel,
              onPressed: brief.nextSteps[i].onPressed,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '② 根拠',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            brief.rationale,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
              fontSize: 14,
            ),
          ),
          if (brief.footnote.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '③ 補足',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              brief.footnote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                height: 1.4,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 反応ランキング本体。将来「似た商品を探す」「同じショップを見る」は [_RankingTile] 行の下に足しやすい。
class _RankingSection extends StatelessWidget {
  const _RankingSection({
    required this.doneCount,
    required this.filter,
    required this.onFilterChanged,
    required this.products,
    required this.shell,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final int doneCount;
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
            LayoutBuilder(
              builder: (context, _) {
                final fabReserve =
                    MediaQuery.viewPaddingOf(context).right + 56;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 2,
                      right: fabReserve.clamp(16.0, 72.0),
                    ),
                    child: Row(
                      children: [
                        _chip(context, 'すべて', _ReactionFilter.all),
                        _chip(context, '売れた', _ReactionFilter.sold),
                        _chip(context, '反応あり', _ReactionFilter.liked),
                        _chip(context, 'その他', _ReactionFilter.weak),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                );
              },
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

/// 1件分の行。現状は [onTap] のみ。将来、アイコン行や副CTAを [child] 直下に足せる構造。
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
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Text(
                        '$rank',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.accentPrimary,
                              fontSize: 17,
                            ),
                      ),
                    ),
                  ),
                ),
                _Thumb(url: product.imageUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.itemName.trim().isEmpty
                            ? '商品名なし'
                            : product.itemName.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  height: 1.25,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: AppColors.accentPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Center(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                      size: 24,
                    ),
                  ),
                ),
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
    if (r.isWeak) return 'その他';
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
        width: 58,
        height: 58,
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
    required this.outcomeLens,
    required this.onOutcomeLensChanged,
    required this.outcomeSubsetCount,
    required this.genreRows,
    required this.shopRows,
    required this.timeBuckets,
  });

  final _OutcomeLens outcomeLens;
  final ValueChanged<_OutcomeLens> onOutcomeLensChanged;
  final int outcomeSubsetCount;
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

  /// 見出し＋件数の2行（口語に近いトーンで揃える）。
  Widget _lensContextHeader(BuildContext context) {
    final theme = Theme.of(context);
    final n = widget.outcomeSubsetCount;
    final (line1, line2) = switch (widget.outcomeLens) {
      _OutcomeLens.combined => (
        '売れた商品と「反応あり」の傾向',
        '$n件をもとに分析しています',
      ),
      _OutcomeLens.sold => (
        '売れた商品の傾向',
        '$n件をもとに分析しています',
      ),
      _OutcomeLens.likedOnly => (
        '反応あり・売れたものは含めない傾向',
        '$n件をもとに分析しています',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line1,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.35,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          line2,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
            height: 1.35,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = widget.outcomeSubsetCount < 6;

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
          _lensContextHeader(context),
          const SizedBox(height: 12),
          SegmentedButton<_OutcomeLens>(
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              ),
            ),
            segments: const [
              ButtonSegment(
                value: _OutcomeLens.combined,
                label: Text('総合'),
              ),
              ButtonSegment(
                value: _OutcomeLens.sold,
                label: Text('売れた'),
              ),
              ButtonSegment(
                value: _OutcomeLens.likedOnly,
                label: Text('反応あり'),
              ),
            ],
            selected: {widget.outcomeLens},
            onSelectionChanged: (s) {
              if (s.isEmpty) return;
              widget.onOutcomeLensChanged(s.first);
              setState(() => _rowsExpanded = false);
            },
          ),
          const SizedBox(height: 12),
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
              '※ 成果件数が少ないため参考値として見てください',
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
    final n = widget.outcomeSubsetCount;
    return switch (_tab) {
      _TrendSubTab.genre =>
        _ActivityAnalyticsTabState._outcomeGenreSectionCopy(
          widget.genreRows,
          n,
        ),
      _TrendSubTab.shop =>
        _ActivityAnalyticsTabState._outcomeShopSectionCopy(
          widget.shopRows,
          n,
        ),
      _TrendSubTab.time =>
        _ActivityAnalyticsTabState._outcomeTimeSectionCopy(
          widget.timeBuckets,
          n,
        ),
    };
  }

  Widget _genreShopBody(BuildContext context, List<_AggRow> rows) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return Text(
        'この条件の成果データがありません',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    final denomTotal =
        widget.outcomeSubsetCount > 0 ? widget.outcomeSubsetCount : 1;
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
          'ランキング（分析対象内の件数シェア）',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        for (var rank = 0; rank < visible.length; rank++) ...[
          _trendDistRow(
            context,
            visible[rank],
            barDenom,
            denomTotal,
            rank + 1,
          ),
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
    int rank,
  ) {
    final theme = Theme.of(context);
    final share = (r.count / denomTotal).clamp(0.0, 1.0);
    final progress = (share / barDenom).clamp(0.0, 1.0);
    final pctOfAll = (share * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '$rank',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.accentPrimary,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: Text(
                r.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${r.count}件（$pctOfAll%）',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
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
            color: AppColors.accentPrimary.withValues(alpha: 0.95),
          ),
        ),
      ],
    );
  }

  Widget _timeBody(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = widget.timeBuckets;
    final sum = buckets.fold<int>(0, (a, b) => a + b.count);
    final sparse = sum < 3 || widget.outcomeSubsetCount < 4;
    final maxC = buckets.fold<int>(0, (a, b) => a > b.count ? a : b.count);
    final denom = maxC > 0 ? maxC : 1;
    var bestI = 0;
    var bestC = -1;
    for (var i = 0; i < buckets.length; i++) {
      if (buckets[i].count > bestC) {
        bestC = buckets[i].count;
        bestI = i;
      }
    }
    final hasBest = sum > 0 && bestC > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '3時間単位・記録された投稿時刻を使用します',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (sparse) ...[
          const SizedBox(height: 6),
          Text(
            '※ まだ参考値です（成果${widget.outcomeSubsetCount}件）',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (hasBest) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentPrimary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '🔥 ゴールデンタイム',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${buckets[bestI].label}・$bestC件',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < buckets.length; i++) ...[
          _timeBucketRow(
            context,
            buckets[i],
            buckets[i].count / denom,
            i == bestI && buckets[i].count == bestC && buckets[i].count > 0,
          ),
          if (i < buckets.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _timeBucketRow(
    BuildContext context,
    ({String label, int count}) b,
    double fill01,
    bool showStrongest,
  ) {
    final theme = Theme.of(context);
    final bar = b.count <= 0
        ? 0.02
        : fill01.clamp(0.08, 1.0).toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            b.label,
            maxLines: 2,
            softWrap: true,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              height: 1.15,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: bar,
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.accentPrimary.withValues(
                alpha: showStrongest ? 1.0 : 0.55,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text(
            '${b.count}件',
            textAlign: TextAlign.right,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        if (showStrongest) ...[
          const SizedBox(width: 4),
          Text(
            '←最強',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _RoomReactionAnalyticsSection extends StatefulWidget {
  const _RoomReactionAnalyticsSection({
    required this.allItems,
  });

  final List<RakutenManagedProduct> allItems;

  @override
  State<_RoomReactionAnalyticsSection> createState() =>
      _RoomReactionAnalyticsSectionState();
}

class _RoomReactionAnalyticsSectionState
    extends State<_RoomReactionAnalyticsSection> {
  RoomReactionSyncHistoryEntry? _history;
  int? _lastLogSignature;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeEmitLogs());
  }

  @override
  void didUpdateWidget(covariant _RoomReactionAnalyticsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeEmitLogs());
  }

  Future<void> _loadHistory() async {
    final e = await RoomReactionSyncHistoryStore.loadLatest();
    if (!mounted) return;
    setState(() => _history = e);
  }

  void _maybeEmitLogs() {
    if (!kDebugMode) return;
    if (!mounted) return;
    final elig = roomReactionAnalyticsEligibleItems(widget.allItems);
    var sig = elig.length;
    for (final e in elig) {
      sig = Object.hash(
        sig,
        e.productId,
        e.roomLikeCount,
        e.roomCommentCount,
        e.updatedAt.millisecondsSinceEpoch,
      );
    }
    if (_lastLogSignature == sig) return;
    _lastLogSignature = sig;

    var withReaction = 0;
    var withComment = 0;
    for (final e in elig) {
      if (roomReactionAnalyticsHasReaction(e)) withReaction++;
      if (_commentOf(e) > 0) withComment++;
    }
    final genreMap = <String, int>{};
    final shopMap = <String, int>{};
    for (final e in elig) {
      final gk = roomReactionAnalyticsGenreBucket(e);
      genreMap[gk] =
          (genreMap[gk] ?? 0) + roomReactionAnalyticsReactionSum(e);
      final sk = roomReactionAnalyticsShopBucket(e);
      if (sk.key.isNotEmpty) {
        shopMap[sk.key] =
            (shopMap[sk.key] ?? 0) + roomReactionAnalyticsReactionSum(e);
      }
    }
    logRoomReactionAnalyticsSource(
      totalDoneRoomItems: elig.length,
      itemsWithReaction: withReaction,
      itemsWithComment: withComment,
      genresAggregated: genreMap.length,
      shopsAggregated: shopMap.length,
    );

    final topScore = List<RakutenManagedProduct>.from(elig)
      ..sort((a, b) {
        final d = roomReactionAnalyticsReactionScore(b)
            .compareTo(roomReactionAnalyticsReactionScore(a));
        if (d != 0) return d;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final ranked = topScore
        .where(roomReactionAnalyticsHasReaction)
        .take(5)
        .toList(growable: false);
    for (var i = 0; i < ranked.length; i++) {
      final p = ranked[i];
      logRoomReactionAnalyticsTopProduct(
        rank: i + 1,
        productId: p.productId,
        title: p.itemName,
        like: _likeOf(p),
        comment: _commentOf(p),
        reactionScore: roomReactionAnalyticsReactionScore(p),
        shopName: _shopLine(p),
        genreName: _genreLine(p),
      );
    }
  }

  int _likeOf(RakutenManagedProduct e) => e.roomLikeCount ?? 0;

  int _commentOf(RakutenManagedProduct e) => e.roomCommentCount ?? 0;

  String _shopLine(RakutenManagedProduct e) {
    final n = e.shopName.trim();
    if (n.isNotEmpty) return n;
    final c = e.shopCode.trim();
    return c.isEmpty ? '' : c;
  }

  String _genreLine(RakutenManagedProduct e) {
    final a = e.persistedGenreDisplayName?.trim();
    if (a != null && a.isNotEmpty) return a;
    final g = e.genreName.trim();
    return g.isEmpty ? 'ジャンル未確認' : g;
  }

  @override
  Widget build(BuildContext context) {
    final elig = roomReactionAnalyticsEligibleItems(widget.allItems);
    final deltas = roomReactionAnalyticsDeltaMap(_history);
    final withReaction =
        elig.where(roomReactionAnalyticsHasReaction).toList(growable: false);

    final topByScore = List<RakutenManagedProduct>.from(withReaction)
      ..sort((a, b) {
        final d = roomReactionAnalyticsReactionScore(b)
            .compareTo(roomReactionAnalyticsReactionScore(a));
        if (d != 0) return d;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final top5Score = topByScore.take(5).toList(growable: false);

    final withComment =
        elig.where((e) => _commentOf(e) > 0).toList(growable: false);
    withComment.sort((a, b) {
      final d = _commentOf(b).compareTo(_commentOf(a));
      if (d != 0) return d;
      return roomReactionAnalyticsReactionScore(b)
          .compareTo(roomReactionAnalyticsReactionScore(a));
    });
    final top5Comment = withComment.take(5).toList(growable: false);

    final genreMap = <String, int>{};
    for (final e in elig) {
      final k = roomReactionAnalyticsGenreBucket(e);
      genreMap[k] =
          (genreMap[k] ?? 0) + roomReactionAnalyticsReactionSum(e);
    }
    final genreTop = genreMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Genre = genreTop.take(5).toList(growable: false);
    final maxGenreSum =
        top5Genre.isEmpty ? 0 : top5Genre.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    final shopLabelByKey = <String, String>{};
    final shopMap = <String, int>{};
    for (final e in elig) {
      final b = roomReactionAnalyticsShopBucket(e);
      if (b.key.isEmpty) continue;
      shopLabelByKey[b.key] = b.label;
      shopMap[b.key] =
          (shopMap[b.key] ?? 0) + roomReactionAnalyticsReactionSum(e);
    }
    final shopTop = shopMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Shop = shopTop.take(5).toList(growable: false);
    final maxShopSum =
        top5Shop.isEmpty ? 0 : top5Shop.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    final historyIncreased = _history == null
        ? const <RoomReactionSyncTopProduct>[]
        : (List<RoomReactionSyncTopProduct>.from(
                _history!.topReactedProducts,
              )..sort((a, b) {
                final sa = a.deltaLike + a.deltaComment * 3;
                final sb = b.deltaLike + b.deltaComment * 3;
                final d = sb.compareTo(sa);
                if (d != 0) return d;
                return b.roomLikeCount.compareTo(a.roomLikeCount);
              }))
            .where((p) => p.deltaLike > 0 || p.deltaComment > 0)
            .take(5)
            .toList(growable: false);

    return AppCard(
      padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
      elevated: true,
      radius: ActivityScreenLayout.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '反応があった商品',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'いいね・コメントが付いた商品から、次に伸ばしやすい傾向を確認できます。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontSize: 15,
                ),
          ),
          if (elig.isEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'ROOMの投稿URLがあり、いいね・コメント数が取り込まれているコレ済商品がまだありません。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
            ),
          ] else ...[
            if (_history != null) ...[
              const SizedBox(height: 14),
              _RoomReactionLastSyncSummaryCard(entry: _history!),
            ],
            if (historyIncreased.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '直近で反応が増えた商品',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              ...historyIncreased.map((p) {
                final managed =
                    activityFindProduct(widget.allItems, p.productId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RoomReactionIncreasedRow(
                    snapshot: p,
                    managed: managed,
                  ),
                );
              }),
            ],
            const SizedBox(height: 14),
            _RoomReactionSubheading(title: '反応が多いROOM投稿（最大5件）'),
            const SizedBox(height: 6),
            if (withReaction.isEmpty)
              _RoomReactionEmptyLine(
                'まだいいね・コメントが付いた商品がありません。',
              )
            else
              ..._productBlocks(context, top5Score, deltas),
            const SizedBox(height: 12),
            _RoomReactionSubheading(title: 'コメントが付いた商品（最大5件）'),
            const SizedBox(height: 6),
            if (withComment.isEmpty)
              _RoomReactionEmptyLine(
                'コメントが付いた商品はまだありません。',
              )
            else
              ..._productBlocks(context, top5Comment, deltas),
            const SizedBox(height: 12),
            _RoomReactionSubheading(title: '反応が多いジャンル（いいね+コメント合計・上位5件）'),
            const SizedBox(height: 6),
            if (top5Genre.isEmpty ||
                top5Genre.every((e) => e.value <= 0))
              _RoomReactionEmptyLine(
                '反応が集まり次第、ここに表示されます。',
              )
            else
              ...top5Genre.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _RoomReactionAggRow(
                    label: e.key,
                    value: e.value,
                    max: maxGenreSum <= 0 ? 1 : maxGenreSum,
                  ),
                );
              }),
            const SizedBox(height: 12),
            _RoomReactionSubheading(title: '反応が多いショップ（いいね+コメント合計・上位5件）'),
            const SizedBox(height: 6),
            if (top5Shop.isEmpty ||
                top5Shop.every((e) => e.value <= 0))
              _RoomReactionEmptyLine(
                '反応が集まり次第、ここに表示されます。',
              )
            else
              ...top5Shop.map((e) {
                final label = shopLabelByKey[e.key] ?? e.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _RoomReactionAggRow(
                    label: label,
                    value: e.value,
                    max: maxShopSum <= 0 ? 1 : maxShopSum,
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  List<Widget> _productBlocks(
    BuildContext context,
    List<RakutenManagedProduct> rows,
    Map<String, RoomReactionSyncTopProduct> deltas,
  ) {
    if (rows.isEmpty) return const [];
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        out.add(
          Divider(
            height: 1,
            color: AppColors.divider.withValues(alpha: 0.45),
          ),
        );
      }
      out.add(
        _RoomReactionProductBlock(
          product: rows[i],
          delta: deltas[rows[i].productId.trim()],
        ),
      );
    }
    return out;
  }
}

class _RoomReactionLastSyncSummaryCard extends StatelessWidget {
  const _RoomReactionLastSyncSummaryCard({
    required this.entry,
  });

  final RoomReactionSyncHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '前回の反応確認（分析）',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '確認${entry.checkedItems}件 / 反応あり${entry.hasReactionItems}件 / '
              'コメントあり${entry.commentedItems}件',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomReactionIncreasedRow extends StatelessWidget {
  const _RoomReactionIncreasedRow({
    required this.snapshot,
    required this.managed,
  });

  final RoomReactionSyncTopProduct snapshot;
  final RakutenManagedProduct? managed;

  @override
  Widget build(BuildContext context) {
    final title = snapshot.title.trim().isEmpty
        ? '（商品名なし）'
        : snapshot.title.trim();
    final managedTitle = managed?.itemName.trim();
    final lineParts = <String>[];
    if (snapshot.deltaLike > 0) {
      lineParts.add('前回よりいいね +${snapshot.deltaLike}');
    }
    if (snapshot.deltaComment > 0) {
      lineParts.add('コメント +${snapshot.deltaComment}');
    }
    final deltaLine = lineParts.join(' / ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.trending_up_rounded, size: 18, color: AppColors.accentPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                managedTitle != null && managedTitle.isNotEmpty
                    ? managedTitle
                    : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
              ),
              if (deltaLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  deltaLine,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
              Text(
                '現在 いいね ${managed != null ? (managed!.roomLikeCount ?? snapshot.roomLikeCount) : snapshot.roomLikeCount} / '
                'コメント ${managed != null ? (managed!.roomCommentCount ?? snapshot.roomCommentCount) : snapshot.roomCommentCount}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'ROOMコレで開く',
          onPressed: managed == null
              ? null
              : () => activityNavigateForProductId(
                    context,
                    productId: managed!.productId,
                  ),
          icon: const Icon(Icons.collections_bookmark_outlined, size: 20),
        ),
      ],
    );
  }
}

class _RoomReactionSubheading extends StatelessWidget {
  const _RoomReactionSubheading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _RoomReactionEmptyLine extends StatelessWidget {
  const _RoomReactionEmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
      ),
    );
  }
}

class _RoomReactionAggRow extends StatelessWidget {
  const _RoomReactionAggRow({
    required this.label,
    required this.value,
    required this.max,
  });

  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final fill = max <= 0 ? 0.0 : (value / max).clamp(0.08, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: fill.toDouble(),
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.accentPrimary.withValues(alpha: 0.75),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}

class _RoomReactionProductBlock extends StatelessWidget {
  const _RoomReactionProductBlock({
    required this.product,
    required this.delta,
  });

  final RakutenManagedProduct product;
  final RoomReactionSyncTopProduct? delta;

  @override
  Widget build(BuildContext context) {
    final like = product.roomLikeCount ?? 0;
    final comment = product.roomCommentCount ?? 0;
    final genre = product.persistedGenreDisplayName?.trim();
    final genreLine =
        (genre != null && genre.isNotEmpty) ? genre : product.genreName.trim();
    final genreOut =
        genreLine.isEmpty ? 'ジャンル未確認' : genreLine;
    final shopLine = product.shopName.trim().isNotEmpty
        ? product.shopName.trim()
        : product.shopCode.trim();

    final deltaParts = <String>[];
    if (delta != null) {
      if (delta!.deltaLike > 0) {
        deltaParts.add('前回よりいいね +${delta!.deltaLike}');
      }
      if (delta!.deltaComment > 0) {
        deltaParts.add('コメント +${delta!.deltaComment}');
      }
    }
    final roomUrl = product.roomUrl.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        height: 1.25,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'いいね $like ・ コメント $comment',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                ),
                if (deltaParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    deltaParts.join(' / '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.accentPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
                Text(
                  shopLine.isEmpty ? 'ショップ —' : shopLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                ),
                Text(
                  genreOut,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    TextButton(
                      onPressed: roomUrl.isEmpty
                          ? null
                          : () => unawaited(
                                AppActionService.openUrl(
                                  context,
                                  url: roomUrl,
                                ),
                              ),
                      child: const Text('ROOMで見る'),
                    ),
                    TextButton(
                      onPressed: product.rakutenOpenUrl.trim().isEmpty
                          ? null
                          : () => unawaited(
                                AppActionService.openUrl(
                                  context,
                                  url: product.rakutenOpenUrl,
                                ),
                              ),
                      child: const Text('楽天で見る'),
                    ),
                    TextButton(
                      onPressed: () {
                        activityNavigateForProductId(
                          context,
                          productId: product.productId,
                        );
                      },
                      child: const Text('ROOMコレ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
