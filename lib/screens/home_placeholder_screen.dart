import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/room_activity_event.dart';
import '../models/room_colle_list_filters.dart';
import '../navigation/app_shell_controller.dart';
import '../navigation/rakuten_search_navigator.dart';
import 'today_recommendations_screen.dart';
import '../services/rakuten_room_home_stats.dart';
import '../services/room_kpi_calculator.dart';
import '../state/room_activity_event_provider.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/room_colle_product_list_card_layout.dart';

// --- ホーム画面：レイアウト・タイポ・装飾の統一（画面ロジックとは分離）---

/// ホーム専用の余白・行間・装飾ルール。
abstract final class _HomeUi {
  const _HomeUi._();

  /// 主要ブロック同士（CTA・セクション・グループ）
  static const double gapSection = 14;

  /// ホーム ListView の左右（アプリ全体の [AppDimensions.screenPaddingH] より一段狭めて表示領域を確保）
  static const double screenPaddingH = 10;

  /// ホーム ListView の上下（画面端との距離を少し詰めつつ窮屈にならない程度）
  static const double screenPaddingV = 10;

  /// セクション外枠の角丸（`AppDimensions.radiusCard` と一致）
  static double get radiusSectionOuter => AppDimensions.radiusCard;

  /// 見出し直下のリスト・メトリクス用インセット枠の角丸
  static const double radiusSectionInner = 12;

  /// セクション内の左右インセット（見出し・区切り・デッキ・単独ブロックで共通）
  static const double insetSectionH = 9;

  /// ROOMコレ管理：見出しブロック（一体感を保ちつつ縦だけ詰める）
  static EdgeInsets get paddingRoomSectionHeader =>
      EdgeInsets.fromLTRB(insetSectionH, 7, insetSectionH, 4);

  /// 最近追加した候補：見出しブロック
  static EdgeInsets get paddingRecentSectionHeader =>
      EdgeInsets.fromLTRB(insetSectionH, 7, insetSectionH, 4);

  /// ROOMコレ管理：メトリクスデッキの外周
  static EdgeInsets get paddingDeckOuterRoom =>
      EdgeInsets.fromLTRB(insetSectionH, 0, insetSectionH, 6);

  /// 最近追加した候補：リストデッキの外周
  static EdgeInsets get paddingDeckOuterRecent =>
      EdgeInsets.fromLTRB(insetSectionH, 0, insetSectionH, 4);

  /// 見出し行：先頭アイコンとタイトル列の間
  static const double gapIconToTitle = 8;

  /// 最近候補セクション内「コレ一覧を開く」（主ブロックより一段薄く保つ）
  static EdgeInsets get paddingRecentListFooterAction =>
      EdgeInsets.symmetric(horizontal: insetSectionH, vertical: 4);

  /// ROOMコレ管理：区切り線とタイルデッキの間
  static const double gapRoomDividerToDeck = 2;

  /// ROOMコレ管理：タイルデッキ内のパディング
  static const double paddingRoomTileDeck = 3;

  /// ROOMコレ管理：グリッドの列・行間（統一）
  static const double gapRoomGrid = 3;

  /// 最近候補：区切り線とリストデッキの間
  static const double gapRecentDividerToDeck = 3;

  /// 最近候補：リストデッキの内側パディング
  static const double paddingRecentListDeck = 2;

  /// 最近候補セクション：最下部の余白
  static const double paddingRecentSectionBottom = 1;

  /// コンパクトな縦の詰まり（チップ上など）
  static const double gapTight = 4;

  /// リスト行内：タイトル直下の補足など（複数行スタックの最小縦間隔）
  static const double gapStackTight = 2;

  /// 区切り線の色（ホーム内で統一）
  static Color dividerLineColor() => HomeScreenColors.inlineDivider;

  /// セクション外枠の境界線（アクセント薄いトーン / 通常）
  static Color sectionBorderColor({bool accentTint = false}) {
    if (accentTint) {
      return HomeScreenColors.sectionOutlineAccent;
    }
    return HomeScreenColors.sectionOutlineNeutral;
  }

  /// 標準リストの下余白（ナビバー押さえ以外）
  static const double listBottomExtra = 10;

  /// 行末 chevron のインセット（複所で統一）
  static const EdgeInsets paddingRowChevron = EdgeInsets.only(left: 4, top: 1);

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: HomeScreenColors.cardShadowColor,
      offset: const Offset(0, 2),
      blurRadius: 10,
    ),
  ];

  /// 楽天で検索：説明＋CTA を1ブロックに（先頭単独ボタンの唐突感を抑える）
  static BoxDecoration searchEntrySectionDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.standaloneCardFill,
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(color: sectionBorderColor(accentTint: true)),
      boxShadow: cardShadow,
    );
  }

  /// ROOMコレ管理：見出し〜タイルまでを1ブロックに見せる外枠
  static BoxDecoration roomManagementSectionDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.roomGroupedShellFill,
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(color: sectionBorderColor(accentTint: false)),
      boxShadow: cardShadow,
    );
  }

  /// ROOMコレ管理：4タイルをまとめる内側デッキ（見出しとは色を分ける）
  static BoxDecoration roomTileDeckDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.deckFill,
      borderRadius: BorderRadius.circular(radiusSectionInner),
      border: Border.all(color: HomeScreenColors.deckOutline),
    );
  }

  /// 最近追加した候補：見出し〜一覧〜フッターを1つにまとめる外枠
  static BoxDecoration recentCandidatesSectionDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.recentGroupedShellFill,
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(color: sectionBorderColor(accentTint: false)),
      boxShadow: cardShadow,
    );
  }

  /// セクション見出し：アクセント（ROOM・最近候補）— サイズは [sectionTitle] と揃え色だけ差す
  static TextStyle sectionTitleAccent(BuildContext context) {
    return sectionTitle(
      context,
    ).copyWith(color: HomeScreenColors.accentSectionHeading);
  }

  /// セクション・カード見出し（何が見出しかを揃える）
  static TextStyle sectionTitle(BuildContext context) {
    final base = Theme.of(context).textTheme.titleSmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      height: 1.22,
      letterSpacing: -0.15,
      color: HomeScreenColors.titlePrimary,
    );
  }

  /// 展開した説明文・補足
  static TextStyle sectionBody(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 13,
      height: 1.38,
      color: HomeScreenColors.bodyOnSection,
    );
  }

  /// タップ可能な補足・キャプション
  static TextStyle tapHint(BuildContext context) {
    final base = Theme.of(context).textTheme.labelSmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 11.5,
      height: 1.32,
      color: HomeScreenColors.footnoteMuted,
    );
  }

  /// セクション末尾のサブアクション見出し（本文より弱く、ただしタップ可能と分かる）
  static TextStyle sectionFooterActionTitle(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.08,
      color: HomeScreenColors.footerActionLabel,
    );
  }

  /// 見出し〜デッキ間の区切り（横インセット統一）
  static Widget sectionDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: insetSectionH),
      child: Divider(height: 1, thickness: 1, color: dividerLineColor()),
    );
  }

  /// 空状態・リスト内のサブ見出し
  static TextStyle bodyEmphasis(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    return (base ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w600,
      height: 1.28,
      color: HomeScreenColors.titlePrimary,
    );
  }
}

