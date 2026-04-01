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
  static const double gapSection = 20;

  /// 見出しカードと、その直下の「まとまり」本体の距離
  static const double gapHeadingToContent = 10;

  /// セクション見出しと折りたたみ要約の間
  static const double gapTitleToSummary = 8;

  /// 囲み（well）の内側パディング
  static const double paddingGroupedWell = 12;

  /// コンパクトな縦の詰まり（チップ上など）
  static const double gapTight = 6;

  /// 標準リストの下余白（ナビバー押さえ以外）
  static const double listBottomExtra = 16;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.055),
          offset: const Offset(0, 2),
          blurRadius: 10,
        ),
      ];

  /// 単体カード（今日のおすすめなど）
  static BoxDecoration elevatedCardDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      border: Border.all(
        color: AppColors.divider.withValues(alpha: 0.92),
      ),
      boxShadow: cardShadow,
    );
  }

  /// メトリクス・最近候補の「親」の囲み（背景差でまとまりを示す）
  static BoxDecoration groupedWellDecoration() {
    return BoxDecoration(
      color: Color.alphaBlend(
        AppColors.surfaceVariant.withValues(alpha: 0.48),
        AppColors.background,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: AppColors.divider.withValues(alpha: 0.78),
      ),
    );
  }

  /// セクション・カード見出し（何が見出しかを揃える）
  static TextStyle sectionTitle(BuildContext context) {
    final base = Theme.of(context).textTheme.titleSmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      height: 1.28,
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
      height: 1.45,
      color: AppColors.textSecondary,
    );
  }

  /// 展開した説明文・補足
  static TextStyle sectionBody(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 13,
      height: 1.5,
      color: AppColors.textSecondary,
    );
  }

  /// タップ可能な補足・キャプション
  static TextStyle tapHint(BuildContext context) {
    final base = Theme.of(context).textTheme.labelSmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 11,
      height: 1.4,
      color: AppColors.textTertiary,
    );
  }

  /// 空状態・リスト内のサブ見出し
  static TextStyle bodyEmphasis(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    return (base ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w600,
      height: 1.35,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RakutenManagedProductProvider>().refreshManagedProductList(
        showLoadingIndicator: false,
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
                        AppDimensions.screenPaddingH,
                        AppDimensions.screenPaddingV,
                        AppDimensions.screenPaddingH,
                        bottomInset + navBarReserve + _HomeUi.listBottomExtra,
                      ),
                      children: [
                        HomePrimaryActionButton(
                          emphasis: HomePrimaryActionEmphasis.hero,
                          icon: Icons.travel_explore_rounded,
                          label: '楽天で検索',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RakutenSearchScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: _HomeUi.gapSection),
                        _HomeExpandableSection(
                          chrome: _HomeExpandableChrome.hero,
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
                        _TodayRecommendationsEntryCard(
                          totalCount: recProvider.totalCount,
                          pendingCount: recProvider.pendingCount,
                          isCompleted: recProvider.isCompleted,
                          onOpen: () => _openTodayRecommendations(context),
                        ),
                        const SizedBox(height: _HomeUi.gapSection),
                        _HomeExpandableSection(
                          chrome: _HomeExpandableChrome.plain,
                          expanded: _roomIntroExpanded,
                          onToggle: () {
                            setState(() {
                              _roomIntroExpanded = !_roomIntroExpanded;
                            });
                          },
                          title: 'ROOMコレ管理',
                          collapsedSummary: '',
                          leadingIcon: Icons.collections_bookmark_outlined,
                          expandedChild: Text(
                            '下の数は端末に保存した一覧の集計です。カードをタップで一覧・活動へ移動します。',
                            style: _HomeUi.sectionBody(context),
                          ),
                        ),
                        const SizedBox(height: _HomeUi.gapHeadingToContent),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(
                            _HomeUi.paddingGroupedWell,
                          ),
                          decoration: _HomeUi.groupedWellDecoration(),
                          child: _RoomStatsCardGrid(
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
                        ),
                        const SizedBox(height: _HomeUi.gapSection),
                        _HomeExpandableSection(
                          chrome: _HomeExpandableChrome.plain,
                          expanded: _recentIntroExpanded,
                          onToggle: () {
                            setState(() {
                              _recentIntroExpanded = !_recentIntroExpanded;
                            });
                          },
                          title: '最近追加した候補',
                          collapsedSummary: '',
                          leadingIcon: Icons.bookmark_added_outlined,
                          expandedChild: Text(
                            '直近の候補を最大5件表示。コレ済にすると消えます。行タップでコレ一覧。',
                            style: _HomeUi.sectionBody(context),
                          ),
                        ),
                        const SizedBox(height: _HomeUi.gapHeadingToContent),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(
                            _HomeUi.paddingGroupedWell,
                          ),
                          decoration: _HomeUi.groupedWellDecoration(),
                          child: _RecentCandidatesPanel(
                            candidates: recentCandidates,
                            onOpenCandidateTap: (productId) => _openRoomList(
                              context,
                              focusCandidateProductId: productId,
                            ),
                          ),
                        ),
                        const SizedBox(height: _HomeUi.gapSection),
                        _HomeCollectionListLink(
                          onPressed: () => _openRoomList(context),
                        ),
                      ],
                    );
                  },
            ),
      ),
    );
  }
}

/// ホームの折りたたみカードの見た目種別。
enum _HomeExpandableChrome { hero, plain }

/// ホーム共通：ヘッダー全面タップ・スプラッシュ・AnimatedSize で開閉。
class _HomeExpandableSection extends StatelessWidget {
  const _HomeExpandableSection({
    required this.chrome,
    required this.expanded,
    required this.onToggle,
    required this.title,
    required this.collapsedSummary,
    required this.leadingIcon,
    required this.expandedChild,
  });

