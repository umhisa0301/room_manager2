import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/room_colle_list_filters.dart';
import '../navigation/app_shell_controller.dart';
import '../navigation/rakuten_search_navigator.dart';
import 'rakuten_search_screen.dart';
import 'saved_shops_screen.dart';
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
import '../widgets/home_primary_action_button.dart';
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

  /// 主行動ボタン同士の縦間隔（詰まり感を抑える）
  static const double gapHeroMainActions = 10;

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

  /// 楽天検索等：単独カード内のパディング（横は [insetSectionH] に揃える）
  static EdgeInsets get paddingDenseCard =>
      EdgeInsets.fromLTRB(insetSectionH, 8, insetSectionH, 8);

  /// 今日のおすすめ候補：縦だけ抑えて要点＋10件文脈が間延びしないようにする
  static EdgeInsets get paddingTodayRecommendationsCard =>
      EdgeInsets.fromLTRB(insetSectionH, 6, insetSectionH, 6);

  /// 最近候補セクション内「コレ一覧を開く」（主ブロックより一段薄く保つ）
  static EdgeInsets get paddingRecentListFooterAction =>
      EdgeInsets.symmetric(horizontal: insetSectionH, vertical: 4);

  /// 見出し直下の一行説明（楽天検索ブロック等）
  static const double gapHeaderTitleToLead = 2;

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

  /// 楽天で検索ブロック：説明文とボタンの間
  static const double gapSearchLeadToButton = 6;

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

  /// 今日のおすすめ：1日あたりの上限（表示・説明用。生成ロジックとも一致）
  static const int todayRecommendationsMaxPerDay = 10;

  /// 今日のおすすめセクション：見出しとステータス行の間
  static const double gapTodayRecTitleToStatus = 2;

  /// 今日のおすすめセクション：ステータスと脚注の間
  static const double gapTodayRecStatusToFootnote = 2;

  /// 今日のおすすめ：プログレスバー上余白（10件プログレも縦を取りすぎない）
  static const double gapTodayRecBeforeProgress = 2;

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

  /// 今日のおすすめ：処理途中・未完了（日替わり特典感のある軽いトーン）
  static BoxDecoration todayRecommendationsSectionDecorationActive() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: HomeScreenColors.todayActiveGradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(color: HomeScreenColors.todayActiveBorder),
      boxShadow: cardShadow,
    );
  }

  /// 今日のおすすめ：本日完了（やり切り感・同一セクション内で弱めのトーン）
  static BoxDecoration todayRecommendationsSectionDecorationCompleted() {
    return BoxDecoration(
      color: HomeScreenColors.todayDoneFill,
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(color: HomeScreenColors.todayDoneBorder),
      boxShadow: cardShadow,
    );
  }

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
                    final nTodayDone =
                        RakutenRoomHomeStats.countDoneOnLocalCalendarDay(
                          items,
                          now,
                        );
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
                            _HomeMomentumHeader(
                              displayName: displayName,
                              summary: kpi,
                            ),
                            SizedBox(height: _HomeUi.gapSection),
                            _HomeTodayProgressCard(
                              kpi: kpi,
                              onTodayCollectTap: () => _openRoomList(
                                context,
                                initialTabIndex: 1,
                                doneFilterLocalDay: todayLocalDay,
                              ),
                              totalCount: recProvider.totalCount,
                              pendingCount: recProvider.pendingCount,
                              isCompleted: recProvider.isCompleted,
                              isLoading: recProvider.isLoading,
                              dateLabel: recProvider.activeDateLabelJp,
                              errorMessage: recProvider.errorMessage,
                              onOpenRecommendations: () =>
                                  _openTodayRecommendations(context),
                              hasTodaySuggestions: hasTodaySuggestions,
                              todayDoneCountForRec: todayDoneCountForRec,
                              recTotalCount: recProvider.totalCount,
                              onPrimaryRecommendations: () =>
                                  _openTodayRecommendations(context),
                            ),
                            SizedBox(height: _HomeUi.gapSection),
                            _HomeHeroMainActions(
                              onRakutenSearch: () {
                                openRakutenSearchScreen(context);
                              },
                              onOpenRoomCollect: () => _openRoomList(context),
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
                            _HomeSavedShopDiscoveryRow(
                              onOpenSavedShops: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const SavedShopsScreen(),
                                  ),
                                );
                              },
                              onOpenShopDiscovery: () {
                                openRakutenSearchScreen(context);
                              },
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
                            _HomeKpiMetricRow(
                              summary: kpi,
                              onTodayCollectTap: () => _openRoomList(
                                context,
                                initialTabIndex: 1,
                                doneFilterLocalDay: todayLocalDay,
                              ),
                              onActivityTap: () => _openActivity(context),
                            ),
                            SizedBox(height: _HomeUi.gapSection),
                            _HomeQuickLinkRow(
                              onSearch: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RakutenSearchScreen(),
                                  ),
                                );
                              },
                              onStaleCandidates: () => _openRoomList(
                                context,
                                candidateStalePreset:
                                    RoomColleStaleCandidatePreset.threePlus,
                              ),
                              onDoneList: () =>
                                  _openRoomList(context, initialTabIndex: 1),
                              onActivity: () => _openActivity(context),
                              showIntroText: false,
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

