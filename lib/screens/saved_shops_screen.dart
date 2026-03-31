import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_search_item.dart';
import '../models/shop_discovery_summary.dart';
import '../state/saved_shop_provider.dart';
import '../theme/app_theme.dart';
import 'rakuten_search_screen.dart';
import 'shop_discovery_detail_screen.dart';

class SavedShopsScreen extends StatelessWidget {
  const SavedShopsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('保存ショップ'),
        actions: [
          IconButton(
            tooltip: 'ショップ発掘へ',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RakutenSearchScreen(),
                ),
              );
            },
            icon: const Icon(Icons.travel_explore_rounded),
          ),
        ],
      ),
      body: Consumer<SavedShopProvider>(
        builder: (context, saved, _) {
          final shops = saved.shops;
          if (shops.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '保存ショップはまだありません。\nショップ発掘結果から保存できます。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RakutenSearchScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.travel_explore_rounded, size: 18),
                      label: const Text('ショップ発掘へ'),
                    ),
                  ],
                ),
              ),
            );
          }
          final viewedCount = shops.where((e) => e.lastViewedAt != null).length;
          return Column(
            children: [
              _SavedShopsSummaryCard(
                totalCount: shops.length,
                viewedCount: viewedCount,
                onOpenDiscovery: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RakutenSearchScreen(),
                    ),
                  );
                },
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: shops.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    return _SavedShopCard(
                      shopName: shop.shopName,
                      savedAt: shop.savedAt,
                      lastViewedAt: shop.lastViewedAt,
                      onOpen: () async {
                        await saved.markViewed(shop.shopId);
                        if (!context.mounted) return;
                        final summary = ShopDiscoverySummary(
                          shopKey: shop.shopId,
                          shopName: shop.shopName,
                          shopUrl: shop.shopUrl,
                          hitItemCount: 0,
                          maxReviewCount: 0,
                          avgReviewAverage: 0,
                          discoveryScore: 0,
                          representativeItems: const [],
                        );
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ShopDiscoveryDetailScreen(
                              summary: summary,
                              items: const <RakutenSearchItem>[],
                            ),
                          ),
                        );
                      },
                      onRemove: () async {
                        await saved.removeShop(shop.shopId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('「${shop.shopName}」を保存解除しました')),
                        );
                      },
                    );
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

class _SavedShopsSummaryCard extends StatelessWidget {
  const _SavedShopsSummaryCard({
    required this.totalCount,
    required this.viewedCount,
    required this.onOpenDiscovery,
  });

  final int totalCount;
  final int viewedCount;
  final VoidCallback onOpenDiscovery;

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
            '保存 $totalCount件 / 閲覧済み $viewedCount件\n'
            '保存ショップから再訪して、候補登録を続けられます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onOpenDiscovery,
              icon: const Icon(Icons.travel_explore_rounded, size: 18),
              label: const Text('ショップ発掘へ戻る'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedShopCard extends StatelessWidget {
  const _SavedShopCard({
    required this.shopName,
    required this.savedAt,
    required this.lastViewedAt,
    required this.onOpen,
    required this.onRemove,
  });

  final String shopName;
  final DateTime savedAt;
  final DateTime? lastViewedAt;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
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
          Text(
            shopName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '保存日: ${_format(savedAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            '最終閲覧: ${lastViewedAt == null ? '未閲覧' : _format(lastViewedAt!)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: const Text('このショップを見る'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('保存解除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _format(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
