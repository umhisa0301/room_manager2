import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/room_colle_list_filters.dart';
import '../navigation/app_shell_controller.dart';
import '../navigation/rakuten_search_navigator.dart';
import 'mypage_placeholder_screen.dart';
import 'today_recommendations_screen.dart';
import '../services/rakuten_room_home_stats.dart';
import '../services/room_collect_post_limit.dart';
import '../services/room_import_collects_policy.dart';
import '../services/room_import_limit_policy.dart';
import '../services/room_kpi_calculator.dart';
import '../utils/today_recommendation_ui_tags.dart';
import '../state/room_activity_event_provider.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/bulk_operation_state_controller.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../state/user_profile_provider.dart';
import '../state/room_import_controller.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/room_colle_product_list_card_layout.dart';
import '../utils/room_reaction_analytics.dart';
import '../utils/room_sync_button_visibility.dart';
import '../utils/room_sync_card_copy.dart';
import '../utils/room_sync_log.dart';
import '../widgets/operation_confirm_dialog.dart';
import '../widgets/room_post_import_flow.dart';
import '../widgets/room_sync_reaction_button.dart';
import '../models/room_reaction_sync_history_entry.dart';
import '../services/room_reaction_sync_history_store.dart';

// --- ホーム画面：レイアウト・タイポ・装飾の統一（画面ロジックとは分離）---

/// ホーム専用の余白・行間・装飾ルール。
abstract final class _HomeUi {
  const _HomeUi._();