/// ホーム上部：今日のコレ（KPI）とおすすめ候補の進捗を1カードにまとめる。
class _HomeTodayProgressCard extends StatelessWidget {
  const _HomeTodayProgressCard({
    required this.kpi,
    required this.onTodayCollectTap,
    required this.totalCount,
    required this.pendingCount,
    required this.isCompleted,
    required this.isLoading,
    required this.dateLabel,
    required this.errorMessage,
    required this.onOpenRecommendations,
    required this.hasTodaySuggestions,
    required this.todayDoneCountForRec,
    required this.recTotalCount,
    required this.onPrimaryRecommendations,
  });

  final RoomKpiSummary kpi;
  final VoidCallback onTodayCollectTap;
  final int totalCount;
  final int pendingCount;
  final bool isCompleted;
  final bool isLoading;
  final String? dateLabel;
  final String? errorMessage;
  final VoidCallback onOpenRecommendations;
  final bool hasTodaySuggestions;
  final int todayDoneCountForRec;
  final int recTotalCount;
  final VoidCallback onPrimaryRecommendations;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _HomeUi.searchEntrySectionDecoration(),
      padding: const EdgeInsets.fromLTRB(
        _HomeUi.insetSectionH,
        10,
        _HomeUi.insetSectionH,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '今日の進捗',
            style: _HomeUi.sectionTitle(
              context,
            ).copyWith(color: HomeScreenColors.accentSectionHeading),
          ),
          const SizedBox(height: 8),
          _HomeMiniKpiTile(
            icon: Icons.today_rounded,
            iconColor: const Color(0xFF1565C0),
            value: '${kpi.todayCoredCount}',
            label: '今日のコレ',
            hint: 'タップでコレ済（今日）',
            onTap: onTodayCollectTap,
          ),
          const SizedBox(height: 10),
          _TodayRecommendationsHomeSection(
            totalCount: totalCount,
            pendingCount: pendingCount,
            isCompleted: isCompleted,
            isLoading: isLoading,
            dateLabel: dateLabel,
            errorMessage: errorMessage,
            onOpen: onOpenRecommendations,
            compactLayout: true,
          ),
          if (hasTodaySuggestions) ...[
            const SizedBox(height: 6),
            Text(
              'おすすめ $todayDoneCountForRec/$recTotalCount 件済',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _HomeUi.tapHint(context),
            ),
          ],
          const SizedBox(height: 8),
          _HomeMainActionSection(
            pendingCount: pendingCount,
            totalCount: totalCount,
            isLoading: isLoading,
            isCompleted: isCompleted,
            onPrimaryTap: onPrimaryRecommendations,
            slim: true,
          ),
        ],
      ),
    );
  }
}

/// 主行動：楽天検索と ROOM コレ一覧（既存の遷移をそのまま利用）。
class _HomeHeroMainActions extends StatelessWidget {
  const _HomeHeroMainActions({
    required this.onRakutenSearch,
    required this.onOpenRoomCollect,
  });

