import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import 'activity_placeholder_screen.dart';
import 'products_placeholder_screen.dart';
import 'rakuten_search_screen.dart';
import 'today_recommendations_screen.dart';
import '../services/rakuten_room_home_stats.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/home_primary_action_button.dart';

// --- ホーム画面：レイアウト・タイポ・装飾の統一（画面ロジックとは分離）---

/// ホーム専用の余白・行間・装飾ルール。
abstract final class _HomeUi {
  const _HomeUi._();

  /// 主要ブロック同士（CTA・セクション・グループ）
  static const double gapSection = 14;

  /// ホーム ListView の左右（アプリ全体の [AppDimensions.screenPaddingH] より一段狭めて表示領域を確保）
  static const double screenPaddingH = 14;

  /// ホーム ListView の上下（画面端との距離を少し詰めつつ窮屈にならない程度）
  static const double screenPaddingV = 14;

  /// セクション外枠の角丸（`AppDimensions.radiusCard` と一致）
  static double get radiusSectionOuter => AppDimensions.radiusCard;

  /// 見出し直下のリスト・メトリクス用インセット枠の角丸
  static const double radiusSectionInner = 12;

  /// セクション内の左右インセット（見出し・区切り・デッキ・単独ブロックで共通）
  static const double insetSectionH = 12;

  /// セクション先頭（見出し＋補足・折りたたみ行）の統一パディング
  static EdgeInsets get paddingSectionHeader =>
      EdgeInsets.fromLTRB(insetSectionH, 12, insetSectionH, 9);

  /// 「このアプリについて」等：開閉ヘッダー（本文との縦リズムを他セクションに寄せる）
  static EdgeInsets get paddingExpandableHeader =>
      EdgeInsets.fromLTRB(insetSectionH, 12, insetSectionH, 10);

  /// グリッド・リスト「デッキ」の外側（下のみ余白を厚めに）
  static EdgeInsets get paddingDeckOuter =>
      EdgeInsets.fromLTRB(insetSectionH, 0, insetSectionH, 12);

  /// 見出し行：先頭アイコンとタイトル列の間
  static const double gapIconToTitle = 12;

  /// 折りたたみセクション：展開ブロックのみ（上はヘッダーで確保）
  static EdgeInsets get paddingSectionExpandedOnly =>
      EdgeInsets.fromLTRB(insetSectionH, 0, insetSectionH, 12);

  /// 楽天検索・今日のおすすめ等：単独カード内のパディング（横は [insetSectionH] に揃える）
  static EdgeInsets get paddingDenseCard =>
      EdgeInsets.fromLTRB(insetSectionH, 12, insetSectionH, 12);

  /// セクション末尾サブアクション行
  static EdgeInsets get paddingSectionFooterAction =>
      EdgeInsets.symmetric(horizontal: insetSectionH, vertical: 10);

  /// セクション見出しと折りたたみ要約の間
  static const double gapTitleToSummary = 5;

  /// 見出し直下の一行リード（ROOM・最近候補・検索で共通）
  static const double gapHeaderTitleToLead = 4;

  /// ROOMコレ管理：展開説明の下余白
  static const double gapRoomDetailBottom = 8;

  /// ROOMコレ管理：区切り線とタイルデッキの間
  static const double gapRoomDividerToDeck = 8;

  /// ROOMコレ管理：タイルデッキ内のパディング
  static const double paddingRoomTileDeck = 7;

  /// ROOMコレ管理：グリッドの列・行間（統一）
  static const double gapRoomGrid = 8;

  /// 最近候補：展開説明の下余白
  static const double gapRecentDetailBottom = 8;

  /// 最近候補：区切り線とリストデッキの間
  static const double gapRecentDividerToDeck = 8;

  /// 最近候補：リストデッキの内側パディング
  static const double paddingRecentListDeck = 7;

  /// 最近候補セクション：最下部の余白
  static const double paddingRecentSectionBottom = 4;

  /// コンパクトな縦の詰まり（チップ上など）
  static const double gapTight = 6;

  /// 楽天で検索ブロック：説明文とボタンの間
  static const double gapSearchLeadToButton = 10;

  /// 区切り線の色（ホーム内で統一）
  static Color dividerLineColor() =>
      AppColors.divider.withValues(alpha: 0.52);