  /// 主要ブロック同士（CTA・セクション・グループ）
  static const double gapSection = 16;

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
  static const double listBottomExtra = 8;

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
      fontSize: 14,
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
  DateTime? _lastAutoRegenerateTriedAt;
  static const Duration _autoRegenerateCooldown = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final room = context.read<RakutenManagedProductProvider>();
      final recommender = context.read<TodayRecommendationProvider>();
      await room.refreshManagedProductList(showLoadingIndicator: false);
      if (!mounted) return;
      unawaited(
        context
            .read<RoomImportController>()
            .tickSlowRoomMetadataEnrichmentIfNeeded(context),
      );
      homeSectionOrderLog(
        'todayRoomOperation,roomColleManagement,roomSync,recentCandidates',
      );
      unknownFloatingButtonAuditLog(
        screen: 'home',
        widget: 'none',
        file: 'lib/screens/home_placeholder_screen.dart',
        visible: false,
        reason: 'noDrawerNoMenuFabOnHomeBody',
      );
      _trace('trigger=homeInit');
      _trigger('postFrame');
      _trace('action=ensureToday');
      await recommender.ensureToday(
        profile: context.read<UserProfileProvider>().profile,
        managedItems: room.items,
        savedShops: context.read<SavedShopProvider>().shops,
        trigger: 'homeInit',
      );
      await _regenerateRecommendationsIfNeeded(
        recommender: recommender,
        roomProvider: room,
        trigger: 'homeInit',
      );
    });
  }

  Future<void> _refreshHome() async {
    if (!mounted) return;
    final room = context.read<RakutenManagedProductProvider>();
    await room.refreshManagedProductList(showLoadingIndicator: false);
    if (!mounted) return;
    context.read<RoomActivityEventProvider>().reloadFromStorage();
    if (!mounted) return;
    final recommender = context.read<TodayRecommendationProvider>();
    _trace('trigger=refresh');
    _trigger('refresh');
    _trace('action=ensureToday');
    recommender.reloadBundleFromStorage();
    await recommender.ensureToday(
      profile: context.read<UserProfileProvider>().profile,
      managedItems: room.items,
      savedShops: context.read<SavedShopProvider>().shops,
      trigger: 'refresh',
    );
    _guard('skipReason=refreshDoesNotForceRegenerate');
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
    final roomProvider = context.read<RakutenManagedProductProvider>();
    _trace('trigger=cta');
    _trigger('cta');
    _trace('action=ensureToday');
    await recommender.ensureToday(
      profile: context.read<UserProfileProvider>().profile,
      managedItems: roomProvider.items,
      savedShops: context.read<SavedShopProvider>().shops,
      trigger: 'cta',
    );
    if (recommender.pendingCount <= 0 &&
        recommender.hasTodayBundleWithEntries) {
      _guard('skipReason=pendingZeroButBundleExists');
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const TodayRecommendationsScreen(skipInitialEnsure: true),
      ),
    );
  }

  Future<void> _regenerateRecommendationsIfNeeded({
    required TodayRecommendationProvider recommender,
    required RakutenManagedProductProvider roomProvider,
    bool force = false,
    String trigger = 'ensure',
  }) async {
    if (!mounted) return;
    _trace('alreadyGenerating=${recommender.isLoading}');
    _trace(
      'lastGeneratedAt=${recommender.bundle?.generatedAt.toIso8601String() ?? 'null'}',
    );
    if (recommender.isLoading) return;
    if (!force && recommender.bundle != null) {
      _trace('shouldSkipBecauseRecentlyTried=true');
      _guard('skipReason=bundleExists');
      return;
    }
    final now = DateTime.now();
    final skipBecauseRecentlyTried =
        !force &&
        _lastAutoRegenerateTriedAt != null &&
        now.difference(_lastAutoRegenerateTriedAt!) < _autoRegenerateCooldown;
    _trace('shouldSkipBecauseRecentlyTried=$skipBecauseRecentlyTried');
    if (skipBecauseRecentlyTried) return;
    _lastAutoRegenerateTriedAt = now;
    _trace('action=regenerateToday');
    await recommender.regenerateToday(
      profile: context.read<UserProfileProvider>().profile,
      managedItems: roomProvider.items,
      savedShops: context.read<SavedShopProvider>().shops,
      trigger: trigger,
      manual: force,
    );
  }

  void _trace(String message) {
    if (!mounted) return;
    debugPrint('[RECOMMEND_TRACE] $message');
  }

  void _trigger(String source) {
    if (!mounted) return;
    debugPrint('[RECOMMEND_TRIGGER] source=$source');
  }

  void _guard(String reason) {
    if (!mounted) return;
    debugPrint('[RECOMMEND_GUARD] $reason');
  }

  Future<void> _openRoomUrlEditSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          const RoomUrlEditSheet(successMessage: 'ROOMプロフィールを登録しました'),
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
                    final collectLimit = RoomCollectPostLimitSnapshot.compute(
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
                    final profileRoomUrl = userProfileProvider.profile.roomUrl
                        .trim();
                    final roomImportedDoneCount = items
                        .where(
                          (e) =>
                              e.status == RakutenManagedProductStatus.done &&
                              e.roomUrl.trim().isNotEmpty,
                        )
                        .length;

                    return RefreshIndicator(
                      onRefresh: _refreshHome,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            _HomeUi.screenPaddingH,
                            _HomeUi.screenPaddingV,
                            _HomeUi.screenPaddingH,
                            bottomInset +
                                navBarReserve +
                                _HomeUi.listBottomExtra,
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
                                generationStatus: recProvider.generationStatus,
                                hasTodaySuggestions: hasTodaySuggestions,
                                todayDoneCountForRec: todayDoneCountForRec,
                                recTotalCount: recProvider.totalCount,
                                recommendationHintLine:
                                    todayRecommendationHomeHintLine(
                                      bundle: recProvider.bundle,
                                      isLoading: recProvider.isLoading,
                                      postStyleKeys: userProfileProvider
                                          .profile
                                          .postStyleList,
                                    ),
                                recommendationStatusMessage:
                                    recProvider.totalCount > 0 &&
                                        recProvider.totalCount < 10
                                    ? '今日は${recProvider.totalCount}件のおすすめを用意しました'
                                    : recProvider.totalCount == 0 &&
                                          (recProvider.generationStatus ==
                                                  TodayRecommendationGenerationStatus
                                                      .failedRateLimit ||
                                              recProvider.generationStatus ==
                                                  TodayRecommendationGenerationStatus
                                                      .failedApiError ||
                                              recProvider.generationStatus ==
                                                  TodayRecommendationGenerationStatus
                                                      .empty)
                                    ? 'おすすめを準備できませんでした'
                                    : null,
                                onOpenSearch: () {
                                  _trace('trigger=cta');
                                  _trace('action=openSearch');
                                  openRakutenSearchScreen(context);
                                },
                                onOpenCandidates: () =>
                                    _openRoomList(context, initialTabIndex: 0),
                                onOpenActivity: () => _openActivity(context),
                                onPrimaryRecommendations: () =>
                                    _openTodayRecommendations(context),
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
                              _HomeRoomPostImportSection(
                                hasRoomProfileUrl: profileRoomUrl.isNotEmpty,
                                importedDoneCount: roomImportedDoneCount,
                                onOpenRoomUrl: () =>
                                    _openRoomUrlEditSheet(context),
                                onOpenReactionAnalytics: () {
                                  logRoomReactionAnalyticsNavigation(
                                    from: 'homeRoomSyncCard',
                                    to: 'analysis',
                                    reason: 'showReactionAnalytics',
                                    scrollToRoomReactionSection: true,
                                  );
                                  context.read<AppShellController>().openActivityTab(
                                        subTabIndex: 1,
                                        scrollToRoomReactionSection: true,
                                      );
                                },
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
                              _RecentCandidatesHomeSection(
                                candidates: recentCandidates,
                                candidateTotalCount: nCandidate,
                                onOpenCandidateTap: (productId) =>
                                    _openRoomList(
                                      context,
                                      focusCandidateProductId: productId,
                                    ),
                                onOpenFullList: () => _openRoomList(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
            ),
      ),
    );
  }
}