  final VoidCallback onRakutenSearch;
  final VoidCallback onOpenRoomCollect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _HomeUi.searchEntrySectionDecoration(),
      padding: const EdgeInsets.fromLTRB(
        _HomeUi.insetSectionH,
        10,
        _HomeUi.insetSectionH,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '次の一歩',
            style: _HomeUi.sectionTitle(
              context,
            ).copyWith(color: HomeScreenColors.accentSectionHeading),
          ),
          const SizedBox(height: 8),
          _HomeSearchEntrySection(
            onSearch: onRakutenSearch,
            embeddedInHero: true,
            omitLeadParagraph: true,
          ),
          SizedBox(height: _HomeUi.gapHeroMainActions),
          HomePrimaryActionButton(
            emphasis: HomePrimaryActionEmphasis.standard,
            icon: Icons.collections_bookmark_outlined,
            label: 'ROOMコレを見る',
            onPressed: onOpenRoomCollect,
          ),
        ],
      ),
    );
  }
}

/// 保存ショップ・ショップ発掘（下部ナビ「＋」シートと同じ遷移先）。
class _HomeSavedShopDiscoveryRow extends StatelessWidget {
  const _HomeSavedShopDiscoveryRow({
    required this.onOpenSavedShops,
    required this.onOpenShopDiscovery,
  });

  final VoidCallback onOpenSavedShops;
  final VoidCallback onOpenShopDiscovery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _HomeUi.searchEntrySectionDecoration(),
      padding: const EdgeInsets.fromLTRB(
        _HomeUi.insetSectionH,
        10,
        _HomeUi.insetSectionH,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'サブ導線',
            style: _HomeUi.sectionTitle(
              context,
            ).copyWith(color: HomeScreenColors.accentSectionHeading),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenSavedShops,
                  icon: Icon(
                    Icons.storefront_rounded,
                    size: 20,
                    color: AppColors.accentPrimary,
                  ),
                  label: Text(
                    '保存ショップ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    side: BorderSide(color: HomeScreenColors.metricTileOutline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusButton,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenShopDiscovery,
                  icon: Icon(
                    Icons.hiking_rounded,
                    size: 20,
                    color: AppColors.accentPrimary,
                  ),
                  label: Text(
                    'ショップ発掘',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    side: BorderSide(color: HomeScreenColors.metricTileOutline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusButton,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeMomentumHeader extends StatelessWidget {
  const _HomeMomentumHeader({required this.displayName, required this.summary});

  final String? displayName;
  final RoomKpiSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameLine = displayName == null || displayName!.trim().isEmpty
        ? 'こんにちは'
        : 'こんにちは、${displayName!.trim()}さん';
    final weekLine = summary.weeklyActivityCount == 0
        ? '今週の活動ログはまだありません'
        : '今週 ${summary.weeklyActivityCount} 件 · 反応 ${summary.weeklyReactionScore}';

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
          Text(weekLine, style: _HomeUi.sectionBody(context)),
        ],
      ),
    );
  }
}

class _HomeMainActionSection extends StatelessWidget {
  const _HomeMainActionSection({
    required this.pendingCount,
    required this.totalCount,
    required this.isLoading,
    required this.isCompleted,
    required this.onPrimaryTap,
    this.slim = false,
  });

  final int pendingCount;
  final int totalCount;
  final bool isLoading;
  final bool isCompleted;
  final VoidCallback onPrimaryTap;

  /// true のときは進捗カード内用に説明を省き、主ボタンだけをコンパクトに置く。
  final bool slim;

