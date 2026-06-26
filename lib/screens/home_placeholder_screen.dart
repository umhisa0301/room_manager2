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
import 'room_type_diagnosis_screen.dart';
import '../services/rakuten_room_home_stats.dart';
import '../services/room_collect_post_limit.dart';
import '../services/room_import_collects_policy.dart';
import '../services/room_import_limit.dart';
import '../services/room_import_limit_policy.dart';
import '../services/room_kpi_calculator.dart';
import '../utils/home_post_milestone.dart';
import '../widgets/home_goal_milestone_progress.dart';
import '../models/room_activity_event.dart';
import '../state/room_activity_event_provider.dart';
import '../utils/room_reaction_status_display.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/bulk_operation_state_controller.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../state/room_recommendation_profile_provider.dart';
import '../state/user_profile_provider.dart';
import '../data/room_type_definitions.dart';
import '../widgets/room_type_diagnosis_widgets.dart';
import '../state/room_import_controller.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/room_colle_product_list_card_layout.dart';
import '../utils/app_debug_log.dart';
import '../utils/room_reaction_analytics.dart';
import '../utils/room_sync_button_visibility.dart';
import '../utils/room_sync_card_copy.dart';
import '../utils/room_sync_log.dart';
import '../widgets/operation_confirm_dialog.dart';
import '../widgets/room_post_import_flow.dart';
import '../models/room_reaction_sync_history_entry.dart';
import '../services/room_reaction_sync_history_store.dart';
import '../widgets/home_auto_reaction_sync_coordinator.dart';
import '../services/home_in_app_notice_dismiss_store.dart';
import '../utils/home_in_app_notice.dart';
import '../widgets/monetization/monetization_ad_slot.dart';

// --- ホーム画面：レイアウト・タイポ・装飾の統一（画面ロジックとは分離）---

/// ホーム専用の余白・行間・装飾ルール。
abstract final class _HomeUi {
  const _HomeUi._();

  /// 主要ブロック同士（カード間）
  static const double gapSection = 10;

  /// 白カード内 padding
  static const EdgeInsets homeCardPadding = EdgeInsets.all(14);

  /// ホーム白カードの角丸
  static const double homeCardRadius = 16;

  /// ホーム ListView の左右
  static const double screenPaddingH = 16;

