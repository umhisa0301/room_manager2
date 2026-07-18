import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/rakuten_search_navigator.dart';
import '../services/app_action_service.dart';
import '../state/saved_shop_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/mypage_screen_tokens.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import '../ui/feedback/app_feedback.dart';
import '../widgets/app_card.dart';
import '../widgets/app_screen_status.dart';
import '../widgets/mypage/mypage_widgets.dart';
import '../widgets/search_group_screen_shell.dart';

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
        subtitle: '保存した楽天ショップを管理します。「このショップで探す」から店内キーワード検索へ進めます。',
        child: Consumer<SavedShopProvider>(
          builder: (context, saved, _) {
            final shops = saved.shops;
            if (shops.isEmpty) {
              return AppScreenEmptyCenter(
                icon: Icons.bookmarks_outlined,
                title: '保存ショップはまだありません',
                body: 'ショップ発掘などでショップを保存すると、ここから検索やページ閲覧に再利用できます。',
                actions: [
                  MyPagePrimaryButton(
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
                        shopId: shop.shopId,
                        shopName: shop.shopName,
                        shopUrl: shop.shopUrl,
                        savedAt: shop.savedAt,
                        lastViewedAt: shop.lastViewedAt,
                        isBusy: saved.isShopBusy(shop.shopId),
                        onSearchInShop: () async {
                          await saved.markViewed(shop.shopId);
                          if (!context.mounted) return;
                          await openRakutenSearchScreen(
                            context,
                            savedShopKeywordEntry: true,
                            initialSavedShopCode: shop.shopId,
                          );
                        },
                        onOpenShopUrl: () async {
                          await saved.markViewed(shop.shopId);
                          if (!context.mounted) return;
                          final url = shop.shopUrl.trim();
                          if (url.isEmpty) {
                            AppFeedback.error(
                              context,
                              message: 'ショップURLが登録されていません',
                            );
                            return;
                          }
                          await AppActionService.openUrl(context, url: url);
                        },
                        onRemove: () async {
                          if (saved.isShopBusy(shop.shopId)) return;
                          final ok = await saved.removeShop(shop.shopId);
                          if (!context.mounted || !ok) return;
                          AppFeedback.success(
                            context,
                            message: 'ショップの保存を解除しました',
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
              '保存ショップの解除・店内検索の起点として使います。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: RakutenSearchScreenUi.gapFieldStack + 3),
            Align(
              alignment: Alignment.centerRight,
              child: MyPageOutlineButton(
                label: 'ショップ発掘へ戻る',
                onPressed: onOpenDiscovery,
                icon: const Icon(Icons.travel_explore_rounded),
                expand: false,
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
    required this.shopId,
    required this.shopName,
    required this.shopUrl,
    required this.savedAt,
    required this.lastViewedAt,
    required this.isBusy,
    required this.onSearchInShop,
    required this.onOpenShopUrl,
    required this.onRemove,
  });

  final String shopId;
  final String shopName;
  final String shopUrl;
  final DateTime savedAt;
  final DateTime? lastViewedAt;
  final bool isBusy;
  final Future<void> Function() onSearchInShop;
  final Future<void> Function() onOpenShopUrl;
  final Future<void> Function() onRemove;

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
            'ショップID: $shopId',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
          SizedBox(height: AppDimensions.spacingXs / 2),
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
          MyPagePrimaryButton(
            label: 'このショップで探す',
            onPressed: () => onSearchInShop(),
            icon: const Icon(Icons.search_rounded),
            height: 46,
          ),
          SizedBox(height: AppDimensions.spacingSm),
          Row(
            children: [
              Expanded(
                child: MyPageOutlineButton(
                  label: 'ショップページを開く',
                  onPressed: shopUrl.trim().isEmpty
                      ? null
                      : () => onOpenShopUrl(),
                  icon: const Icon(Icons.open_in_new_rounded),
                  height: 44,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onRemove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MyPageScreenUi.textSecondary,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    side: BorderSide(color: MyPageScreenUi.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isBusy)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MyPageScreenUi.textSecondary,
                          ),
                        )
                      else
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: MyPageScreenUi.textSecondary,
                        ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isBusy ? '解除中…' : '保存解除',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
