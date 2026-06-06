import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog_product.dart';
import '../models/rakuten_search_item.dart';
import '../models/shop_discovery_summary.dart';
import '../models/rakuten_product_search_condition.dart';
import '../navigation/rakuten_search_navigator.dart';
import '../repository/genre_master_repository.dart';
import '../repository/product_catalog_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../services/app_action_service.dart';
import '../services/rakuten_genre_master_service.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../utils/catalog_product_mapper.dart';
import '../utils/product_catalog_audit.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/saved_shop_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import '../utils/app_debug_log.dart';
import '../widgets/app_button.dart';
import '../widgets/rakuten_search_result_card.dart';
import '../utils/search_tab_ui_audit_log.dart';
import '../widgets/search_group_screen_shell.dart';
import 'saved_shops_screen.dart';

enum _ShopDetailSort { reviewCount, reviewAverage, priceHigh, priceLow }

class ShopDiscoveryDetailScreen extends StatefulWidget {
  const ShopDiscoveryDetailScreen({
    super.key,
    required this.summary,
    required this.items,
    this.discoveryRank,
  });

  final ShopDiscoverySummary summary;
  final List<RakutenSearchItem> items;
  final int? discoveryRank;

  @override
  State<ShopDiscoveryDetailScreen> createState() =>
      _ShopDiscoveryDetailScreenState();
}

class _ShopDiscoveryDetailScreenState extends State<ShopDiscoveryDetailScreen> {
  _ShopDetailSort _sort = _ShopDetailSort.reviewCount;
  final ScrollController _detailItemsScrollController = ScrollController();

  /// 表示用商品（保存ショップ等で初期が空のときは shopCode 検索で埋める）。
  late List<RakutenSearchItem> _items;
  bool _shopItemsLoading = false;
  String? _shopItemsError;
  bool _didRequestShopItems = false;

  /// ジャンルAPI解決後の表示名（キーは genreId 文字列）。
  Map<String, String> _genreLabels = const {};

  final ShopDiscoveryDetailCatalogUpsertGuard _catalogUpsertGuard =
      ShopDiscoveryDetailCatalogUpsertGuard();