  @override
  Widget build(BuildContext context) {
    final title = isLoading && totalCount == 0
        ? '今日やることを準備中です'
        : isCompleted && totalCount > 0
        ? '今日のおすすめは完了しました'
        : totalCount == 0
        ? 'まずは今日のおすすめを用意しましょう'
        : 'まずは残り $pendingCount 件を確認しましょう';
    final subtitle = isCompleted && totalCount > 0
        ? '完了済み。必要なら一覧で確認できます。'
        : '候補の追加・見送りで今日の分を片付けられます。';

    if (slim) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _HomeUi.sectionTitle(context).copyWith(fontSize: 14.5),
          ),
          const SizedBox(height: _HomeUi.gapSearchLeadToButton),
          HomePrimaryActionButton(
            emphasis: HomePrimaryActionEmphasis.hero,
            icon: Icons.auto_awesome_rounded,
            label: '今日のおすすめを見る',
            onPressed: onPrimaryTap,
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      decoration: _HomeUi.searchEntrySectionDecoration(),
      padding: _HomeUi.paddingDenseCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '今日の入口',
            style: _HomeUi.sectionTitle(
              context,
            ).copyWith(color: HomeScreenColors.accentSectionHeading),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: _HomeUi.sectionTitle(context).copyWith(fontSize: 16),
          ),
          const SizedBox(height: _HomeUi.gapStackTight),
          Text(subtitle, style: _HomeUi.sectionBody(context)),
          const SizedBox(height: _HomeUi.gapSearchLeadToButton),
          HomePrimaryActionButton(
            emphasis: HomePrimaryActionEmphasis.hero,
            icon: Icons.auto_awesome_rounded,
            label: '今日のおすすめを見る',
            onPressed: onPrimaryTap,
          ),
        ],
      ),
    );
  }
}

class _HomeKpiMetricRow extends StatelessWidget {
  const _HomeKpiMetricRow({
    required this.summary,
    required this.onTodayCollectTap,
    required this.onActivityTap,
  });

  final RoomKpiSummary summary;
  final VoidCallback onTodayCollectTap;
  final VoidCallback onActivityTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HomeMiniKpiTile(
            icon: Icons.today_rounded,
            iconColor: const Color(0xFF1565C0),
            value: '${summary.todayCoredCount}',
            label: '今日のコレ',
            hint: 'タップでコレ済（今日）',
            onTap: onTodayCollectTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HomeMiniKpiTile(
            icon: Icons.local_fire_department_outlined,
            iconColor: const Color(0xFFE65100),
            value: '${summary.consecutiveActiveDays}',
            label: '連続活動',
            hint: '活動ログ基準',
            onTap: onActivityTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HomeMiniKpiTile(
            icon: Icons.favorite_outline_rounded,
            iconColor: const Color(0xFF2E7D32),
            value: '${summary.weeklyReactionScore}',
            label: '週の反応',
            hint: '👍+1 💰+3 👎-1',
            onTap: onActivityTap,
          ),
        ),
      ],
    );
  }
}

class _HomeMiniKpiTile extends StatelessWidget {
  const _HomeMiniKpiTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_HomeUi.radiusSectionInner),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
          decoration: BoxDecoration(
            color: HomeScreenColors.roomMetricTileFill,
            borderRadius: BorderRadius.circular(_HomeUi.radiusSectionInner),
            border: Border.all(color: HomeScreenColors.metricTileOutline),
            boxShadow: HomeScreenColors.roomMetricTileShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: HomeScreenColors.metricTileTitleColor,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: HomeScreenColors.metricTileValueColor,
                  height: 1,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 9.5,
                  height: 1.25,
                  color: HomeScreenColors.metricTileCaptionColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeQuickLinkRow extends StatelessWidget {
  const _HomeQuickLinkRow({
    required this.onSearch,
    required this.onStaleCandidates,
    required this.onDoneList,
    required this.onActivity,
    this.showIntroText = true,
  });

  final VoidCallback onSearch;
  final VoidCallback onStaleCandidates;
  final VoidCallback onDoneList;
  final VoidCallback onActivity;

  /// false のときは見出し下の説明文を出さず、チップ行だけにする。
  final bool showIntroText;

  @override
  Widget build(BuildContext context) {
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
        if (showIntroText)
          Padding(
            padding: EdgeInsets.fromLTRB(
              _HomeUi.insetSectionH,
              0,
              _HomeUi.insetSectionH,
              6,
            ),
            child: Text('状況に応じて使う補助導線です。', style: _HomeUi.tapHint(context)),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HomeChipAction(
              icon: Icons.search_rounded,
              label: '候補を探す',
              onTap: onSearch,
            ),
            _HomeChipAction(
              icon: Icons.inventory_2_outlined,
              label: '放置候補',
              onTap: onStaleCandidates,
            ),
            _HomeChipAction(
              icon: Icons.task_alt_rounded,
              label: 'コレ済を確認',
              onTap: onDoneList,
            ),
            _HomeChipAction(
              icon: Icons.insights_outlined,
              label: '活動',
              onTap: onActivity,
            ),
          ],
        ),
      ],
    );
  }
}