  /// ホーム ListView の上下
  static const double screenPaddingV = 8;

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
      color: Colors.black.withValues(alpha: 0.03),
      offset: const Offset(0, 1),
      blurRadius: 4,
    ),
  ];

  /// ホーム5ブロック共通の白カード装飾
  static BoxDecoration homeCardDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.homeCardFill,
      borderRadius: BorderRadius.circular(homeCardRadius),
      border: Border.all(color: HomeScreenColors.homeCardBorder),
      boxShadow: cardShadow,
    );
  }

  static TextStyle homeCardTitle(BuildContext context) {
    return sectionTitle(context).copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: HomeScreenColors.homeTextPrimary,
      letterSpacing: -0.15,
    );
  }

  static TextStyle homeCardSubtitle(BuildContext context) {
    return sectionBody(context).copyWith(
      fontSize: 14,
      color: HomeScreenColors.homeTextSecondary,
      height: 1.35,
    );
  }

  static TextStyle homeMetricLabel(BuildContext context) {
    return tapHint(context).copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: HomeScreenColors.homeTextSecondary,
    );
  }

  static TextStyle homeMetricValue(BuildContext context) {
    return bodyEmphasis(context).copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: HomeScreenColors.homeAccentTeal,
      height: 1.0,
    );
  }

  static TextStyle homeFootnote(BuildContext context) {
    return tapHint(context).copyWith(
      fontSize: 12.5,
      color: const Color(0xFF9CA3AF),
      fontWeight: FontWeight.w500,
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

/// データ更新カード内ボタンの共通スタイル（薄枠・白背景）
abstract final class _HomeDataUpdateButtonStyle {
  const _HomeDataUpdateButtonStyle._();

  static ButtonStyle outlined(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF374151),
      backgroundColor: Colors.white,
      disabledForegroundColor: const Color(0xFF9CA3AF),
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      minimumSize: const Size(double.infinity, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  static ButtonStyle reactionAccent(
    BuildContext context, {
    required bool enabled,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: HomeScreenColors.homeAccentTeal,
      backgroundColor: HomeScreenColors.homeAccentTealLight,
      disabledForegroundColor: HomeScreenColors.homeAccentTeal.withValues(
        alpha: 0.55,
      ),
      disabledBackgroundColor: HomeScreenColors.homeAccentTealLight,
      side: BorderSide(
        color: enabled
            ? HomeScreenColors.homeAccentTealBorder
            : HomeScreenColors.homeAccentTeal.withValues(alpha: 0.45),
      ),
      minimumSize: const Size(double.infinity, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    );
  }

  static ButtonStyle tealOutlined(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: HomeScreenColors.homeAccentTeal,
      backgroundColor: Colors.white,
      disabledForegroundColor: const Color(0xFF9CA3AF),
      side: const BorderSide(color: HomeScreenColors.homeAccentTealBorder),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  static ButtonStyle dataUpdateOutlined(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: HomeScreenColors.homeAccentTeal,
      backgroundColor: Colors.white,
      disabledForegroundColor: const Color(0xFF9CA3AF),
      side: const BorderSide(color: HomeScreenColors.homeCardBorder),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  /// 反応チェック見出し行の閲覧導線（コンパクト Pill）
  static ButtonStyle reactionViewPill(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: HomeScreenColors.homeAccentTeal,
      backgroundColor: Colors.white,
      side: const BorderSide(color: HomeScreenColors.homeAccentTealBorder),
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
  int _reactionNoticeRefreshNonce = 0;
  bool _isHomeRefreshing = false;
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
        'todayRoomStatusWithGoal,todayRoomWork,recentReactedProducts,dataUpdate',
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
        recommendationProfile:
            context.read<RoomRecommendationProfileProvider>().profile,
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
      recommendationProfile:
          context.read<RoomRecommendationProfileProvider>().profile,
      trigger: 'refresh',
    );
    _guard('skipReason=refreshDoesNotForceRegenerate');
  }

  Future<void> _handleHomeLatestRefresh(BuildContext context) async {
    if (_isHomeRefreshing) return;
    setState(() => _isHomeRefreshing = true);
    var hadError = false;
    try {
      await _refreshHome();
      if (!mounted) return;
      setState(() => _reactionNoticeRefreshNonce++);
      // TODO: 確認ダイアログなしで投稿取り込み＋反応確認を連続実行する場合はここに追加
    } catch (_) {
      hadError = true;
    } finally {
      if (mounted) setState(() => _isHomeRefreshing = false);
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          hadError ? '一部の情報を更新できませんでした。時間をおいて再試行してください。' : '最新の状態に更新しました',
        ),
      ),
    );
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

  Future<void> _openRoomTypeDiagnosis(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const RoomTypeDiagnosisScreen(),
      ),
    );
  }

  Future<void> _openTodayRecommendations(BuildContext context) async {
    final recProfile = context.read<RoomRecommendationProfileProvider>();
    if (!recProfile.isDiagnosed && !recProfile.isDiagnosisPromptSkipped) {
      final startDiagnosis = await RoomTypeDiagnosisPromptSheet.show(context);
      if (!context.mounted) return;
      if (startDiagnosis == true) {
        await _openRoomTypeDiagnosis(context);
        if (!context.mounted) return;
      } else if (startDiagnosis == false) {
        await recProfile.markDiagnosisPromptSkipped();
      }
    }
    final recommender = context.read<TodayRecommendationProvider>();
    final roomProvider = context.read<RakutenManagedProductProvider>();
    _trace('trigger=cta');
    _trigger('cta');
    _trace('action=ensureToday');
    await recommender.ensureToday(
      profile: context.read<UserProfileProvider>().profile,
      managedItems: roomProvider.items,
      savedShops: context.read<SavedShopProvider>().shops,
      recommendationProfile: recProfile.profile,
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
      recommendationProfile:
          context.read<RoomRecommendationProfileProvider>().profile,
      trigger: trigger,
      manual: force,
    );
  }

  void _trace(String message) {
    if (!mounted) return;
    roomAuditLog('[RECOMMEND_TRACE] $message');
  }

  void _trigger(String source) {
    if (!mounted) return;
    roomAuditLog('[RECOMMEND_TRIGGER] source=$source');
  }

  void _guard(String reason) {
    if (!mounted) return;
    roomAuditLog('[RECOMMEND_GUARD] $reason');
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
                    final now = DateTime.now();
                    final collectLimit = RoomCollectPostLimitSnapshot.compute(
                      items: items,
                      events: actProvider.events,
                      now: now,
                    );
                    final recentReactedProducts = _homeRecentReactedProducts(
                      items,
                    );
                    final bottomInset = MediaQuery.paddingOf(context).bottom;
                    const navBarReserve = 52.0;
                    final todayLocalDay = DateTime(
                      now.year,
                      now.month,
                      now.day,
                    );

                    final milestonePostCount =
                        RakutenRoomHomeStats.countDoneOnLocalCalendarDay(
                          items,
                          todayLocalDay,
                        );
                    final profileRoomUrl = userProfileProvider.profile.roomUrl
                        .trim();
                    final recProfileProvider =
                        context.watch<RoomRecommendationProfileProvider>();
                    final roomImportedDoneCount = items
                        .where(
                          (e) =>
                              e.status == RakutenManagedProductStatus.done &&
                              e.roomUrl.trim().isNotEmpty,
                        )
                        .length;

                    final todayCandidateAddedCount = _countTodayCandidateAdded(
                      actProvider.events,
                      todayLocalDay,
                    );
                    final todayRoomPostCount = milestonePostCount;
                    final unconfirmedReactionCount = _countUnconfirmedReactions(
                      items,
                    );

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
                              HomeAutoReactionSyncCoordinator(
                                onSyncCompleted: () => setState(
                                  () => _reactionNoticeRefreshNonce++,
                                ),
                              ),
                              _HomeMomentumHeader(
                                displayName: displayName,
                                milestonePostCount: milestonePostCount,
                                recPendingCount: recProvider.pendingCount,
                                recTotalCount: recProvider.totalCount,
                                recIsLoading:
                                    recProvider.isLoading ||
                                    recProvider.generationStatus ==
                                        TodayRecommendationGenerationStatus
                                            .loading,
                                unconfirmedReactionCount:
                                    unconfirmedReactionCount,
                                reactionHistoryRefreshNonce:
                                    _reactionNoticeRefreshNonce,
                              ),
                              SizedBox(height: _HomeUi.gapSection),
                              _TodayRoomWorkCard(
                                todayCandidateAddedCount:
                                    todayCandidateAddedCount,
                                todayRoomPostCount: todayRoomPostCount,
                                pendingCandidateCount: nCandidate,
                                isRecommendationLoading:
                                    recProvider.isLoading ||
                                    recProvider.generationStatus ==
                                        TodayRecommendationGenerationStatus
                                            .loading,
                                roomTypeHint: recProfileProvider.isDiagnosed
                                    ? '${RoomTypeDefinitions.displayNameFor(recProfileProvider.profile!.primaryTypeId)}に合わせて提案'
                                    : null,
                                onOpenRecommendations: () =>
                                    _openTodayRecommendations(context),
                                onOpenPendingCandidates: () =>
                                    _openRoomList(context, initialTabIndex: 0),
                                onOpenSearch: () {
                                  _trace('trigger=cta');
                                  _trace('action=openSearch');
                                  openRakutenSearchScreen(context);
                                },
                              ),
                              SizedBox(height: _HomeUi.gapSection),
                              _TodayRoomStatusCard(
                                todayCandidateAddedCount:
                                    todayCandidateAddedCount,
                                todayRoomPostCount: todayRoomPostCount,
                                pendingCandidateCount: nCandidate,
                                collectLimit: collectLimit,
                              ),
                              SizedBox(height: _HomeUi.gapSection),
                              _ReactionCheckCard(
                                products: recentReactedProducts,
                                unconfirmedReactionCount:
                                    unconfirmedReactionCount,
                                hasRoomProfileUrl: profileRoomUrl.isNotEmpty,
                                onOpenProductTap: (_) =>
                                    _openRoomList(context, initialTabIndex: 1),
                                onOpenReactionList: () {
                                  context
                                      .read<AppShellController>()
                                      .openActivityTab(
                                        subTabIndex: 1,
                                        scrollToRoomReactionSection: true,
                                      );
                                },
                                onOpenRoomUrl: () =>
                                    _openRoomUrlEditSheet(context),
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
                              _DataUpdateCard(
                                hasRoomProfileUrl: profileRoomUrl.isNotEmpty,
                                importedDoneCount: roomImportedDoneCount,
                                unconfirmedReactionCount:
                                    unconfirmedReactionCount,
                                reactionHistoryRefreshNonce:
                                    _reactionNoticeRefreshNonce,
                                onOpenRoomUrl: () =>
                                    _openRoomUrlEditSheet(context),
                                onReactionSyncCompleted: () => setState(
                                  () => _reactionNoticeRefreshNonce++,
                                ),
                              ),
                              SizedBox(height: _HomeUi.gapSection),
                              const MonetizationAdSlot(
                                placement:
                                    MonetizationAdPlacement.homeBottomBanner,
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

String _formatSyncHistoryTimeShort(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$h:$min';
  } catch (_) {
    return '未確認';
  }
}

int _countTodayCandidateAdded(
  List<RoomActivityEvent> events,
  DateTime todayLocalDay,
) {
  final tomorrow = todayLocalDay.add(const Duration(days: 1));
  return events
      .where(
        (e) =>
            e.type == RoomActivityEventType.candidateAdded &&
            !e.createdAt.isBefore(todayLocalDay) &&
            e.createdAt.isBefore(tomorrow),
      )
      .length;
}

int _countUnconfirmedReactions(List<RakutenManagedProduct> items) {
  var n = 0;
  for (final e in items) {
    if (RoomReactionStatusDisplay.chipLabelForProduct(e) == '未確認') {
      n++;
    }
  }
  return n;
}

String _homeGoalMessage(int postCount) {
  if (postCount >= 20) return '今日の投稿目標を達成しました';
  if (postCount >= 10) return '余裕があれば20件に挑戦しましょう';
  if (postCount >= 5) return '次は10件投稿を目指しましょう';
  if (postCount >= 1) return '次は5件投稿を目指しましょう';
  return 'まずは1件投稿しましょう';
}

String _homeGoalPostedCountLabel(int postCount) => '$postCount件 投稿済み';

String _homeGoalRemainingLabel(int postCount) =>
    HomePostMilestoneSnapshot.remainingProgressLabel(postCount);

List<RakutenManagedProduct> _homeRecentReactedProducts(
  List<RakutenManagedProduct> items,
) {
  final reacted =
      roomReactionAnalyticsEligibleItems(
        items,
      ).where(roomReactionAnalyticsHasReaction).toList()..sort(
        (a, b) => roomReactionAnalyticsReactionScore(
          b,
        ).compareTo(roomReactionAnalyticsReactionScore(a)),
      );
  return reacted.take(2).toList(growable: false);
}

String _homeReactionSummary(RakutenManagedProduct product) {
  final like = product.roomLikeCount ?? 0;
  final comment = product.roomCommentCount ?? 0;
  final parts = <String>[];
  if (like > 0) parts.add('いいね$like');
  if (comment > 0) parts.add('コメント$comment');
  if (parts.isEmpty) return '反応あり';
  return parts.join(' · ');
}

/// 1. 今日の状況（今日の目標・投稿上限を統合）
class _TodayRoomStatusCard extends StatelessWidget {
  const _TodayRoomStatusCard({
    required this.todayCandidateAddedCount,
    required this.todayRoomPostCount,
    required this.pendingCandidateCount,
    required this.collectLimit,
  });

  final int todayCandidateAddedCount;
  final int todayRoomPostCount;
  final int pendingCandidateCount;
  final RoomCollectPostLimitSnapshot collectLimit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _HomeUi.homeCardDecoration(),
      padding: _HomeUi.homeCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('今日の状況', style: _HomeUi.homeCardTitle(context)),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _HomeStatusMetricColumn(
                    icon: Icons.post_add_outlined,
                    label: '候補追加',
                    count: todayCandidateAddedCount,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: HomeScreenColors.homeCardBorder,
                ),
                Expanded(
                  child: _HomeStatusMetricColumn(
                    icon: Icons.hourglass_empty_outlined,
                    label: '投稿待ち',
                    count: pendingCandidateCount,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: HomeScreenColors.homeCardBorder,
                ),
                Expanded(
                  child: _HomeStatusMetricColumn(
                    icon: Icons.upload_outlined,
                    label: '投稿',
                    count: todayRoomPostCount,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: HomeScreenColors.homeCardBorder),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '今日の目標',
                  style: _HomeUi.bodyEmphasis(context).copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HomeScreenColors.homeTextPrimary,
                  ),
                ),
              ),
              Text(
                _homeGoalPostedCountLabel(todayRoomPostCount),
                textAlign: TextAlign.right,
                style: _HomeUi.bodyEmphasis(context).copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: HomeScreenColors.homeTextSecondary,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _homeGoalRemainingLabel(todayRoomPostCount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _HomeUi.bodyEmphasis(context).copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: HomeScreenColors.homeTextPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          HomeGoalMilestoneProgress(postCount: todayRoomPostCount),
          const SizedBox(height: 6),
          _HomePostLimitSection(collectLimit: collectLimit),
        ],
      ),
    );
  }
}

class _HomeStatusMetricColumn extends StatelessWidget {
  const _HomeStatusMetricColumn({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: HomeScreenColors.homeMutedText),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _HomeUi.homeMetricLabel(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _HomeMetricCountText(count: count),
        ],
      ),
    );
  }
}

