import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/today_recommendation.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_screen_status.dart';

class TodayRecommendationsScreen extends StatefulWidget {
  const TodayRecommendationsScreen({super.key});

  @override
  State<TodayRecommendationsScreen> createState() =>
      _TodayRecommendationsScreenState();
}

class _TodayRecommendationsScreenState extends State<TodayRecommendationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureToday();
    });
  }

  Future<void> _ensureToday() async {
    if (!mounted) return;
    final recommender = context.read<TodayRecommendationProvider>();
    final profile = context.read<UserProfileProvider>().profile;
    final managed = context.read<RakutenManagedProductProvider>().items;
    final saved = context.read<SavedShopProvider>().shops;
    await recommender.ensureToday(
      profile: profile,
      managedItems: managed,
      savedShops: saved,
    );
  }

  Future<void> _regenerate() async {
    final recommender = context.read<TodayRecommendationProvider>();
    final profile = context.read<UserProfileProvider>().profile;
    final managed = context.read<RakutenManagedProductProvider>().items;
    final saved = context.read<SavedShopProvider>().shops;
    await recommender.regenerateToday(
      profile: profile,
      managedItems: managed,
      savedShops: saved,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('今日のおすすめコレ候補'),
      ),
      body: Consumer<TodayRecommendationProvider>(
        builder: (context, rec, _) {
          if (rec.isLoading) {
            return const AppScreenLoadingCenter(
              title: '今日のおすすめを準備しています',
              subtitle: '保存済みのプロフィールや検索履歴に基づき、候補を集めています。通信状況により少し時間がかかることがあります。',
            );
          }
          if (rec.errorMessage != null) {
            return AppScreenErrorCenter(
              title: 'おすすめを表示できませんでした',
              message: rec.errorMessage!,
              onRetry: _regenerate,
              retryLabel: 'もう一度生成する',
            );
          }

          final bundle = rec.bundle;
          if (bundle == null || bundle.entries.isEmpty) {
            return AppScreenEmptyCenter(
              icon: Icons.auto_awesome_outlined,
              title: 'まだ今日のおすすめがありません',
              body:
                  '下のボタンで最大10件のコレ候補を提案します。マイページでプロフィールや好きなジャンルを入れておくと、より合った候補になりやすくなります。',
              actions: [
                FilledButton.icon(
                  onPressed: _regenerate,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: const Text('今日のおすすめを作る'),
                ),
              ],
            );
          }

          return Column(
            children: [
              _SummaryCard(
                total: bundle.entries.length,
                pending: rec.pendingCount,
                completed: rec.isCompleted,
                onRegenerate: _regenerate,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: bundle.entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = bundle.entries[index];
                    return _RecommendationCard(entry: entry);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.pending,
    required this.completed,
    required this.onRegenerate,
  });

  final int total;
  final int pending;
  final bool completed;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            completed
                ? '本日のおすすめはチェック完了です'
                : '本日のおすすめ $total件（未処理 $pending件）',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            completed
                ? '10件見終わりました。次回は翌日に新しい候補が生成されます。'
                : '各カードの「候補にする」「見送る」で、今日見る候補を整理できます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('今日の候補を再生成'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.entry});

  final TodayRecommendationEntry entry;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(imageUrl: item.imageUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.shopName.trim().isEmpty ? 'ショップ名なし' : item.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '評価 ${item.reviewAverage.toStringAsFixed(2)} / '
                      '評価数 ${item.reviewCount}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
              _DecisionChip(decision: entry.decision),
            ],
          ),
          const SizedBox(height: 10),
          _ActionRow(entry: entry),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.entry});

  final TodayRecommendationEntry entry;

  @override
  Widget build(BuildContext context) {
    final enabled = entry.decision == TodayRecommendationDecision.pending;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: enabled
                ? () async {
                    final rec = context.read<TodayRecommendationProvider>();
                    final managed = context.read<RakutenManagedProductProvider>();
                    final err = await rec.markAddedCandidate(
                      managedProvider: managed,
                      item: entry.item,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err ?? '候補に追加しました'),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.bookmark_add_rounded, size: 18),
            label: const Text('候補にする'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled
                ? () async {
                    final rec = context.read<TodayRecommendationProvider>();
                    await rec.markSkipped(entry.item.productId);
                  }
                : null,
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            label: const Text('見送る'),
          ),
        ),
      ],
    );
  }
}

class _DecisionChip extends StatelessWidget {
  const _DecisionChip({required this.decision});
  final TodayRecommendationDecision decision;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color bg;
    late final Color fg;
    switch (decision) {
      case TodayRecommendationDecision.pending:
        text = '未処理';
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
      case TodayRecommendationDecision.skipped:
        text = '見送り';
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFEF6C00);
      case TodayRecommendationDecision.addedCandidate:
        text = '候補追加済';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 62,
        height: 62,
        color: AppColors.surfaceVariant,
        child: imageUrl.trim().isEmpty
            ? const Icon(Icons.image_outlined, color: AppColors.textTertiary)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
              ),
      ),
    );
  }
}