class _HomeChipAction extends StatelessWidget {
  const _HomeChipAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: HomeScreenColors.titlePrimary),
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      backgroundColor: HomeScreenColors.roomMetricTileFill,
      side: BorderSide(color: HomeScreenColors.metricTileOutline),
    );
  }
}

/// 楽天検索を**文脈付きブロック**として提示（ホーム主行動内の埋め込み時は枠なし・説明省略可）。
class _HomeSearchEntrySection extends StatelessWidget {
  const _HomeSearchEntrySection({
    required this.onSearch,
    this.embeddedInHero = false,
    this.omitLeadParagraph = false,
  });

  final VoidCallback onSearch;

  /// true のときは外枠装飾を付けず、親カード内にそのまま置く。
  final bool embeddedInHero;

  /// true のときはリード文（補助導線の説明）を出さない。
  final bool omitLeadParagraph;

  @override
  Widget build(BuildContext context) {
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.travel_explore_rounded,
                size: 22,
                color: HomeScreenColors.statusAccentStrong,
              ),
            ),
            SizedBox(width: _HomeUi.gapIconToTitle),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('楽天で商品を探す', style: _HomeUi.sectionTitle(context)),
                  if (!omitLeadParagraph) ...[
                    SizedBox(height: _HomeUi.gapHeaderTitleToLead),
                    Text('検索して候補に追加できます。', style: _HomeUi.sectionBody(context)),
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: _HomeUi.gapSearchLeadToButton),
        HomePrimaryActionButton(
          emphasis: HomePrimaryActionEmphasis.hero,
          icon: Icons.travel_explore_rounded,
          label: '楽天でコレ候補を検索する',
          onPressed: onSearch,
        ),
      ],
    );

    if (embeddedInHero) {
      return inner;
    }

    return Container(
      width: double.infinity,
      decoration: _HomeUi.searchEntrySectionDecoration(),
      padding: _HomeUi.paddingDenseCard,
      child: inner,
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

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(leadingIcon, size: 20, color: AppColors.accentPrimary),
        label: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.accentPrimary,
            height: 1.25,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          backgroundColor: HomeScreenColors.standaloneCardFill,
          side: BorderSide(color: HomeScreenColors.metricTileOutline),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(double.infinity, 46),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
        ),
      ),
    );
  }
}

/// 今日のおすすめ：日替わり提案の文脈・残件・完了・最大10件を1ブロックで提示する。
class _TodayRecommendationsHomeSection extends StatelessWidget {
  const _TodayRecommendationsHomeSection({
    required this.totalCount,
    required this.pendingCount,
    required this.isCompleted,
    required this.isLoading,
    required this.dateLabel,
    this.errorMessage,
    required this.onOpen,
    this.compactLayout = false,
  });

  final int totalCount;
  final int pendingCount;
  final bool isCompleted;
  final bool isLoading;
  final String? dateLabel;
  final String? errorMessage;
  final VoidCallback onOpen;

  /// 進捗カード内では脚注・日付行を抑え、縦の占有を減らす。
  final bool compactLayout;