  /// セクション外枠の境界線（アクセント薄いトーン / 通常）
  static Color sectionBorderColor({bool accentTint = false}) {
    if (accentTint) {
      return AppColors.accentPrimary.withValues(alpha: 0.16);
    }
    return AppColors.divider.withValues(alpha: 0.76);
  }

  /// 今日のおすすめ：1日あたりの上限（表示・説明用。生成ロジックとも一致）
  static const int todayRecommendationsMaxPerDay = 10;

  /// 今日のおすすめセクション：見出しとステータス行の間
  static const double gapTodayRecTitleToStatus = 5;

  /// 今日のおすすめセクション：ステータスと脚注の間
  static const double gapTodayRecStatusToFootnote = 4;

  /// 今日のおすすめ：プログレスバー上余白
  static const double gapTodayRecBeforeProgress = 6;

  /// 標準リストの下余白（ナビバー押さえ以外）
  static const double listBottomExtra = 12;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.055),
          offset: const Offset(0, 2),
          blurRadius: 10,
        ),
      ];

  /// 今日のおすすめ：処理途中・未完了（日替わり特典感のある軽いトーン）
  static BoxDecoration todayRecommendationsSectionDecorationActive() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.accentLight.withValues(alpha: 0.55),
          AppColors.surface,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(
        color: AppColors.accentPrimary.withValues(alpha: 0.2),
      ),
      boxShadow: cardShadow,
    );
  }

  /// 今日のおすすめ：本日完了（やり切り感・同一セクション内で弱めのトーン）
  static BoxDecoration todayRecommendationsSectionDecorationCompleted() {
    return BoxDecoration(
      color: Color.alphaBlend(
        AppColors.surfaceVariant.withValues(alpha: 0.52),
        AppColors.surface,
      ),
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(
        color: sectionBorderColor(accentTint: false),
      ),
      boxShadow: cardShadow,
    );
  }

  /// 楽天で検索：説明＋CTA を1ブロックに（先頭単独ボタンの唐突感を抑える）
  static BoxDecoration searchEntrySectionDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(
        color: sectionBorderColor(accentTint: true),
      ),
      boxShadow: cardShadow,
    );
  }

  /// ROOMコレ管理：見出し〜タイルまでを1ブロックに見せる外枠
  static BoxDecoration roomManagementSectionDecoration() {
    return BoxDecoration(
      color: Color.alphaBlend(
        AppColors.surfaceVariant.withValues(alpha: 0.4),
        AppColors.background,
      ),
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(
        color: sectionBorderColor(accentTint: false),
      ),
      boxShadow: cardShadow,
    );
  }

  /// ROOMコレ管理：4タイルをまとめる内側デッキ（見出しとは色を分ける）
  static BoxDecoration roomTileDeckDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radiusSectionInner),
      border: Border.all(
        color: AppColors.divider.withValues(alpha: 0.72),
      ),
    );
  }

  /// 最近追加した候補：見出し〜一覧〜フッターを1つにまとめる外枠
  static BoxDecoration recentCandidatesSectionDecoration() {
    return BoxDecoration(
      color: Color.alphaBlend(
        AppColors.surfaceVariant.withValues(alpha: 0.4),
        AppColors.background,
      ),
      borderRadius: BorderRadius.circular(radiusSectionOuter),
      border: Border.all(
        color: sectionBorderColor(accentTint: false),
      ),
      boxShadow: cardShadow,
    );
  }

  /// セクション見出し：アクセント（ROOM・最近候補）— サイズは [sectionTitle] と揃え色だけ差す
  static TextStyle sectionTitleAccent(BuildContext context) {
    return sectionTitle(context).copyWith(color: AppColors.accentPrimary);
  }

  /// 見出し直下の一行リード（全セクションで統一）
  static TextStyle sectionHeaderLead(BuildContext context) {
    final base = Theme.of(context).textTheme.labelSmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.35,
      letterSpacing: 0.02,
      color: AppColors.textTertiary,
    );
  }

  /// セクション・カード見出し（何が見出しかを揃える）
  static TextStyle sectionTitle(BuildContext context) {
    final base = Theme.of(context).textTheme.titleSmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      height: 1.22,
      letterSpacing: -0.15,
      color: AppColors.textPrimary,
    );
  }

  /// 折りたたみ時の一行サマリー
  static TextStyle sectionCollapsedSummary(BuildContext context) {
    final base = Theme.of(context).textTheme.labelMedium;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.32,
      color: AppColors.textSecondary,
    );
  }

  /// 展開した説明文・補足
  static TextStyle sectionBody(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 13,
      height: 1.38,
      color: AppColors.textSecondary,
    );
  }

  /// タップ可能な補足・キャプション
  static TextStyle tapHint(BuildContext context) {
    final base = Theme.of(context).textTheme.labelSmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 11.5,
      height: 1.32,
      color: AppColors.textTertiary,
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
      color: AppColors.accentPrimary,
    );
  }

  /// 見出し〜デッキ間の区切り（横インセット統一）
  static Widget sectionDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: insetSectionH),
      child: Divider(
        height: 1,
        thickness: 1,
        color: dividerLineColor(),
      ),
    );
  }

  /// 空状態・リスト内のサブ見出し
  static TextStyle bodyEmphasis(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    return (base ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w600,
      height: 1.28,
      color: AppColors.textPrimary,
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
  bool _aboutExpanded = false;
  bool _roomIntroExpanded = false;
  bool _recentIntroExpanded = false;
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
  }) {
    final idx = initialTabIndex.clamp(0, 1);
    DateTime? dayNorm;
    if (doneFilterLocalDay != null) {
      dayNorm = DateTime(
        doneFilterLocalDay.year,
        doneFilterLocalDay.month,
        doneFilterLocalDay.day,
      );
    }
    final focusId = focusCandidateProductId != null &&
            focusCandidateProductId.isNotEmpty &&
            idx == 0
        ? focusCandidateProductId
        : null;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductsPlaceholderScreen(
          initialTabIndex: idx,
          initialDoneFilterLocalDay: dayNorm,
          initialFocusCandidateProductId: focusId,
        ),
      ),
    );
  }

  void _openActivity(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ActivityPlaceholderScreen(),
      ),
    );
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child:
            Consumer3<
              RakutenManagedProductProvider,
              UserProfileProvider,
              TodayRecommendationProvider
            >(
              builder:
                  (context, roomProvider, userProfileProvider, recProvider, _) {
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
                        ).take(5).toList();
                    final bottomInset = MediaQuery.paddingOf(context).bottom;
                    const navBarReserve = 52.0;
                    final todayLocalDay = DateTime(
                      now.year,
                      now.month,
                      now.day,
                    );

                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        _HomeUi.screenPaddingH,
                        _HomeUi.screenPaddingV,
                        _HomeUi.screenPaddingH,
                        bottomInset + navBarReserve + _HomeUi.listBottomExtra,
                      ),
                      children: [
                        _HomeExpandableSection(
                          expanded: _aboutExpanded,
                          onToggle: () {
                            setState(() {
                              _aboutExpanded = !_aboutExpanded;
                            });
                          },
                          title: 'このアプリについて',
                          collapsedSummary: '3ステップでROOMコレを進める（詳しく）',
                          leadingIcon: Icons.info_outline_rounded,
                          expandedChild: _AboutAppExpandedBody(
                            displayName: displayName,
                          ),
                        ),
                        const SizedBox(height: _HomeUi.gapSection),
                        _HomeSearchEntrySection(
                          onSearch: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RakutenSearchScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: _HomeUi.gapSection),
                        _TodayRecommendationsHomeSection(
                          totalCount: recProvider.totalCount,
                          pendingCount: recProvider.pendingCount,
                          isCompleted: recProvider.isCompleted,
                          isLoading: recProvider.isLoading,
                          dateLabel: recProvider.activeDateLabelJp,
                          errorMessage: recProvider.errorMessage,
                          onOpen: () => _openTodayRecommendations(context),
                        ),
                        const SizedBox(height: _HomeUi.gapSection),
                        _RoomManagementSection(
                          expanded: _roomIntroExpanded,
                          onToggle: () {
                            setState(() {
                              _roomIntroExpanded = !_roomIntroExpanded;
                            });
                          },
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
                        const SizedBox(height: _HomeUi.gapSection),
                        _RecentCandidatesHomeSection(
                          expanded: _recentIntroExpanded,
                          onToggle: () {
                            setState(() {
                              _recentIntroExpanded = !_recentIntroExpanded;
                            });
                          },
                          candidates: recentCandidates,
                          onOpenCandidateTap: (productId) => _openRoomList(
                            context,
                            focusCandidateProductId: productId,
                          ),
                          onOpenFullList: () => _openRoomList(context),
                        ),
                      ],
                    );
                  },
            ),
      ),
    );
  }
}