class _HomePostLimitSection extends StatefulWidget {
  const _HomePostLimitSection({required this.collectLimit});

  final RoomCollectPostLimitSnapshot collectLimit;

  @override
  State<_HomePostLimitSection> createState() => _HomePostLimitSectionState();
}

class _HomePostLimitSectionState extends State<_HomePostLimitSection> {
  bool _expanded = false;

  Color _barColor(RoomCollectPostLimitBarState state) {
    switch (state) {
      case RoomCollectPostLimitBarState.reached:
        return AppColors.error;
      case RoomCollectPostLimitBarState.warning:
        return HomeScreenColors.homeWarning;
      case RoomCollectPostLimitBarState.normal:
        return HomeScreenColors.homeAccentTeal.withValues(alpha: 0.45);
    }
  }

  Color _summaryColor() {
    final limit = widget.collectLimit;
    if (limit.isAnyLimitReached) return AppColors.error;
    if (limit.isDailyWarning || limit.isHourlyWarning) {
      return HomeScreenColors.homeWarning;
    }
    return HomeScreenColors.homeLimitRowText;
  }

  @override
  Widget build(BuildContext context) {
    final limit = widget.collectLimit;
    final summaryColor = _summaryColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'home_post_limit_toggle',
          button: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '投稿上限　24時間の残り ${limit.dailyRemaining}件',
                        style: _HomeUi.tapHint(context).copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: summaryColor,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: summaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          _HomeLimitDetailRow(
            label: '直近1時間',
            used: limit.hourCount,
            max: RoomCollectPostLimitSnapshot.hourlyLimit,
            barState: limit.hourlyBarState,
            barColor: _barColor(limit.hourlyBarState),
          ),
          const SizedBox(height: 6),
          _HomeLimitDetailRow(
            label: '直近24時間',
            used: limit.todayCount,
            max: RoomCollectPostLimitSnapshot.dailyLimit,
            barState: limit.dailyBarState,
            barColor: _barColor(limit.dailyBarState),
          ),
        ],
      ],
    );
  }
}

class _HomeLimitDetailRow extends StatelessWidget {
  const _HomeLimitDetailRow({
    required this.label,
    required this.used,
    required this.max,
    required this.barState,
    required this.barColor,
  });

  final String label;
  final int used;
  final int max;
  final RoomCollectPostLimitBarState barState;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (used / max).clamp(0.0, 1.0);
    final percentLabel = '${(ratio * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label  $used / $max件',
                style: _HomeUi.tapHint(context).copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: HomeScreenColors.homeLimitRowText,
                ),
              ),
            ),
            Text(
              percentLabel,
              style: _HomeUi.tapHint(context).copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: HomeScreenColors.homeMutedText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 3,
            value: ratio,
            backgroundColor: HomeScreenColors.progressTrack,
            color: barColor,
          ),
        ),
      ],
    );
  }
}

class _HomeRefreshPillButton extends StatelessWidget {
  const _HomeRefreshPillButton({
    required this.isRefreshing,
    required this.onPressed,
  });

  final bool isRefreshing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRefreshing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: Color(0xFF374151),
                  ),
                const SizedBox(width: 5),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = MediaQuery.sizeOf(context).width < 380;
                    return Text(
                      isRefreshing
                          ? '読込中...'
                          : (compact ? '再読み込み' : '状況を再読み込み'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _HomeUi.tapHint(context).copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF374151),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeStatusMiniCard extends StatelessWidget {
  const _HomeStatusMiniCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.footnote,
    required this.backgroundColor,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final int count;
  final String footnote;
  final Color backgroundColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _HomeUi.homeMetricLabel(context).copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          _HomeMetricCountText(count: count),
          Text(
            footnote,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _HomeUi.homeFootnote(context).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _HomeMetricCountText extends StatelessWidget {
  const _HomeMetricCountText({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$count',
            style: _HomeUi.homeMetricValue(
              context,
            ).copyWith(fontSize: 28, fontWeight: FontWeight.w800, height: 1.0),
          ),
          TextSpan(
            text: '件',
            style: _HomeUi.homeMetricValue(
              context,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w700, height: 1.0),
          ),
        ],
      ),
    );
  }
}

/// 2. 今日やること
enum _HomeWorkPrimaryAction { recommendations, roomPost, searchMore }

class _TodayRoomWorkCard extends StatelessWidget {
  const _TodayRoomWorkCard({
    required this.todayCandidateAddedCount,
    required this.todayRoomPostCount,
    required this.pendingCandidateCount,
    required this.isRecommendationLoading,
    this.roomTypeHint,
    required this.onOpenRecommendations,
    required this.onOpenPendingCandidates,
    required this.onOpenSearch,
  });

  final int todayCandidateAddedCount;
  final int todayRoomPostCount;
  final int pendingCandidateCount;
  final bool isRecommendationLoading;
  final String? roomTypeHint;
  final VoidCallback onOpenRecommendations;
  final VoidCallback onOpenPendingCandidates;
  final VoidCallback onOpenSearch;