/// ホーム（ダッシュボード）。ROOM コレ管理の導線と集計を中心に構成する。
class HomePlaceholderScreen extends StatefulWidget {
  const HomePlaceholderScreen({super.key});

  @override
  State<HomePlaceholderScreen> createState() => _HomePlaceholderScreenState();
}

class _HomePlaceholderScreenState extends State<HomePlaceholderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final room = context.read<RakutenManagedProductProvider>();
      await room.refreshManagedProductList(showLoadingIndicator: false);
      if (!mounted) return;
      await context.read<TodayRecommendationProvider>().ensureToday(
        profile: context.read<UserProfileProvider>().profile,
        managedItems: room.items,
        savedShops: context.read<SavedShopProvider>().shops,
      );
    });
  }

  void _openRoomList(
    BuildContext context, {
    int initialTabIndex = 0,
    DateTime? doneFilterLocalDay,
    String? focusCandidateProductId,
    RoomColleStaleCandidatePreset? candidateStalePreset,
  }) {
    final idx = initialTabIndex.clamp(0, 1);
    DateTime? dayNorm;
    if (doneFilterLocalDay != null) {
      try {
        final d = doneFilterLocalDay;
        final y = d.year;
        if (y >= 1900 && y <= 2100) {
          dayNorm = DateTime(d.year, d.month, d.day);
        }
      } catch (_) {}
    }
    final trimmedFocus = focusCandidateProductId?.trim();
    final focusId = trimmedFocus != null && trimmedFocus.isNotEmpty && idx == 0
        ? trimmedFocus
        : null;
    context.read<AppShellController>().openRoomCollect(
      initialTabIndex: idx,
      doneFilterLocalDay: dayNorm,
      focusCandidateProductId: focusId,
      candidateStalePreset: candidateStalePreset,
    );
  }

  void _openActivity(BuildContext context) {
    context.read<AppShellController>().openActivityTab();
  }

  void _openComments(BuildContext context) {
    context.read<AppShellController>().selectTab(2);
  }

  Future<void> _openTodayRecommendations(BuildContext context) async {
    final recommender = context.read<TodayRecommendationProvider>();
    await recommender.ensureToday(
      profile: context.read<UserProfileProvider>().profile,
      managedItems: context.read<RakutenManagedProductProvider>().items,
      savedShops: context.read<SavedShopProvider>().shops,
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TodayRecommendationsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeScreenColors.canvas,
      body: SafeArea(
        child:
            Consumer4<
              RakutenManagedProductProvider,
              RoomActivityEventProvider,
              UserProfileProvider,
              TodayRecommendationProvider
            >(
              builder:
                  (
                    context,
                    roomProvider,
                    actProvider,
                    userProfileProvider,
                    recProvider,
                    _,
                  ) {
                    final items = roomProvider.items;
                    final rawName = userProfileProvider.profile.displayName;
                    final displayName = rawName.trim().isEmpty
                        ? null
                        : rawName.trim();
                    final nCandidate = RakutenRoomHomeStats.countCandidates(
                      items,
                    );
                    final nDone = RakutenRoomHomeStats.countDone(items);
                    final now = DateTime.now();
                    final collectLimit = _CollectLimitStats.from(
                      items: items,
                      events: actProvider.events,
                      now: now,
                    );
                    final nTodayDone = collectLimit.todayCount;
                    final lastDone = RakutenRoomHomeStats.latestDoneAt(items);
                    final recentCandidates =
                        RakutenRoomHomeStats.candidatesNewestFirst(
                          items,
                        ).take(3).toList();
                    final bottomInset = MediaQuery.paddingOf(context).bottom;
                    const navBarReserve = 52.0;
                    final todayLocalDay = DateTime(
                      now.year,
                      now.month,
                      now.day,
                    );

                    final kpiProducts = items
                        .map(RoomKpiProductRecord.fromManagedProduct)
                        .toList(growable: false);
                    final kpi = RoomKpiCalculator.calculate(
                      products: kpiProducts,
                      events: actProvider.events,
                      now: now,
                    );
                    final hasTodaySuggestions = recProvider.totalCount > 0;
                    final todayDoneCountForRec =
                        (recProvider.totalCount - recProvider.pendingCount)
                            .clamp(0, recProvider.totalCount);

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          _HomeUi.screenPaddingH,
                          _HomeUi.screenPaddingV,
                          _HomeUi.screenPaddingH,
                          bottomInset + navBarReserve + _HomeUi.listBottomExtra,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HomeMomentumHeader(displayName: displayName),
                            SizedBox(height: _HomeUi.gapSection),
                            _HomeTodayProgressCard(
                              kpi: kpi,
                              collectLimit: collectLimit,
                              candidateCount: nCandidate,
                              totalCount: recProvider.totalCount,
                              pendingCount: recProvider.pendingCount,
                              isCompleted: recProvider.isCompleted,
                              isLoading: recProvider.isLoading,
                              hasTodaySuggestions: hasTodaySuggestions,
                              todayDoneCountForRec: todayDoneCountForRec,
                              recTotalCount: recProvider.totalCount,
                              onOpenSearch: () =>
                                  openRakutenSearchScreen(context),
                              onOpenCandidates: () =>
                                  _openRoomList(context, initialTabIndex: 0),
                              onOpenActivity: () => _openActivity(context),
                              onPrimaryRecommendations: () =>
                                  _openTodayRecommendations(context),
                            ),
                            _HomeLimitAlertCard(
                              collectLimit: collectLimit,
                              onOrganizeCandidates: () =>
                                  _openRoomList(context, initialTabIndex: 0),
                              onComments: () => _openComments(context),
                              onDoneList: () =>
                                  _openRoomList(context, initialTabIndex: 1),
                              onActivity: () => _openActivity(context),
                            ),
                            SizedBox(height: _HomeUi.gapSection),
                            _HomeNextActionsSection(
                              collectLimit: collectLimit,
                              pendingRecommendations: recProvider.pendingCount,
                              candidateCount: nCandidate,
                              doneCount: nDone,
                              onRecommendations: () =>
                                  _openTodayRecommendations(context),
                              onSearch: () => openRakutenSearchScreen(context),
                              onCandidates: () =>
                                  _openRoomList(context, initialTabIndex: 0),
                              onDone: () =>
                                  _openRoomList(context, initialTabIndex: 1),
                              onComments: () => _openComments(context),
                              onActivity: () => _openActivity(context),
                            ),
                            SizedBox(height: _HomeUi.gapSection),
                            _RecentCandidatesHomeSection(
                              candidates: recentCandidates,
                              candidateTotalCount: nCandidate,
                              onOpenCandidateTap: (productId) => _openRoomList(
                                context,
                                focusCandidateProductId: productId,
                              ),
                              onOpenFullList: () => _openRoomList(context),
                            ),
                            SizedBox(height: _HomeUi.gapSection),
                            _RoomManagementSection(
                              candidateTotal: nCandidate,
                              doneTotal: nDone,
                              todayDoneCount: nTodayDone,
                              lastDoneAt: lastDone,
                              onCandidateTap: () =>
                                  _openRoomList(context, initialTabIndex: 0),
                              onDoneTap: () =>
                                  _openRoomList(context, initialTabIndex: 1),
                              onTodayTap: () => _openRoomList(
                                context,
                                initialTabIndex: 1,
                                doneFilterLocalDay: todayLocalDay,
                              ),
                              onLastCollectTap: () => _openActivity(context),
                            ),
                            SizedBox(height: _HomeUi.gapSection),
                            _HomeShortcutGrid(
                              onSearch: () {
                                openRakutenSearchScreen(context);
                              },
                              onRoomCollect: () => _openRoomList(context),
                              onActivity: () => _openActivity(context),
                              onComments: () => _openComments(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
            ),
      ),
    );
  }
}

enum _CollectLimitState { normal, warning, reached }

class _CollectLimitStats {
  const _CollectLimitStats({
    required this.todayCount,
    required this.hourCount,
    required this.hasAnyCollectRecord,
    required this.hourRecoveryAt,
  });

  static const int dailyLimit = 200;
  static const int hourlyLimit = 100;
  static const int dailyWarningThreshold = 180;
  static const int hourlyWarningThreshold = 80;

  final int todayCount;
  final int hourCount;
  final bool hasAnyCollectRecord;
  final DateTime? hourRecoveryAt;

  int get dailyRemaining => (dailyLimit - todayCount).clamp(0, dailyLimit);
  int get hourlyRemaining => (hourlyLimit - hourCount).clamp(0, hourlyLimit);
  bool get isDailyReached => todayCount >= dailyLimit;
  bool get isHourlyReached => hourCount >= hourlyLimit;
  bool get isAnyLimitReached => isDailyReached || isHourlyReached;
  bool get isDailyWarning =>
      !isDailyReached && todayCount >= dailyWarningThreshold;
  bool get isHourlyWarning =>
      !isHourlyReached && hourCount >= hourlyWarningThreshold;

  _CollectLimitState get dailyState {
    if (isDailyReached) return _CollectLimitState.reached;
    if (isDailyWarning) return _CollectLimitState.warning;
    return _CollectLimitState.normal;
  }

  _CollectLimitState get hourlyState {
    if (isHourlyReached) return _CollectLimitState.reached;
    if (isHourlyWarning) return _CollectLimitState.warning;
    return _CollectLimitState.normal;
  }

  static _CollectLimitStats from({
    required List<RakutenManagedProduct> items,
    required List<RoomActivityEvent> events,
    required DateTime now,
  }) {
    final timestamps = <DateTime>[];
    final productIdsWithDoneAt = <String>{};

    for (final item in items) {
      if (!RakutenManagedProduct.isMemberForStatusTab(
        item,
        RakutenManagedProductStatus.done,
      )) {
        continue;
      }
      final doneAt = item.doneAt;
      if (doneAt == null) continue;
      timestamps.add(doneAt);
      final id = item.productId.trim();
      if (id.isNotEmpty) productIdsWithDoneAt.add(id);
    }

    for (final event in events) {
      if (event.type != RoomActivityEventType.movedToCored) continue;
      if (productIdsWithDoneAt.contains(event.productId.trim())) continue;
      timestamps.add(event.createdAt);
    }

    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final hourStart = now.subtract(const Duration(hours: 1));
    var todayCount = 0;
    final hourTimestamps = <DateTime>[];

    for (final at in timestamps) {
      if (!at.isBefore(todayStart) && at.isBefore(tomorrowStart)) {
        todayCount++;
      }
      if (!at.isBefore(hourStart) && !at.isAfter(now)) {
        hourTimestamps.add(at);
      }
    }
    hourTimestamps.sort();

    return _CollectLimitStats(
      todayCount: todayCount,
      hourCount: hourTimestamps.length,
      hasAnyCollectRecord: timestamps.isNotEmpty,
      hourRecoveryAt: hourTimestamps.isEmpty
          ? null
          : hourTimestamps.first.add(const Duration(hours: 1)),
    );
  }
}

/// ホーム上部：今日の運用判断とコレ上限を1カードにまとめる。
class _HomeTodayProgressCard extends StatelessWidget {
  const _HomeTodayProgressCard({
    required this.kpi,
    required this.collectLimit,
    required this.candidateCount,
    required this.totalCount,
    required this.pendingCount,
    required this.isCompleted,
    required this.isLoading,
    required this.hasTodaySuggestions,
    required this.todayDoneCountForRec,
    required this.recTotalCount,
    required this.onOpenSearch,
    required this.onOpenCandidates,
    required this.onOpenActivity,
    required this.onPrimaryRecommendations,
  });

  final RoomKpiSummary kpi;
  final _CollectLimitStats collectLimit;
  final int candidateCount;
  final int totalCount;
  final int pendingCount;
  final bool isCompleted;
  final bool isLoading;
  final bool hasTodaySuggestions;
  final int todayDoneCountForRec;
  final int recTotalCount;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenCandidates;
  final VoidCallback onOpenActivity;
  final VoidCallback onPrimaryRecommendations;

  @override
  Widget build(BuildContext context) {
    final primary = _primaryAction();
    final statusMessage = collectLimit.isDailyReached
        ? '今日は結果確認へ'
        : collectLimit.isHourlyReached
        ? '今は整理しましょう'
        : pendingCount > 0
        ? 'あと$pendingCount件進めましょう'
        : candidateCount == 0
        ? '候補を探しましょう'
        : '候補を整理して進めましょう';
    final recommendationLabel = isLoading && totalCount == 0
        ? '算出中'
        : totalCount == 0
        ? 'まだなし'
        : pendingCount == 0
        ? '完了'
        : '残り$pendingCount件';
    final doneLabel = hasTodaySuggestions && recTotalCount > 0
        ? 'おすすめ $todayDoneCountForRec/$recTotalCount 件済'
        : '今日の記録から集計';

    return Container(
      width: double.infinity,
      decoration: _HomeUi.searchEntrySectionDecoration(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日のROOM運用',
                      style: _HomeUi.sectionTitle(context).copyWith(
                        color: HomeScreenColors.accentSectionHeading,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(statusMessage, style: _HomeUi.sectionBody(context)),
                  ],
                ),
              ),
              _HomeTinyBadge(
                label: collectLimit.hasAnyCollectRecord ? '記録あり' : '記録なし',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TodayCollectHero(
            count: collectLimit.todayCount,
            limit: _CollectLimitStats.dailyLimit,
            remaining: collectLimit.dailyRemaining,
            state: collectLimit.dailyState,
          ),
          const SizedBox(height: 14),
          _HomeHeroCtaButton(
            icon: primary.icon,
            label: primary.label,
            onPressed: primary.onPressed,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _HomeInlineMetric(label: 'おすすめ', value: recommendationLabel),
              _HomeInlineMetric(
                label: '連続活動',
                value: kpi.consecutiveActiveDays == 0
                    ? '記録待ち'
                    : '${kpi.consecutiveActiveDays}日',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(doneLabel, style: _HomeUi.tapHint(context)),
          const SizedBox(height: 10),
          _CollectLimitProgressLine(
            title: '今日の進捗',
            count: collectLimit.todayCount,
            limit: _CollectLimitStats.dailyLimit,
            remaining: collectLimit.dailyRemaining,
            state: collectLimit.dailyState,
          ),
          const SizedBox(height: 9),
          _CollectLimitProgressLine(
            title: '今コレできる',
            count: collectLimit.hourlyRemaining,
            limit: _CollectLimitStats.hourlyLimit,
            remaining: collectLimit.hourlyRemaining,
            state: collectLimit.hourlyState,
            trailing: _formatRecoveryLabel(collectLimit.hourRecoveryAt),
            progressCount: collectLimit.hourCount,
          ),
        ],
      ),
    );
  }

  _HomeActionSpec _primaryAction() {
    if (collectLimit.isDailyReached) {
      return _HomeActionSpec(
        label: '今日の結果を見る',
        icon: Icons.insights_rounded,
        onPressed: onOpenActivity,
      );
    }
    if (collectLimit.isHourlyReached) {
      return _HomeActionSpec(
        label: '候補を整理',
        icon: Icons.inventory_2_outlined,
        onPressed: onOpenCandidates,
      );
    }
    if (pendingCount > 0) {
      return _HomeActionSpec(
        label: 'おすすめコレを見る',
        icon: Icons.auto_awesome_rounded,
        onPressed: onPrimaryRecommendations,
      );
    }
    if (candidateCount == 0) {
      return _HomeActionSpec(
        label: '候補を探す',
        icon: Icons.travel_explore_rounded,
        onPressed: onOpenSearch,
      );
    }
    return _HomeActionSpec(
      label: '候補を整理',
      icon: Icons.inventory_2_outlined,
      onPressed: onOpenCandidates,
    );
  }
}

class _TodayCollectHero extends StatelessWidget {
  const _TodayCollectHero({
    required this.count,
    required this.limit,
    required this.remaining,
    required this.state,
  });

  final int count;
  final int limit;
  final int remaining;
  final _CollectLimitState state;

  @override
  Widget build(BuildContext context) {
    final accent = switch (state) {
      _CollectLimitState.normal => AppColors.accentPrimary,
      _CollectLimitState.warning => const Color(0xFFE67E22),
      _CollectLimitState.reached => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.accentLight.withValues(alpha: 0.34),
          AppColors.surface,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 40,
                      height: 0.95,
                      letterSpacing: -1.0,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ $limit件',
                  maxLines: 1,
                  style: _HomeUi.sectionBody(context).copyWith(
                    fontWeight: FontWeight.w800,
                    color: HomeScreenColors.footnoteMuted,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '今日のコレ',
                  maxLines: 1,
                  style: _HomeUi.sectionTitle(context).copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            remaining == 0 ? '今日はここまで' : 'あと$remaining件',
            maxLines: 1,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: HomeScreenColors.titlePrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeroCtaButton extends StatelessWidget {
  const _HomeHeroCtaButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPrimary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SizedBox(
        height: 58,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            foregroundColor: AppColors.textOnAccent,
            backgroundColor: AppColors.accentPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: Icon(icon, size: 22),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: AppTextStyles.button.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeActionSpec {
  const _HomeActionSpec({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

class _HomeTinyBadge extends StatelessWidget {
  const _HomeTinyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentLight.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.20),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: HomeScreenColors.accentSectionHeading,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

class _CollectLimitProgressLine extends StatelessWidget {
  const _CollectLimitProgressLine({
    required this.title,
    required this.count,
    required this.limit,
    required this.remaining,
    required this.state,
    this.trailing,
    this.progressCount,
  });

  final String title;
  final int count;
  final int limit;
  final int remaining;
  final _CollectLimitState state;
  final String? trailing;
  final int? progressCount;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _CollectLimitState.normal => AppColors.accentPrimary,
      _CollectLimitState.warning => const Color(0xFFE67E22),
      _CollectLimitState.reached => AppColors.textSecondary,
    };
    final usedCount = progressCount ?? count;
    final progress = limit <= 0 ? 0.0 : (usedCount / limit).clamp(0.0, 1.0);
    final trailingText = trailing == null || trailing!.isEmpty
        ? '残り $remaining件'
        : trailing!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title == '今コレできる'
                    ? '$title：$remaining件'
                    : '$title：$count / $limit件',
                maxLines: 1,
                style: _HomeUi.sectionBody(context).copyWith(
                  fontWeight: FontWeight.w800,
                  color: HomeScreenColors.titlePrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title == '今コレできる' ? '1時間' : trailingText,
              maxLines: 1,
              style: _HomeUi.tapHint(context).copyWith(
                color: state == _CollectLimitState.normal
                    ? HomeScreenColors.footnoteMuted
                    : color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: HomeScreenColors.progressTrack,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _HomeInlineMetric extends StatelessWidget {
  const _HomeInlineMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: HomeScreenColors.roomMetricTileFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HomeScreenColors.metricTileOutline),
      ),
      child: Text(
        '$label：$value',
        maxLines: 1,
        style: _HomeUi.tapHint(context).copyWith(
          color: HomeScreenColors.titlePrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HomeLimitAlertCard extends StatelessWidget {
  const _HomeLimitAlertCard({
    required this.collectLimit,
    required this.onOrganizeCandidates,
    required this.onComments,
    required this.onDoneList,
    required this.onActivity,
  });

  final _CollectLimitStats collectLimit;
  final VoidCallback onOrganizeCandidates;
  final VoidCallback onComments;
  final VoidCallback onDoneList;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    if (!collectLimit.isAnyLimitReached &&
        !collectLimit.isHourlyWarning &&
        !collectLimit.isDailyWarning) {
      return const SizedBox.shrink();
    }

    final isReached = collectLimit.isAnyLimitReached;
    late final String title;
    late final String message;
    late final List<_HomeActionSpec> actions;

    if (collectLimit.isDailyReached) {
      title = '今日の上限に達しました';
      message = '明日また続けましょう';
      actions = [
        _HomeActionSpec(
          label: '活動を見る',
          icon: Icons.insights_outlined,
          onPressed: onActivity,
        ),
        _HomeActionSpec(
          label: 'コレ済を見る',
          icon: Icons.task_alt_rounded,
          onPressed: onDoneList,
        ),
      ];
    } else if (collectLimit.isHourlyReached) {
      title = '1時間の上限に達しました';
      message = _minutesToRecoveryText(collectLimit.hourRecoveryAt);
      actions = [
        _HomeActionSpec(
          label: '候補を整理',
          icon: Icons.inventory_2_outlined,
          onPressed: onOrganizeCandidates,
        ),
        _HomeActionSpec(
          label: 'コメント',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: onComments,
        ),
        _HomeActionSpec(
          label: 'コレ済を見る',
          icon: Icons.task_alt_rounded,
          onPressed: onDoneList,
        ),
      ];
    } else if (collectLimit.isDailyWarning) {
      title = '今日の上限が近づいています';
      message = '残り${collectLimit.dailyRemaining}件です。';
      actions = [
        _HomeActionSpec(
          label: 'コレ済を見る',
          icon: Icons.task_alt_rounded,
          onPressed: onDoneList,
        ),
      ];
    } else {
      title = 'あと少しで1時間上限です';
      message = '残り${collectLimit.hourlyRemaining}件。候補整理もおすすめです。';
      actions = [
        _HomeActionSpec(
          label: '候補を整理',
          icon: Icons.inventory_2_outlined,
          onPressed: onOrganizeCandidates,
        ),
        _HomeActionSpec(
          label: 'コメント',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: onComments,
        ),
      ];
    }

    final accent = isReached ? AppColors.error : const Color(0xFFE67E22);
    return Padding(
      padding: EdgeInsets.only(top: _HomeUi.gapSection),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            accent.withValues(alpha: 0.08),
            AppColors.surface,
          ),
          borderRadius: BorderRadius.circular(_HomeUi.radiusSectionOuter),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
          boxShadow: _HomeUi.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isReached
                      ? Icons.pause_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  size: 22,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _HomeUi.sectionTitle(context)),
                      const SizedBox(height: 2),
                      Text(message, style: _HomeUi.sectionBody(context)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _HomeActionWrap(actions: actions),
          ],
        ),
      ),
    );
  }
}

class _HomeNextActionsSection extends StatelessWidget {
  const _HomeNextActionsSection({
    required this.collectLimit,
    required this.pendingRecommendations,
    required this.candidateCount,
    required this.doneCount,
    required this.onRecommendations,
    required this.onSearch,
    required this.onCandidates,
    required this.onDone,
    required this.onComments,
    required this.onActivity,
  });

  final _CollectLimitStats collectLimit;
  final int pendingRecommendations;
  final int candidateCount;
  final int doneCount;
  final VoidCallback onRecommendations;
  final VoidCallback onSearch;
  final VoidCallback onCandidates;
  final VoidCallback onDone;
  final VoidCallback onComments;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions();
    return Container(
      width: double.infinity,
      decoration: _HomeUi.searchEntrySectionDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '次のアクション',
            style: _HomeUi.sectionTitle(
              context,
            ).copyWith(color: HomeScreenColors.accentSectionHeading),
          ),
          const SizedBox(height: 10),
          _HomeHeroCtaButton(
            icon: actions.first.icon,
            label: actions.first.label,
            onPressed: actions.first.onPressed,
          ),
          if (actions.length > 1) ...[
            const SizedBox(height: 8),
            _HomeActionWrap(actions: actions.skip(1).toList(growable: false)),
          ],
        ],
      ),
    );
  }

  List<_HomeActionSpec> _buildActions() {
    final out = <_HomeActionSpec>[];
    void add(_HomeActionSpec spec) {
      if (out.any((e) => e.label == spec.label)) return;
      if (out.length < 3) out.add(spec);
    }

    if (collectLimit.isDailyReached) {
      add(
        _HomeActionSpec(
          label: '今日の結果を見る',
          icon: Icons.insights_outlined,
          onPressed: onActivity,
        ),
      );
      add(
        _HomeActionSpec(
          label: 'コレ済を見る',
          icon: Icons.task_alt_rounded,
          onPressed: onDone,
        ),
      );
      add(
        _HomeActionSpec(
          label: 'コメント',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: onComments,
        ),
      );
      return out;
    }

    if (collectLimit.isHourlyReached) {
      add(
        _HomeActionSpec(
          label: '候補を整理',
          icon: Icons.inventory_2_outlined,
          onPressed: onCandidates,
        ),
      );
      add(
        _HomeActionSpec(
          label: 'コメント',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: onComments,
        ),
      );
      add(
        _HomeActionSpec(
          label: 'コレ済を見る',
          icon: Icons.task_alt_rounded,
          onPressed: onDone,
        ),
      );
      return out;
    }

    if (pendingRecommendations > 0) {
      add(
        _HomeActionSpec(
          label: 'おすすめコレを見る',
          icon: Icons.auto_awesome_rounded,
          onPressed: onRecommendations,
        ),
      );
    }
    if (candidateCount < 5) {
      add(
        _HomeActionSpec(
          label: '候補を探す',
          icon: Icons.travel_explore_rounded,
          onPressed: onSearch,
        ),
      );
    } else {
      add(
        _HomeActionSpec(
          label: '候補を整理',
          icon: Icons.inventory_2_outlined,
          onPressed: onCandidates,
        ),
      );
    }
    if (doneCount > 0) {
      add(
        _HomeActionSpec(
          label: 'コレ済を見る',
          icon: Icons.task_alt_rounded,
          onPressed: onDone,
        ),
      );
    }
    if (out.length < 3) {
      add(
        _HomeActionSpec(
          label: '活動を見る',
          icon: Icons.insights_outlined,
          onPressed: onActivity,
        ),
      );
    }
    return out;
  }
}

class _HomeActionWrap extends StatelessWidget {
  const _HomeActionWrap({required this.actions});

  final List<_HomeActionSpec> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions)
          AppSecondaryButton(
            label: action.label,
            onPressed: action.onPressed,
            icon: Icon(action.icon, size: 18, color: AppColors.accentPrimary),
            height: 40,
          ),
      ],
    );
  }
}

class _HomeShortcutGrid extends StatelessWidget {
  const _HomeShortcutGrid({
    required this.onSearch,
    required this.onRoomCollect,
    required this.onActivity,
    required this.onComments,
  });

  final VoidCallback onSearch;
  final VoidCallback onRoomCollect;
  final VoidCallback onActivity;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      _HomeActionSpec(
        label: '探す',
        icon: Icons.search_rounded,
        onPressed: onSearch,
      ),
      _HomeActionSpec(
        label: 'ROOMコレ',
        icon: Icons.collections_bookmark_outlined,
        onPressed: onRoomCollect,
      ),
      _HomeActionSpec(
        label: '活動',
        icon: Icons.insights_outlined,
        onPressed: onActivity,
      ),
      _HomeActionSpec(
        label: 'コメント',
        icon: Icons.chat_bubble_outline_rounded,
        onPressed: onComments,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            _HomeUi.insetSectionH,
            0,
            _HomeUi.insetSectionH,
            6,
          ),
          child: Text('ショートカット', style: _HomeUi.sectionTitle(context)),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            final width = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final item in shortcuts)
                  SizedBox(
                    width: width,
                    child: AppSecondaryButton(
                      label: item.label,
                      onPressed: item.onPressed,
                      icon: Icon(
                        item.icon,
                        size: 18,
                        color: AppColors.accentPrimary,
                      ),
                      expand: true,
                      height: 42,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

String _formatRecoveryLabel(DateTime? recoveryAt) {
  if (recoveryAt == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '回復 ${two(recoveryAt.hour)}:${two(recoveryAt.minute)}';
}

String _minutesToRecoveryText(DateTime? recoveryAt) {
  if (recoveryAt == null) return '少し時間をおいて再開できます';
  final minutes = recoveryAt.difference(DateTime.now()).inMinutes.clamp(1, 60);
  return 'あと$minutes分で再開できます';
}

class _HomeMomentumHeader extends StatelessWidget {
  const _HomeMomentumHeader({required this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameLine = displayName == null || displayName!.trim().isEmpty
        ? 'こんにちは'
        : 'こんにちは、${displayName!.trim()}さん';
    const subLine = '今日もROOM運用を進めましょう';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _HomeUi.insetSectionH,
        2,
        _HomeUi.insetSectionH,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nameLine,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomeScreenColors.titlePrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(subLine, style: _HomeUi.sectionBody(context)),
        ],
      ),
    );
  }
}

/// ROOMコレ管理：見出し・4タイルを1セクションとして囲う（ホームでは説明折りたたみなし）。
class _RoomManagementSection extends StatelessWidget {
  const _RoomManagementSection({
    required this.candidateTotal,
    required this.doneTotal,
    required this.todayDoneCount,
    required this.lastDoneAt,
    required this.onCandidateTap,
    required this.onDoneTap,
    required this.onTodayTap,
    required this.onLastCollectTap,
  });

  final int candidateTotal;
  final int doneTotal;
  final int todayDoneCount;
  final DateTime? lastDoneAt;
  final VoidCallback onCandidateTap;
  final VoidCallback onDoneTap;
  final VoidCallback onTodayTap;
  final VoidCallback onLastCollectTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _HomeUi.roomManagementSectionDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: HomeScreenColors.roomSectionHeaderBand,
            child: Padding(
              padding: _HomeUi.paddingRoomSectionHeader,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.collections_bookmark_outlined,
                      size: 22,
                      color: HomeScreenColors.statusAccentStrong,
                    ),
                  ),
                  SizedBox(width: _HomeUi.gapIconToTitle),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ROOMコレ管理',
                          style: _HomeUi.sectionTitleAccent(context),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '各タイルで一覧・ログへ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _HomeUi.tapHint(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _HomeUi.sectionDivider(),
          SizedBox(height: _HomeUi.gapRoomDividerToDeck),
          ColoredBox(
            color: HomeScreenColors.roomContentWellFill,
            child: Padding(
              padding: _HomeUi.paddingDeckOuterRoom,
              child: DecoratedBox(
                decoration: _HomeUi.roomTileDeckDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(_HomeUi.paddingRoomTileDeck),
                  child: _RoomStatsCardGrid(
                    unifiedRoomSection: true,
                    candidateTotal: candidateTotal,
                    doneTotal: doneTotal,
                    todayDoneCount: todayDoneCount,
                    lastDoneAt: lastDoneAt,
                    onCandidateTap: onCandidateTap,
                    onDoneTap: onDoneTap,
                    onTodayTap: onTodayTap,
                    onLastCollectTap: onLastCollectTap,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 最近追加した候補：ホームでは先頭最大3件のみ。再開のきっかけ用の軽量表示。
class _RecentCandidatesHomeSection extends StatelessWidget {
  const _RecentCandidatesHomeSection({
    required this.candidates,
    required this.candidateTotalCount,
    required this.onOpenCandidateTap,
    required this.onOpenFullList,
  });

  final List<RakutenManagedProduct> candidates;
  final int candidateTotalCount;
  final void Function(String productId) onOpenCandidateTap;
  final VoidCallback onOpenFullList;

  @override
  Widget build(BuildContext context) {
    final hasMore = candidateTotalCount > candidates.length;

    return Container(
      width: double.infinity,
      decoration: _HomeUi.recentCandidatesSectionDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: HomeScreenColors.recentSectionHeaderBand,
            child: Padding(
              padding: _HomeUi.paddingRecentSectionHeader,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.bookmark_added_outlined,
                      size: 22,
                      color: HomeScreenColors.statusAccentStrong,
                    ),
                  ),
                  SizedBox(width: _HomeUi.gapIconToTitle),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '最近追加した候補',
                          style: _HomeUi.sectionTitleAccent(context),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          candidateTotalCount == 0
                              ? '追加すると表示されます'
                              : '直近3件 · 行タップでROOMコレへ',
                          style: _HomeUi.tapHint(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _HomeUi.sectionDivider(),
          SizedBox(height: _HomeUi.gapRecentDividerToDeck),
          ColoredBox(
            color: HomeScreenColors.recentContentWellFill,
            child: Padding(
              padding: _HomeUi.paddingDeckOuterRecent,
              child: DecoratedBox(
                decoration: _HomeUi.roomTileDeckDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(_HomeUi.paddingRecentListDeck),
                  child: _RecentCandidatesPanel(
                    embedInUnifiedSection: true,
                    compactPreview: true,
                    candidates: candidates,
                    onOpenCandidateTap: onOpenCandidateTap,
                  ),
                ),
              ),
            ),
          ),
          _HomeCollectionListLink(
            embeddedInSection: true,
            onPressed: onOpenFullList,
            title: hasMore ? 'すべて見る' : 'コレ一覧を開く',
            hint: hasMore
                ? '候補 $candidateTotalCount 件 · ROOMコレへ'
                : 'ROOMコレの一覧へ',
            leadingIcon: hasMore
                ? Icons.view_list_outlined
                : Icons.playlist_add_check_outlined,
          ),
          SizedBox(height: _HomeUi.paddingRecentSectionBottom),
        ],
      ),
    );
  }
}

/// 下部のサブ導線：コレ一覧（ROOMコレタブと補完）。
class _HomeCollectionListLink extends StatelessWidget {
  const _HomeCollectionListLink({
    required this.onPressed,
    this.embeddedInSection = false,
    this.title = 'コレ一覧を開く',
    this.hint = 'ROOMコレの一覧へ',
    this.leadingIcon = Icons.playlist_add_check_outlined,
  });

  final VoidCallback onPressed;

  /// true のときはセクション末尾のサブアクション（主要CTAと競合しない薄めの見た目）
  final bool embeddedInSection;

  final String title;
  final String hint;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    if (embeddedInSection) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          splashColor: HomeScreenColors.inkNeutralSplash,
          highlightColor: HomeScreenColors.inkNeutralHighlight,
          child: Container(
            width: double.infinity,
            padding: _HomeUi.paddingRecentListFooterAction,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: _HomeUi.dividerLineColor()),
              ),
              color: HomeScreenColors.recentFooterRowFill,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    leadingIcon,
                    size: 22,
                    color: HomeScreenColors.leadOnSection,
                  ),
                ),
                SizedBox(width: _HomeUi.gapIconToTitle),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: _HomeUi.sectionFooterActionTitle(context),
                      ),
                      const SizedBox(height: _HomeUi.gapStackTight),
                      Text(hint, style: _HomeUi.tapHint(context)),
                    ],
                  ),
                ),
                Padding(
                  padding: _HomeUi.paddingRowChevron,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: HomeScreenColors.chevronOnSection,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppSecondaryButton(
      label: title,
      onPressed: onPressed,
      icon: Icon(leadingIcon, size: 20, color: AppColors.accentPrimary),
      expand: true,
      height: 46,
    );
  }
}