  bool get _shouldLoadItemsFromShopCode =>
      widget.items.isEmpty && widget.summary.shopKey.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _items = List<RakutenSearchItem>.from(widget.items);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SavedShopProvider>().markViewed(widget.summary.shopKey);
      if (_shouldLoadItemsFromShopCode) {
        unawaited(_loadItemsFromShopCode());
      } else {
        unawaited(_prepareInitialItems());
      }
    });
  }

  Future<void> _prepareInitialItems() async {
    await _prefetchGenreLabelsFor(_items);
    if (!mounted) return;
    await _upsertItemsToProductCatalog(
      _items,
      upsertSource: 'initialItems',
      sourceTrust: CatalogProductSourceTrust.medium,
    );
  }

  ProductCatalogRepository? _readProductCatalogRepository() {
    try {
      return context.read<ProductCatalogRepository>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _upsertItemsToProductCatalog(
    List<RakutenSearchItem> items, {
    required String upsertSource,
    required CatalogProductSourceTrust sourceTrust,
  }) async {
    if (items.isEmpty) {
      logShopDiscoveryDetailCatalogAudit(
        repository: _readProductCatalogRepository(),
        shopCode: widget.summary.shopKey,
        itemsFromSearch: 0,
        wouldFetchFromApiIfEmpty: _shouldLoadItemsFromShopCode,
        catalogUpsertOnOpen: false,
      );
      return;
    }

    final shouldUpsert = upsertSource == 'loadedByShopCode'
        ? _catalogUpsertGuard.shouldUpsertLoaded(items)
        : _catalogUpsertGuard.shouldUpsertInitial(items);
    if (!shouldUpsert) return;

    final repo = _readProductCatalogRepository();
    if (repo == null) return;

    var upserted = 0;
    try {
      final summary = await upsertCatalogFromShopDiscoveryDetailItems(
        repo,
        items,
        shopCode: widget.summary.shopKey,
        upsertSource: upsertSource,
        sourceTrust: sourceTrust,
      );
      upserted = summary.upserted;
      if (upsertSource == 'loadedByShopCode') {
        _catalogUpsertGuard.markLoadedUpserted(items);
      } else {
        _catalogUpsertGuard.markInitialUpserted(items);
      }
    } catch (_) {
      // upsert 失敗でも詳細画面は継続
    }

    if (!mounted) return;
    logShopDiscoveryDetailCatalogAudit(
      repository: repo,
      shopCode: widget.summary.shopKey,
      itemsFromSearch: items.length,
      wouldFetchFromApiIfEmpty: _shouldLoadItemsFromShopCode,
      catalogUpsertOnOpen: upserted > 0,
    );
  }

  @override
  void dispose() {
    _detailItemsScrollController.dispose();
    super.dispose();
  }

  void _scheduleShopDetailViewportAudit({
    required BuildContext context,
    required int resultCount,
    required double bottomPadding,
  }) {
    if (!kDebugMode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      var listViewportHeight = -1.0;
      var bottomSpaceEstimate = -1.0;
      var firstItemVisible = false;
      if (_detailItemsScrollController.hasClients) {
        final pos = _detailItemsScrollController.position;
        listViewportHeight = pos.viewportDimension;
        bottomSpaceEstimate =
            (pos.viewportDimension - pos.maxScrollExtent - bottomPadding).clamp(
              0.0,
              double.infinity,
            );
        firstItemVisible = pos.pixels <= 1;
      }
      shopDetailResultViewportAuditLog(
        'shopName=${widget.summary.shopName} resultCount=$resultCount '
        'headerHeight=shopDetailHeader+filter listViewportHeight=$listViewportHeight '
        'bottomPadding=$bottomPadding firstItemVisible=$firstItemVisible '
        'bottomSpaceEstimate=$bottomSpaceEstimate',
      );
    });
  }

  Future<void> _loadItemsFromShopCode() async {
    final code = widget.summary.shopKey.trim();
    if (code.isEmpty) return;
    setState(() {
      _shopItemsLoading = true;
      _shopItemsError = null;
      _didRequestShopItems = true;
    });
    try {
      final repo = context.read<RakutenSearchRepository>();
      final fetched = await repo.search(
        condition: RakutenProductSearchCondition(keyword: '', shopCode: code),
      );
      if (!mounted) return;
      setState(() {
        _items = fetched;
        _shopItemsLoading = false;
      });
      await _prefetchGenreLabelsFor(_items);
      if (!mounted) return;
      await _upsertItemsToProductCatalog(
        _items,
        upsertSource: 'loadedByShopCode',
        sourceTrust: CatalogProductSourceTrust.high,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _shopItemsLoading = false;
        _shopItemsError = e.toString();
      });
    }
  }

  Future<void> _prefetchGenreLabelsFor(List<RakutenSearchItem> items) async {
    final repo = context.read<GenreMasterRepository>();
    final ids = items
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
        setState(() => _genreLabels = {..._genreLabels, ...next});
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
    final out = List<RakutenSearchItem>.from(_items);
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
      appBar: AppBar(title: const Text('ショップ詳細')),
      body: SearchGroupScreenShell(
        backgroundColor: HomeScreenColors.canvas,
        subtitle: '探すグループ · 並べ替えたうえで各商品から「候補に追加」し、コレ登録まで進められます。',
        child: Column(
          children: [
            _ShopDetailHeader(
              shopName: widget.summary.shopName,
              isSaved: isSaved,
              canSave: widget.summary.shopKey.trim().isNotEmpty &&
                  widget.summary.shopName.trim().isNotEmpty,
              onSaveShop: () => _saveShop(context, saved),
              onBackToSearch: () => Navigator.of(context).maybePop(),
              onOpenExternal: () => _openShopUrl(context),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                RakutenSearchScreenUi.gapFieldStack,
                0,
                RakutenSearchScreenUi.gapResultStatusRowBottom,
              ),
              child: DecoratedBox(
                decoration: RakutenSearchScreenUi.listFilterStripDecoration(),
                child: Padding(
                  padding: RakutenSearchScreenUi.listFilterStripInnerPadding,
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
                          '商品${items.length}件',
                          maxLines: 1,
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
                  if (_shopItemsLoading) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          SizedBox(
                            height: RakutenSearchScreenUi.gapFieldStack + 4,
                          ),
                          Text(
                            'ショップの商品を読み込み中…',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (_shopItemsError != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal:
                              AppDimensions.spacingMd + AppDimensions.spacingSm,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '商品一覧の取得に失敗しました。\n$_shopItemsError',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                            ),
                            SizedBox(height: RakutenSearchScreenUi.gapSection),
                            AppPrimaryButton(
                              label: '再読み込み',
                              expand: false,
                              onPressed: _loadItemsFromShopCode,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal:
                              AppDimensions.spacingMd + AppDimensions.spacingSm,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 44,
                              color: AppColors.textTertiary.withValues(
                                alpha: 0.65,
                              ),
                            ),
                            SizedBox(
                              height: RakutenSearchScreenUi.gapFieldStack,
                            ),
                            Text(
                              '商品を見つけられませんでした',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            SizedBox(height: AppDimensions.spacingSm),
                            Text(
                              _didRequestShopItems && _items.isEmpty
                                  ? '公開商品がないか、一覧取得の条件により表示できないことがあります。'
                                  : widget.summary.shopKey.trim().isEmpty
                                  ? 'ショップ情報がないため商品を表示できません。保存ショップ一覧から開き直してください。'
                                  : 'まだ表示できる商品がありません。発掘画面の条件を変えて探し直すと表示される場合があります。',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                            ),
                            if (_shouldLoadItemsFromShopCode ||
                                _didRequestShopItems) ...[
                              SizedBox(
                                height: RakutenSearchScreenUi.gapSection,
                              ),
                              AppPrimaryButton(
                                label: '商品名で探す',
                                expand: false,
                                onPressed: () {
                                  openRakutenSearchScreen(
                                    context,
                                    initialMode:
                                        RakutenSearchInitialMode.product,
                                  );
                                },
                                icon: const Icon(Icons.search_rounded),
                              ),
                              SizedBox(height: AppDimensions.spacingSm),
                              AppSecondaryButton(
                                label: '再取得',
                                expand: false,
                                onPressed: _loadItemsFromShopCode,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                              SizedBox(height: AppDimensions.spacingSm),
                              AppSecondaryButton(
                                label: 'ショップを楽天で開く',
                                expand: false,
                                onPressed: () => _openShopUrl(context),
                                icon: const Icon(Icons.open_in_new_rounded),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }
                  final detailBottomPad = RakutenSearchScreenUi.listBottomPad;
                  _scheduleShopDetailViewportAudit(
                    context: context,
                    resultCount: items.length,
                    bottomPadding: detailBottomPad,
                  );
                  return ListView.separated(
                    controller: _detailItemsScrollController,
                    padding: EdgeInsets.fromLTRB(
                      RakutenSearchScreenUi.screenPadH,
                      RakutenSearchScreenUi.listScrollTopPad,
                      RakutenSearchScreenUi.screenPadH,
                      detailBottomPad,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: RakutenSearchScreenUi.listCardGap),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return RakutenSearchResultCard(
                        item: item,
                        localStatus: managed.statusForProduct(item.productId),
                        isRegistering: managed.isRegistering(item.productId),
                        genreDisplayLineOverride: _genreLineForItem(item),
                        sourceContextLabel: _shouldLoadItemsFromShopCode
                            ? '保存ショップ'
                            : null,
                        compactListLayout: _shouldLoadItemsFromShopCode,
                        onRegisterCandidate: () async {
                          final err = await managed.registerCandidate(item);
                          if (!context.mounted) return;
                          if (err != null) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(err)));
                          } else {
                            _logFallbackAction(
                              action: 'addProductsToCandidate',
                              itemCount: 1,
                            );
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

  Future<void> _saveShop(
    BuildContext context,
    SavedShopProvider saved,
  ) async {
    final shopCode = widget.summary.shopKey.trim();
    final shopName = widget.summary.shopName.trim();
    if (saved.isSaved(shopCode)) {
      return;
    }
    if (shopCode.isEmpty || shopName.isEmpty) {
      _logSaveShopResult(
        shopCode: shopCode,
        shopName: shopName,
        result: 'failure',
        reason: 'missingShopInfo',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ショップ情報が不足しているため保存できません')),
      );
      return;
    }
    try {
      await saved.upsertShop(
        shopId: shopCode,
        shopName: shopName,
        shopUrl: widget.summary.shopUrl,
      );
      if (!saved.isSaved(shopCode)) {
        throw StateError('save verification failed');
      }
      _logSaveShopResult(
        shopCode: shopCode,
        shopName: shopName,
        result: 'success',
      );
      _logFallbackAction(action: 'saveShop');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ショップを保存しました')),
      );
    } catch (e) {
      _logSaveShopResult(
        shopCode: shopCode,
        shopName: shopName,
        result: 'failure',
        reason: e.toString(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ショップの保存に失敗しました: $e')),
      );
    }
  }

  void _logSaveShopResult({
    required String shopCode,
    required String shopName,
    required String result,
    String? reason,
  }) {
    final codeForLog = shopCode.isEmpty ? '-' : shopCode;
    final nameForLog = shopName.isEmpty ? '-' : shopName;
    var message =
        '[SHOP_DISCOVERY_SAVE_SHOP] source=detail '
        'shopCode=$codeForLog shopName=$nameForLog result=$result';
    if (reason != null && reason.trim().isNotEmpty) {
      message = '$message reason=$reason';
    }
    shopDiscoveryUserActionLog(message);
  }

  Future<void> _openShopUrl(BuildContext context) async {
    final url = widget.summary.shopUrl.trim();
    if (kDebugMode) {
      shopDetailExternalButtonCopyAuditLog(
        'oldLabel=外部で開く newLabel=楽天で開く opensRakuten=true '
        'urlType=${url.isEmpty ? 'unknown' : 'shopUrl'}',
      );
    }
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ショップURLが見つかりません')));
      return;
    }
    await AppActionService.openUrl(context, url: url);
  }

  void _logFallbackAction({required String action, int? itemCount}) {
    if (widget.summary.origin != 'shopPoolFallback') return;
    final keyword = (widget.summary.discoveryKeyword ?? '').trim();
    final keywordForLog = keyword.isEmpty ? '-' : keyword;
    var message =
        '[SHOP_DISCOVERY_FALLBACK_ACTION] action=$action '
        'shopCode=${widget.summary.shopKey} '
        'origin=shopPoolFallback '
        'keyword=$keywordForLog '
        'rank=${widget.summary.discoveryRank ?? widget.discoveryRank ?? -1}';
    if (itemCount != null) {
      message = '$message itemCount=$itemCount';
    }
    catalogOrRoomAuditLog(message);
  }
}

class _ShopDetailHeader extends StatelessWidget {
  const _ShopDetailHeader({
    required this.shopName,
    required this.isSaved,
    required this.canSave,
    required this.onSaveShop,
    required this.onBackToSearch,
    required this.onOpenExternal,
  });

  final String shopName;
  final bool isSaved;
  final bool canSave;
  final VoidCallback onSaveShop;
  final VoidCallback onBackToSearch;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(0, RakutenSearchScreenUi.gapSection, 0, 0),
      padding: const EdgeInsets.all(RakutenSearchScreenUi.inputDeckPadding),
      decoration: RakutenSearchScreenUi.outerSectionShellDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shopName,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: AppDimensions.spacingSm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (canSave)
                _HeaderMiniButton(
                  key: const Key('shop_discovery_detail_save_shop'),
                  filled: isSaved,
                  label: isSaved ? '保存済み' : 'このショップを保存',
                  icon: Icon(
                    isSaved
                        ? Icons.bookmark_added_rounded
                        : Icons.bookmark_add_outlined,
                    size: 18,
                  ),
                  onPressed: isSaved ? null : onSaveShop,
                ),
              _HeaderMiniButton(
                label: '条件変更',
                icon: const Icon(Icons.tune_rounded, size: 18),
                onPressed: onBackToSearch,
              ),
              _HeaderMiniButton(
                label: '楽天で開く',
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                onPressed: () {
                  if (kDebugMode) {
                    shopDetailExternalButtonCopyAuditLog(
                      'oldLabel=外部で開く newLabel=楽天で開く opensRakuten=true urlType=shopUrl',
                    );
                  }
                  onOpenExternal();
                },
              ),
              IconButton(
                tooltip: 'その他',
                icon: const Icon(Icons.more_horiz_rounded, size: 22),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  final choice = await showModalBottomSheet<String>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.bookmarks_outlined),
                              title: const Text('保存ショップ一覧'),
                              onTap: () => Navigator.pop(ctx, 'saved'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                  if (!context.mounted || choice == null) return;
                  if (choice == 'saved') {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SavedShopsScreen(),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMiniButton extends StatelessWidget {
  const _HeaderMiniButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: filled
          ? AppColors.accentPrimary
          : AppColors.textSecondary,
      backgroundColor: filled
          ? AppColors.accentLight.withValues(alpha: 0.42)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: filled
              ? AppColors.accentPrimary.withValues(alpha: 0.22)
              : AppColors.divider.withValues(alpha: 0.75),
        ),
      ),
    );
    return TextButton.icon(
      onPressed: onPressed,
      style: style,
      icon: icon,
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
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
    return Theme(
      data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
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
    );
  }
}