  final _HomeExpandableChrome chrome;
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
    final radius = BorderRadius.circular(AppDimensions.radiusCard);
    final isHero = chrome == _HomeExpandableChrome.hero;
    final splashColor = isHero
        ? AppColors.accentPrimary.withValues(alpha: 0.14)
        : AppColors.textPrimary.withValues(alpha: 0.08);
    final highlightColor = isHero
        ? AppColors.accentPrimary.withValues(alpha: 0.07)
        : AppColors.textPrimary.withValues(alpha: 0.05);
    final iconColor = isHero
        ? AppColors.accentPrimary
        : AppColors.textSecondary;

    final BoxDecoration decoration;
    if (isHero) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentLight.withValues(alpha: 0.9),
            const Color(0xFFFFF5F9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.14),
        ),
        boxShadow: _HomeUi.cardShadow,
      );
    } else {
      decoration = _HomeUi.elevatedCardDecoration();
    }

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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(leadingIcon, size: 22, color: iconColor),
                    const SizedBox(width: 10),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: expandedChild,
                  )
                : const SizedBox(width: double.infinity),
          ),
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
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.4,
              ),
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
                    height: 1.45,
                    fontSize: 13,
                  ),
            ),
          ),
        const _FlowStepLine(
          number: '1',
          title: '商品を探す',
          subtitle: '「楽天で検索」から。',
        ),
        const SizedBox(height: 10),
        const _FlowStepLine(
          number: '2',
          title: '候補に追加',
          subtitle: '検索結果から候補登録。',
        ),
        const SizedBox(height: 10),
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
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.28,
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
  const _HomeCollectionListLink({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
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

class _TodayRecommendationsEntryCard extends StatelessWidget {
  const _TodayRecommendationsEntryCard({
    required this.totalCount,
    required this.pendingCount,
    required this.isCompleted,
    required this.onOpen,
  });

  final int totalCount;
  final int pendingCount;
  final bool isCompleted;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final body = totalCount == 0
        ? 'タップで候補を作成'
        : isCompleted
            ? '本日は完了・明日更新'
            : '未処理 $pendingCount / $totalCount';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        splashColor: AppColors.textPrimary.withValues(alpha: 0.07),
        highlightColor: AppColors.textPrimary.withValues(alpha: 0.04),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: _HomeUi.elevatedCardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 22,
                  color: AppColors.accentPrimary.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日のおすすめコレ候補',
                      style: _HomeUi.sectionTitle(context),
                    ),
                    const SizedBox(height: _HomeUi.gapTight),
                    Text(
                      body,
                      style: _HomeUi.sectionBody(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ② 4 枚統一のメトリクス（2×2、タップで遷移）。値・補足は改行で区切る。
class _RoomStatsCardGrid extends StatelessWidget {
  const _RoomStatsCardGrid({
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
    final lastPrimary = lastDoneAt == null ? '—' : _formatDateTime(lastDoneAt!);

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
                  onTap: onCandidateTap,
                ),
              ),
              SizedBox(width: _HomeUi.gapTight + 2),
              Expanded(
                child: _RoomMetricTile(
                  title: 'コレ済',
                  valueMain: '$doneTotal件',
                  caption: 'タップで一覧を開く',
                  icon: Icons.task_alt_rounded,
                  accent: const Color(0xFF2E7D32),
                  iconBackground: const Color(0xFFE8F5E9),
                  valueProminent: true,
                  onTap: onDoneTap,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _HomeUi.gapTight + 2),
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
                  onTap: onTodayTap,
                ),
              ),
              SizedBox(width: _HomeUi.gapTight + 2),
              Expanded(
                child: _RoomMetricTile(
                  title: '前回コレ日時',
                  valueMain: lastPrimary,
                  caption: 'タップで活動を開く',
                  icon: Icons.history_rounded,
                  accent: const Color(0xFF5C6BC0),
                  iconBackground: const Color(0xFFE8EAF6),
                  valueProminent: false,
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
    required this.onTap,
  });

  final String title;
  final String valueMain;
  final String caption;
  final IconData icon;
  final Color accent;
  final Color iconBackground;
  final bool valueProminent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        splashColor: AppColors.textPrimary.withValues(alpha: 0.07),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
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
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accent, size: 17),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            height: 1.22,
                            fontSize: 13,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                valueMain,
                textAlign: TextAlign.left,
                maxLines: valueProminent ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: valueProminent
                    ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.12,
                          fontSize: 25,
                          letterSpacing: -0.45,
                        )
                    : Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.22,
                          fontSize: 16,
                        ),
              ),
              const SizedBox(height: 6),
              Text(
                caption,
                maxLines: 2,
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
    required this.candidates,
    required this.onOpenCandidateTap,
  });

  final List<RakutenManagedProduct> candidates;
  final void Function(String productId) onOpenCandidateTap;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.88),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < candidates.length; i++) ...[
            _RecentCandidateTile(
              product: candidates[i],
              onTap: () => onOpenCandidateTap(candidates[i].productId),
            ),
            if (i < candidates.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 72,
                endIndent: 12,
                color: AppColors.divider.withValues(alpha: 0.55),
              ),
          ],
        ],
      ),
    );
  }
}

class _RecentCandidateTile extends StatelessWidget {
  const _RecentCandidateTile({required this.product, required this.onTap});

  final RakutenManagedProduct product;
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
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(),
              const SizedBox(width: 12),
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
                            height: 1.32,
                            fontSize: 14,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.shopName.isEmpty ? 'ショップ名なし' : product.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _HomeUi.sectionBody(context),
                    ),
                    const SizedBox(height: 5),
                    _ExtractionChip(status: product.extractionStatus),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
      ),
    );
  }
}