  _HomeWorkStepVisualState _stateForStep(int step) {
    final step1Complete = todayCandidateAddedCount > 0;
    final step2Complete = pendingCandidateCount == 0;

    int? nextStep;
    if (!step1Complete) {
      nextStep = 1;
    } else if (pendingCandidateCount > 0) {
      nextStep = 2;
    } else {
      nextStep = 3;
    }

    switch (step) {
      case 1:
        if (step1Complete) return _HomeWorkStepVisualState.completed;
        if (nextStep == 1) return _HomeWorkStepVisualState.next;
        return _HomeWorkStepVisualState.optional;
      case 2:
        if (step2Complete && todayRoomPostCount > 0) {
          return _HomeWorkStepVisualState.completed;
        }
        if (nextStep == 2) return _HomeWorkStepVisualState.next;
        if (pendingCandidateCount > 0 && todayRoomPostCount > 0) {
          return _HomeWorkStepVisualState.remaining;
        }
        return _HomeWorkStepVisualState.optional;
      case 3:
        if (nextStep == 3) return _HomeWorkStepVisualState.next;
        return _HomeWorkStepVisualState.optional;
      default:
        return _HomeWorkStepVisualState.optional;
    }
  }

  _HomeWorkPrimaryAction _primaryAction() {
    if (todayCandidateAddedCount == 0) {
      return _HomeWorkPrimaryAction.recommendations;
    }
    if (pendingCandidateCount > 0) {
      return _HomeWorkPrimaryAction.roomPost;
    }
    return _HomeWorkPrimaryAction.searchMore;
  }