String _formatSyncHistoryTime(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}/$m/$d $h:$min';
  } catch (_) {
    return '未確認';
  }
}

/// ホーム：ROOM同期（取り込み・反応数・メンテナンス）。
class _HomeRoomPostImportSection extends StatelessWidget {
  const _HomeRoomPostImportSection({
    required this.hasRoomProfileUrl,
    required this.importedDoneCount,
    required this.onOpenRoomUrl,
    required this.onOpenReactionAnalytics,
  });

  final bool hasRoomProfileUrl;
  final int importedDoneCount;
  final VoidCallback onOpenRoomUrl;
  final VoidCallback onOpenReactionAnalytics;

  Future<void> _handleImport(BuildContext context) async {
    if (!hasRoomProfileUrl) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ROOM投稿を取り込む'),
        content: const Text(
          'ROOM投稿を取り込みます。\n処理中は検索や登録操作を一時停止します。\nよろしいですか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('開始する'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (kDebugMode) {
      debugPrint(
        '[OPERATION_CONFIRM_DIALOG] operation=roomImport shown=true accepted=true',
      );
    }
    final ctl = context.read<RoomImportController>();
    final result = await ctl.runImport(context);
    if (!context.mounted) return;
    if (result == null) {
      final url = context.read<UserProfileProvider>().profile.roomUrl.trim();
      if (url.isEmpty) {
        onOpenRoomUrl();
      }
      return;
    }
    await RoomPostImportFlow.presentPostImportUi(
      context,
      result,
      startBatch: () => ctl.runImport(context),
      startDeepCollectsBatch: () =>
          ctl.runImport(context, deepCollectsExplore: true),
    );
  }