/// ROOM メトリクス4枚の役割（色は [HomeScreenColors] で統一ベース＋バッジアクセント）
enum _RoomMetricTileRole { candidate, done, today, history }

/// ② 4 枚統一のメトリクス（2×2、タップで遷移）。値・補足は改行で区切る。
class _RoomStatsCardGrid extends StatelessWidget {
  const _RoomStatsCardGrid({
    this.unifiedRoomSection = false,
    required this.candidateTotal,
    required this.doneTotal,
    required this.todayDoneCount,
    required this.lastDoneAt,
    required this.onCandidateTap,
    required this.onDoneTap,
    required this.onTodayTap,
    required this.onLastCollectTap,
  });

  /// true のとき ROOM セクション内デッキ用（グリッド間隔・タイル形状を統一）
  final bool unifiedRoomSection;

  final int candidateTotal;
  final int doneTotal;
  final int todayDoneCount;
  final DateTime? lastDoneAt;
  final VoidCallback onCandidateTap;
  final VoidCallback onDoneTap;
  final VoidCallback onTodayTap;
  final VoidCallback onLastCollectTap;

  @override
  Widget build(BuildContext context) {
    final lastPrimary = lastDoneAt == null
        ? '—'
        : _formatLastCollectForTile(lastDoneAt!);
    final g = unifiedRoomSection ? _HomeUi.gapRoomGrid : _HomeUi.gapTight + 1;
    final deck = unifiedRoomSection;

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RoomMetricTile(
                  role: _RoomMetricTileRole.candidate,
                  title: 'コレ候補',
                  valueMain: '$candidateTotal件',
                  caption: '候補一覧へ進む',
                  icon: Icons.bookmark_outline_rounded,
                  valueProminent: true,
                  compactDeck: deck,
                  onTap: onCandidateTap,
                ),
              ),
              SizedBox(width: g),
              Expanded(
                child: _RoomMetricTile(
                  role: _RoomMetricTileRole.done,
                  title: 'コレ済',
                  valueMain: '$doneTotal件',
                  caption: 'コレ済一覧へ進む',
                  icon: Icons.task_alt_rounded,
                  valueProminent: true,
                  compactDeck: deck,
                  onTap: onDoneTap,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: g),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RoomMetricTile(
                  role: _RoomMetricTileRole.today,
                  title: '今日のコレ',
                  valueMain: '$todayDoneCount件',
                  caption: '今日分のコレ済へ',
                  icon: Icons.today_rounded,
                  valueProminent: true,
                  compactDeck: deck,
                  onTap: onTodayTap,
                ),
              ),
              SizedBox(width: g),
              Expanded(
                child: _RoomMetricTile(
                  role: _RoomMetricTileRole.history,
                  title: '前回コレ日時',
                  valueMain: lastPrimary,
                  caption: '活動ログを開く',
                  icon: Icons.history_rounded,
                  valueProminent: false,
                  compactDeck: deck,
                  onTap: onLastCollectTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 前回コレ日時タイル用。1行を短くして値のフォントを上げても折り返し・切れを起こしにくくする。
  String _formatLastCollectForTile(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.month}/${d.day}\n${two(d.hour)}:${two(d.minute)}';
  }
}

class _RoomMetricTile extends StatelessWidget {
  const _RoomMetricTile({
    required this.role,
    required this.title,
    required this.valueMain,
    required this.caption,
    required this.icon,
    required this.valueProminent,
    this.compactDeck = false,
    required this.onTap,
  });

