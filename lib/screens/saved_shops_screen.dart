import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_search_item.dart';
import '../models/shop_discovery_summary.dart';
import '../navigation/rakuten_search_navigator.dart';
import '../state/saved_shop_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_screen_status.dart';
import '../widgets/search_group_screen_shell.dart';
import 'shop_discovery_detail_screen.dart';

class SavedShopsScreen extends StatelessWidget {
  const SavedShopsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeScreenColors.canvas,
      appBar: AppBar(
        title: const Text('保存ショップ'),
        actions: [
          IconButton(
            tooltip: 'ショップ発掘へ',
            onPressed: () {
              openRakutenSearchScreen(
                context,
                initialMode: RakutenSearchInitialMode.shopDiscovery,
              );
            },
            icon: const Icon(Icons.travel_explore_rounded),
          ),
        ],
      ),
      body: SearchGroupScreenShell(
        backgroundColor: HomeScreenColors.canvas,
        subtitle: '探すグループ · 楽天検索やショップ発掘で保存したショップを一覧し、再訪やコレ候補登録につなげます。',
        child: Consumer<SavedShopProvider>(
          builder: (context, saved, _) {
            final shops = saved.shops;
            if (shops.isEmpty) {
              return AppScreenEmptyCenter(
                icon: Icons.bookmarks_outlined,
                title: '保存ショップはまだありません',
                body: '楽天検索の「ショップ発掘」で候補を探し、気に入ったショップを保存すると、ここからすぐ開けます。',
                actions: [
                  AppPrimaryButton(
                    label: 'ショップ発掘を開く',
                    onPressed: () {
                      openRakutenSearchScreen(
                        context,
                        initialMode: RakutenSearchInitialMode.shopDiscovery,
                      );
                    },
                    icon: const Icon(Icons.travel_explore_rounded),
                  ),
                ],
              );
            }
            final viewedCount = shops
                .where((e) => e.lastViewedAt != null)
                .length;
            return Column(
              children: [
                _SavedShopsSummaryCard(
                  totalCount: shops.length,
                  viewedCount: viewedCount,
                  onOpenDiscovery: () {
                    openRakutenSearchScreen(
                      context,
                      initialMode: RakutenSearchInitialMode.shopDiscovery,
                    );
                  },
                ),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      RakutenSearchScreenUi.listScrollTopPad,
                      0,
                      AppDimensions.spacingLg,
                    ),
                    itemCount: shops.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.spacingSm + 2),
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
                            SnackBar(
                              content: Text('「${shop.shopName}」を保存解除しました'),
                            ),
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
    return SizedBox(
      width: double.infinity,
      child: AppCard(
        margin: EdgeInsets.fromLTRB(
          0,
          RakutenSearchScreenUi.gapSection,
          0,
          RakutenSearchScreenUi.gapListAfterDivider,
        ),
        padding: const EdgeInsets.all(RakutenSearchScreenUi.inputDeckPadding),
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
            SizedBox(height: RakutenSearchScreenUi.gapFieldStack + 3),
            Align(
              alignment: Alignment.centerRight,
              child: AppSecondaryButton(
                label: 'ショップ発掘へ戻る',
                onPressed: onOpenDiscovery,
                icon: const Icon(Icons.travel_explore_rounded),
              ),
            ),
          ],
        ),
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
    return AppCard(
      padding: const EdgeInsets.all(RakutenSearchScreenUi.inputDeckPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            shopName,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppDimensions.spacingXs + 2),
          Text(
            '保存日: ${_format(savedAt)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          SizedBox(height: AppDimensions.spacingXs / 2),
          Text(
            '最終閲覧: ${lastViewedAt == null ? '未閲覧' : _format(lastViewedAt!)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          SizedBox(height: AppDimensions.spacingSm),
          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  label: 'このショップを見る',
                  onPressed: onOpen,
                  icon: const Icon(Icons.storefront_outlined),
                  height: 44,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: AppSecondaryButton(
                  label: '保存解除',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  expand: true,
                  height: 44,
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