  @override
  Widget build(BuildContext context) {
    final maxN = _HomeUi.todayRecommendationsMaxPerDay;
    final done = isCompleted && totalCount > 0;
    final deco = done
        ? _HomeUi.todayRecommendationsSectionDecorationCompleted()
        : _HomeUi.todayRecommendationsSectionDecorationActive();

    final titleStyle = _HomeUi.sectionTitle(context).copyWith(
      color: done
          ? HomeScreenColors.bodyOnSection
          : HomeScreenColors.titlePrimary,
    );

    late final String statusLine;
    late final String footnote;
    if (isLoading && totalCount == 0) {
      statusLine = '今日の提案を用意しています…';
      footnote = '最大$maxN件まで。追加/見送りで整理できます。';
    } else if (errorMessage != null &&
        errorMessage!.isNotEmpty &&
        totalCount == 0) {
      statusLine = 'いま一度お試しください';
      footnote = 'タップで再試行。最大$maxN件/日。';
    } else if (totalCount == 0) {
      statusLine = '今日やる候補を、最大$maxN件まで作成できます';
      footnote = '日替わり提案。追加/見送りで未処理が減ります。';
    } else if (done) {
      statusLine = '本日のおすすめはすべて完了しました';
      footnote = '日付が変わると最大$maxN件まで再提案されます。';
    } else {
      statusLine = '残り $pendingCount 件 · 本日は最大$maxN件まで';
      footnote = '各件で追加または見送りを選べます。';
    }

    final String footnoteForLayout = compactLayout ? '' : footnote;

    final progress = totalCount > 0 && !done
        ? (totalCount - pendingCount) / totalCount
        : 0.0;

    IconData leadingIcon;
    Color leadingColor;
    if (done) {
      leadingIcon = Icons.check_circle_outline_rounded;
      leadingColor = HomeScreenColors.statusSuccessIcon;
    } else if (isLoading && totalCount == 0) {
      leadingIcon = Icons.auto_awesome_outlined;
      leadingColor = HomeScreenColors.statusAccentMuted;
    } else {
      leadingIcon = Icons.auto_awesome_outlined;
      leadingColor = HomeScreenColors.statusAccentStrong;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(_HomeUi.radiusSectionOuter),
        splashColor: HomeScreenColors.inkNeutralSplash.withValues(
          alpha: done ? 0.06 : 0.09,
        ),
        highlightColor: HomeScreenColors.inkNeutralHighlight.withValues(
          alpha: done ? 0.04 : 0.05,
        ),
        child: Opacity(
          opacity: done ? 0.98 : 1,
          child: Container(
            width: double.infinity,
            padding: compactLayout
                ? EdgeInsets.fromLTRB(
                    _HomeUi.insetSectionH,
                    5,
                    _HomeUi.insetSectionH,
                    5,
                  )
                : _HomeUi.paddingTodayRecommendationsCard,
            decoration: deco,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: isLoading && totalCount == 0
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: HomeScreenColors.statusAccentStrong,
                          ),
                        )
                      : Icon(leadingIcon, size: 22, color: leadingColor),
                ),
                SizedBox(width: _HomeUi.gapIconToTitle),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('今日やるおすすめ候補', style: titleStyle),
                      if (!compactLayout &&
                          dateLabel != null &&
                          dateLabel!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          '${dateLabel!}の提案（日替わり）',
                          style: _HomeUi.tapHint(context),
                        ),
                      ],
                      SizedBox(height: _HomeUi.gapTodayRecTitleToStatus),
                      Text(
                        statusLine,
                        maxLines: compactLayout ? 2 : 4,
                        overflow: TextOverflow.ellipsis,
                        style: _HomeUi.sectionBody(context).copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.32,
                          color: done
                              ? HomeScreenColors.bodyOnSection
                              : HomeScreenColors.titlePrimary,
                        ),
                      ),
                      if (errorMessage != null &&
                          errorMessage!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          errorMessage!.trim(),
                          style: _HomeUi.sectionBody(context).copyWith(
                            color: AppColors.error.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (footnoteForLayout.isNotEmpty) ...[
                        SizedBox(height: _HomeUi.gapTodayRecStatusToFootnote),
                        Text(
                          footnoteForLayout,
                          style: _HomeUi.tapHint(context),
                        ),
                      ],
                      if (totalCount > 0 && !done && !isLoading) ...[
                        SizedBox(height: _HomeUi.gapTodayRecBeforeProgress),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: HomeScreenColors.progressTrack,
                            color: HomeScreenColors.progressValue,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: _HomeUi.paddingRowChevron,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: HomeScreenColors.chevronOnSection.withValues(
                      alpha: done ? 0.52 : 0.90,
                    ),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
