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
import '../../services/room_reaction_sync_history_store.dart';
import '../../state/rakuten_managed_product_provider.dart';
import '../../state/room_activity_event_provider.dart';
import '../../state/saved_shop_provider.dart';
import '../../theme/activity_screen_tokens.dart';
import '../../theme/app_theme.dart';
import '../../utils/analytics_shop_search_launcher.dart';
import '../../utils/analytics_unknown_label.dart';
import '../../utils/room_reaction_analytics.dart';
import '../../utils/room_sync_log.dart';
import '../../utils/shop_display_resolve.dart';
import '../../widgets/app_card.dart';
import '../../widgets/product_open_action_buttons.dart';
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

enum _OutcomeLens { combined, sold, likedOnly }

/// 分析サブタブのセクション表示フラグ（将来復活・再設計用）。
abstract final class _ActivityAnalyticsUiFlags {
  _ActivityAnalyticsUiFlags._();

  /// 「次にやること」カード。現時点では分析価値が弱いため非表示。
  static const bool showDecisionInsightCard = false;

  /// 「今日の気づき」カード。再設計後に復活予定のため非表示。
  static const bool showTodayInsightCard = false;
}

class _ActivityAnalyticsTabState extends State<ActivityAnalyticsTab> {
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
          logRoomReactionAnalyticsNoSideEffectIfChanged(
            candidateCount: candidateCount,
            doneCount: allDoneCount,
            todayAppCollectCount: todayCollectedByApp,
            todayRoomImportCount: todayImportedFromRoom,
            importedFromRoomCount: importedFromRoomCount,
          );
        }
        final listChildren = <Widget>[
          KeyedSubtree(
            key: widget.roomReactionSectionKey,
            child: _RoomReactionAnalyticsSection(
              allItems: items,
            ),
          ),
        ];

        if (_ActivityAnalyticsUiFlags.showDecisionInsightCard) {
          final done = items
              .where(
                (e) =>
                    RakutenManagedProduct.isMemberForStatusTab(
                      e,
                      RakutenManagedProductStatus.done,
                    ),
              )
              .toList(growable: false);
          final outcomeLens = _OutcomeLens.combined;
          final outcomeSubset = _outcomeSubset(done, outcomeLens);
          final genreRows = _genreOutcomeAggregation(outcomeSubset);
          final shopRows = _shopOutcomeAggregation(outcomeSubset);
          final timeBuckets = _postedHourBuckets8(outcomeSubset, act.events);
          final insight = _buildDecisionBrief(
            context: context,
            shell: shell,
            done: done,
            outcomeSubset: outcomeSubset,
            outcomeLens: outcomeLens,
            genreRows: genreRows,
            shopRows: shopRows,
            timeBuckets: timeBuckets,
            savedShopIds: saved.shops
                .map((e) => e.shopId.trim())
                .where((e) => e.isNotEmpty)
                .toSet(),
          );
          listChildren.insertAll(0, [
            _DecisionInsightCard(brief: insight),
            const SizedBox(height: ActivityScreenLayout.sectionGap),
          ]);
        }

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            controller: widget.scrollController,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              ActivityScreenLayout.paddingH,
              8,
              ActivityScreenLayout.paddingH +
                  ActivityScreenLayout.fabSideReserve,
              bottomPad,
            ),
            children: listChildren,
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
    final labels = <String, String>{};
    final genreIds = <String, String>{};
    for (final p in subset) {
      if (!roomReactionAnalyticsGenreTrendEligible(p)) {
        continue;
      }
      final label = _resolvedGenreLabelForOutcome(p);
      if (label == null) continue;
      final gid = p.genreId.trim();
      final key = gid.isNotEmpty ? gid : label;
      map[key] = (map[key] ?? 0) + 1;
      labels[key] = label;
      if (gid.isNotEmpty) genreIds[key] = gid;
    }
    final list = map.entries
        .map(
          (e) => _AggRow(
            label: labels[e.key] ?? e.key,
            count: e.value,
            reactCount: e.value,
            genreId: genreIds[e.key],
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
    final labels = <String, String>{};
    for (final p in subset) {
      if (!roomReactionAnalyticsShopTrendEligible(p)) continue;
      final code = p.shopCode.trim();
      if (code.isEmpty) continue;
      final label = ShopDisplayResolve.resolveDisplayShopName(
        shopName: p.shopName,
        shopCode: code,
        screen: 'activityOutcomeShop',
      );
      if (AnalyticsUnknownLabel.isUnknownShopLabel(label, shopCode: code)) {
        continue;
      }
      map[code] = (map[code] ?? 0) + 1;
      labels[code] = label;
    }
    final list = map.entries
        .map(
          (e) => _AggRow(
            label: labels[e.key] ?? e.key,
            count: e.value,
            reactCount: e.value,
            shopCode: e.key,
          ),
        )
        .toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  static String? _resolvedGenreLabelForOutcome(RakutenManagedProduct p) {
    final persisted = p.persistedGenreDisplayName?.trim() ?? '';
    if (persisted.isNotEmpty &&
        AnalyticsUnknownLabel.isAnalyticsEligibleGenre(
          persisted,
          genreId: p.genreId,
        )) {
      return persisted;
    }
    return AnalyticsUnknownLabel.resolveAnalyticsGenreLabel(
      genreName: p.genreName,
      genreId: p.genreId,
    );
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
        conclusion: 'まだ分析材料が少ないです。',
        rationale:
            'まずはおすすめコレから候補を2件追加し、コレ済に移して結果を記録しましょう。',
        footnote: 'コレ済：${done.length}件',
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

    final doneTotal = done.length;
    final sampleHeadline = doneTotal == n
        ? '評価が付いた$n件から読み取れること'
        : '評価が付いた$n件から読み取れること（コレ済$doneTotal件）';
    analyticsCountSourceLog(
      'tag=ANALYTICS_SAMPLE_COUNT_COPY outcomeCount=$n doneTotal=$doneTotal '
      'headline=$sampleHeadline lens=$lensJa',
    );
    final rationale = StringBuffer()
      ..write('$sampleHeadline（$lensJa）：')
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
    if (topGenre != null &&
        topGenre.count >= 2 &&
        !AnalyticsUnknownLabel.isUnknownGenreLabel(topGenre.label)) {
      final genreCta = switch (outcomeLens) {
        _OutcomeLens.sold => '売れたジャンルの商品を探す',
        _OutcomeLens.likedOnly => '「${topGenre.label}」の商品を探す',
        _OutcomeLens.combined => '成果の出たジャンルの商品を探す',
      };
      final gid = topGenre.genreId?.trim() ?? '';
      nextSteps.add(
        _NextStepAction(
          title: '「${topGenre.label}」系をあと3件候補に追加する',
          basis: '最多ジャンルは「${topGenre.label}」の${topGenre.count}件です',
          buttonLabel: genreCta,
          onPressed: () {
            if (gid.isNotEmpty) {
              unawaited(
                openRakutenSearchScreen(
                  navCtx,
                  initialMode: RakutenSearchInitialMode.genre,
                  initialGenreId: gid,
                ),
              );
            } else {
              navRec();
            }
          },
        ),
      );
    } else if (topGenre != null && topGenre.count >= 2) {
      AnalyticsUnknownLabel.logNextActionGuard(
        candidateAction: 'outcomeGenreExplore',
        removed: true,
        reason: 'unknownGenre',
      );
    }
    if (topShop != null &&
        topShop.count >= 2 &&
        topShop.shopCode != null &&
        topShop.shopCode!.trim().isNotEmpty) {
      final shopLabel = _shortShopLabel(topShop.label);
      nextSteps.add(
        _NextStepAction(
          title: '「$shopLabel」で商品を探す',
          basis: '最多ショップは「$shopLabel」の${topShop.count}件です',
          buttonLabel: '「$shopLabel」の商品を探す',
          onPressed: () => AnalyticsShopSearchLauncher.launchShopSearch(
            navCtx,
            shopCode: topShop.shopCode!,
            shopName: topShop.label,
            screen: 'activityOutcomeBrief',
          ),
        ),
      );
    }
    if (nextSteps.isEmpty) {
      final hasEligibleGenre = genreRows.isNotEmpty;
      final hasEligibleShop = shopRows.isNotEmpty;
      if (!hasEligibleGenre && !hasEligibleShop) {
        nextSteps.add(
          _NextStepAction(
            title: 'まだ十分な傾向はありません',
            basis: 'まずは反応がある商品を増やしましょう',
            buttonLabel: 'おすすめコレを開く',
            onPressed: navRec,
          ),
        );
      } else {
        nextSteps.add(
          _NextStepAction(
            title: '候補を増やして成果のサンプルを厚くする',
            basis: '成果は$n件ありますが、時間帯・ジャンル・ショップの偏りがまだはっきりしません',
            buttonLabel: 'おすすめコレを開く',
            onPressed: navRec,
          ),
        );
      }
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

  static String _shortShopLabel(String raw) {
    final t = raw.trim();
    if (t.length <= 18) return t;
    return '${t.substring(0, 16)}…';
  }
}

class _AggRow {
  const _AggRow({
    required this.label,
    required this.count,
    required this.reactCount,
    this.genreId,
    this.shopCode,
  });

  final String label;
  final int count;
  final int reactCount;
  final String? genreId;
  final String? shopCode;

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

  static String _compactInsightLine(String raw, {int maxChars = 44}) {
    final t = raw.trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars - 1)}…';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
      elevated: true,
      radius: ActivityScreenLayout.cardRadius,
      borderColor: ActivityScreenUi.border,
      backgroundColor: ActivityScreenUi.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.bolt_rounded, size: 26, color: ActivityScreenUi.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '次にやること',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: ActivityScreenUi.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < brief.nextSteps.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: ActivityScreenUi.subBlockFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ActivityScreenUi.subBlockBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    brief.nextSteps[i].title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      fontSize: 15,
                      color: ActivityScreenUi.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _compactInsightLine(brief.nextSteps[i].basis),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ActivityScreenUi.textSecondary,
                      height: 1.35,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (i == 0)
                    FilledButton.icon(
                      onPressed: brief.nextSteps[i].onPressed,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(brief.nextSteps[i].buttonLabel),
                      style: ActivityScreenUi.primaryFilledButtonStyle(
                        theme: theme,
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: brief.nextSteps[i].onPressed,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(brief.nextSteps[i].buttonLabel),
                      style: ActivityScreenUi.primaryOutlinedButtonStyle(
                        theme: theme,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
  bool _historyLoadDone = false;
  int? _lastLogSignature;
  bool _topProductsExpanded = false;

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
    setState(() {
      _history = e;
      _historyLoadDone = true;
    });
    _emitHistoryDebugLog();
  }

  void _emitHistoryDebugLog() {
    if (!kDebugMode || !_historyLoadDone) return;
    final tops = _history?.topReactedProducts ?? const <RoomReactionSyncTopProduct>[];
    var dLike = 0;
    var dCom = 0;
    for (final p in tops) {
      if (p.deltaLike > 0) dLike++;
      if (p.deltaComment > 0) dCom++;
    }
    logRoomReactionAnalyticsHistoryIfChanged(
      loaded: true,
      topReactedProducts: tops.length,
      deltaLikeItems: dLike,
      deltaCommentItems: dCom,
    );
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
    final reacted = elig.where(roomReactionAnalyticsHasReaction).toList();
    for (final e in elig) {
      if (roomReactionAnalyticsHasReaction(e)) withReaction++;
      if (_commentOf(e) > 0) withComment++;
    }
    final genreMap = <String, int>{};
    final shopMap = <String, int>{};
    for (final e in reacted) {
      final gk = roomReactionAnalyticsGenreBucket(e);
      genreMap[gk] =
          (genreMap[gk] ?? 0) + roomReactionAnalyticsReactionSum(e);
      final sk = roomReactionAnalyticsShopBucket(e);
      shopMap[sk.key] =
          (shopMap[sk.key] ?? 0) + roomReactionAnalyticsReactionSum(e);
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

  String _shopLine(RakutenManagedProduct e) =>
      roomReactionAnalyticsShopDisplayLine(e);

  String _genreLine(RakutenManagedProduct e) {
    final a = e.persistedGenreDisplayName?.trim();
    if (a != null && a.isNotEmpty) return a;
    final g = e.genreName.trim();
    return g.isEmpty ? 'ジャンル未確認' : g;
  }

  List<String> _buildTodayInsightTexts({
    required int reactionCount,
    required int commentedCount,
    required List<MapEntry<String, int>> genreBySumSorted,
    required List<MapEntry<String, ({String label, int sum})>> shopAggSorted,
  }) {
    if (reactionCount < 1) return [];

    final out = <String>[];
    if (reactionCount < 4) {
      out.add('まだ傾向は参考値です');
      out.add(
        '反応がある商品は見つかっています。もう少し件数が増えると、伸びやすい傾向が見えやすくなります。',
      );
    } else {
      if (genreBySumSorted.isNotEmpty && genreBySumSorted.first.value > 0) {
        out.add(
          '「${genreBySumSorted.first.key}」ジャンルの商品にいいね・コメントが集まっています',
        );
      }
      if (shopAggSorted.isNotEmpty && shopAggSorted.first.value.sum > 0) {
        final lab = shopAggSorted.first.value.label.trim();
        out.add('「$lab」の商品にいいね・コメントが集まっています');
      }
      if (out.isEmpty) {
        out.add('まだ十分な傾向はありません');
        out.add('まずは反応がある商品を増やしましょう');
      }
    }
    if (commentedCount > 0) {
      out.add('コメントが付いた商品は$commentedCount件あります');
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final deltas = roomReactionAnalyticsDeltaMap(_history);
    final elig = roomReactionAnalyticsEligibleItems(widget.allItems);
    final withReaction =
        elig.where(roomReactionAnalyticsHasReaction).toList(growable: false);

    final unknownGenreCount = withReaction
        .where((e) => roomReactionAnalyticsGenreBucket(e) == 'ジャンル未確認')
        .length;
    final unknownShopCount = withReaction
        .where(
          (e) => roomReactionAnalyticsShopBucket(e).label == 'ショップ未確認',
        )
        .length;

    final reactedSorted = List<RakutenManagedProduct>.from(withReaction)
      ..sort((a, b) {
        final sa = roomReactionAnalyticsReactionSum(a);
        final sb = roomReactionAnalyticsReactionSum(b);
        final d = sb.compareTo(sa);
        if (d != 0) return d;
        return roomReactionAnalyticsReactionScore(b)
            .compareTo(roomReactionAnalyticsReactionScore(a));
      });

    final genreTrend = <String, int>{};
    final shopLabelByKey = <String, String>{};
    final shopTrend = <String, int>{};
    for (final e in withReaction) {
      final sum = roomReactionAnalyticsReactionSum(e);
      if (roomReactionAnalyticsGenreTrendEligible(e)) {
        final gk = roomReactionAnalyticsGenreBucket(e);
        genreTrend[gk] = (genreTrend[gk] ?? 0) + sum;
      }
      if (roomReactionAnalyticsShopTrendEligible(e)) {
        final b = roomReactionAnalyticsShopBucket(e);
        shopLabelByKey[b.key] = b.label;
        shopTrend[b.key] = (shopTrend[b.key] ?? 0) + sum;
      }
    }
    List<MapEntry<String, int>> genreRows = genreTrend.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    genreRows = genreRows.take(5).toList();

    if (kDebugMode) {
      logAnalyticsGenreEligibilityAudit(
        items: widget.allItems,
        reactionItems: withReaction,
        genreRows: genreRows.length,
      );
    }

    List<MapEntry<String, ({String label, int sum})>> shopRows =
        shopTrend.entries
            .map(
              (e) => MapEntry(
                e.key,
                (
                  label: shopLabelByKey[e.key] ?? e.key,
                  sum: e.value,
                ),
              ),
            )
            .where((e) => e.value.sum > 0)
            .toList()
          ..sort((a, b) => b.value.sum.compareTo(a.value.sum));
    shopRows = shopRows.take(5).toList();

    final commentedInReaction = withReaction
        .where((e) => _commentOf(e) > 0)
        .length;

    logRoomReactionTrendRenderIfChanged(
      itemsWithReaction: withReaction.length,
      genreRows: genreRows.length,
      shopRows: shopRows.length,
      unknownGenreCount: unknownGenreCount,
      unknownShopCount: unknownShopCount,
    );

    final topGenreLabels =
        genreRows.map((e) => e.key).join(',');
    final topShopLabels =
        shopRows.map((e) => e.value.label).join(',');

    logRoomReactionAnalyticsSectionRenderIfChanged(
      itemsWithReaction: withReaction.length,
      itemsWithComment: commentedInReaction,
      topGenres: topGenreLabels,
      topShops: topShopLabels,
      historyLoaded: _historyLoadDone,
    );

    if (elig.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
        elevated: true,
        radius: ActivityScreenLayout.cardRadius,
        borderColor: ActivityScreenUi.border,
        backgroundColor: ActivityScreenUi.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '反応分析',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: ActivityScreenUi.textPrimary,
                  ),
            ),
            const SizedBox(height: 14),
            Icon(
              Icons.insights_outlined,
              size: 40,
              color: ActivityScreenUi.emptyStateIcon,
            ),
            const SizedBox(height: 10),
            Text(
              'まだ反応データがありません。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ActivityScreenUi.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'ROOM同期の「反応を確認する」から、いいね・コメントを確認できます。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ActivityScreenUi.textSecondary,
                    fontSize: 15,
                    height: 1.35,
                  ),
            ),
          ],
        ),
      );
    }

    if (withReaction.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
        elevated: true,
        radius: ActivityScreenLayout.cardRadius,
        borderColor: ActivityScreenUi.border,
        backgroundColor: ActivityScreenUi.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '反応分析',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: ActivityScreenUi.textPrimary,
                  ),
            ),
            const SizedBox(height: 12),
            Icon(
              Icons.sync_rounded,
              size: 40,
              color: ActivityScreenUi.emptyStateIcon,
            ),
            const SizedBox(height: 10),
            Text(
              'いいねやコメントの取得が進むと、このカードから傾向を確認できます。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ActivityScreenUi.textPrimary,
                    height: 1.4,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'まずはROOM同期カードから「反応を確認する」を実行してください。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ActivityScreenUi.textSecondary,
                    height: 1.35,
                    fontSize: 14,
                  ),
            ),
          ],
        ),
      );
    }

    final maxGenre =
        genreRows.isEmpty ? 1 : genreRows.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxShop = shopRows.isEmpty
        ? 1
        : shopRows.map((e) => e.value.sum).reduce((a, b) => a > b ? a : b);

    const compactProductCap = 3;
    const compactAggCap = 3;
    final topLimit = _topProductsExpanded
        ? reactedSorted.length.clamp(0, 5)
        : reactedSorted.length.clamp(0, compactProductCap);
    final canExpandProducts = reactedSorted.length > compactProductCap;
    final genreRowsShown = genreRows.take(compactAggCap).toList();
    final shopRowsShown = shopRows.take(compactAggCap).toList();
    analyticsCountSourceLog(
      'tag=ANALYTICS_UI_COMPACT nextActions=decisionCard '
      'topProductsShown=$topLimit genresShown=${genreRowsShown.length} '
      'shopsShown=${shopRowsShown.length} expanded=$_topProductsExpanded',
    );

    final children = <Widget>[
      if (_ActivityAnalyticsUiFlags.showTodayInsightCard) ...[
        AppCard(
          padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
          elevated: true,
          radius: ActivityScreenLayout.cardRadius,
          borderColor: ActivityScreenUi.border,
          backgroundColor: ActivityScreenUi.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今日の気づき',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: ActivityScreenUi.textPrimary,
                    ),
              ),
              const SizedBox(height: 10),
              for (final line in _buildTodayInsightTexts(
                reactionCount: withReaction.length,
                commentedCount: commentedInReaction,
                genreBySumSorted: genreRows,
                shopAggSorted: shopRows,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          fontSize: 14,
                          color: ActivityScreenUi.textPrimary,
                        ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: ActivityScreenLayout.sectionGap),
      ],
      AppCard(
        padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
        elevated: true,
        radius: ActivityScreenLayout.cardRadius,
        borderColor: ActivityScreenUi.border,
        backgroundColor: ActivityScreenUi.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '反応が良かった商品',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: ActivityScreenUi.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              withReaction.isEmpty
                  ? 'いいね・コメントが多い順'
                  : '反応が確認できた${withReaction.length}件から（いいね・コメントが多い順）',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ActivityScreenUi.textSecondary,
                    height: 1.4,
                    fontSize: 14,
                  ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < topLimit; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  color: AppColors.divider.withValues(alpha: 0.45),
                ),
              _RoomReactionCompactProductRow(
                rank: i + 1,
                product: reactedSorted[i],
                delta:
                    deltas[reactedSorted[i].productId.trim()],
              ),
            ],
            if (canExpandProducts)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () => setState(
                    () =>
                        _topProductsExpanded = !_topProductsExpanded,
                  ),
                  icon: Icon(
                    _topProductsExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: ActivityScreenUi.primary,
                  ),
                  label: Text(
                    _topProductsExpanded
                        ? '閉じる'
                        : 'もっと見る（最大5件）',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: ActivityScreenUi.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: ActivityScreenLayout.sectionGap),
      AppCard(
        padding: const EdgeInsets.all(ActivityScreenLayout.cardPadding),
        elevated: true,
        radius: ActivityScreenLayout.cardRadius,
        borderColor: ActivityScreenUi.border,
        backgroundColor: ActivityScreenUi.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '反応の傾向',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: ActivityScreenUi.textPrimary,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              '反応が多いジャンル',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'いいね・コメントの合計です',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 10),
            if (genreRowsShown.isEmpty)
              Text(
                unknownGenreCount >= withReaction.length
                    ? 'ジャンル未確認の商品は傾向から除外しています。ROOMコレで商品情報を確認すると表示されます。'
                    : 'ジャンル傾向はまだ十分にありません。商品情報の確認後に表示されます。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              )
            else
              for (var i = 0; i < genreRowsShown.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _RoomReactionAggRow(
                  label: genreRowsShown[i].key,
                  value: genreRowsShown[i].value,
                  max: maxGenre <= 0 ? 1 : maxGenre,
                ),
              ],
            if (unknownGenreCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                'ジャンル未確認の商品は傾向から除外しています。ROOMコレで商品情報を確認すると、分析の精度が上がります。',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              '反応が多いショップ',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'いいね・コメントの合計です',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 10),
            if (shopRows.isEmpty)
              Text(
                unknownShopCount >= withReaction.length
                    ? 'ショップ未確認の商品は傾向から除外しています。ROOMコレで商品情報を確認すると表示されます。'
                    : 'ショップ傾向はまだ十分にありません。商品情報の確認後に表示されます。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              )
            else
              for (var i = 0; i < shopRowsShown.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _RoomReactionAggRow(
                  label: shopRowsShown[i].value.label,
                  value: shopRowsShown[i].value.sum,
                  max: maxShop <= 0 ? 1 : maxShop,
                ),
              ],
            if (shopRows.isNotEmpty) ...[
              const SizedBox(height: 14),
              Builder(
                builder: (context) {
                  final topShop = AnalyticsShopSearchLauncher.topReactedShop(
                    widget.allItems,
                  );
                  final rawShopName = topShop != null &&
                          topShop.shopName.trim().isNotEmpty
                      ? topShop.shopName.trim()
                      : shopRowsShown.isNotEmpty
                      ? shopRowsShown.first.value.label.trim()
                      : '';
                  final shopLabel = rawShopName.isEmpty
                      ? null
                      : _ActivityAnalyticsTabState._shortShopLabel(rawShopName);
                  final ctaLabel = shopLabel != null
                      ? '「$shopLabel」の商品を探す'
                      : '反応が良かったショップで検索する';
                  return OutlinedButton.icon(
                    onPressed: () =>
                        AnalyticsShopSearchLauncher.launchTopShopSearch(
                      context,
                      items: widget.allItems,
                      screen: 'activityReactionTrend',
                    ),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: Text(ctaLabel),
                    style: ActivityScreenUi.primaryOutlinedButtonStyle(
                      theme: Theme.of(context),
                      minHeight: 48,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _RoomReactionCompactProductRow extends StatelessWidget {
  const _RoomReactionCompactProductRow({
    required this.rank,
    required this.product,
    this.delta,
  });

  final int rank;
  final RakutenManagedProduct product;
  final RoomReactionSyncTopProduct? delta;

  @override
  Widget build(BuildContext context) {
    final like = product.roomLikeCount ?? 0;
    final comment = product.roomCommentCount ?? 0;
    final genre = product.persistedGenreDisplayName?.trim();
    final genreLine =
        (genre != null && genre.isNotEmpty) ? genre : product.genreName.trim();
    final genreOut = roomReactionAnalyticsGenreTrendEligible(product) &&
            genreLine.isNotEmpty
        ? genreLine
        : 'ジャンル未確認';
    final shopOut = roomReactionAnalyticsShopDisplayLine(product);
    final price =
        RoomColleProductListCardLayout.formatPriceYen(product.itemPrice);
    final deltaParts = <String>[];
    if (delta != null) {
      if (delta!.deltaLike > 0) {
        deltaParts.add('前回よりいいね +${delta!.deltaLike}');
      }
      if (delta!.deltaComment > 0) {
        deltaParts.add('コメント +${delta!.deltaComment}');
      }
    }
    final deltaLine = deltaParts.join(' / ');

    final soldNote = product.feedbackSoldAt != null;

    Future<void> openRakutenFromCard() async {
      if (kDebugMode) {
        debugPrint(
          '[PRODUCT_CARD_AFFILIATE_TAP_TARGET] screen=activityReactionProduct '
          'productId=${product.productId.trim()} target=titleOrImage',
        );
      }
      final err = await context
          .read<RakutenManagedProductProvider>()
          .openRakutenItemPage(context, product.productId);
      if (!context.mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      }
    }

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: ActivityScreenUi.primary,
                          fontSize: 17,
                        ),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: product.rakutenOpenUrl.trim().isEmpty
                  ? null
                  : () => unawaited(openRakutenFromCard()),
              borderRadius: BorderRadius.circular(10),
              child: _Thumb(url: product.imageUrl),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: product.rakutenOpenUrl.trim().isEmpty
                        ? null
                        : () => unawaited(openRakutenFromCard()),
                    child: Text(
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
                                decoration: product.rakutenOpenUrl
                                        .trim()
                                        .isNotEmpty
                                    ? TextDecoration.underline
                                    : null,
                                decorationColor: AppColors.textPrimary
                                    .withValues(alpha: 0.25),
                              ),
                    ),
                  ),
                    const SizedBox(height: 4),
                    Text(
                      'いいね $like ・ コメント $comment',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary,
                              ),
                    ),
                    if (deltaLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        deltaLine,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: ActivityScreenUi.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                      ),
                    ],
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
                      shopOut,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                    ),
                    Text(
                      genreOut,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                    ),
                    if (soldNote) ...[
                      const SizedBox(height: 4),
                      Text(
                        'コレ済の評価：売れた',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ProductOpenActionButtons(
                      product: product,
                      compact: true,
                      screen: 'activityReactionProduct',
                      logStyleAudit: true,
                      outlineButtonStyle:
                          ActivityScreenUi.compactProductOutlineButtonStyle(
                        theme: Theme.of(context),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => activityNavigateForProductId(
                  context,
                  productId: product.productId,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 8),
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
              backgroundColor: ActivityScreenUi.progressTrack,
              color: ActivityScreenUi.primary.withValues(alpha: 0.75),
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



