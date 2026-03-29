import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../screens/products_placeholder_screen.dart';
import '../screens/rakuten_search_screen.dart';
import '../services/rakuten_room_home_stats.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';

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

  void _openRoomList(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProductsPlaceholderScreen(),
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
                _MainSearchSection(
                  onSearch: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RakutenSearchScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                _SectionIntro(
                  title: 'ROOMコレ管理',
                  body: 'コレ候補・コレ済をまとめて管理します。数値は端末に保存された一覧から集計しています。',
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                _RoomStatsCardGrid(
                  candidateTotal: nCandidate,
                  doneTotal: nDone,
                  todayDoneCount: nTodayDone,
                  lastDoneAt: lastDone,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _openRoomList(context),
                    icon: const Icon(Icons.collections_bookmark_outlined),
                    label: const Text('コレ一覧を開く'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: const Color(0xFF1565C0),
                    ),
                  ),
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

/// ① メインアクション：楽天検索
class _MainSearchSection extends StatelessWidget {
  const _MainSearchSection({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentLight.withValues(alpha: 0.9),
            const Color(0xFFE8F4FD),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.travel_explore_rounded,
                  size: 26, color: AppColors.accentPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'まずはここから',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.accentPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '楽天ROOMの「コレ」候補をこのアプリで集め、コレ済まで整理できます。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded, size: 22),
            label: const Text(
              '楽天で検索',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: AppColors.textOnAccent,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '商品を検索してコレ候補に追加',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
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

/// ② 数値カード（候補・コレ済・今日のコレ・前回日時）
class _RoomStatsCardGrid extends StatelessWidget {
  const _RoomStatsCardGrid({
    required this.candidateTotal,
    required this.doneTotal,
    required this.todayDoneCount,
    required this.lastDoneAt,
  });

  final int candidateTotal;
  final int doneTotal;
  final int todayDoneCount;
  final DateTime? lastDoneAt;

  @override
  Widget build(BuildContext context) {
    final lastLabel = lastDoneAt == null
        ? 'まだありません'
        : _formatDateTime(lastDoneAt!);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatNumberCard(
                label: 'コレ候補',
                value: candidateTotal,
                caption: '候補の総数',
                icon: Icons.bookmark_outline_rounded,
                tint: const Color(0xFFE3F2FD),
                accent: const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatNumberCard(
                label: 'コレ済',
                value: doneTotal,
                caption: 'コレ済の総数',
                icon: Icons.task_alt_rounded,
                tint: const Color(0xFFE8F5E9),
                accent: const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StatNumberCard(
                label: '今日のコレ',
                value: todayDoneCount,
                caption: '今日（0:00〜）にコレ済へ移した件数',
                icon: Icons.today_rounded,
                tint: AppColors.accentLightest,
                accent: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LastCollectCard(lastLabel: lastLabel),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _StatNumberCard extends StatelessWidget {
  const _StatNumberCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.tint,
    required this.accent,
  });

  final String label;
  final int value;
  final String caption;
  final IconData icon;
  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
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
    );
  }
}

class _LastCollectCard extends StatelessWidget {
  const _LastCollectCard({required this.lastLabel});

  final String lastLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '前回コレ日時',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lastLabel,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'このアプリでコレ済へ移した直近の日時（最新の doneAt）です。',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.35,
                ),
          ),
        ],
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