  final _RoomMetricTileRole role;
  final String title;
  final String valueMain;
  final String caption;
  final IconData icon;
  final bool valueProminent;

  /// ROOM セクション内デッキ用：角丸・余白・キャプション行を揃える
  final bool compactDeck;
  final VoidCallback onTap;

  (Color iconFg, Color iconBg) _roleBadgeColors() {
    switch (role) {
      case _RoomMetricTileRole.candidate:
        return (
          HomeScreenColors.metricRoleCandidateIcon,
          HomeScreenColors.metricRoleCandidateIconBg,
        );
      case _RoomMetricTileRole.done:
        return (
          HomeScreenColors.metricRoleDoneIcon,
          HomeScreenColors.metricRoleDoneIconBg,
        );
      case _RoomMetricTileRole.today:
        return (
          HomeScreenColors.metricRoleTodayIcon,
          HomeScreenColors.metricRoleTodayIconBg,
        );
      case _RoomMetricTileRole.history:
        return (
          HomeScreenColors.metricRoleHistoryIcon,
          HomeScreenColors.metricRoleHistoryIconBg,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = compactDeck ? 12.0 : AppDimensions.radiusCard;
    final pad = compactDeck
        ? const EdgeInsets.symmetric(horizontal: 5, vertical: 5)
        : const EdgeInsets.fromLTRB(9, 7, 9, 7);
    final titleSize = compactDeck ? 12.5 : 13.0;
    final valueLarge = compactDeck ? 24.0 : 26.0;
    final valueSmall = compactDeck ? 16.0 : 16.5;

    /// 前回コレ日時：数値タイルより一回り小さく、従来の valueSmall より一段大きく（2行表示と組み合わせ）
    final valueHistory = compactDeck ? 18.5 : 19.5;
    final captionMaxLines = compactDeck ? 1 : 2;
    final (accent, iconBackground) = _roleBadgeColors();
    final isHistoryTile = role == _RoomMetricTileRole.history;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: HomeScreenColors.inkNeutralSplash,
        child: Container(
          padding: pad,
          decoration: BoxDecoration(
            color: HomeScreenColors.roomMetricTileFill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: HomeScreenColors.roomMetricTileBorder),
            boxShadow: compactDeck
                ? HomeScreenColors.roomMetricTileShadow
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accent, size: 16),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: HomeScreenColors.metricTileTitleColor,
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                        fontSize: titleSize,
                        letterSpacing: -0.02,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compactDeck ? 2 : 5),
              Text(
                valueMain,
                textAlign: TextAlign.left,
                maxLines: valueProminent ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: valueProminent
                    ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: HomeScreenColors.metricTileValueColor,
                        height: 1.02,
                        fontSize: valueLarge,
                        letterSpacing: -0.55,
                      )
                    : Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: HomeScreenColors.metricTileValueColor,
                        height: isHistoryTile ? 1.08 : 1.12,
                        fontSize: isHistoryTile ? valueHistory : valueSmall,
                        letterSpacing: isHistoryTile ? -0.35 : -0.25,
                      ),
              ),
              SizedBox(height: compactDeck ? 1 : 2),
              Text(
                caption,
                maxLines: captionMaxLines,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: compactDeck ? 10.5 : 11,
                  fontWeight: FontWeight.w500,
                  height: 1.28,
                  color: HomeScreenColors.metricTileCaptionColor,
                  letterSpacing: 0.01,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentCandidatesPanel extends StatelessWidget {
  const _RecentCandidatesPanel({
    this.embedInUnifiedSection = false,
    this.compactPreview = false,
    required this.candidates,
    required this.onOpenCandidateTap,
  });

  /// [_RecentCandidatesHomeSection] 内では外枠なし（親デッキが枠を持つ）
  final bool embedInUnifiedSection;

  /// ホームの「最近追加した候補」向け：行を薄くし、詳細を省く。
  final bool compactPreview;

  final List<RakutenManagedProduct> candidates;
  final void Function(String productId) onOpenCandidateTap;

  @override
  Widget build(BuildContext context) {
    final tilePadding = compactPreview
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
        : embedInUnifiedSection
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 7);

    if (candidates.isEmpty) {
      return Padding(
        padding: embedInUnifiedSection
            ? const EdgeInsets.symmetric(vertical: 2, horizontal: 2)
            : const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('候補はまだありません', style: _HomeUi.bodyEmphasis(context)),
            const SizedBox(height: _HomeUi.gapTight),
            Text('おすすめ画面または楽天検索から追加できます。', style: _HomeUi.sectionBody(context)),
          ],
        ),
      );
    }

