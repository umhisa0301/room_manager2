import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import 'activity_placeholder_screen.dart';
import 'products_placeholder_screen.dart';
import 'rakuten_search_screen.dart';
import '../services/rakuten_room_home_stats.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/home_primary_action_button.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RakutenManagedProductProvider>().refreshManagedProductList(
            showLoadingIndicator: false,
          );
    });
  }

  void _openRoomList(BuildContext context, {int initialTabIndex = 0}) {
    final idx = initialTabIndex.clamp(0, 1);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductsPlaceholderScreen(initialTabIndex: idx),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ホーム'),
      ),
      body: SafeArea(
        child: Consumer<RakutenManagedProductProvider>(
          builder: (context, roomProvider, _) {
            final items = roomProvider.items;
            final nCandidate = RakutenRoomHomeStats.countCandidates(items);
            final nDone = RakutenRoomHomeStats.countDone(items);
            final now = DateTime.now();
            final nTodayDone =
                RakutenRoomHomeStats.countDoneOnLocalCalendarDay(items, now);
            final lastDone = RakutenRoomHomeStats.latestDoneAt(items);
            final recentCandidates =
                RakutenRoomHomeStats.candidatesNewestFirst(items).take(5).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenPaddingH,
                AppDimensions.spacingMd,
                AppDimensions.screenPaddingH,
                90,
              ),
              children: [
                const _MainSearchSection(),
                const SizedBox(height: AppDimensions.spacingMd),
                HomePrimaryActionButton(
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
                const SizedBox(height: AppDimensions.spacingSm),
                HomePrimaryActionButton(
                  icon: Icons.collections_bookmark_rounded,
                  label: 'コレ一覧を開く',
                  onPressed: () => _openRoomList(context),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                _SectionIntro(
                  title: 'ROOMコレ管理',
                  body: 'コレ候補・コレ済をまとめて管理します。数値は端末に保存された一覧から集計しています。下のカードをタップすると該当画面へ進みます。',
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                _RoomStatsCardGrid(
                  candidateTotal: nCandidate,
                  doneTotal: nDone,
                  todayDoneCount: nTodayDone,
                  lastDoneAt: lastDone,
                  onCandidateTap: () => _openRoomList(context, initialTabIndex: 0),
                  onDoneTap: () => _openRoomList(context, initialTabIndex: 1),
                  onTodayTap: () => _openActivity(context),
                  onLastCollectTap: () => _openActivity(context),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                _SectionIntro(
                  title: '最近候補に追加した商品',
                  body: '直近で候補登録した商品です。タップで一覧画面へ移動します。',
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                _RecentCandidatesPanel(
                  candidates: recentCandidates,
                  onOpenList: () => _openRoomList(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ① ヒーロー：役割の説明（主ボタンは直下で統一スタイル）。
class _MainSearchSection extends StatelessWidget {
  const _MainSearchSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentLight.withValues(alpha: 0.9),
            const Color(0xFFFFF5F9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.waving_hand_rounded,
                  size: 26, color: AppColors.accentPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '次にやること',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.accentPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1. 「楽天で検索」で商品を探して候補に追加\n2. 「コレ一覧」で URL 取得後にコレする\n3. 下の数字で活動を確認',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '楽天ROOMの「コレ」候補をこのアプリで集め、コレ済まで整理できます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '検索結果から「コレ候補へ登録」すると、ROOMコレ管理に表示されます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
        ),
      ],
    );
  }
}

/// ② 4 枚統一のコンパクトメトリクス（2×2、タップで遷移）。
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
    final lastPrimary = lastDoneAt == null
        ? '—'
        : _formatDateTime(lastDoneAt!);

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RoomMetricTile(
                  title: 'コレ候補',
                  valueText: '$candidateTotal',
                  caption: '候補の総数（タップで一覧）',
                  icon: Icons.bookmark_outline_rounded,
                  accent: const Color(0xFF1565C0),
                  iconBackground: const Color(0xFFE3F2FD),
                  emphasizeValue: true,
                  onTap: onCandidateTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RoomMetricTile(
                  title: 'コレ済',
                  valueText: '$doneTotal',
                  caption: 'コレ済の総数（タップで一覧）',
                  icon: Icons.task_alt_rounded,
                  accent: const Color(0xFF2E7D32),
                  iconBackground: const Color(0xFFE8F5E9),
                  emphasizeValue: true,
                  onTap: onDoneTap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RoomMetricTile(
                  title: '今日のコレ',
                  valueText: '$todayDoneCount',
                  caption: '本日コレ済へ移した件数（タップで活動）',
                  icon: Icons.today_rounded,
                  accent: AppColors.accentPrimary,
                  iconBackground: AppColors.accentLightest,
                  emphasizeValue: true,
                  onTap: onTodayTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RoomMetricTile(
                  title: '前回コレ日時',
                  valueText: lastPrimary,
                  caption: '最新の doneAt（タップで活動）',
                  icon: Icons.history_rounded,
                  accent: const Color(0xFF5C6BC0),
                  iconBackground: const Color(0xFFE8EAF6),
                  emphasizeValue: false,
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
    required this.valueText,
    required this.caption,
    required this.icon,
    required this.accent,
    required this.iconBackground,
    required this.emphasizeValue,
    required this.onTap,
  });

  final String title;
  final String valueText;
  final String caption;
  final IconData icon;
  final Color accent;
  final Color iconBackground;
  final bool emphasizeValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                valueText,
                textAlign: TextAlign.right,
                maxLines: emphasizeValue ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: emphasizeValue
                    ? Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.05,
                          fontSize: 30,
                        )
                    : Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.15,
                          fontSize: 18,
                        ),
              ),
              const SizedBox(height: 6),
              Text(
                caption,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      height: 1.35,
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
    required this.candidates,
    required this.onOpenList,
  });

  final List<RakutenManagedProduct> candidates;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '候補の商品はまだありません',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '上部の「楽天で検索」から商品を追加してください。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < candidates.length; i++) ...[
            _RecentCandidateTile(product: candidates[i], onTap: onOpenList),
            if (i < candidates.length - 1)
              const Divider(height: 1, indent: 72),
          ],
        ],
      ),
    );
  }
}

class _RecentCandidateTile extends StatelessWidget {
  const _RecentCandidateTile({
    required this.product,
    required this.onTap,
  });

  final RakutenManagedProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          height: 1.25,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.shopName.isEmpty ? 'ショップ名なし' : product.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  _ExtractionChip(status: product.extractionStatus),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
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
            ),
      ),
    );
  }
}
