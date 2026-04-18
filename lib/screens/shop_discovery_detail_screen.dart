import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_search_item.dart';
import '../models/shop_discovery_summary.dart';
import '../repository/genre_master_repository.dart';
import '../services/app_action_service.dart';
import '../services/rakuten_genre_master_service.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/saved_shop_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import '../widgets/rakuten_search_result_card.dart';
import '../widgets/search_group_screen_shell.dart';
import 'saved_shops_screen.dart';

enum _ShopDetailSort { reviewCount, reviewAverage, priceHigh, priceLow }

class ShopDiscoveryDetailScreen extends StatefulWidget {
  const ShopDiscoveryDetailScreen({
    super.key,
    required this.summary,
    required this.items,
  });

  final ShopDiscoverySummary summary;
  final List<RakutenSearchItem> items;

  @override
  State<ShopDiscoveryDetailScreen> createState() =>
      _ShopDiscoveryDetailScreenState();
}

class _ShopDiscoveryDetailScreenState extends State<ShopDiscoveryDetailScreen> {
  _ShopDetailSort _sort = _ShopDetailSort.reviewCount;

  /// ジャンルAPI解決後の表示名（キーは genreId 文字列）。
  Map<String, String> _genreLabels = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SavedShopProvider>().markViewed(widget.summary.shopKey);
      _prefetchGenreLabels();
    });
  }

  Future<void> _prefetchGenreLabels() async {
    final repo = context.read<GenreMasterRepository>();
    final ids = widget.items
        .map((e) => int.tryParse(e.genreId.trim()))
        .whereType<int>()
        .where((id) => id > 0)
        .toSet();
    if (ids.isEmpty) return;
    final toPrefetch = RakutenGenreMasterService.instance
        .genreIdsNeedingApiPrefetch(ids);
    if (toPrefetch.isEmpty) return;
    try {
      await repo.prefetchGenreMasters(toPrefetch);
      final next = <String, String>{};
      for (final id in toPrefetch) {
        final idStr = '$id';
        final raw = await repo.getGenreName(id);
        if (raw.isNotEmpty && raw != idStr) {
          next[idStr] = raw;
        }
      }
      RakutenGenreMasterService.instance.mergeRuntimeGenreNames(next);
      if (mounted) {
        setState(() => _genreLabels = next);
      }
    } catch (_) {}
  }

  String _genreLineForItem(RakutenSearchItem item) {
    final id = item.genreId.trim();
    if (id.isEmpty) return '';
    final pf = _genreLabels[id];
    return RakutenProductGenreDisplay.resolve(
      apiGenreName: item.genreName,
      persistedGenreName: null,
      prefetchedGenreName: pf,
      genreId: item.genreId,
      traceItemCode: item.productId,
    );
  }

  List<RakutenSearchItem> _sortedItems() {
    final out = List<RakutenSearchItem>.from(widget.items);
    switch (_sort) {
      case _ShopDetailSort.reviewCount:
        out.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
      case _ShopDetailSort.reviewAverage:
        out.sort((a, b) => b.reviewAverage.compareTo(a.reviewAverage));
      case _ShopDetailSort.priceHigh:
        out.sort((a, b) => b.itemPrice.compareTo(a.itemPrice));
      case _ShopDetailSort.priceLow:
        out.sort((a, b) => a.itemPrice.compareTo(b.itemPrice));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final items = _sortedItems();
    final saved = context.watch<SavedShopProvider>();
    final isSaved = saved.isSaved(widget.summary.shopKey);
    return Scaffold(
      backgroundColor: HomeScreenColors.canvas,
      appBar: AppBar(
        title: const Text('ショップ詳細'),
        actions: [
          IconButton(
            tooltip: 'このショップを外部で開く',
            onPressed: () => _openShopUrl(context),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: SearchGroupScreenShell(
        backgroundColor: HomeScreenColors.canvas,
        subtitle: '探すグループ · 発掘・保存ショップから開いた店の商品を並べ替えながら、コレ候補登録につなげます。',
        child: Column(
          children: [
            _ShopDetailHeader(
              shopName: widget.summary.shopName,
              isSaved: isSaved,
              onSaveToggle: () async {
                if (isSaved) {
                  await saved.removeShop(widget.summary.shopKey);
                } else {
                  await saved.upsertShop(
                    shopId: widget.summary.shopKey,
                    shopName: widget.summary.shopName,
                    shopUrl: widget.summary.shopUrl,
                  );
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isSaved ? '保存解除しました' : '保存しました')),
                );
              },
              onBackToSearch: () => Navigator.of(context).maybePop(),
            ),
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(
                0,
                RakutenSearchScreenUi.gapFieldStack + 3,
                0,
                RakutenSearchScreenUi.gapListAfterDivider,
              ),
              padding: const EdgeInsets.all(
                RakutenSearchScreenUi.inputDeckPadding,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                '使い方: 商品検索画面と同じく、各商品カードから「コレ候補へ登録」できます。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                RakutenSearchScreenUi.gapListAfterDivider,
                0,
                RakutenSearchScreenUi.gapResultStatusRowBottom,
              ),
              child: DecoratedBox(
                decoration: RakutenSearchScreenUi.listFilterStripDecoration(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingSm + 2,
                    vertical: AppDimensions.spacingSm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 17,
                        color: HomeScreenColors.statusAccentStrong,
                      ),
                      SizedBox(width: RakutenSearchScreenUi.gapIconToTitle),
                      Expanded(
                        child: Text(
                          '商品一覧（${items.length}件）',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: HomeScreenColors.leadOnSection,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      SizedBox(width: RakutenSearchScreenUi.gapIconToTitle),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: _SortMenu(
                              value: _sort,
                              onChanged: (next) => setState(() => _sort = next),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Consumer<RakutenManagedProductProvider>(
                builder: (context, managed, _) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal:
                              AppDimensions.spacingMd + AppDimensions.spacingSm,
                        ),
                        child: Text(
                          'このショップの表示対象商品がありません。\n'
                          '検索条件を変えて再発掘すると、商品が表示される場合があります。',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      RakutenSearchScreenUi.listScrollTopPad,
                      0,
                      AppDimensions.spacingLg,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.spacingSm + 2),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return RakutenSearchResultCard(
                        item: item,
                        localStatus: managed.statusForProduct(item.productId),
                        isRegistering: managed.isRegistering(item.productId),
                        genreDisplayLineOverride: _genreLineForItem(item),
                        onRegisterCandidate: () async {
                          final err = await managed.registerCandidate(item);
                          if (!context.mounted) return;
                          if (err != null) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(err)));
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openShopUrl(BuildContext context) async {
    final url = widget.summary.shopUrl.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ショップURLが見つかりません')));
      return;
    }
    await AppActionService.openUrl(context, url: url);
  }
}

class _ShopDetailHeader extends StatelessWidget {
  const _ShopDetailHeader({
    required this.shopName,
    required this.isSaved,
    required this.onSaveToggle,
    required this.onBackToSearch,
  });

  final String shopName;
  final bool isSaved;
  final VoidCallback onSaveToggle;
  final VoidCallback onBackToSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(0, RakutenSearchScreenUi.gapSection, 0, 0),
      padding: const EdgeInsets.all(RakutenSearchScreenUi.inputDeckPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shopName,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppDimensions.spacingXs + 2),
          Text(
            'このショップの商品を比較しながら、コレ候補登録まで進められます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: AppDimensions.spacingSm),
          Wrap(
            spacing: AppDimensions.spacingSm,
            runSpacing: AppDimensions.spacingXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onSaveToggle,
                icon: Icon(
                  isSaved
                      ? Icons.bookmark_added_rounded
                      : Icons.bookmark_add_outlined,
                  size: 18,
                ),
                label: Text(isSaved ? '保存済み' : 'このショップを保存'),
              ),
              OutlinedButton.icon(
                onPressed: onBackToSearch,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('条件を変えて再検索'),
              ),
              IconButton(
                tooltip: '保存ショップ一覧を開く',
                icon: const Icon(Icons.bookmarks_outlined, size: 20),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SavedShopsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _shopDetailSortLabel(_ShopDetailSort mode) {
  switch (mode) {
    case _ShopDetailSort.reviewCount:
      return '評価数順';
    case _ShopDetailSort.reviewAverage:
      return '評価点順';
    case _ShopDetailSort.priceHigh:
      return '価格が高い順';
    case _ShopDetailSort.priceLow:
      return '価格が安い順';
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final _ShopDetailSort value;
  final ValueChanged<_ShopDetailSort> onChanged;

  static const List<_ShopDetailSort> _order = [
    _ShopDetailSort.reviewCount,
    _ShopDetailSort.reviewAverage,
    _ShopDetailSort.priceHigh,
    _ShopDetailSort.priceLow,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '並び順',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: HomeScreenColors.footnoteMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        Theme(
          data: Theme.of(
            context,
          ).copyWith(visualDensity: VisualDensity.compact),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_ShopDetailSort>(
              value: value,
              isDense: true,
              alignment: AlignmentDirectional.centerEnd,
              icon: Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: HomeScreenColors.leadOnSection,
              ),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: HomeScreenColors.leadOnSection,
                fontWeight: FontWeight.w700,
              ),
              items: _order
                  .map(
                    (mode) => DropdownMenuItem<_ShopDetailSort>(
                      value: mode,
                      child: Text(_shopDetailSortLabel(mode)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                if (next == null || next == value) return;
                onChanged(next);
              },
            ),
          ),
        ),
      ],
    );
  }
}