    final dividerIndent = compactPreview
        ? 52.0
        : embedInUnifiedSection
        ? 60.0
        : 62.0;

    final list = Column(
      children: [
        for (int i = 0; i < candidates.length; i++) ...[
          _RecentCandidateTile(
            product: candidates[i],
            contentPadding: tilePadding,
            compactPreview: compactPreview,
            onTap: () => onOpenCandidateTap(candidates[i].productId),
          ),
          if (i < candidates.length - 1)
            Divider(
              height: 1,
              thickness: 1,
              indent: dividerIndent,
              endIndent: embedInUnifiedSection ? 9 : 9,
              color: HomeScreenColors.listRowDivider,
            ),
        ],
      ],
    );

    if (embedInUnifiedSection) {
      return list;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeScreenColors.standaloneCardFill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: HomeScreenColors.metricTileOutline),
      ),
      child: list,
    );
  }
}

class _RecentCandidateTile extends StatelessWidget {
  const _RecentCandidateTile({
    required this.product,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 4,
    ),
    this.compactPreview = false,
    required this.onTap,
  });

  final RakutenManagedProduct product;
  final EdgeInsetsGeometry contentPadding;
  final bool compactPreview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumbSize = compactPreview ? 40.0 : 46.0;

    if (compactPreview) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: HomeScreenColors.inkNeutralSplash,
          highlightColor: HomeScreenColors.inkNeutralHighlight,
          child: Padding(
            padding: contentPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _thumb(thumbSize),
                SizedBox(width: _HomeUi.gapIconToTitle),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.itemName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.22,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        RoomColleProductListCardLayout.formatPriceYen(
                          product.itemPrice,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            RoomColleProductListCardLayout.priceTextStyle(
                              Theme.of(context),
                            )?.copyWith(fontSize: 13.5) ??
                            _HomeUi.tapHint(context),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: HomeScreenColors.chevronOnSection.withValues(
                    alpha: 0.55,
                  ),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: HomeScreenColors.inkNeutralSplash,
        highlightColor: HomeScreenColors.inkNeutralHighlight,
        child: Padding(
          padding: contentPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(thumbSize),
              SizedBox(width: _HomeUi.gapIconToTitle),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.24,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: _HomeUi.gapStackTight),
                    Text(
                      product.shopName.isEmpty ? 'ショップ名なし' : product.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _HomeUi.sectionBody(context),
                    ),
                    const SizedBox(height: _HomeUi.gapStackTight),
                    _ExtractionChip(status: product.extractionStatus),
                  ],
                ),
              ),
              Padding(
                padding: _HomeUi.paddingRowChevron,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: HomeScreenColors.chevronOnSection.withValues(
                    alpha: 0.88,
                  ),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: HomeScreenColors.candidateThumbPlaceholder,
        child: product.imageUrl.isNotEmpty
            ? Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.image_outlined,
                  size: size * 0.48,
                  color: AppColors.textTertiary,
                ),
              )
            : Icon(
                Icons.image_outlined,
                size: size * 0.48,
                color: AppColors.textTertiary,
              ),
      ),
    );
  }
}

class _ExtractionChip extends StatelessWidget {
  const _ExtractionChip({required this.status});

  final RakutenUrlExtractionStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;
    switch (status) {
      case RakutenUrlExtractionStatus.notStarted:
        label = 'URL準備・待機';
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
      case RakutenUrlExtractionStatus.extracting:
        label = 'URL取得中';
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
      case RakutenUrlExtractionStatus.success:
        label = 'URL取得済み';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
      case RakutenUrlExtractionStatus.failed:
        label = 'URL取得失敗';
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          height: 1.18,
        ),
      ),
    );
  }
}