/// ホーム共通：ヘッダー全面タップ・スプラッシュ・AnimatedSize で開閉。
class _HomeExpandableSection extends StatelessWidget {
  const _HomeExpandableSection({
    required this.expanded,
    required this.onToggle,
    required this.title,
    required this.collapsedSummary,
    required this.leadingIcon,
    required this.expandedChild,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String title;
  final String collapsedSummary;
  final IconData leadingIcon;
  final Widget expandedChild;

  static const Duration _animDuration = Duration(milliseconds: 280);
  static const Curve _animCurve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_HomeUi.radiusSectionOuter);
    final splashColor = AppColors.accentPrimary.withValues(alpha: 0.14);
    final highlightColor = AppColors.accentPrimary.withValues(alpha: 0.07);
    const iconColor = AppColors.accentPrimary;

    final decoration = BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.accentLight.withValues(alpha: 0.88),
          const Color(0xFFFFF5F9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: radius,
      border: Border.all(
        color: _HomeUi.sectionBorderColor(accentTint: true),
      ),
      boxShadow: _HomeUi.cardShadow,
    );

    return Container(
      width: double.infinity,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: radius,
              splashColor: splashColor,
              highlightColor: highlightColor,
              child: Padding(
                padding: _HomeUi.paddingExpandableHeader,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(leadingIcon, size: 22, color: iconColor),
                    ),
                    SizedBox(width: _HomeUi.gapIconToTitle),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: _HomeUi.sectionTitle(context),
                          ),
                          if (collapsedSummary.isNotEmpty && !expanded) ...[
                            const SizedBox(height: _HomeUi.gapTitleToSummary),
                            Text(
                              collapsedSummary,
                              style: _HomeUi.sectionCollapsedSummary(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: _animDuration,
            curve: _animCurve,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: _HomeUi.paddingSectionExpandedOnly,
                    child: expandedChild,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// 「このアプリについて」の直後：楽天検索を**文脈付きブロック**として提示（ステップ1）。
class _HomeSearchEntrySection extends StatelessWidget {
  const _HomeSearchEntrySection({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _HomeUi.searchEntrySectionDecoration(),
      padding: _HomeUi.paddingDenseCard,
      child: Column(
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
                  color: AppColors.accentPrimary.withValues(alpha: 0.9),
                ),
              ),
              SizedBox(width: _HomeUi.gapIconToTitle),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '楽天で商品を探す',
                      style: _HomeUi.sectionTitle(context),
                    ),
                    SizedBox(height: _HomeUi.gapHeaderTitleToLead),
                    Text(
                      '検索して気に入った商品をコレ候補に登録。ROOMコレの第一歩です。',
                      style: _HomeUi.sectionBody(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: _HomeUi.gapSearchLeadToButton),
          HomePrimaryActionButton(
            emphasis: HomePrimaryActionEmphasis.hero,
            icon: Icons.travel_explore_rounded,
            label: '楽天で検索',
            onPressed: onSearch,
          ),
        ],
      ),
    );
  }
}

/// ROOMコレ管理：見出し・補足・4タイルを1セクションとして囲う。
class _RoomManagementSection extends StatelessWidget {
  const _RoomManagementSection({
    required this.expanded,
    required this.onToggle,
    required this.candidateTotal,
    required this.doneTotal,
    required this.todayDoneCount,
    required this.lastDoneAt,
    required this.onCandidateTap,
    required this.onDoneTap,
    required this.onTodayTap,
    required this.onLastCollectTap,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final int candidateTotal;
  final int doneTotal;
  final int todayDoneCount;
  final DateTime? lastDoneAt;
  final VoidCallback onCandidateTap;
  final VoidCallback onDoneTap;
  final VoidCallback onTodayTap;
  final VoidCallback onLastCollectTap;

  static const Duration _animDuration = Duration(milliseconds: 280);
  static const Curve _animCurve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _HomeUi.roomManagementSectionDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              splashColor: AppColors.accentPrimary.withValues(alpha: 0.09),
              highlightColor: AppColors.accentPrimary.withValues(alpha: 0.05),
              child: Padding(
                padding: _HomeUi.paddingSectionHeader,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.collections_bookmark_outlined,
                        size: 22,
                        color: AppColors.accentPrimary.withValues(alpha: 0.9),
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
                          SizedBox(height: _HomeUi.gapHeaderTitleToLead),
                          Text(
                            '端末に保存した一覧の集計です。下のカードで一覧・活動へ。',
                            style: _HomeUi.sectionHeaderLead(context),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: _animDuration,
            curve: _animCurve,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: EdgeInsets.only(
                      left: _HomeUi.insetSectionH,
                      right: _HomeUi.insetSectionH,
                      bottom: _HomeUi.gapRoomDetailBottom,
                    ),
                    child: Text(
                      '下の数は端末に保存した一覧の集計です。カードをタップで一覧・活動へ移動します。',
                      style: _HomeUi.sectionBody(context),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          _HomeUi.sectionDivider(),
          SizedBox(height: _HomeUi.gapRoomDividerToDeck),
          Padding(
            padding: _HomeUi.paddingDeckOuter,
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
        ],
      ),
    );
  }
}

/// 最近追加した候補：見出し・一覧・コレ一覧導線を1セクションにまとめる。
class _RecentCandidatesHomeSection extends StatelessWidget {
  const _RecentCandidatesHomeSection({
    required this.expanded,
    required this.onToggle,
    required this.candidates,
    required this.onOpenCandidateTap,
    required this.onOpenFullList,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final List<RakutenManagedProduct> candidates;
  final void Function(String productId) onOpenCandidateTap;
  final VoidCallback onOpenFullList;

  static const Duration _animDuration = Duration(milliseconds: 280);
  static const Curve _animCurve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _HomeUi.recentCandidatesSectionDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              splashColor: AppColors.accentPrimary.withValues(alpha: 0.09),
              highlightColor: AppColors.accentPrimary.withValues(alpha: 0.05),
              child: Padding(
                padding: _HomeUi.paddingSectionHeader,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.bookmark_added_outlined,
                        size: 22,
                        color: AppColors.accentPrimary.withValues(alpha: 0.9),
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
                          SizedBox(height: _HomeUi.gapHeaderTitleToLead),
                          Text(
                            '直近5件まで。行タップで一覧の該当へ。コレ済で消えます。',
                            style: _HomeUi.sectionHeaderLead(context),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: _animDuration,
            curve: _animCurve,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: EdgeInsets.only(
                      left: _HomeUi.insetSectionH,
                      right: _HomeUi.insetSectionH,
                      bottom: _HomeUi.gapRecentDetailBottom,
                    ),
                    child: Text(
                      '直近の候補を最大5件表示。コレ済にすると消えます。行タップでコレ一覧の該当商品へ移動します。',
                      style: _HomeUi.sectionBody(context),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          _HomeUi.sectionDivider(),
          SizedBox(height: _HomeUi.gapRecentDividerToDeck),
          Padding(
            padding: _HomeUi.paddingDeckOuter,
            child: DecoratedBox(
              decoration: _HomeUi.roomTileDeckDecoration(),
              child: Padding(
                padding: const EdgeInsets.all(_HomeUi.paddingRecentListDeck),
                child: _RecentCandidatesPanel(
                  embedInUnifiedSection: true,
                  candidates: candidates,
                  onOpenCandidateTap: onOpenCandidateTap,
                ),
              ),
            ),
          ),
          _HomeCollectionListLink(
            embeddedInSection: true,
            onPressed: onOpenFullList,
          ),
          SizedBox(height: _HomeUi.paddingRecentSectionBottom),
        ],
      ),
    );
  }
}

class _AboutAppExpandedBody extends StatelessWidget {
  const _AboutAppExpandedBody({required this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '検索 → 候補 → コレ',
          style: _HomeUi.sectionCollapsedSummary(context),
        ),
        const SizedBox(height: _HomeUi.gapTitleToSummary),
        if (displayName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: _HomeUi.gapTight),
            child: Text(
              '$displayNameさん、まずは検索から',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    fontSize: 13,
                  ),
            ),
          ),
        const _FlowStepLine(
          number: '1',
          title: '商品を探す',
          subtitle: '「楽天で検索」から。',
        ),
        const SizedBox(height: 6),
        const _FlowStepLine(
          number: '2',
          title: '候補に追加',
          subtitle: '検索結果から候補登録。',
        ),
        const SizedBox(height: 6),
        const _FlowStepLine(
          number: '3',
          title: 'ROOMでコレ',
          subtitle: 'コレ一覧のURLからROOMでコレ。',
        ),
      ],
    );
  }
}

class _FlowStepLine extends StatelessWidget {
  const _FlowStepLine({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            number,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        SizedBox(width: _HomeUi.gapIconToTitle),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.22,
                      fontSize: 14,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: _HomeUi.sectionBody(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 下部のサブ導線：コレ一覧（ROOMコレタブと補完）。
class _HomeCollectionListLink extends StatelessWidget {
  const _HomeCollectionListLink({
    required this.onPressed,
    this.embeddedInSection = false,
  });

  final VoidCallback onPressed;

  /// true のときはセクション末尾のサブアクション（主要CTAと競合しない薄めの見た目）
  final bool embeddedInSection;

  @override
  Widget build(BuildContext context) {
    if (embeddedInSection) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          splashColor: AppColors.textPrimary.withValues(alpha: 0.06),
          highlightColor: AppColors.textPrimary.withValues(alpha: 0.03),
          child: Container(
            width: double.infinity,
            padding: _HomeUi.paddingSectionFooterAction,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: _HomeUi.dividerLineColor(),
                ),
              ),
              color: Color.alphaBlend(
                AppColors.surfaceVariant.withValues(alpha: 0.32),
                AppColors.surface,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.playlist_add_check_outlined,
                    size: 22,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(width: _HomeUi.gapIconToTitle),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'コレ一覧を開く',
                        style: _HomeUi.sectionFooterActionTitle(context),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '候補とコレ済の全体を表示',
                        style: _HomeUi.tapHint(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary.withValues(alpha: 0.9),
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
        icon: Icon(
          Icons.collections_bookmark_outlined,
          size: 20,
          color: AppColors.accentPrimary,
        ),
        label: Text(
          'コレ一覧を開く',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.accentPrimary,
            height: 1.25,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.95),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(double.infinity, 50),
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
  });

  final int totalCount;
  final int pendingCount;
  final bool isCompleted;
  final bool isLoading;
  final String? dateLabel;
  final String? errorMessage;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final maxN = _HomeUi.todayRecommendationsMaxPerDay;
    final done = isCompleted && totalCount > 0;
    final deco = done
        ? _HomeUi.todayRecommendationsSectionDecorationCompleted()
        : _HomeUi.todayRecommendationsSectionDecorationActive();

    final titleStyle = _HomeUi.sectionTitle(context).copyWith(
      color: done ? AppColors.textSecondary : AppColors.textPrimary,
    );

    late final String statusLine;
    late final String footnote;
    if (isLoading && totalCount == 0) {
      statusLine = '今日の提案を用意しています…';
      footnote =
          '1日あたり最大$maxN件まで。日付が変わると、新しいセットに切り替わります。';
    } else if (errorMessage != null &&
        errorMessage!.isNotEmpty &&
        totalCount == 0) {
      statusLine = 'いま一度お試しください';
      footnote =
          'タップで再試行できます。1日あたり最大$maxN件まで提案します（日付が変わると更新）。';
    } else if (totalCount == 0) {
      statusLine = 'タップして、今日のおすすめを最大$maxN件まで用意できます';
      footnote =
          '毎日替わる提案です。ここでの内容は本日中だけ有効で、最大$maxN件です。';
    } else if (done) {
      statusLine = '本日のおすすめはすべて完了しました';
      footnote =
          '今日の分はここまでです。日付が変わると、また最大$maxN件まで新しくなります。';
    } else {
      statusLine =
          '残り $pendingCount 件 · 本日は最大$maxN件まで';
      footnote = '未処理の提案だけがカウントされます。今日だけのセットです。';
    }

    final progress = totalCount > 0 && !done
        ? (totalCount - pendingCount) / totalCount
        : 0.0;

    IconData leadingIcon;
    Color leadingColor;
    if (done) {
      leadingIcon = Icons.check_circle_outline_rounded;
      leadingColor = const Color(0xFF2E7D32).withValues(alpha: 0.75);
    } else if (isLoading && totalCount == 0) {
      leadingIcon = Icons.auto_awesome_outlined;
      leadingColor = AppColors.accentPrimary.withValues(alpha: 0.55);
    } else {
      leadingIcon = Icons.auto_awesome_outlined;
      leadingColor = AppColors.accentPrimary.withValues(alpha: 0.88);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(_HomeUi.radiusSectionOuter),
        splashColor: AppColors.textPrimary.withValues(
          alpha: done ? 0.05 : 0.08,
        ),
        highlightColor: AppColors.textPrimary.withValues(
          alpha: done ? 0.03 : 0.04,
        ),
        child: Opacity(
          opacity: done ? 0.96 : 1,
          child: Container(
            width: double.infinity,
            padding: _HomeUi.paddingDenseCard,
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
                            color: AppColors.accentPrimary.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        )
                      : Icon(
                          leadingIcon,
                          size: 22,
                          color: leadingColor,
                        ),
                ),
                SizedBox(width: _HomeUi.gapIconToTitle),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今日のおすすめコレ候補',
                        style: titleStyle,
                      ),
                      if (dateLabel != null && dateLabel!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${dateLabel!}の提案（日替わり）',
                          style: _HomeUi.tapHint(context),
                        ),
                      ],
                      SizedBox(height: _HomeUi.gapTodayRecTitleToStatus),
                      Text(
                        statusLine,
                        style: _HomeUi.sectionBody(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: done
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (errorMessage != null &&
                          errorMessage!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          errorMessage!.trim(),
                          style: _HomeUi.sectionBody(context).copyWith(
                            color: AppColors.error.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      SizedBox(height: _HomeUi.gapTodayRecStatusToFootnote),
                      Text(
                        footnote,
                        style: _HomeUi.tapHint(context),
                      ),
                      if (totalCount > 0 && !done && !isLoading) ...[
                        SizedBox(height: _HomeUi.gapTodayRecBeforeProgress),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor:
                                AppColors.divider.withValues(alpha: 0.45),
                            color: AppColors.accentPrimary.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary.withValues(
                      alpha: done ? 0.5 : 0.85,
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
    final lastPrimary = lastDoneAt == null ? '—' : _formatDateTime(lastDoneAt!);
    final g = unifiedRoomSection ? _HomeUi.gapRoomGrid : _HomeUi.gapTight + 2;
    final deck = unifiedRoomSection;

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RoomMetricTile(
                  title: 'コレ候補',
                  valueMain: '$candidateTotal件',
                  caption: 'タップで一覧を開く',
                  icon: Icons.bookmark_outline_rounded,
                  accent: const Color(0xFF1565C0),
                  iconBackground: const Color(0xFFE3F2FD),
                  valueProminent: true,
                  compactDeck: deck,
                  onTap: onCandidateTap,
                ),
              ),
              SizedBox(width: g),
              Expanded(
                child: _RoomMetricTile(
                  title: 'コレ済',
                  valueMain: '$doneTotal件',
                  caption: 'タップで一覧を開く',
                  icon: Icons.task_alt_rounded,
                  accent: const Color(0xFF2E7D32),
                  iconBackground: const Color(0xFFE8F5E9),
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
                  title: '今日のコレ',
                  valueMain: '$todayDoneCount件',
                  caption: 'タップで一覧を開く',
                  icon: Icons.today_rounded,
                  accent: AppColors.accentPrimary,
                  iconBackground: AppColors.accentLightest,
                  valueProminent: true,
                  compactDeck: deck,
                  onTap: onTodayTap,
                ),
              ),
              SizedBox(width: g),
              Expanded(
                child: _RoomMetricTile(
                  title: '前回コレ日時',
                  valueMain: lastPrimary,
                  caption: 'タップで活動を開く',
                  icon: Icons.history_rounded,
                  accent: const Color(0xFF5C6BC0),
                  iconBackground: const Color(0xFFE8EAF6),
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

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _RoomMetricTile extends StatelessWidget {
  const _RoomMetricTile({
    required this.title,
    required this.valueMain,
    required this.caption,
    required this.icon,
    required this.accent,
    required this.iconBackground,
    required this.valueProminent,
    this.compactDeck = false,
    required this.onTap,
  });

  final String title;
  final String valueMain;
  final String caption;
  final IconData icon;
  final Color accent;
  final Color iconBackground;
  final bool valueProminent;
  /// ROOM セクション内デッキ用：角丸・余白・キャプション行を揃える
  final bool compactDeck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = compactDeck ? 12.0 : AppDimensions.radiusCard;
    final pad = compactDeck
        ? const EdgeInsets.symmetric(horizontal: 9, vertical: 9)
        : const EdgeInsets.fromLTRB(11, 9, 11, 9);
    final titleSize = compactDeck ? 12.5 : 13.0;
    final valueLarge = compactDeck ? 24.0 : 25.0;
    final valueSmall = compactDeck ? 15.5 : 16.0;
    final captionMaxLines = compactDeck ? 1 : 2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: AppColors.textPrimary.withValues(alpha: 0.07),
        child: Container(
          padding: pad,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: AppColors.divider.withValues(alpha: 0.88),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accent, size: 16),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                            fontSize: titleSize,
                          ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compactDeck ? 6 : 7),
              Text(
                valueMain,
                textAlign: TextAlign.left,
                maxLines: valueProminent ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: valueProminent
                    ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.06,
                          fontSize: valueLarge,
                          letterSpacing: -0.45,
                        )
                    : Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.14,
                          fontSize: valueSmall,
                        ),
              ),
              SizedBox(height: compactDeck ? 3 : 4),
              Text(
                caption,
                maxLines: captionMaxLines,
                overflow: TextOverflow.ellipsis,
                style: _HomeUi.tapHint(context),
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
    required this.candidates,
    required this.onOpenCandidateTap,
  });

  /// [_RecentCandidatesHomeSection] 内では外枠なし（親デッキが枠を持つ）
  final bool embedInUnifiedSection;

  final List<RakutenManagedProduct> candidates;
  final void Function(String productId) onOpenCandidateTap;

  @override
  Widget build(BuildContext context) {
    final tilePadding = embedInUnifiedSection
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 9);

    if (candidates.isEmpty) {
      return Padding(
        padding: embedInUnifiedSection
            ? const EdgeInsets.symmetric(vertical: 4, horizontal: 2)
            : const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '候補はまだありません',
              style: _HomeUi.bodyEmphasis(context),
            ),
            const SizedBox(height: _HomeUi.gapTight),
            Text(
              'まずは「楽天で検索」から追加してください。',
              style: _HomeUi.sectionBody(context),
            ),
          ],
        ),
      );
    }

    final list = Column(
      children: [
        for (int i = 0; i < candidates.length; i++) ...[
          _RecentCandidateTile(
            product: candidates[i],
            contentPadding: tilePadding,
            onTap: () => onOpenCandidateTap(candidates[i].productId),
          ),
          if (i < candidates.length - 1)
            Divider(
              height: 1,
              thickness: 1,
              indent: embedInUnifiedSection ? 76 : 72,
              endIndent: embedInUnifiedSection ? 12 : 12,
              color: AppColors.divider.withValues(
                alpha: embedInUnifiedSection ? 0.5 : 0.55,
              ),
            ),
        ],
      ],
    );

    if (embedInUnifiedSection) {
      return list;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.88),
        ),
      ),
      child: list,
    );
  }
}

class _RecentCandidateTile extends StatelessWidget {
  const _RecentCandidateTile({
    required this.product,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    required this.onTap,
  });

  final RakutenManagedProduct product;
  final EdgeInsetsGeometry contentPadding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.textPrimary.withValues(alpha: 0.06),
        highlightColor: AppColors.textPrimary.withValues(alpha: 0.03),
        child: Padding(
          padding: contentPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(),
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
                    const SizedBox(height: 3),
                    Text(
                      product.shopName.isEmpty ? 'ショップ名なし' : product.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _HomeUi.sectionBody(context),
                    ),
                    const SizedBox(height: 3),
                    _ExtractionChip(status: product.extractionStatus),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary.withValues(alpha: 0.9),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        color: const Color(0xFFE3F2FD),
        child: product.imageUrl.isNotEmpty
            ? Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.image_outlined,
                  size: 22,
                  color: AppColors.textTertiary,
                ),
              )
            : const Icon(
                Icons.image_outlined,
                size: 22,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
