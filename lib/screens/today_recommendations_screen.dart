import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/today_recommendation.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_screen_status.dart';

class TodayRecommendationsScreen extends StatefulWidget {
  const TodayRecommendationsScreen({super.key});

  @override
  State<TodayRecommendationsScreen> createState() =>
      _TodayRecommendationsScreenState();
}

class _TodayRecommendationsScreenState
    extends State<TodayRecommendationsScreen> {
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
      appBar: AppBar(title: const Text('今日のおすすめコレ候補')),
      body: SafeArea(
        child: Consumer<TodayRecommendationProvider>(
          builder: (context, rec, _) {
            if (rec.isLoading) {
              return const AppScreenLoadingCenter(
                title: '今日のおすすめを準備しています',
                subtitle:
                    '保存済みのプロフィールや検索履歴に基づき、候補を集めています。通信状況により少し時間がかかることがあります。',
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
              final favoriteGenres = context
                  .read<UserProfileProvider>()
                  .profile
                  .favoriteGenreIdList;
              return AppScreenEmptyCenter(
                icon: Icons.auto_awesome_outlined,
                title: 'まだ今日のおすすめがありません',
                body: favoriteGenres.isEmpty
                    ? 'まずはジャンルを設定すると精度が上がります。登録後に生成すると、好きなジャンルや候補履歴に近い商品を優先します。'
                    : '下のボタンで最大10件のコレ候補を提案します。コレ履歴・候補履歴・保存ショップを使って、あなた向けに並び替えます。',
                actions: [
                  AppPrimaryButton(
                    label: '今日のおすすめを作る',
                    onPressed: _regenerate,
                    icon: const Icon(Icons.auto_awesome_rounded),
                  ),
                ],
              );
            }

            final rows = _RecommendationListRow.fromEntries(bundle.entries);
            return Column(
              children: [
                _SummaryCard(
                  total: bundle.entries.length,
                  pending: rec.pendingCount,
                  completed: rec.isCompleted,
                  onRegenerate: _regenerate,
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row.section != null) {
                        return _RecommendationSectionHeader(
                          section: row.section!,
                          topPadding: index == 0 ? 4 : 16,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecommendationCard(entry: row.entry!),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecommendationListRow {
  const _RecommendationListRow.entry(this.entry) : section = null;
  const _RecommendationListRow.section(this.section) : entry = null;

  final TodayRecommendationEntry? entry;
  final TodayRecommendationSection? section;

  static List<_RecommendationListRow> fromEntries(
    List<TodayRecommendationEntry> entries,
  ) {
    final rows = <_RecommendationListRow>[];
    for (final section in TodayRecommendationSection.values) {
      final sectionEntries = entries
          .where((e) => e.section == section)
          .toList(growable: false);
      if (sectionEntries.isEmpty) continue;
      rows.add(_RecommendationListRow.section(section));
      rows.addAll(sectionEntries.map(_RecommendationListRow.entry));
    }
    return rows;
  }
}

class _RecommendationSectionHeader extends StatelessWidget {
  const _RecommendationSectionHeader({
    required this.section,
    required this.topPadding,
  });

  final TodayRecommendationSection section;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, topPadding, 2, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sectionTitle(section),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _sectionSubtitle(section),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  String _sectionTitle(TodayRecommendationSection section) {
    switch (section) {
      case TodayRecommendationSection.sellable:
        return '売れやすい';
      case TodayRecommendationSection.popular:
        return '人気商品';
      case TodayRecommendationSection.fresh:
        return '新着';
    }
  }

  String _sectionSubtitle(TodayRecommendationSection section) {
    switch (section) {
      case TodayRecommendationSection.sellable:
        return '価格帯とあなた向け度のバランスが良い候補です。';
      case TodayRecommendationSection.popular:
        return 'レビュー評価や件数が強い候補です。';
      case TodayRecommendationSection.fresh:
        return 'いつもの傾向から少し広げた候補です。';
    }
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
    return AppCard(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            completed ? '本日のおすすめはチェック完了です' : '本日のおすすめ $total件（未処理 $pending件）',
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
            child: AppSecondaryButton(
              label: '今日の候補を再生成',
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh_rounded),
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
    return AppCard(
      padding: const EdgeInsets.all(12),
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
                      _formatPrice(item.itemPrice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
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
                    const SizedBox(height: 6),
                    _ReasonChip(reason: entry.reason),
                    const SizedBox(height: 6),
                    _RecommendationTagWrap(entry: entry),
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

String _formatPrice(int price) {
  final raw = price.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return '¥$buffer';
}

class _RecommendationTagWrap extends StatelessWidget {
  const _RecommendationTagWrap({required this.entry});

  final TodayRecommendationEntry entry;

  @override
  Widget build(BuildContext context) {
    final tags = <String>[];
    final item = entry.item;
    if (item.itemPrice >= 2000 && item.itemPrice < 5000) {
      tags.add('売れやすい価格');
    }
    if (entry.reason == '人気商品' ||
        entry.section == TodayRecommendationSection.popular) {
      tags.add('人気商品');
    }
    if (entry.section == TodayRecommendationSection.fresh) {
      tags.add('新しい候補');
    }
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.map((e) => _ProductTag(label: e)).toList(growable: false),
    );
  }
}

class _ProductTag extends StatelessWidget {
  const _ProductTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEF5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.accentPrimary.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          reason,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.accentPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
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
          child: AppPrimaryButton(
            label: '候補にする',
            onPressed: enabled
                ? () async {
                    final rec = context.read<TodayRecommendationProvider>();
                    final managed = context
                        .read<RakutenManagedProductProvider>();
                    final err = await rec.markAddedCandidate(
                      managedProvider: managed,
                      item: entry.item,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(err ?? '候補に追加しました')));
                  }
                : null,
            icon: const Icon(Icons.bookmark_add_rounded),
            height: 44,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppSecondaryButton(
            label: '見送る',
            onPressed: enabled
                ? () async {
                    final rec = context.read<TodayRecommendationProvider>();
                    await rec.markSkipped(entry.item.productId);
                  }
                : null,
            icon: const Icon(Icons.skip_next_rounded),
            expand: true,
            height: 44,
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
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
      ),
    );
  }
}