  Future<void> _handleDeepRoomImport(BuildContext context) async {
    if (!hasRoomProfileUrl) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('さらに古い投稿を探す'),
        content: Text(
          '通常取り込みで見つからない古いROOM投稿を探します。'
          'ROOMの collects API を最大${RoomImportCollectsPolicy.deepMaxCollectPages}ページまで取得し、'
          '数分〜10分以上かかる場合があります。実行しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('実行'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final ctl = context.read<RoomImportController>();
    final result = await ctl.runImport(context, deepCollectsExplore: true);
    if (!context.mounted) return;
    if (result == null) return;
    await RoomPostImportFlow.presentPostImportUi(
      context,
      result,
      startBatch: () => ctl.runImport(context),
      startDeepCollectsBatch: () =>
          ctl.runImport(context, deepCollectsExplore: true),
    );
  }

  Future<void> _handleReactionSync(BuildContext context) async {
    if (!hasRoomProfileUrl) return;
    final ctl = context.read<RoomImportController>();
    final bulk = context.read<BulkOperationStateController>();
    final syncBusy = ctl.isRunning ||
        bulk.isMetadataEnriching ||
        bulk.isRoomReactionSyncRunning;
    if (syncBusy || bulk.isAnyBlockingOperationRunning) {
      if (kDebugMode) {
        debugPrint(
          '[ROOM_REACTION_SYNC_START_GUARD] screen=home blockedByBusy=true '
          'confirmed=false',
        );
      }
      return;
    }
    final confirmed = await showRoomReactionSyncConfirmDialog(
      context,
      screen: 'home',
    );
    if (kDebugMode) {
      debugPrint(
        '[ROOM_REACTION_SYNC_START_GUARD] screen=home blockedByBusy=false '
        'confirmed=$confirmed',
      );
    }
    if (!confirmed || !context.mounted) return;
    final r = await ctl.runReactionSync(context);
    if (!context.mounted || r == null) return;
    if (r.hasFatalError) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('反応を確認する'),
          content: Text(r.fatalErrorMessage!.trim()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.uiSummaryMessage.trim().isNotEmpty
              ? r.uiSummaryMessage
              : '反応を確認しました：確認${r.itemsChecked}件 / 変更なし',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RoomImportController, BulkOperationStateController>(
      builder: (context, ctl, bulk, _) {
        final syncBusy = ctl.isRunning ||
            bulk.isMetadataEnriching ||
            bulk.isRoomReactionSyncRunning;

        final enrichingOnly =
            !ctl.isRunning &&
            !bulk.isRoomReactionSyncRunning &&
            bulk.isMetadataEnriching;

        final reactionOnly =
            !ctl.isRunning &&
            !bulk.isMetadataEnriching &&
            bulk.isRoomReactionSyncRunning;

        final syncJob = RoomSyncButtonVisibility.jobLabel(
          importing: ctl.isRunning,
          syncingReactions: reactionOnly,
          enrichingMetadata: enrichingOnly,
        );
        if (syncBusy) {
          for (final b in const [
            'import',
            'reaction',
            'maintenance',
            'deepSearch',
            'metadataRetry',
          ]) {
            RoomSyncButtonVisibility.logHiddenWhileBusy(
              screen: 'home',
              job: syncJob,
              button: b,
            );
            RoomSyncButtonVisibility.logRenderDecision(
              screen: 'home',
              button: b,
              canRun: false,
              visible: false,
              reason: 'busy',
            );
          }
        }

        final actionLocked = bulk.isAnyBlockingOperationRunning;

        var busyLead = ctl.isRunning
            ? ctl.uiPhaseLabel
            : (reactionOnly
                  ? RoomSyncCardCopy.importPhaseLabel(
                      RoomImportUiPhase.checkingReactions,
                    )
                  : (enrichingOnly
                        ? RoomSyncCardCopy.importPhaseLabel(
                            RoomImportUiPhase.checkingProductInfo,
                          )
                        : ''));
        if (syncBusy && busyLead.trim().isEmpty) {
          busyLead = RoomSyncCardCopy.importPhaseLabel(
            RoomImportUiPhase.checkingTargets,
          );
        }
        final busyProgress = ctl.isRunning
            ? ctl.uiPhaseProgress
            : (reactionOnly
                  ? RoomSyncCardCopy.importPhaseProgress(
                      RoomImportUiPhase.checkingReactions,
                    )
                  : (enrichingOnly
                        ? RoomSyncCardCopy.importPhaseProgress(
                            RoomImportUiPhase.checkingProductInfo,
                          )
                        : null));

        final syncCardState = !hasRoomProfileUrl
            ? 'noRoomUrl'
            : syncBusy
            ? 'busy'
            : importedDoneCount <= 0
            ? 'empty'
            : 'ready';

        final canRunPrimary = hasRoomProfileUrl && !actionLocked;
        final showImportButton = canRunPrimary && !syncBusy;
        final showReactionButton =
            showImportButton && importedDoneCount > 0;
        final showAnalysisLink = !syncBusy && hasRoomProfileUrl;
        roomSyncCardUxRenderLog(
          state: syncCardState,
          showImportButton: showImportButton,
          showReactionButton: showReactionButton,
          showAnalysisCta: false,
          hiddenDisabledButtons: syncBusy ? 'allHiddenWhileBusy' : 'none',
        );
        roomSyncButtonRenderDecisionLog(
          'screen=home button=import visible=$showImportButton '
          'enabled=$showImportButton '
          'label=${importedDoneCount > 0 ? '投稿済み商品を取り込む' : 'ROOM投稿を取り込む'} '
          'reason=${syncBusy ? 'busy' : (!hasRoomProfileUrl ? 'missingRoomUrl' : (actionLocked ? 'guarded' : 'ready'))}',
        );
        roomSyncButtonRenderDecisionLog(
          'screen=home button=reaction visible=$showReactionButton '
          'enabled=$showReactionButton label=反応を確認する '
          'reason=${syncBusy ? 'busy' : (importedDoneCount <= 0 ? 'notImportedYet' : (!hasRoomProfileUrl ? 'missingRoomUrl' : (actionLocked ? 'guarded' : 'ready')))}',
        );
        roomSyncEmptyButtonAuditLog(
          screen: 'home',
          button: 'import',
          visible: showImportButton,
          enabled: showImportButton,
          label: importedDoneCount > 0
              ? '投稿済み商品を取り込む'
              : 'ROOM投稿を取り込む',
          reason: showImportButton ? 'rendered' : 'hiddenByUxPolicy',
        );
        roomSyncEmptyButtonAuditLog(
          screen: 'home',
          button: 'reaction',
          visible: showReactionButton,
          enabled: showReactionButton,
          label: '反応を確認する',
          reason: showReactionButton ? 'rendered' : 'notImportedYetOrBusy',
        );

        final showPrimaryButtons = showImportButton;
        if (!syncBusy) {
          final baseReason = !hasRoomProfileUrl
              ? 'missingRoomUrl'
              : (actionLocked ? 'guarded' : 'ready');
          final showMaintenanceUi = showRoomSyncMaintenanceDebugUi;
          roomSyncMaintenanceVisibilityLog(
            'screen=home '
            'visible=$showMaintenanceUi '
            'reason=${showMaintenanceUi ? 'debugOnly' : 'hiddenForNormalUx'}',
          );
          RoomSyncButtonVisibility.logRenderDecision(
            screen: 'home',
            button: 'import',
            canRun: canRunPrimary,
            visible: showPrimaryButtons,
            reason: baseReason,
          );
          RoomSyncButtonVisibility.logRenderDecision(
            screen: 'home',
            button: 'reaction',
            canRun: canRunPrimary,
            visible: showPrimaryButtons,
            reason: baseReason,
          );
          RoomSyncButtonVisibility.logRenderDecision(
            screen: 'home',
            button: 'maintenance',
            canRun: false,
            visible: showMaintenanceUi,
            reason: showMaintenanceUi ? 'debugOnly' : 'hiddenByUxPolicy',
          );
          final maintChildReason =
              showMaintenanceUi ? baseReason : 'hiddenByUxPolicy';
          RoomSyncButtonVisibility.logRenderDecision(
            screen: 'home',
            button: 'deepSearch',
            canRun: canRunPrimary,
            visible: showPrimaryButtons && showMaintenanceUi,
            reason: maintChildReason,
          );
          RoomSyncButtonVisibility.logRenderDecision(
            screen: 'home',
            button: 'metadataRetry',
            canRun: canRunPrimary,
            visible: showPrimaryButtons && showMaintenanceUi,
            reason: maintChildReason,
          );
        }

        return Container(
          width: double.infinity,
          decoration: _HomeUi.searchEntrySectionDecoration(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                RoomSyncCardCopy.title,
                style: _HomeUi.sectionTitle(context).copyWith(
                  color: HomeScreenColors.accentSectionHeading,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                RoomSyncCardCopy.subtitle,
                style: _HomeUi.sectionBody(context),
              ),
              const SizedBox(height: 14),
              if (!hasRoomProfileUrl) ...[
                Text(
                  'ROOMプロフィールURLを登録すると同期できます',
                  style: _HomeUi.bodyEmphasis(context).copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onOpenRoomUrl,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: const Text('ROOMプロフィールを登録'),
                ),
              ] else ...[
                if (syncBusy) ...[
                  Text(
                    busyLead,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: busyProgress,
                      backgroundColor: HomeScreenColors.progressTrack,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  if (actionLocked &&
                      !syncBusy) ...[
                    Text(
                      bulk.blockingRoomTourUserMessage ??
                          BulkOperationStateController.blockingSnackMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (importedDoneCount > 0) ...[
                    FutureBuilder<RoomReactionSyncHistoryEntry?>(
                      future: RoomReactionSyncHistoryStore.loadLatest(),
                      builder: (context, snap) {
                        final last = snap.data;
                        final lastLabel = last == null
                            ? '前回確認：未確認'
                            : '前回確認：${_formatSyncHistoryTime(last.syncedAtIso)}';
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: HomeScreenColors.deckFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: HomeScreenColors.deckOutline,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '取り込み済み：$importedDoneCount件',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lastLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    Text(
                      'まだROOM投稿を取り込んでいません',
                      style: _HomeUi.bodyEmphasis(context).copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      RoomSyncCardCopy.emptyImportHint,
                      style: _HomeUi.tapHint(context),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Consumer<RakutenManagedProductProvider>(
                    builder: (context, managed, _) {
                      final showLink = showAnalysisLink &&
                          roomReactionAnalyticsHomeShowCta(managed.items);
                      if (!showLink) return const SizedBox.shrink();
                      roomSyncButtonRenderDecisionLog(
                        'screen=home button=analysis visible=true enabled=true '
                        'label=${RoomSyncCardCopy.analysisTabHint} reason=textLinkOnly',
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: onOpenReactionAnalytics,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              '${RoomSyncCardCopy.analysisTabHint} ＞',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.accentPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (showImportButton) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentPrimary.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: () {
                          RoomSyncButtonVisibility.logIdleVisible(
                            screen: 'home',
                            button: 'import',
                          );
                          _handleImport(context);
                        },
                        style: FilledButton.styleFrom(
                          foregroundColor: AppColors.textOnAccent,
                          backgroundColor: AppColors.accentPrimary,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: AppTextStyles.button.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        child: Text(
                          importedDoneCount > 0
                              ? '投稿済み商品を取り込む'
                              : 'ROOM投稿を取り込む',
                        ),
                      ),
                    ),
                  ],
                  if (showReactionButton) ...[
                    const SizedBox(height: 10),
                    RoomSyncReactionButton(
                      screen: 'home',
                      onPressed: () {
                        RoomSyncButtonVisibility.logIdleVisible(
                          screen: 'home',
                          button: 'reaction',
                        );
                        _handleReactionSync(context);
                      },
                    ),
                  ],
                  Text(
                    RoomSyncCardCopy.combinedFooterHint,
                    style: _HomeUi.tapHint(context),
                  ),
                  if (showRoomSyncMaintenanceDebugUi) ...[
                    const SizedBox(height: 14),
                    ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        RoomSyncCardCopy.maintenanceTileTitle,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      subtitle: Text(
                        RoomSyncCardCopy.maintenanceTileSubtitle,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                      ),
                      children: [
                        if (showPrimaryButtons) ...[
                          OutlinedButton.icon(
                            onPressed: () {
                              RoomSyncButtonVisibility.logIdleVisible(
                                screen: 'home',
                                button: 'deepSearch',
                              );
                              _handleDeepRoomImport(context);
                            },
                            icon: const Icon(
                              Icons.manage_search_outlined,
                              size: 18,
                            ),
                            label: const Text('さらに古い投稿を探す'),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '通常取り込みで見つからない古いROOM投稿を探します。時間がかかる場合があります。',
                            style: _HomeUi.tapHint(context),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              RoomSyncButtonVisibility.logIdleVisible(
                                screen: 'home',
                                button: 'metadataRetry',
                              );
                              RoomPostImportFlow
                                  .runManualPendingRoomImportMetadataEnrich(
                                    context,
                                  );
                            },
                            icon: const Icon(
                              Icons.auto_fix_high_outlined,
                              size: 18,
                            ),
                            label: const Text('ショップ名・ジャンルを再確認'),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '取り込み時に商品情報を取得できなかった商品だけ再試行します（1回あたり最大${RoomImportLimitPolicy.manualEnrichMaxProductsPerRun}件）。',
                            style: _HomeUi.tapHint(context),
                          ),
                        ] else if (hasRoomProfileUrl) ...[
                          Text(
                            bulk.blockingRoomTourUserMessage ??
                                BulkOperationStateController
                                    .blockingSnackMessage,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      RoomSyncCardCopy.freeTierLine(
                        limit: RoomImportLimitPolicy.freeBatchLimit,
                      ),
                      style: _HomeUi.tapHint(context),
                    ),
                  ],
                ],
              ],
            ],
          ),
        );
      },
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
    required this.generationStatus,
    required this.hasTodaySuggestions,
    required this.todayDoneCountForRec,
    required this.recTotalCount,
    required this.recommendationHintLine,
    required this.recommendationStatusMessage,
    required this.onOpenSearch,
    required this.onOpenCandidates,
    required this.onOpenActivity,
    required this.onPrimaryRecommendations,
  });

  final RoomKpiSummary kpi;
  final RoomCollectPostLimitSnapshot collectLimit;
  final int candidateCount;
  final int totalCount;
  final int pendingCount;
  final bool isCompleted;
  final bool isLoading;
  final TodayRecommendationGenerationStatus generationStatus;
  final bool hasTodaySuggestions;
  final int todayDoneCountForRec;
  final int recTotalCount;
  final String? recommendationHintLine;
  final String? recommendationStatusMessage;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenCandidates;
  final VoidCallback onOpenActivity;
  final VoidCallback onPrimaryRecommendations;

  @override
  Widget build(BuildContext context) {
    // 親から渡る集計・KPIは画面導線の安定のため保持（表示は上限・おすすめ未処理に集約）。
    final _ = (
      kpi,
      isCompleted,
      hasTodaySuggestions,
      todayDoneCountForRec,
      recTotalCount,
    );

    final primary = _primaryAction();
    final pendingLine =
        generationStatus == TodayRecommendationGenerationStatus.loading
        ? 'おすすめを準備中です'
        : 'おすすめ未処理：$pendingCount件';

    return Container(
      width: double.infinity,
      decoration: _HomeUi.searchEntrySectionDecoration(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '今日のROOM運用',
            style: _HomeUi.sectionTitle(context).copyWith(
              color: HomeScreenColors.accentSectionHeading,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (recommendationHintLine != null &&
              recommendationHintLine!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              recommendationHintLine!.trim(),
              maxLines: 3,
              softWrap: true,
              style: _HomeUi.tapHint(context).copyWith(
                fontSize: 13,
                height: 1.38,
                color: HomeScreenColors.bodyOnSection,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _CollectLimitProgressLine(
            title: '直近24時間の投稿数',
            usedCount: collectLimit.todayCount,
            limit: RoomCollectPostLimitSnapshot.dailyLimit,
            state: collectLimit.dailyBarState,
            rightLabel: 'あと${collectLimit.dailyRemaining}件',
          ),
          const SizedBox(height: 12),
          _CollectLimitProgressLine(
            title: 'この1時間の投稿数',
            usedCount: collectLimit.hourCount,
            limit: RoomCollectPostLimitSnapshot.hourlyLimit,
            state: collectLimit.hourlyBarState,
            rightLabel: 'この1時間あと${collectLimit.hourlyRemaining}件',
            footnote: collectLimit.isHourlyReached
                ? collectLimit.recoveryFootnote(DateTime.now())
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            '今日のおすすめ',
            maxLines: 2,
            softWrap: true,
            style: _HomeUi.bodyEmphasis(context).copyWith(
              fontSize: 15,
              height: 1.35,
              color: HomeScreenColors.titlePrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            generationStatus == TodayRecommendationGenerationStatus.loading
                ? pendingLine
                : pendingLine.replaceFirst('おすすめ未処理', '未確認候補'),
            maxLines: 2,
            softWrap: true,
            style: _HomeUi.tapHint(context).copyWith(
              fontSize: 13,
              height: 1.3,
              color: HomeScreenColors.bodyOnSection,
            ),
          ),
          if (recommendationStatusMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              recommendationStatusMessage!,
              maxLines: 3,
              softWrap: true,
              style: _HomeUi.tapHint(
                context,
              ).copyWith(fontSize: 12, color: HomeScreenColors.footnoteMuted),
            ),
          ],
          const SizedBox(height: 14),
          _HomeHeroCtaButton(
            icon: primary.icon,
            label: primary.label,
            onPressed:
                generationStatus == TodayRecommendationGenerationStatus.loading
                ? null
                : primary.onPressed,
          ),
        ],
      ),
    );
  }

  _HomeActionSpec _primaryAction() {
    if (isLoading ||
        generationStatus == TodayRecommendationGenerationStatus.loading) {
      return _HomeActionSpec(
        label: '準備中',
        icon: Icons.auto_awesome_rounded,
        onPressed: () {},
      );
    }
    if (pendingCount > 0) {
      return _HomeActionSpec(
        label: 'おすすめコレを見る',
        icon: Icons.auto_awesome_rounded,
        onPressed: onPrimaryRecommendations,
      );
    }
    if (generationStatus ==
            TodayRecommendationGenerationStatus.failedRateLimit ||
        generationStatus ==
            TodayRecommendationGenerationStatus.failedApiError) {
      return _HomeActionSpec(
        label: 'おすすめを再生成',
        icon: Icons.refresh_rounded,
        onPressed: onPrimaryRecommendations,
      );
    }
    if (generationStatus == TodayRecommendationGenerationStatus.empty) {
      return _HomeActionSpec(
        label: 'おすすめを再生成',
        icon: Icons.refresh_rounded,
        onPressed: onPrimaryRecommendations,
      );
    }
    return _HomeActionSpec(
      label: 'おすすめを再生成',
      icon: Icons.refresh_rounded,
      onPressed: onPrimaryRecommendations,
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
  final VoidCallback? onPressed;

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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            foregroundColor: AppColors.textOnAccent,
            backgroundColor: AppColors.accentPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: Icon(icon, size: 22),
          label: Text(
            label,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: AppTextStyles.button.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
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

class _HomeAnimatedPostedCount extends StatefulWidget {
  const _HomeAnimatedPostedCount({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  State<_HomeAnimatedPostedCount> createState() =>
      _HomeAnimatedPostedCountState();
}

class _HomeAnimatedPostedCountState extends State<_HomeAnimatedPostedCount> {
  int _begin = 0;

  @override
  void initState() {
    super.initState();
    _begin = widget.value;
  }

  @override
  void didUpdateWidget(covariant _HomeAnimatedPostedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _begin = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      tween: IntTween(begin: _begin, end: widget.value),
      onEnd: () {
        if (!mounted) return;
        setState(() => _begin = widget.value);
      },
      builder: (context, v, child) {
        return Text('$v', style: widget.style);
      },
    );
  }
}

class _CollectLimitProgressLine extends StatelessWidget {
  const _CollectLimitProgressLine({
    required this.title,
    required this.usedCount,
    required this.limit,
    required this.state,
    required this.rightLabel,
    this.footnote,
  });

  final String title;
  final int usedCount;
  final int limit;
  final RoomCollectPostLimitBarState state;
  final String rightLabel;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      RoomCollectPostLimitBarState.normal => AppColors.accentPrimary,
      RoomCollectPostLimitBarState.warning => const Color(0xFFE67E22),
      RoomCollectPostLimitBarState.reached => AppColors.textSecondary,
    };
    final progress = limit <= 0 ? 0.0 : (usedCount / limit).clamp(0.0, 1.0);
    final foot = footnote?.trim();

    final metricStyle = _HomeUi.sectionBody(context).copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w900,
      height: 1.32,
      color: HomeScreenColors.titlePrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 0,
                runSpacing: 4,
                children: [
                  Text('$title：', style: metricStyle),
                  _HomeAnimatedPostedCount(
                    value: usedCount,
                    style: metricStyle,
                  ),
                  Text(' / $limit件', style: metricStyle),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                rightLabel,
                textAlign: TextAlign.end,
                maxLines: 2,
                softWrap: true,
                style: _HomeUi.sectionBody(context).copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  height: 1.28,
                  color: state == RoomCollectPostLimitBarState.normal
                      ? HomeScreenColors.footnoteMuted
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
            value: progress,
            minHeight: 10,
            backgroundColor: HomeScreenColors.progressTrack,
            color: color,
          ),
        ),
        if (foot != null && foot.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            foot,
            maxLines: 2,
            softWrap: true,
            style: _HomeUi.tapHint(
              context,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ],
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

  final RoomCollectPostLimitSnapshot collectLimit;
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
      title = '直近24時間の上限に達しました';
      message = '直近24時間の上限です。24時間より古い投稿がカウントから外れるまでお待ちください。';
      actions = [
        _HomeActionSpec(
          label: '分析を見る',
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
      message =
          'この1時間は上限です。少し待ってから再開してください。\n${collectLimit.recoveryFootnote(DateTime.now())}';
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
      title = '直近24時間の上限が近づいています';
      message = 'あと${collectLimit.dailyRemaining}件です。';
      actions = [
        _HomeActionSpec(
          label: 'コレ済を見る',
          icon: Icons.task_alt_rounded,
          onPressed: onDoneList,
        ),
      ];
    } else {
      title = 'あと少しで1時間上限です';
      message = 'この1時間あと${collectLimit.hourlyRemaining}件です。候補を整理しましょう。';
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

/// ホーム内の輪郭ボタン（ラベルを省略しない）。
class _HomeOutlinedHomeButton extends StatelessWidget {
  const _HomeOutlinedHomeButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.minHeight = 48,
    this.verticalPadding = 10,
    this.expandLabel = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double minHeight;
  final double verticalPadding;

  /// [false] は [Wrap] 配下など、横方向が無限幅になる場合に指定する。
  final bool expandLabel;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 8);
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.visible,
      softWrap: true,
    );

    late final Widget labelCell;
    if (expandLabel) {
      labelCell = Expanded(child: text);
    } else {
      labelCell = text;
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: AppColors.divider.withValues(alpha: 0.82)),
        elevation: 0,
        minimumSize: Size(0, minHeight),
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: verticalPadding,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: AppTextStyles.label.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
      clipBehavior: Clip.none,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: expandLabel ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.accentPrimary),
          gap,
          labelCell,
        ],
      ),
    );
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
          if (action.label.trim().isNotEmpty)
            _HomeOutlinedHomeButton(
              icon: action.icon,
              label: action.label,
              onPressed: action.onPressed,
              minHeight: 44,
              verticalPadding: 8,
              expandLabel: false,
            ),
      ],
    );
  }
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
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.visible,
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
                  caption: '分析タブを開く',
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

  /// 前回コレ日時タイル用（横1行：`4/28 23:29`）。
  String _formatLastCollectForTile(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}';
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

    /// 前回コレ日時：1行表示・やや大きめ（+2〜3pt）・weight 600 以上
    final valueHistorySize = compactDeck ? 21.0 : 22.5;
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
                maxLines: valueProminent || isHistoryTile ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: valueProminent
                    ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: HomeScreenColors.metricTileValueColor,
                        height: 1.02,
                        fontSize: valueLarge,
                        letterSpacing: -0.55,
                      )
                    : isHistoryTile
                    ? Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: HomeScreenColors.metricTileValueColor,
                        height: 1.2,
                        fontSize: valueHistorySize,
                        letterSpacing: -0.2,
                      )
                    : Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: HomeScreenColors.metricTileValueColor,
                        height: 1.12,
                        fontSize: valueSmall,
                        letterSpacing: -0.25,
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