  ({
    String title,
    String subtitle,
    String buttonLabel,
    VoidCallback? onTap,
    String semanticsLabel,
  })
  _primaryCtaSpec() {
    switch (_primaryAction()) {
      case _HomeWorkPrimaryAction.recommendations:
        return (
          title: '今日の候補を確認',
          subtitle: 'おすすめコレをチェックしましょう',
          buttonLabel: 'おすすめコレ',
          onTap: isRecommendationLoading ? null : onOpenRecommendations,
          semanticsLabel: 'home_recommendation_button',
        );
      case _HomeWorkPrimaryAction.roomPost:
        return (
          title: '候補を投稿',
          subtitle: pendingCandidateCount == 0
              ? '投稿待ちの候補はありません'
              : 'コレ候補$pendingCandidateCount件',
          buttonLabel: '投稿する',
          onTap: onOpenPendingCandidates,
          semanticsLabel: 'home_room_post_button',
        );
      case _HomeWorkPrimaryAction.searchMore:
        return (
          title: '候補を増やす',
          subtitle: '商品を検索して追加できます',
          buttonLabel: '探す',
          onTap: onOpenSearch,
          semanticsLabel: 'home_search_more_button',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _HomeUi.homeCardDecoration(),
      padding: _HomeUi.homeCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('今日やること', style: _HomeUi.homeCardTitle(context)),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final cta = _primaryCtaSpec();
              return Container(
                constraints: const BoxConstraints(minHeight: 82),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HomeScreenColors.homeAccentTealLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: HomeScreenColors.homeAccentTealBorder.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: HomeScreenColors.homeAccentTeal,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '次にやる',
                                  style: _HomeUi.tapHint(context).copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cta.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _HomeUi.bodyEmphasis(context).copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: HomeScreenColors.homeTextPrimary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                cta.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _HomeUi.homeCardSubtitle(
                                  context,
                                ).copyWith(fontSize: 13, height: 1.25),
                              ),
                              if (roomTypeHint != null &&
                                  _primaryAction() ==
                                      _HomeWorkPrimaryAction.recommendations) ...[
                                const SizedBox(height: 2),
                                Text(
                                  roomTypeHint!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _HomeUi.homeCardSubtitle(context)
                                      .copyWith(
                                    fontSize: 12,
                                    color: HomeScreenColors.homeAccentTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          label: cta.semanticsLabel,
                          button: true,
                          child: FilledButton(
                            onPressed: cta.onTap,
                            style: FilledButton.styleFrom(
                              backgroundColor: HomeScreenColors.homeAccentTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              minimumSize: const Size(96, 44),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                            child: Text(
                              cta.buttonLabel,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isRecommendationLoading &&
                        _primaryAction() ==
                            _HomeWorkPrimaryAction.recommendations) ...[
                      const SizedBox(height: 4),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _HomeWorkFlowRow(
            step1State: _stateForStep(1),
            step2State: _stateForStep(2),
            step3State: _stateForStep(3),
            onOpenRecommendations: onOpenRecommendations,
            onOpenPendingCandidates: onOpenPendingCandidates,
            onOpenSearch: onOpenSearch,
            isRecommendationLoading: isRecommendationLoading,
          ),
        ],
      ),
    );
  }
}

class _HomeWorkFlowRow extends StatelessWidget {
  const _HomeWorkFlowRow({
    required this.step1State,
    required this.step2State,
    required this.step3State,
    required this.onOpenRecommendations,
    required this.onOpenPendingCandidates,
    required this.onOpenSearch,
    required this.isRecommendationLoading,
  });

  final _HomeWorkStepVisualState step1State;
  final _HomeWorkStepVisualState step2State;
  final _HomeWorkStepVisualState step3State;
  final VoidCallback onOpenRecommendations;
  final VoidCallback onOpenPendingCandidates;
  final VoidCallback onOpenSearch;
  final bool isRecommendationLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HomeWorkFlowChip(
            label: 'おすすめ確認',
            state: step1State,
            onTap: isRecommendationLoading ? null : onOpenRecommendations,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: HomeScreenColors.homeMutedText.withValues(alpha: 0.45),
          ),
        ),
        Expanded(
          child: _HomeWorkFlowChip(
            label: '投稿',
            state: step2State,
            onTap: onOpenPendingCandidates,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: HomeScreenColors.homeMutedText.withValues(alpha: 0.45),
          ),
        ),
        Expanded(
          child: _HomeWorkFlowChip(
            label: '商品探し',
            state: step3State,
            onTap: onOpenSearch,
          ),
        ),
      ],
    );
  }
}

class _HomeWorkFlowChip extends StatelessWidget {
  const _HomeWorkFlowChip({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _HomeWorkStepVisualState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    late final String statusLabel;
    late final Color iconColor;
    late final IconData icon;

    switch (state) {
      case _HomeWorkStepVisualState.completed:
        statusLabel = '完了';
        iconColor = HomeScreenColors.homeSuccess;
        icon = Icons.check_circle_rounded;
      case _HomeWorkStepVisualState.next:
        statusLabel = '次にやる';
        iconColor = HomeScreenColors.homeAccentTeal;
        icon = Icons.radio_button_checked_rounded;
      case _HomeWorkStepVisualState.remaining:
        statusLabel = '残りあり';
        iconColor = HomeScreenColors.homeWarning;
        icon = Icons.radio_button_checked_rounded;
      case _HomeWorkStepVisualState.optional:
        statusLabel = '任意';
        iconColor = HomeScreenColors.homeMutedText;
        icon = Icons.radio_button_unchecked_rounded;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: iconColor),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _HomeUi.tapHint(context).copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HomeScreenColors.homeTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _HomeUi.tapHint(context).copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _HomeWorkStepVisualState { completed, next, remaining, optional }

/// 3. 反応チェック（最近反応商品 + 閲覧導線）
class _ReactionCheckCard extends StatelessWidget {
  const _ReactionCheckCard({
    required this.products,
    required this.unconfirmedReactionCount,
    required this.hasRoomProfileUrl,
    required this.onOpenProductTap,
    required this.onOpenReactionList,
    required this.onOpenRoomUrl,
  });

  final List<RakutenManagedProduct> products;
  final int unconfirmedReactionCount;
  final bool hasRoomProfileUrl;
  final void Function(String productId) onOpenProductTap;
  final VoidCallback onOpenReactionList;
  final VoidCallback onOpenRoomUrl;

  bool get _showViewButton =>
      hasRoomProfileUrl &&
      (products.isNotEmpty || unconfirmedReactionCount > 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _HomeUi.homeCardDecoration(),
      padding: _HomeUi.homeCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '反応チェック',
                        style: _HomeUi.homeCardTitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unconfirmedReactionCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: HomeScreenColors.homeUnreadBadge.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: HomeScreenColors.homeUnreadBadge.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Text(
                          '未確認 $unconfirmedReactionCount件',
                          style: _HomeUi.tapHint(context).copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: HomeScreenColors.homeUnreadBadge,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_showViewButton) ...[
                const SizedBox(width: 8),
                Semantics(
                  label: 'home_reaction_view_button',
                  button: true,
                  child: OutlinedButton(
                    onPressed: onOpenReactionList,
                    style: _HomeDataUpdateButtonStyle.reactionViewPill(context),
                    child: const Text(
                      '反応商品を見る',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (products.isNotEmpty) ...[
            const SizedBox(height: 8),
            Column(
              children: [
                for (int i = 0; i < products.length; i++) ...[
                  _RecentReactedProductTile(
                    product: products[i],
                    onTap: () => onOpenProductTap(products[i].productId),
                  ),
                  if (i < products.length - 1)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: HomeScreenColors.listRowDivider.withValues(
                        alpha: 0.7,
                      ),
                    ),
                ],
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text('最近反応があった商品はありません', style: _HomeUi.homeCardSubtitle(context)),
          ],
          if (!hasRoomProfileUrl) ...[
            const SizedBox(height: 6),
            Text(
              'ROOMプロフィールURLを登録すると反応を確認できます',
              style: _HomeUi.homeCardSubtitle(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentReactedProductTile extends StatelessWidget {
  const _RecentReactedProductTile({required this.product, required this.onTap});

  final RakutenManagedProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 42,
                    height: 42,
                    color: HomeScreenColors.candidateThumbPlaceholder,
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(
                            product.imageUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_outlined,
                              size: 18,
                              color: Color(0xFF9CA3AF),
                            ),
                          )
                        : const Icon(
                            Icons.image_outlined,
                            size: 18,
                            color: Color(0xFF9CA3AF),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
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
                          color: HomeScreenColors.homeTextPrimary,
                          height: 1.22,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 13,
                            color: HomeScreenColors.homeMutedText,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${product.roomLikeCount ?? 0}',
                            style: _HomeUi.tapHint(context).copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: HomeScreenColors.homeMutedText,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 13,
                            color: HomeScreenColors.homeMutedText,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${product.roomCommentCount ?? 0}',
                            style: _HomeUi.tapHint(context).copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: HomeScreenColors.homeMutedText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 5. データ更新（取り込み・反応確認をコンパクトに）

Future<void> _homeHandleRoomImport(
  BuildContext context, {
  required VoidCallback onOpenRoomUrl,
}) async {
  final importState = resolveRoomImportAvailabilityFromItems(
    items: context.read<RakutenManagedProductProvider>().items,
  );
  if (!importState.allowed) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('room_import_limit_blocked_snackbar'),
          content: Text(buildRoomImportLimitBlockedBody(importState)),
        ),
      );
    }
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('room_import_confirm_dialog'),
      title: const Text('ROOM投稿を取り込む'),
      content: const Text('ROOM投稿を取り込みます。\n処理中は検索や登録操作を一時停止します。\nよろしいですか？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('room_import_start_button'),
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

Future<void> _homeHandleReactionSync(
  BuildContext context, {
  VoidCallback? onCompleted,
}) async {
  final ctl = context.read<RoomImportController>();
  final bulk = context.read<BulkOperationStateController>();
  final syncBusy =
      ctl.isRunning ||
      bulk.isMetadataEnriching ||
      bulk.isRoomReactionSyncRunning;
  if (syncBusy || bulk.isAnyBlockingOperationRunning) {
    if (kDebugMode) {
      debugPrint(
        '[ROOM_REACTION_SYNC_START_GUARD] screen=home blockedByBusy=true '
        'confirmed=false',
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ROOMデータの更新が終わってから、反応の確認を行ってください')),
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
  onCompleted?.call();
}

class _DataUpdateCard extends StatelessWidget {
  const _DataUpdateCard({
    required this.hasRoomProfileUrl,
    required this.importedDoneCount,
    required this.unconfirmedReactionCount,
    required this.reactionHistoryRefreshNonce,
    required this.onOpenRoomUrl,
    this.onReactionSyncCompleted,
  });

  final bool hasRoomProfileUrl;
  final int importedDoneCount;
  final int unconfirmedReactionCount;
  final int reactionHistoryRefreshNonce;
  final VoidCallback onOpenRoomUrl;
  final VoidCallback? onReactionSyncCompleted;

  Future<void> _handleImport(BuildContext context) async {
    if (!hasRoomProfileUrl) return;
    await _homeHandleRoomImport(context, onOpenRoomUrl: onOpenRoomUrl);
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
    await _homeHandleReactionSync(
      context,
      onCompleted: onReactionSyncCompleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RoomImportController, BulkOperationStateController>(
      builder: (context, ctl, bulk, _) {
        final roomImportState = resolveRoomImportAvailabilityFromItems(
          items: context.watch<RakutenManagedProductProvider>().items,
        );
        final syncBusy =
            ctl.isRunning ||
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
        final importButtonEnabled = showImportButton && roomImportState.allowed;
        final showReactionButtonSlot =
            hasRoomProfileUrl &&
            importedDoneCount > 0 &&
            (syncBusy || canRunPrimary);
        final reactionButtonEnabled = canRunPrimary && !syncBusy;
        final reactionButtonLabel = syncBusy && reactionOnly
            ? RoomSyncCardCopy.reactionCheckBusyLabel
            : RoomSyncCardCopy.manualReactionCheckLabel;
        final showReactionButton = showReactionButtonSlot;
        roomSyncCardUxRenderLog(
          state: syncCardState,
          showImportButton: showImportButton,
          showReactionButton: showReactionButton,
          showAnalysisCta: false,
          hiddenDisabledButtons: syncBusy && showReactionButtonSlot
              ? 'reactionDisabledWhileBusy'
              : (syncBusy ? 'allHiddenWhileBusy' : 'none'),
        );
        roomSyncButtonRenderDecisionLog(
          'screen=home button=import visible=$showImportButton '
          'enabled=$importButtonEnabled '
          'label=投稿を取り込む '
          'reason=${syncBusy ? 'busy' : (!hasRoomProfileUrl ? 'missingRoomUrl' : (actionLocked ? 'guarded' : (!roomImportState.allowed ? 'roomImportLimitReached' : 'ready')))}',
        );
        roomSyncButtonRenderDecisionLog(
          'screen=home button=reaction visible=$showReactionButton '
          'enabled=$reactionButtonEnabled label=${syncBusy && reactionOnly ? reactionButtonLabel : '反応データ取得'} '
          'reason=${syncBusy ? 'busyDisabled' : (importedDoneCount <= 0 ? 'notImportedYet' : (!hasRoomProfileUrl ? 'missingRoomUrl' : (actionLocked ? 'guarded' : 'ready')))}',
        );
        roomSyncEmptyButtonAuditLog(
          screen: 'home',
          button: 'import',
          visible: showImportButton,
          enabled: showImportButton,
          label: '投稿を取り込む',
          reason: showImportButton ? 'rendered' : 'hiddenByUxPolicy',
        );
        roomSyncEmptyButtonAuditLog(
          screen: 'home',
          button: 'reaction',
          visible: showReactionButton,
          enabled: reactionButtonEnabled,
          label: syncBusy && reactionOnly ? reactionButtonLabel : '反応データ取得',
          reason: showReactionButton
              ? (reactionButtonEnabled ? 'rendered' : 'disabledWhileBusy')
              : 'notImportedYetOrHidden',
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
            visible: showReactionButton,
            reason: importedDoneCount <= 0
                ? 'notImportedYet'
                : (syncBusy ? 'busyDisabled' : baseReason),
          );
          RoomSyncButtonVisibility.logRenderDecision(
            screen: 'home',
            button: 'maintenance',
            canRun: false,
            visible: showMaintenanceUi,
            reason: showMaintenanceUi ? 'debugOnly' : 'hiddenByUxPolicy',
          );
          final maintChildReason = showMaintenanceUi
              ? baseReason
              : 'hiddenByUxPolicy';
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
          decoration: _HomeUi.homeCardDecoration(),
          padding: _HomeUi.homeCardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('データ更新', style: _HomeUi.homeCardTitle(context)),
              const SizedBox(height: 4),
              Text(
                hasRoomProfileUrl
                    ? 'ROOM投稿の取込と反応確認を行えます'
                    : 'ROOMプロフィールURLを登録すると、コレ済み商品や反応チェックを更新できます。',
                style: _HomeUi.homeCardSubtitle(context),
              ),
              const SizedBox(height: 8),
              if (!hasRoomProfileUrl) ...[
                OutlinedButton.icon(
                  onPressed: onOpenRoomUrl,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomeScreenColors.homeAccentTeal,
                    backgroundColor: HomeScreenColors.homeCardFill,
                    side: const BorderSide(
                      color: HomeScreenColors.homeAccentTealBorder,
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  icon: const Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: HomeScreenColors.homeAccentTeal,
                  ),
                  label: const Text('ROOMプロフィールを登録'),
                ),
              ] else ...[
                if (syncBusy) ...[
                  KeyedSubtree(
                    key: const Key('room_import_status_area'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ROOMデータを更新中です',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          busyLead,
                          style: _HomeUi.homeCardSubtitle(context),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            value: busyProgress,
                            backgroundColor: HomeScreenColors.progressTrack,
                            color: HomeScreenColors.homeAccentTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  if (actionLocked && !syncBusy) ...[
                    Text(
                      bulk.blockingRoomTourUserMessage ??
                          BulkOperationStateController.blockingSnackMessage,
                      style: _HomeUi.homeFootnote(context),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (importedDoneCount <= 0 && hasRoomProfileUrl) ...[
                    Text(
                      'まだROOM投稿を取り込んでいません',
                      style: _HomeUi.homeCardSubtitle(context),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      if (showImportButton)
                        Expanded(
                          child: Semantics(
                            label: 'home_room_import_button',
                            button: true,
                            child: OutlinedButton.icon(
                              key: const Key('room_import_entry_button'),
                              onPressed: importButtonEnabled
                                  ? () {
                                      RoomSyncButtonVisibility.logIdleVisible(
                                        screen: 'home',
                                        button: 'import',
                                      );
                                      _handleImport(context);
                                    }
                                  : null,
                              style:
                                  _HomeDataUpdateButtonStyle.dataUpdateOutlined(
                                    context,
                                  ),
                              icon: const Icon(
                                Icons.download_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                '投稿を取り込む',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      if (showImportButton && showReactionButtonSlot)
                        const SizedBox(width: 8),
                      if (showReactionButtonSlot)
                        Expanded(
                          child: Semantics(
                            label: 'home_reaction_sync_button',
                            button: true,
                            child: OutlinedButton.icon(
                              onPressed: reactionButtonEnabled
                                  ? () {
                                      RoomSyncButtonVisibility.logIdleVisible(
                                        screen: 'home',
                                        button: 'reaction',
                                      );
                                      _handleReactionSync(context);
                                    }
                                  : null,
                              style:
                                  _HomeDataUpdateButtonStyle.dataUpdateOutlined(
                                    context,
                                  ),
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                syncBusy && reactionOnly
                                    ? reactionButtonLabel
                                    : '反応データ取得',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (showRoomSyncMaintenanceDebugUi) ...[
                    const SizedBox(height: 14),
                    ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        RoomSyncCardCopy.maintenanceTileTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        RoomSyncCardCopy.maintenanceTileSubtitle,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                              RoomPostImportFlow.runManualPendingRoomImportMetadataEnrich(
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
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
    required this.milestonePostCount,
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
  final int milestonePostCount;
  final int recTotalCount;
  final String? recommendationHintLine;
  final String? recommendationStatusMessage;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenCandidates;
  final VoidCallback onOpenActivity;
  final VoidCallback onPrimaryRecommendations;

  String _todayStatusMessage() {
    if (isLoading ||
        generationStatus == TodayRecommendationGenerationStatus.loading) {
      return 'おすすめを準備しています';
    }
    if (pendingCount > 0) {
      return '今日のおすすめを見てみましょう';
    }
    if (generationStatus ==
            TodayRecommendationGenerationStatus.failedRateLimit ||
        generationStatus ==
            TodayRecommendationGenerationStatus.failedApiError) {
      return 'おすすめを準備できませんでした';
    }
    if (generationStatus == TodayRecommendationGenerationStatus.empty) {
      return '今日の小さな目標から始めましょう';
    }
    if (totalCount > 0) {
      return 'まずは今日の1件から、無理なく進めましょう';
    }
    return '無理なくROOM運用を続けましょう';
  }

  String? _titleRowChipLabel() {
    if (isLoading ||
        generationStatus == TodayRecommendationGenerationStatus.loading) {
      return null;
    }
    if (pendingCount > 0) return '未確認 $pendingCount件';
    if (totalCount > 0) return '整理済み';
    return null;
  }

  String? _compactInfoLine() {
    if (isLoading ||
        generationStatus == TodayRecommendationGenerationStatus.loading) {
      return 'おすすめを準備中です';
    }
    if (pendingCount > 0) return null;
    final statusMsg = recommendationStatusMessage?.trim();
    if (totalCount > 0) {
      return statusMsg?.isNotEmpty == true ? statusMsg : 'おすすめ候補 $totalCount件';
    }
    if (statusMsg?.isNotEmpty == true) return statusMsg;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // 親から渡る集計・KPIは画面導線の安定のため保持（表示は上限・おすすめ未処理に集約）。
    final _ = (
      kpi,
      isCompleted,
      hasTodaySuggestions,
      todayDoneCountForRec,
      milestonePostCount,
      recTotalCount,
      candidateCount,
      recommendationHintLine,
      onOpenSearch,
      onOpenCandidates,
      onOpenActivity,
    );

    final primary = _primaryAction();
    final titleRowChipLabel = _titleRowChipLabel();
    final compactInfoLine = _compactInfoLine();

    return Container(
      width: double.infinity,
      decoration: _HomeUi.searchEntrySectionDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '今日のROOM運用',
                  style: _HomeUi.sectionTitle(context).copyWith(
                    color: HomeScreenColors.accentSectionHeading,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (titleRowChipLabel != null)
                _HomeTodayStatusChip(label: titleRowChipLabel),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _todayStatusMessage(),
            maxLines: 2,
            softWrap: true,
            style: _HomeUi.bodyEmphasis(context).copyWith(
              fontSize: 14.5,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: HomeScreenColors.titlePrimary,
            ),
          ),
          const SizedBox(height: 10),
          _HomeHeroCtaButton(
            icon: primary.icon,
            label: primary.label,
            onPressed: primary.onPressed,
          ),
          if (compactInfoLine != null && compactInfoLine.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              compactInfoLine.trim(),
              maxLines: 2,
              softWrap: true,
              textAlign: TextAlign.center,
              style: _HomeUi.tapHint(context).copyWith(
                fontSize: 11.5,
                height: 1.3,
                color: HomeScreenColors.footnoteMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _HomePostMilestoneSection(postCount: milestonePostCount),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            thickness: 1,
            color: HomeScreenColors.sectionOutlineNeutral.withValues(
              alpha: 0.22,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
            decoration: BoxDecoration(
              color: HomeScreenColors.subActionRowFill.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '投稿しすぎ防止の目安',
                  style: _HomeUi.tapHint(context).copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: HomeScreenColors.footnoteMuted,
                  ),
                ),
                const SizedBox(height: 2),
                _CollectLimitProgressLine(
                  title: '直近24時間',
                  usedCount: collectLimit.todayCount,
                  limit: RoomCollectPostLimitSnapshot.dailyLimit,
                  state: collectLimit.dailyBarState,
                  rightLabel: 'あと${collectLimit.dailyRemaining}',
                  compact: true,
                  subtle: true,
                ),
                const SizedBox(height: 2),
                _CollectLimitProgressLine(
                  title: 'この1時間',
                  usedCount: collectLimit.hourCount,
                  limit: RoomCollectPostLimitSnapshot.hourlyLimit,
                  state: collectLimit.hourlyBarState,
                  rightLabel: 'あと${collectLimit.hourlyRemaining}',
                  footnote: collectLimit.isHourlyReached
                      ? collectLimit.recoveryFootnote(DateTime.now())
                      : null,
                  compact: true,
                  subtle: true,
                ),
                Text(
                  '参考値です。無理に上限を目指す必要はありません。',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _HomeUi.tapHint(context).copyWith(
                    fontSize: 9.5,
                    height: 1.25,
                    color: HomeScreenColors.footnoteMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
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
        onPressed: null,
      );
    }
    if (pendingCount > 0) {
      return _HomeActionSpec(
        label: 'おすすめコレを見る',
        icon: Icons.auto_awesome_rounded,
        onPressed: onPrimaryRecommendations,
      );
    }
    if (totalCount > 0) {
      return _HomeActionSpec(
        label: 'おすすめを見る',
        icon: Icons.auto_awesome_rounded,
        onPressed: onPrimaryRecommendations,
      );
    }
    return _HomeActionSpec(
      label: 'おすすめを用意する',
      icon: Icons.auto_awesome_rounded,
      onPressed: onPrimaryRecommendations,
    );
  }
}

class _HomePostMilestoneSection extends StatelessWidget {
  const _HomePostMilestoneSection({required this.postCount});

  final int postCount;

  @override
  Widget build(BuildContext context) {
    final snapshot = HomePostMilestoneSnapshot.fromPostCount(
      postCount,
      useCalendarDayLabel: true,
    );
    final countSummary = snapshot.countSummaryLine;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: HomeScreenColors.todayDoneFill.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: HomeScreenColors.todayActiveBorder.withValues(alpha: 0.38),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  snapshot.sectionTitle,
                  style: _HomeUi.tapHint(context).copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: HomeScreenColors.accentSectionHeading,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              if (countSummary != null)
                Text(
                  countSummary,
                  style: _HomeUi.tapHint(context).copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: HomeScreenColors.bodyOnSection,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            snapshot.hintMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _HomeUi.bodyEmphasis(context).copyWith(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: HomeScreenColors.titlePrimary,
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              const chipGap = 4.0;
              final chipWidth =
                  (constraints.maxWidth -
                      (HomePostMilestoneSnapshot.milestones.length - 1) *
                          chipGap) /
                  HomePostMilestoneSnapshot.milestones.length;
              return Row(
                children: [
                  for (
                    var i = 0;
                    i < HomePostMilestoneSnapshot.milestones.length;
                    i++
                  ) ...[
                    if (i > 0) const SizedBox(width: chipGap),
                    _HomeMilestoneChip(
                      label: '${HomePostMilestoneSnapshot.milestones[i]}件',
                      reached: snapshot.isMilestoneReached(
                        HomePostMilestoneSnapshot.milestones[i],
                      ),
                      width: chipWidth,
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: snapshot.segmentProgress,
              minHeight: 3,
              backgroundColor: HomeScreenColors.sectionOutlineNeutral
                  .withValues(alpha: 0.2),
              color: HomeScreenColors.homeAccentTeal.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMilestoneChip extends StatelessWidget {
  const _HomeMilestoneChip({
    required this.label,
    required this.reached,
    required this.width,
  });

  final String label;
  final bool reached;
  final double width;

  @override
  Widget build(BuildContext context) {
    final fill = reached
        ? HomeScreenColors.homeAccentTealLight.withValues(alpha: 0.95)
        : HomeScreenColors.subActionRowFill.withValues(alpha: 0.55);
    final border = reached
        ? HomeScreenColors.homeAccentTeal.withValues(alpha: 0.42)
        : HomeScreenColors.sectionOutlineNeutral.withValues(alpha: 0.35);
    final textColor = reached
        ? HomeScreenColors.homeAccentTeal
        : HomeScreenColors.footnoteMuted;

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _HomeUi.tapHint(
          context,
        ).copyWith(fontSize: 10, fontWeight: FontWeight.w800, color: textColor),
      ),
    );
  }
}

class _HomeTodayStatusChip extends StatelessWidget {
  const _HomeTodayStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HomeScreenColors.subActionRowFill.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: HomeScreenColors.sectionOutlineNeutral.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: _HomeUi.tapHint(context).copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: HomeScreenColors.footnoteMuted,
          height: 1.1,
        ),
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
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: HomeScreenColors.homeAccentTeal.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: FilledButton.icon(
          key: const Key('today_recommendation_entry_button'),
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            foregroundColor: AppColors.textOnAccent,
            backgroundColor: HomeScreenColors.homeAccentTeal,
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
  final VoidCallback? onPressed;
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
    this.compact = false,
    this.subtle = false,
  });

  final String title;
  final int usedCount;
  final int limit;
  final RoomCollectPostLimitBarState state;
  final String rightLabel;
  final String? footnote;
  final bool compact;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      RoomCollectPostLimitBarState.normal => HomeScreenColors.homeAccentTeal,
      RoomCollectPostLimitBarState.warning => const Color(0xFFE67E22),
      RoomCollectPostLimitBarState.reached => AppColors.textSecondary,
    };
    final progress = limit <= 0 ? 0.0 : (usedCount / limit).clamp(0.0, 1.0);
    final foot = footnote?.trim();

    final metricStyle = _HomeUi.sectionBody(context).copyWith(
      fontSize: subtle ? 10.5 : (compact ? 12 : 15),
      fontWeight: subtle
          ? FontWeight.w600
          : (compact ? FontWeight.w700 : FontWeight.w900),
      height: 1.28,
      color: subtle
          ? HomeScreenColors.footnoteMuted
          : compact
          ? HomeScreenColors.bodyOnSection
          : HomeScreenColors.titlePrimary,
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
                runSpacing: 2,
                children: [
                  Text('$title ', style: metricStyle),
                  _HomeAnimatedPostedCount(
                    value: usedCount,
                    style: metricStyle,
                  ),
                  Text(' / $limit', style: metricStyle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 88 : 160),
              child: Text(
                rightLabel,
                textAlign: TextAlign.end,
                maxLines: 2,
                softWrap: true,
                style: _HomeUi.sectionBody(context).copyWith(
                  fontSize: subtle ? 10 : (compact ? 10.5 : 12.5),
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: state == RoomCollectPostLimitBarState.normal
                      ? HomeScreenColors.footnoteMuted
                      : color,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: subtle ? 3 : (compact ? 4 : 6)),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: subtle ? 4 : (compact ? 6 : 10),
            backgroundColor: HomeScreenColors.progressTrack,
            color: color.withValues(
              alpha: subtle ? 0.55 : (compact ? 0.72 : 1.0),
            ),
          ),
        ),
        if (foot != null && foot.isNotEmpty) ...[
          SizedBox(height: compact ? 3 : 5),
          Text(
            foot,
            maxLines: 2,
            softWrap: true,
            style: _HomeUi.tapHint(context).copyWith(
              fontSize: compact ? 10.5 : 12,
              fontWeight: FontWeight.w600,
              color: HomeScreenColors.footnoteMuted,
            ),
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
  final VoidCallback? onPressed;
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
          Icon(icon, size: 18, color: HomeScreenColors.homeAccentTeal),
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
  const _HomeMomentumHeader({
    required this.displayName,
    required this.milestonePostCount,
    required this.recPendingCount,
    required this.recTotalCount,
    required this.recIsLoading,
    required this.unconfirmedReactionCount,
    this.reactionHistoryRefreshNonce = 0,
  });

  final String? displayName;
  final int milestonePostCount;
  final int recPendingCount;
  final int recTotalCount;
  final bool recIsLoading;
  final int unconfirmedReactionCount;
  final int reactionHistoryRefreshNonce;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameLine = displayName == null || displayName!.trim().isEmpty
        ? 'こんにちは'
        : 'こんにちは　${displayName!.trim()}さん';
    const subLine = '今日もROOM運用を進めましょう';

    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameLine,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    color: HomeScreenColors.homeTextPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subLine,
                  style: _HomeUi.sectionBody(context).copyWith(
                    fontSize: 14,
                    color: HomeScreenColors.homeTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          _HomeNotificationBell(
            milestonePostCount: milestonePostCount,
            recPendingCount: recPendingCount,
            recTotalCount: recTotalCount,
            recIsLoading: recIsLoading,
            unconfirmedReactionCount: unconfirmedReactionCount,
            reactionHistoryRefreshNonce: reactionHistoryRefreshNonce,
          ),
        ],
      ),
    );
  }
}

/// ホーム右上の通知ベル（お知らせは本文カードに出さずここに集約）。
class _HomeNotificationBell extends StatefulWidget {
  const _HomeNotificationBell({
    required this.milestonePostCount,
    required this.recPendingCount,
    required this.recTotalCount,
    required this.recIsLoading,
    required this.unconfirmedReactionCount,
    this.reactionHistoryRefreshNonce = 0,
  });

  final int milestonePostCount;
  final int recPendingCount;
  final int recTotalCount;
  final bool recIsLoading;
  final int unconfirmedReactionCount;
  final int reactionHistoryRefreshNonce;

  @override
  State<_HomeNotificationBell> createState() => _HomeNotificationBellState();
}

class _HomeNotificationBellState extends State<_HomeNotificationBell> {
  final Set<String> _sessionDismissedKeys = {};
  Set<String> _persistedDismissedKeys = {};
  RoomReactionSyncHistoryEntry? _latestReactionSyncHistory;
  int _reactionSyncHistoryCount = 0;
  bool _storeLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNoticeContext());
  }

  @override
  void didUpdateWidget(covariant _HomeNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reactionHistoryRefreshNonce !=
        widget.reactionHistoryRefreshNonce) {
      unawaited(_loadNoticeContext());
    }
  }

  Future<void> _loadNoticeContext() async {
    final results = await Future.wait([
      HomeInAppNoticeDismissStore.loadDismissedKeysForToday(),
      RoomReactionSyncHistoryStore.loadEntries(),
    ]);
    if (!mounted) return;
    final entries = results[1] as List<RoomReactionSyncHistoryEntry>;
    setState(() {
      _persistedDismissedKeys = results[0] as Set<String>;
      _latestReactionSyncHistory = entries.isEmpty ? null : entries.first;
      _reactionSyncHistoryCount = entries.length;
      _storeLoaded = true;
    });
  }

  Set<String> get _allDismissedKeys => {
    ..._persistedDismissedKeys,
    ..._sessionDismissedKeys,
  };

  HomeInAppNotice? get _selectedNotice {
    if (!_storeLoaded) return null;
    return HomeInAppNoticeSelector.select(
      milestonePostCount: widget.milestonePostCount,
      recPendingCount: widget.recPendingCount,
      recTotalCount: widget.recTotalCount,
      recIsLoading: widget.recIsLoading,
      dismissedKeys: _allDismissedKeys,
      todayDateKey: HomeInAppNoticeDismissStore.todayDateKey(),
      latestReactionSyncHistory: _latestReactionSyncHistory,
      reactionSyncHistoryCount: _reactionSyncHistoryCount,
    );
  }

  int get _badgeCount {
    var count = widget.unconfirmedReactionCount;
    if (_selectedNotice != null) count += 1;
    return count;
  }

  void _onBellTap() {
    final notice = _selectedNotice;
    final unconfirmed = widget.unconfirmedReactionCount;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'お知らせ',
                  style: _HomeUi.homeCardTitle(ctx).copyWith(fontSize: 18),
                ),
                const SizedBox(height: 12),
                if (notice != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      notice.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(notice.body),
                    onTap: () {
                      Navigator.pop(ctx);
                      _onNoticeAction(notice);
                    },
                  ),
                  const Divider(height: 1),
                ],
                if (unconfirmed > 0)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('反応未確認 $unconfirmed件'),
                    subtitle: const Text('反応チェックカードから確認できます'),
                    onTap: () => Navigator.pop(ctx),
                  ),
                if (notice == null && unconfirmed <= 0)
                  Text('新しいお知らせはありません', style: _HomeUi.homeCardSubtitle(ctx)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onNoticeAction(HomeInAppNotice notice) {
    final action = notice.action;
    if (action == null) return;
    final shell = context.read<AppShellController>();
    switch (action) {
      case HomeInAppNoticeAction.openActivity:
        shell.openActivityTab(
          subTabIndex: 1,
          scrollToRoomReactionSection: true,
        );
      case HomeInAppNoticeAction.openRoomCollect:
        shell.openRoomCollect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeCount = _badgeCount;

    return Semantics(
      label: 'home_notification_button',
      button: true,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        onPressed: _onBellTap,
        icon: Badge(
          isLabelVisible: badgeCount > 0,
          offset: const Offset(4, -4),
          label: Text(
            '$badgeCount',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          backgroundColor: HomeScreenColors.homeUnreadBadge,
          child: const Icon(
            Icons.notifications_none_rounded,
            size: 24,
            color: HomeScreenColors.homeTextPrimary,
          ),
        ),
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
                top: BorderSide(
                  color: _HomeUi.dividerLineColor().withValues(alpha: 0.65),
                ),
              ),
              color: const Color(0xFFF9FAFB),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    leadingIcon,
                    size: 20,
                    color: HomeScreenColors.homeAccentTeal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: _HomeUi.sectionFooterActionTitle(
                          context,
                        ).copyWith(color: HomeScreenColors.homeAccentTeal),
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
      icon: Icon(leadingIcon, size: 20, color: HomeScreenColors.homeAccentTeal),
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
                  title: '直近24時間のコレ',
                  valueMain: '$todayDoneCount件',
                  caption: '直近24時間のコレ済へ',
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
            Text(
              '「探す」や「今日のおすすめ」から追加できます。',
              style: _HomeUi.sectionBody(context),
            ),
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
              thickness: 0.5,
              indent: dividerIndent,
              endIndent: embedInUnifiedSection ? 9 : 9,
              color: HomeScreenColors.listRowDivider.withValues(alpha: 0.7),
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF374151),
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
                              )?.copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ) ??
                              _HomeUi.tapHint(
                                context,
                              ).copyWith(fontWeight: FontWeight.w800),
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
