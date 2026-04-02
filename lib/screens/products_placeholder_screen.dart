import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../navigation/app_shell_controller.dart';
import '../repository/done_tab_notice_repository.dart';
import '../repository/room_colle_ui_state_repository.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_screen_status.dart';
import '../widgets/rakuten_managed_product_card.dart';
import 'rakuten_search_screen.dart';

/// ROOMコレ一覧専用。アプリ共通 [AppDimensions.screenPaddingH] より詰め密度を上げる。
const double _kRoomListScreenPadH = 12;
const double _kRoomListCardGap = 6;

bool _roomColleScreenHasExplicitRouteArgs(ProductsPlaceholderScreen widget) {
  return widget.initialDoneFilterLocalDay != null ||
      (widget.initialFocusCandidateProductId?.isNotEmpty ?? false) ||
      widget.initialTabIndex != 0;
}

bool _managedProductMatchesQuery(RakutenManagedProduct e, String t) {
  return e.itemName.toLowerCase().contains(t) ||
      e.shopName.toLowerCase().contains(t) ||
      e.productId.toLowerCase().contains(t) ||
      e.itemUrl.toLowerCase().contains(t) ||
      e.shopCode.toLowerCase().contains(t) ||
      e.genreId.toLowerCase().contains(t);
}

/// キーワード絞り込み（1件のデータ破損で全体を失敗させない）。
List<RakutenManagedProduct> _filterManagedProductsByQuery(
  List<RakutenManagedProduct> items,
  String query,
) {
  final t = query.trim().toLowerCase();
  if (t.isEmpty) return List<RakutenManagedProduct>.from(items);
  final out = <RakutenManagedProduct>[];
  for (final e in items) {
    try {
      if (_managedProductMatchesQuery(e, t)) out.add(e);
    } catch (err, st) {
      assert(() {
        debugPrint('[ROOMコレ] キーワード判定スキップ productId=${e.productId}: $err\n$st');
        return true;
      }());
    }
  }
  return out;
}

/// 同一 productId の重複は先勝ち（GlobalKey 衝突・描画クラッシュ防止）。
List<RakutenManagedProduct> _dedupeManagedProductsPreserveOrder(
  List<RakutenManagedProduct> items,
) {
  final seen = <String>{};
  final out = <RakutenManagedProduct>[];
  for (final e in items) {
    final id = e.productId.trim();
    if (id.isEmpty || seen.contains(id)) continue;
    seen.add(id);
    out.add(e);
  }
  return out;
}

/// コレ済の暦日フィルタを安全なローカル日付に正規化（不正値は null）。
DateTime? _normalizeDoneDayFilter(DateTime? raw) {
  if (raw == null) return null;
  try {
    final y = raw.year;
    if (y < 1900 || y > 2100) return null;
    return DateTime(raw.year, raw.month, raw.day);
  } catch (_) {
    return null;
  }
}

/// 一覧タブと同じ管線で表示リストを求める（URL未取得除外はコレ候補タブのみ適用）。
List<RakutenManagedProduct> _roomListVisibleItems({
  required RakutenManagedProductProvider provider,
  required RakutenManagedProductStatus status,
  required String filterQuery,
  required bool excludeUrlNotReady,
  DateTime? doneAtLocalDayFilter,
}) {
  final baseList = provider.sortedItemsForStatus(status);
  final day = doneAtLocalDayFilter;
  final scoped = status == RakutenManagedProductStatus.done && day != null
      ? _filterDoneOnLocalCalendarDay(baseList, day)
      : baseList;
  final urlActive =
      status == RakutenManagedProductStatus.candidate && excludeUrlNotReady;
  final urlScoped = _filterExcludeUrlNotReady(scoped, urlActive);
  final queried = _filterManagedProductsByQuery(urlScoped, filterQuery);
  return _dedupeManagedProductsPreserveOrder(queried);
}

/// タブ表示件数を [_roomListVisibleItems] に揃える。
int _roomColleVisibleCount({
  required RakutenManagedProductProvider provider,
  required RakutenManagedProductStatus status,
  required String filterQuery,
  required bool excludeUrlNotReady,
  DateTime? doneAtLocalDayFilter,
}) {
  return _roomListVisibleItems(
    provider: provider,
    status: status,
    filterQuery: filterQuery,
    excludeUrlNotReady: excludeUrlNotReady,
    doneAtLocalDayFilter: doneAtLocalDayFilter,
  ).length;
}

/// [anchor] のローカル暦日と同一日の [doneAt] をもつコレ済のみ。
List<RakutenManagedProduct> _filterDoneOnLocalCalendarDay(
  List<RakutenManagedProduct> items,
  DateTime anchor,
) {
  try {
    final target = DateTime(anchor.year, anchor.month, anchor.day);
    return items.where((e) {
      final d = e.doneAt;
      if (d == null) return false;
      try {
        final localDay = DateTime(d.year, d.month, d.day);
        return localDay == target;
      } catch (_) {
        return false;
      }
    }).toList();
  } catch (_) {
    return <RakutenManagedProduct>[];
  }
}

/// ON のとき、URL が取得済みで開ける商品だけ残す（コレ前の絞り込み用）。
List<RakutenManagedProduct> _filterExcludeUrlNotReady(
  List<RakutenManagedProduct> items,
  bool enabled,
) {
  if (!enabled) return items;
  return items.where((e) {
    if (e.extractionStatus != RakutenUrlExtractionStatus.success) {
      return false;
    }
    return e.extractedUrl.trim().isNotEmpty ||
        e.affiliateUrl.trim().isNotEmpty ||
        e.itemUrl.trim().isNotEmpty;
  }).toList();
}

/// 各タブ一覧エリアの表面状態（読込 / 表示成功の内訳 / 失敗）。デバッグは [debugLabel]。
enum _RoomColleListSurface {
  loading,
  loadError,
  readyEmptyNoData,
  readyEmptyFilteredByDay,
  readyEmptyFilteredByUrl,
  readyEmptyFilteredBySearch,
  readyEmptyAnomaly,
  readyList,
}

extension on _RoomColleListSurface {
  String get debugLabel {
    switch (this) {
      case _RoomColleListSurface.loading:
        return 'loading';
      case _RoomColleListSurface.loadError:
        return 'load_error';
      case _RoomColleListSurface.readyEmptyNoData:
        return 'ok_empty_no_data';
      case _RoomColleListSurface.readyEmptyFilteredByDay:
        return 'ok_empty_filter_day';
      case _RoomColleListSurface.readyEmptyFilteredByUrl:
        return 'ok_empty_filter_url';
      case _RoomColleListSurface.readyEmptyFilteredBySearch:
        return 'ok_empty_filter_search';
      case _RoomColleListSurface.readyEmptyAnomaly:
        return 'ok_empty_anomaly';
      case _RoomColleListSurface.readyList:
        return 'ok_list';
    }
  }
}

/// [idle] / [ready] はここでは表示可能として扱い、[loading] / [error] と 0件の内訳を返す。
_RoomColleListSurface _resolveRoomColleListSurface({
  required RakutenManagedProductListUiStatus ui,
  required List<RakutenManagedProduct> baseList,
  required List<RakutenManagedProduct> scoped,
  required List<RakutenManagedProduct> list,
  required List<RakutenManagedProduct> urlScoped,
  required bool urlActive,
  required String filterQuery,
  required bool hasDayFilter,
  required bool canShowDayEmptyMessage,
}) {
  if (ui == RakutenManagedProductListUiStatus.loading) {
    return _RoomColleListSurface.loading;
  }
  if (ui == RakutenManagedProductListUiStatus.error) {
    return _RoomColleListSurface.loadError;
  }

  if (baseList.isEmpty) {
    return _RoomColleListSurface.readyEmptyNoData;
  }

  if (hasDayFilter &&
      scoped.isEmpty &&
      canShowDayEmptyMessage) {
    return _RoomColleListSurface.readyEmptyFilteredByDay;
  }

  if (list.isEmpty) {
    final q = filterQuery.trim();
    if (urlActive && scoped.isNotEmpty && urlScoped.isEmpty) {
      return _RoomColleListSurface.readyEmptyFilteredByUrl;
    }
    if (scoped.isNotEmpty && q.isNotEmpty) {
      return _RoomColleListSurface.readyEmptyFilteredBySearch;
    }
    return _RoomColleListSurface.readyEmptyAnomaly;
  }

  return _RoomColleListSurface.readyList;
}

Widget _roomColleRefreshableScroll(
  RakutenManagedProductProvider provider, {
  required Widget child,
}) {
  return RefreshIndicator(
    onRefresh: () =>
        provider.refreshManagedProductList(showLoadingIndicator: true),
    child: child,
  );
}

/// ROOMコレ管理画面。楽天検索で登録したコレ候補・コレ済をタブで表示する。
class ProductsPlaceholderScreen extends StatefulWidget {
  const ProductsPlaceholderScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialDoneFilterLocalDay,
    this.initialFocusCandidateProductId,
  });

  /// 0: コレ候補、1: コレ済
  final int initialTabIndex;

  /// 指定したローカル暦日に [doneAt] があるコレ済のみ表示（コレ済タブ向け）。
  final DateTime? initialDoneFilterLocalDay;

  /// コレ候補タブで、この商品IDの行へスクロールし、約1秒ハイライトする。
  final String? initialFocusCandidateProductId;

  @override
  State<ProductsPlaceholderScreen> createState() =>
      _ProductsPlaceholderScreenState();
}

class _ProductsPlaceholderScreenState extends State<ProductsPlaceholderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _candidateScrollController = ScrollController();
  final Map<String, GlobalKey> _candidateRowKeys = <String, GlobalKey>{};
  String _searchQuery = '';
  DateTime? _doneLocalDayFilter;
  Timer? _flashTimer;
  String? _flashProductId;
  bool _candidateFocusHandled = false;
  String? _shellFocusCandidateProductId;
  late final AppShellController _shellCtrl;
  late final RoomColleUiStateRepository _roomColleUiRepo;
  bool _excludeUrlNotReady = false;
  Timer? _persistSearchDebounce;

  String? get _focusCandidateTargetId {
    final w = widget.initialFocusCandidateProductId;
    if (w != null && w.isNotEmpty) return w;
    final s = _shellFocusCandidateProductId;
    if (s != null && s.isNotEmpty) return s;
    return null;
  }

  GlobalKey _keyForCandidateRow(String productId) =>
      _candidateRowKeys.putIfAbsent(productId, GlobalKey.new);

  void _onCandidateFocusListReady() {
    if (_candidateFocusHandled) return;
    final id = _focusCandidateTargetId;
    if (id == null || id.isEmpty) return;
    _candidateFocusHandled = true;
    setState(() => _shellFocusCandidateProductId = null);
    _runScrollToCandidate(id, 0);
  }

  void _onCandidateFocusProductMissing() {
    if (_candidateFocusHandled) return;
    _candidateFocusHandled = true;
    setState(() => _shellFocusCandidateProductId = null);
  }

  void _runScrollToCandidate(String productId, int attempt) {
    if (!mounted || attempt > 16) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _candidateRowKeys[productId]?.currentContext;
      if (ctx != null) {
        try {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.12,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        } catch (e, st) {
          assert(() {
            debugPrint('[ROOMコレ] ensureVisible 失敗: $e\n$st');
            return true;
          }());
        }
        if (!mounted) return;
        setState(() => _flashProductId = productId);
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) setState(() => _flashProductId = null);
        });
        return;
      }
      _runScrollToCandidate(productId, attempt + 1);
    });
  }

  void _resetRoomColleFilters() {
    if (!mounted) return;
    setState(() {
      _excludeUrlNotReady = false;
      _searchQuery = '';
      _searchController.clear();
      _doneLocalDayFilter = null;
    });
    _persistRoomColleUiNow();
  }

  RoomColleUiStateSnapshot _snapshotForPersist() {
    return RoomColleUiStateSnapshot(
      tabIndex: _tabController.index.clamp(0, 1),
      searchQuery: _searchQuery,
      excludeUrlNotReady: _excludeUrlNotReady,
      doneLocalDay: _doneLocalDayFilter,
    );
  }

  void _persistRoomColleUiNow() {
    unawaited(_roomColleUiRepo.saveSanitized(_snapshotForPersist()));
  }

  void _schedulePersistRoomColleSearch() {
    _persistSearchDebounce?.cancel();
    _persistSearchDebounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      _persistRoomColleUiNow();
    });
  }

  int _resolveInitialTabIndex(RoomColleUiStateSnapshot persisted) {
    if (widget.initialTabIndex != 0) {
      return widget.initialTabIndex.clamp(0, 1);
    }
    return persisted.tabIndex.clamp(0, 1);
  }

  Future<void> _recoverRoomColleListAndFilters() async {
    if (!mounted) return;
    if (kDebugMode) {
      debugPrint('[ROOMコレ] recover: filters + list UI (user)');
    }
    setState(() {
      _excludeUrlNotReady = false;
      _searchQuery = '';
      _searchController.clear();
      _doneLocalDayFilter = null;
    });
    await _roomColleUiRepo.clearPersisted();
    await _roomColleUiRepo.saveSanitized(RoomColleUiStateSnapshot.defaults());
    if (!mounted) return;
    final managed = context.read<RakutenManagedProductProvider>();
    managed.recoverListUiSilently();
    await managed.refreshManagedProductList(showLoadingIndicator: true);
  }

  @override
  void initState() {
    super.initState();
    _roomColleUiRepo = context.read<RoomColleUiStateRepository>();
    final persisted = _roomColleUiRepo.loadSanitized();

    if (_roomColleScreenHasExplicitRouteArgs(widget)) {
      _doneLocalDayFilter =
          _normalizeDoneDayFilter(widget.initialDoneFilterLocalDay);
    } else {
      _searchQuery = persisted.searchQuery;
      _searchController.text = persisted.searchQuery;
      _excludeUrlNotReady = persisted.excludeUrlNotReady;
      _doneLocalDayFilter = _normalizeDoneDayFilter(persisted.doneLocalDay);
    }

    final focusId = widget.initialFocusCandidateProductId;
    final idx0 = widget.initialTabIndex.clamp(0, 1);
    if (focusId != null &&
        focusId.isNotEmpty &&
        idx0 == 0) {
      _searchController.clear();
      _searchQuery = '';
    }
    final initialIndex = _resolveInitialTabIndex(persisted);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (mounted) {
        setState(() {});
        _persistRoomColleUiNow();
      }
    });
    _shellCtrl = context.read<AppShellController>();
    _shellCtrl.addListener(_onShellCtrlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final managed = context.read<RakutenManagedProductProvider>();
      if (managed.listUiStatus == RakutenManagedProductListUiStatus.error) {
        if (kDebugMode) {
          debugPrint('[ROOMコレ] init_post_frame: recover list UI from error');
        }
        managed.recoverListUiSilently();
      }
      managed.refreshManagedProductList(
        showLoadingIndicator: false,
      );
      _tryConsumeRoomCollectIntent();
    });
  }

  void _onShellCtrlChanged() {
    if (!mounted) return;
    // IndexedStack 維持のため initState は1回のみ。タブ再表示時に一覧とエラー状態を復旧する。
    if (_shellCtrl.currentIndex == 1) {
      final managed = context.read<RakutenManagedProductProvider>();
      if (managed.listUiStatus == RakutenManagedProductListUiStatus.error) {
        if (kDebugMode) {
          debugPrint('[ROOMコレ] shell_tab_focus: recover list UI from error');
        }
        managed.recoverListUiSilently();
      }
      managed.refreshManagedProductList(
        showLoadingIndicator: false,
      );
    }
    _tryConsumeRoomCollectIntent();
  }

  void _tryConsumeRoomCollectIntent() {
    if (!mounted) return;
    final intent = _shellCtrl.takePendingRoomCollectIntent();
    if (intent != null) {
      _applyRoomCollectIntent(intent);
    }
  }

  void _applyRoomCollectIntent(RoomCollectNavigationIntent intent) {
    final idx = intent.initialTabIndex.clamp(0, 1);
    final focusRaw = intent.focusCandidateProductId;
    final focusId = (focusRaw != null && focusRaw.isNotEmpty && idx == 0)
        ? focusRaw
        : null;

    setState(() {
      if (idx == 0) {
        _doneLocalDayFilter = null;
        if (focusId != null) {
          _searchController.clear();
          _searchQuery = '';
        }
      } else {
        _doneLocalDayFilter = _normalizeDoneDayFilter(intent.doneFilterLocalDay);
      }
      _shellFocusCandidateProductId = focusId;
      _candidateFocusHandled = false;
    });

    if (_tabController.index != idx) {
      _tabController.animateTo(idx);
    }
    _persistRoomColleUiNow();
  }

  @override
  void dispose() {
    _persistSearchDebounce?.cancel();
    _persistRoomColleUiNow();
    _shellCtrl.removeListener(_onShellCtrlChanged);
    _flashTimer?.cancel();
    _candidateScrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.divider.withValues(alpha: 0.88),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            /// ① タブ（一覧モード切替）— 検索・フィルタと役割を分離
            Padding(
              padding: EdgeInsets.fromLTRB(
                _kRoomListScreenPadH,
                canPop ? 2 : 8,
                _kRoomListScreenPadH,
                6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canPop)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, top: 2),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 22),
                        color: AppColors.textPrimary,
                        tooltip: '戻る',
                      ),
                    ),
                  Expanded(
                    child: Consumer<RakutenManagedProductProvider>(
                      builder: (context, managed, _) {
                        final nCand = _roomColleVisibleCount(
                          provider: managed,
                          status: RakutenManagedProductStatus.candidate,
                          filterQuery: _searchQuery,
                          excludeUrlNotReady: _excludeUrlNotReady,
                          doneAtLocalDayFilter: null,
                        );
                        final nDone = _roomColleVisibleCount(
                          provider: managed,
                          status: RakutenManagedProductStatus.done,
                          filterQuery: _searchQuery,
                          excludeUrlNotReady: _excludeUrlNotReady,
                          doneAtLocalDayFilter: _doneLocalDayFilter,
                        );
                        final idx = _tabController.index;
                        final selectedAccent = idx == 0
                            ? RoomListAccent.candidate
                            : RoomListAccent.done;
                        return SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: <ButtonSegment<int>>[
                            ButtonSegment<int>(
                              value: 0,
                              label: Text('コレ候補 ($nCand)'),
                              tooltip: 'コレ候補の一覧',
                            ),
                            ButtonSegment<int>(
                              value: 1,
                              label: Text('コレ済 ($nDone)'),
                              tooltip: 'コレ済の一覧',
                            ),
                          ],
                          selected: <int>{_tabController.index},
                          onSelectionChanged: (Set<int> selection) {
                            if (selection.isEmpty) return;
                            final v = selection.first;
                            if (v != _tabController.index) {
                              _tabController.animateTo(v);
                            }
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: WidgetStateProperty.all(
                              const BorderSide(color: AppColors.divider),
                            ),
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                            ),
                            foregroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return selectedAccent;
                              }
                              return AppColors.textSecondary;
                            }),
                            backgroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return selectedAccent.withValues(alpha: 0.12);
                              }
                              return AppColors.surface;
                            }),
                            textStyle: WidgetStateProperty.all(
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            /// 楽天検索へ（一覧のキーワード欄とは別物。店舗アイコンで虫眼鏡と差別化）
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kRoomListScreenPadH,
                2,
                _kRoomListScreenPadH,
                8,
              ),
              child: Tooltip(
                message: '楽天の検索画面を開き、商品を探してコレ候補に登録できます',
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RakutenSearchScreen(),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.storefront_outlined,
                      size: 22,
                      color: AppColors.accentPrimary,
                    ),
                    label: Text(
                      '楽天で検索',
                      style: TextStyle(
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentPrimary,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(
                        color: AppColors.accentPrimary.withValues(alpha: 0.55),
                        width: 1.25,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusButton,
                        ),
                      ),
                      backgroundColor: AppColors.surface,
                    ),
                  ),
                ),
              ),
            ),
            /// キーワード検索（この一覧内のみ絞り込み。右端は虫眼鏡のみ）
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kRoomListScreenPadH,
                0,
                _kRoomListScreenPadH,
                4,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  if (!mounted) return;
                  setState(() => _searchQuery = v);
                  _schedulePersistRoomColleSearch();
                },
                textInputAction: TextInputAction.search,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.2,
                    ),
                decoration: InputDecoration(
                  hintText: 'キーワード検索',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSearchBar,
                    ),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSearchBar,
                    ),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSearchBar,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.accentPrimary,
                      width: 1.5,
                    ),
                  ),
                  suffixIcon: const Padding(
                    padding: EdgeInsetsDirectional.only(end: 10),
                    child: Icon(
                      Icons.search_rounded,
                      color: AppColors.textTertiary,
                      size: 24,
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ),
            ),
            /// ③ フィルタ（チップ）— タブと見た目を分離したブロック
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kRoomListScreenPadH,
                4,
                _kRoomListScreenPadH,
                8,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter_list_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '絞り込み',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 0.2,
                                ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FilterChip(
                            label: const Text('URL未取得除外'),
                            tooltip: 'コレ候補タブの一覧にのみ適用されます',
                            selected: _excludeUrlNotReady,
                            onSelected: (v) {
                              if (!mounted) return;
                              setState(() => _excludeUrlNotReady = v);
                              _persistRoomColleUiNow();
                            },
                            showCheckmark: false,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            pressElevation: 0,
                            backgroundColor: AppColors.surface,
                            selectedColor: const Color(0xFF546E7A)
                                .withValues(alpha: 0.14),
                            side: BorderSide(
                              color: _excludeUrlNotReady
                                  ? const Color(0xFF546E7A)
                                  : AppColors.divider,
                              width: _excludeUrlNotReady ? 1.25 : 1,
                            ),
                            labelStyle: TextStyle(
                              color: _excludeUrlNotReady
                                  ? const Color(0xFF37474F)
                                  : AppColors.textPrimary,
                              fontWeight: _excludeUrlNotReady
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'フィルタを初期化',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: _resetRoomColleFilters,
                        icon: Icon(
                          Icons.restart_alt_rounded,
                          size: 22,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _RoomManagedProductListTab(
                    status: RakutenManagedProductStatus.candidate,
                    variant: RakutenManagedProductCardVariant.candidate,
                    filterQuery: _searchQuery,
                    excludeUrlNotReady: _excludeUrlNotReady,
                    candidateFocusHandled: _candidateFocusHandled,
                    onRecoverFromListError: _recoverRoomColleListAndFilters,
                    emptyTitle: 'コレ候補はまだありません',
                    emptySubtitle: '保存データでは、このタブに該当する商品はまだありません。',
                    emptyHint: '',
                    accentColor: RoomListAccent.candidate,
                    listScrollController: _candidateScrollController,
                    flashHighlightProductId: _flashProductId,
                    rowKeyFor: _keyForCandidateRow,
                    focusCandidateProductId: _focusCandidateTargetId,
                    onCandidateFocusListReady:
                        _focusCandidateTargetId != null &&
                                _focusCandidateTargetId!.isNotEmpty
                            ? _onCandidateFocusListReady
                            : null,
                    onCandidateFocusProductMissing:
                        _focusCandidateTargetId != null &&
                                _focusCandidateTargetId!.isNotEmpty
                            ? _onCandidateFocusProductMissing
                            : null,
                  ),
                  _RoomManagedProductListTab(
                    status: RakutenManagedProductStatus.done,
                    variant: RakutenManagedProductCardVariant.done,
                    filterQuery: _searchQuery,
                    excludeUrlNotReady: _excludeUrlNotReady,
                    candidateFocusHandled: true,
                    onRecoverFromListError: _recoverRoomColleListAndFilters,
                    doneAtLocalDayFilter: _doneLocalDayFilter,
                    onClearDoneDayFilter: _doneLocalDayFilter == null
                        ? null
                        : () {
                            setState(() => _doneLocalDayFilter = null);
                            _persistRoomColleUiNow();
                          },
                    emptyTitle: 'コレ済の商品はまだありません',
                    emptySubtitle: '保存データでは、このタブに該当する商品はまだありません。',
                    emptyHint: '',
                    dayFilterEmptyTitle: 'この日にコレした商品はありません',
                    dayFilterEmptySubtitle: '表示は端末の日付（このアプリでコレ済にした日時）に基づきます。',
                    accentColor: RoomListAccent.done,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomManagedProductListTab extends StatefulWidget {
  const _RoomManagedProductListTab({
    required this.status,
    required this.variant,
    required this.filterQuery,
    this.excludeUrlNotReady = false,
    this.candidateFocusHandled = true,
    this.onRecoverFromListError,
    this.doneAtLocalDayFilter,
    this.onClearDoneDayFilter,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyHint,
    this.dayFilterEmptyTitle,
    this.dayFilterEmptySubtitle,
    required this.accentColor,
    this.listScrollController,
    this.flashHighlightProductId,
    this.rowKeyFor,
    this.focusCandidateProductId,
    this.onCandidateFocusListReady,
    this.onCandidateFocusProductMissing,
  });

  final RakutenManagedProductStatus status;
  final RakutenManagedProductCardVariant variant;
  final String filterQuery;
  final bool excludeUrlNotReady;

  /// 親が候補フォーカス意図を消化済みなら true（build 内での post-frame 連発を止める）。
  final bool candidateFocusHandled;

  /// 一覧エラー時にフィルタ初期化＋再読込で復旧する。
  final Future<void> Function()? onRecoverFromListError;

  final DateTime? doneAtLocalDayFilter;
  final VoidCallback? onClearDoneDayFilter;
  final String emptyTitle;
  final String emptySubtitle;
  final String emptyHint;
  final String? dayFilterEmptyTitle;
  final String? dayFilterEmptySubtitle;
  final Color accentColor;
  final ScrollController? listScrollController;
  final String? flashHighlightProductId;
  final GlobalKey Function(String productId)? rowKeyFor;
  final String? focusCandidateProductId;
  final VoidCallback? onCandidateFocusListReady;
  final VoidCallback? onCandidateFocusProductMissing;

  @override
  State<_RoomManagedProductListTab> createState() =>
      _RoomManagedProductListTabState();
}

class _RoomManagedProductListTabState extends State<_RoomManagedProductListTab> {
  bool _candidateFocusCallbackEnqueued = false;
  String? _lastSeenFocusProductId;
  _RoomColleListSurface? _lastDebugSurface;

  @override
  void initState() {
    super.initState();
    _lastSeenFocusProductId = widget.focusCandidateProductId;
  }

  @override
  void didUpdateWidget(covariant _RoomManagedProductListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newId = widget.focusCandidateProductId;
    if (newId != _lastSeenFocusProductId) {
      _lastSeenFocusProductId = newId;
      _candidateFocusCallbackEnqueued = false;
    }
    if (oldWidget.candidateFocusHandled && !widget.candidateFocusHandled) {
      _candidateFocusCallbackEnqueued = false;
    }
  }

  void _scheduleCandidateFocusKickOnce(
    BuildContext context,
  ) {
    if (widget.status != RakutenManagedProductStatus.candidate) return;
    if (widget.candidateFocusHandled) return;
    final fid = widget.focusCandidateProductId;
    if (fid == null || fid.isEmpty) return;
    if (widget.onCandidateFocusListReady == null ||
        widget.onCandidateFocusProductMissing == null) {
      return;
    }
    if (_candidateFocusCallbackEnqueued) return;
    _candidateFocusCallbackEnqueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _candidateFocusCallbackEnqueued = false;
      if (!mounted) {
        return;
      }
      try {
        final p = context.read<RakutenManagedProductProvider>();
        if (p.listUiStatus != RakutenManagedProductListUiStatus.ready) {
          return;
        }
        if (widget.candidateFocusHandled) return;

        final listNow = _roomListVisibleItems(
          provider: p,
          status: RakutenManagedProductStatus.candidate,
          filterQuery: widget.filterQuery,
          excludeUrlNotReady: widget.excludeUrlNotReady,
          doneAtLocalDayFilter: null,
        );
        final baseCand = p.sortedItemsForStatus(RakutenManagedProductStatus.candidate);

        if (listNow.any((e) => e.productId == fid)) {
          widget.onCandidateFocusListReady!();
        } else if (baseCand.isNotEmpty) {
          widget.onCandidateFocusProductMissing!();
        }
      } catch (e, st) {
        assert(() {
          debugPrint('[ROOMコレ] 候補フォーカス処理エラー: $e\n$st');
          return true;
        }());
      }
    });
  }

  void _debugLogSurface(_RoomColleListSurface surface) {
    assert(() {
      if (_lastDebugSurface != surface) {
        final tabName = widget.status == RakutenManagedProductStatus.candidate
            ? 'candidate'
            : 'done';
        debugPrint(
          '[ROOMコレ][surface] tab=$tabName surface=${surface.debugLabel}',
        );
        _lastDebugSurface = surface;
      }
      return true;
    }());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RakutenManagedProductProvider>(
      builder: (context, provider, _) {
        final ui = provider.listUiStatus;

        final list = _roomListVisibleItems(
          provider: provider,
          status: widget.status,
          filterQuery: widget.filterQuery,
          excludeUrlNotReady: widget.excludeUrlNotReady,
          doneAtLocalDayFilter: widget.doneAtLocalDayFilter,
        );

        final baseList = provider.sortedItemsForStatus(widget.status);
        final day = widget.doneAtLocalDayFilter;
        final scoped = widget.status == RakutenManagedProductStatus.done &&
                day != null
            ? _filterDoneOnLocalCalendarDay(baseList, day)
            : baseList;
        final urlActive = widget.status == RakutenManagedProductStatus.candidate &&
            widget.excludeUrlNotReady;
        final urlScoped = _filterExcludeUrlNotReady(scoped, urlActive);

        final canShowDayEmpty = widget.dayFilterEmptyTitle != null &&
            widget.dayFilterEmptySubtitle != null;

        final surface = _resolveRoomColleListSurface(
          ui: ui,
          baseList: baseList,
          scoped: scoped,
          list: list,
          urlScoped: urlScoped,
          urlActive: urlActive,
          filterQuery: widget.filterQuery,
          hasDayFilter: widget.doneAtLocalDayFilter != null,
          canShowDayEmptyMessage: canShowDayEmpty,
        );
        _debugLogSurface(surface);

        switch (surface) {
          case _RoomColleListSurface.loading:
            return const AppScreenLoadingCenter(
              title: '一覧を読み込み中',
              subtitle:
                  '端末に保存した一覧を読み込んでいます。しばらくお待ちください。',
            );

          case _RoomColleListSurface.loadError:
            return _RoomCollectionErrorState(
              message:
                  provider.listUiErrorMessage ?? '一覧データの読み込みに失敗しました。',
              onRetry: () =>
                  provider.refreshManagedProductList(showLoadingIndicator: true),
              onResetFiltersAndRetry: widget.onRecoverFromListError,
            );

          case _RoomColleListSurface.readyEmptyNoData:
            return _roomColleRefreshableScroll(
              provider,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RoomCollectionEmptyState(
                    title: widget.emptyTitle,
                    subtitle: widget.emptySubtitle,
                    hint: widget.emptyHint,
                    accentColor: widget.accentColor,
                    stateFootnote: '読み込みは完了していますが、このタブに該当するデータは0件です。',
                    embedInListView: false,
                  ),
                ],
              ),
            );

          case _RoomColleListSurface.readyEmptyFilteredByDay:
            return _roomColleRefreshableScroll(
              provider,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RoomCollectionEmptyState(
                    title: widget.dayFilterEmptyTitle!,
                    subtitle: widget.dayFilterEmptySubtitle!,
                    hint: '',
                    accentColor: widget.accentColor,
                    actionLabel:
                        widget.onClearDoneDayFilter != null ? 'すべて表示' : null,
                    onAction: widget.onClearDoneDayFilter,
                    stateFootnote:
                        '読み込みは完了しています。日付条件に一致する商品は0件です。「すべて表示」で解除できます。',
                    embedInListView: false,
                  ),
                ],
              ),
            );

          case _RoomColleListSurface.readyEmptyFilteredByUrl:
            return _roomColleRefreshableScroll(
              provider,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RoomCollectionUrlFilterEmptyState(
                    accentColor: widget.accentColor,
                    embedInListView: false,
                  ),
                ],
              ),
            );

          case _RoomColleListSurface.readyEmptyFilteredBySearch:
            return _roomColleRefreshableScroll(
              provider,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RoomCollectionSearchEmptyState(
                    accentColor: widget.accentColor,
                    embedInListView: false,
                  ),
                ],
              ),
            );

          case _RoomColleListSurface.readyEmptyAnomaly:
            return _roomColleRefreshableScroll(
              provider,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RoomCollectionRenderOrDataEmptyState(
                    accentColor: widget.accentColor,
                    embedInListView: false,
                    onResetFilters: widget.onRecoverFromListError,
                  ),
                ],
              ),
            );

          case _RoomColleListSurface.readyList:
            break;
        }

        _scheduleCandidateFocusKickOnce(context);

        final showDayBanner =
            widget.status == RakutenManagedProductStatus.done &&
            widget.doneAtLocalDayFilter != null &&
            widget.onClearDoneDayFilter != null;

        return RefreshIndicator(
          onRefresh: () =>
              provider.refreshManagedProductList(showLoadingIndicator: true),
          child: ListView(
            controller: widget.listScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              _kRoomListScreenPadH,
              2,
              _kRoomListScreenPadH,
              12,
            ),
            children: [
              if (showDayBanner) ...[
                _DoneDayFilterBanner(
                  filterDay: widget.doneAtLocalDayFilter!,
                  onClear: widget.onClearDoneDayFilter!,
                ),
                const SizedBox(height: _kRoomListCardGap),
              ],
              if (widget.status == RakutenManagedProductStatus.done)
                _DoneTabCollapsibleNotice(
                  repository: context.read<DoneTabNoticeRepository>(),
                ),
              for (var i = 0; i < list.length; i++) ...[
                _KeyedCandidateProductRow(
                  product: list[i],
                  variant: widget.variant,
                  rowKey: widget.rowKeyFor?.call(list[i].productId),
                  flash: widget.flashHighlightProductId == list[i].productId,
                ),
                if (i != list.length - 1)
                  const SizedBox(height: _kRoomListCardGap),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _KeyedCandidateProductRow extends StatelessWidget {
  const _KeyedCandidateProductRow({
    required this.product,
    required this.variant,
    this.rowKey,
    this.flash = false,
  });

  final RakutenManagedProduct product;
  final RakutenManagedProductCardVariant variant;
  final GlobalKey? rowKey;
  final bool flash;

  @override
  Widget build(BuildContext context) {
    try {
      Widget card = RakutenManagedProductCard(
        product: product,
        variant: variant,
      );
      if (flash) {
        card = AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: AppColors.accentLight.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accentPrimary, width: 1.5),
          ),
          child: card,
        );
      }
      if (rowKey != null) {
        return KeyedSubtree(key: rowKey, child: card);
      }
      return card;
    } catch (e, st) {
      assert(() {
        debugPrint('[ROOMコレ] 行描画エラー productId=${product.productId}: $e\n$st');
        return true;
      }());
      final fallback = _RoomColleBrokenProductRow(productId: product.productId);
      if (rowKey != null) {
        return KeyedSubtree(key: rowKey, child: fallback);
      }
      return fallback;
    }
  }
}

/// 1件のデータ／ウィジェット失敗時もリスト全体を落とさないためのプレースホルダ。
class _RoomColleBrokenProductRow extends StatelessWidget {
  const _RoomColleBrokenProductRow({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                productId.trim().isEmpty
                    ? 'この行の商品データを表示できませんでした'
                    : '商品ID $productId の表示に失敗しました',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  productId.trim().isEmpty
                      ? '表示できない商品行があります（タップで詳細）'
                      : '表示エラー: $productId',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneDayFilterBanner extends StatelessWidget {
  const _DoneDayFilterBanner({required this.filterDay, required this.onClear});

  final DateTime filterDay;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: AppColors.accentPrimary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '本日（${filterDay.month}/${filterDay.day}）コレした分のみ表示中',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('すべて表示'),
            ),
          ],
        ),
      ),
    );
  }
}

/// コレ済タブ先頭に1つだけ置く注意書き（折りたたみ・今後表示しないで永続的に非表示）。
class _DoneTabCollapsibleNotice extends StatefulWidget {
  const _DoneTabCollapsibleNotice({required this.repository});

  final DoneTabNoticeRepository repository;

  @override
  State<_DoneTabCollapsibleNotice> createState() =>
      _DoneTabCollapsibleNoticeState();
}

class _DoneTabCollapsibleNoticeState extends State<_DoneTabCollapsibleNotice> {
  bool _suppressed = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _suppressed = widget.repository.isSuppressed;
  }

  static const String _summary =
      'このアプリの「コレ済」とROOMの投稿は別です（詳しくは展開）。';
  static const String _body =
      'このアプリではコレ済です。ROOM投稿の完了は別途ご確認ください。';

  Future<void> _onSuppressForever() async {
    await widget.repository.suppressForever();
    if (mounted) setState(() => _suppressed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_suppressed) return const SizedBox.shrink();

    final borderColor = RoomListAccent.done.withValues(alpha: 0.34);
    return Padding(
      padding: const EdgeInsets.only(bottom: _kRoomListCardGap),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: RoomListAccent.done.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_expanded) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  child: Text(
                    _body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                          fontSize: 12,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _onSuppressForever,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        minimumSize: const Size(48, 48),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('今後表示しない'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomCollectionSearchEmptyState extends StatelessWidget {
  const _RoomCollectionSearchEmptyState({
    required this.accentColor,
    this.embedInListView = true,
  });

  final Color accentColor;
  final bool embedInListView;

  @override
  Widget build(BuildContext context) {
    final pane = SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.35,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kRoomListScreenPadH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_outlined,
                size: 44,
                color: accentColor.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 10),
              Text(
                '一致する商品がありません',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'キーワードを変えるか、絞り込みを解除してください。読み込み自体は成功しています。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      height: 1.35,
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
    if (embedInListView) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [pane],
      );
    }
    return pane;
  }
}

/// 「URL未取得除外」により表示対象が0件（データは存在する）。
class _RoomCollectionUrlFilterEmptyState extends StatelessWidget {
  const _RoomCollectionUrlFilterEmptyState({
    required this.accentColor,
    this.embedInListView = true,
  });

  final Color accentColor;
  final bool embedInListView;

  @override
  Widget build(BuildContext context) {
    final pane = SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.35,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kRoomListScreenPadH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.link_off_rounded,
                size: 44,
                color: accentColor.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 10),
              Text(
                'URL未取得除外のため表示できる商品がありません',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'チップ「URL未取得除外」をオフにすると一覧が表示されます。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                      fontSize: 13,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'データの読み込みは成功しています（コレ候補をURL条件で絞り込んだ結果が0件です）。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      height: 1.35,
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
    if (embedInListView) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [pane],
      );
    }
    return pane;
  }
}

/// 本当の0件ではなく、想定外で一覧が空になったとき（真っ白防止）。
class _RoomCollectionRenderOrDataEmptyState extends StatelessWidget {
  const _RoomCollectionRenderOrDataEmptyState({
    required this.accentColor,
    this.embedInListView = true,
    this.onResetFilters,
  });

  final Color accentColor;
  final bool embedInListView;
  final Future<void> Function()? onResetFilters;

  @override
  Widget build(BuildContext context) {
    final pane = SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.35,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kRoomListScreenPadH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 44,
                color: accentColor.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 10),
              Text(
                '一覧を描画できませんでした',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '読み込みエラーではなく、画面上の整合が取れていない可能性（描画・データの不整合）があります。下に引っ張って再読み込みするか、フィルタを初期化してください。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                      fontSize: 13,
                    ),
              ),
              if (onResetFilters != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => onResetFilters!(),
                  child: const Text('フィルタを初期化'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (embedInListView) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [pane],
      );
    }
    return pane;
  }
}

class _RoomCollectionEmptyState extends StatelessWidget {
  const _RoomCollectionEmptyState({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.accentColor,
    this.actionLabel,
    this.onAction,
    this.stateFootnote,
    this.embedInListView = true,
  });

  final String title;
  final String subtitle;
  final String hint;
  final Color accentColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? stateFootnote;
  final bool embedInListView;

  @override
  Widget build(BuildContext context) {
    final pane = SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.4,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kRoomListScreenPadH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: accentColor.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                        fontSize: 13,
                      ),
                ),
              ],
              if (hint.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        height: 1.35,
                      ),
                ),
              ],
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
              if (stateFootnote != null && stateFootnote!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  stateFootnote!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (embedInListView) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [pane],
      );
    }
    return pane;
  }
}

class _RoomCollectionErrorState extends StatelessWidget {
  const _RoomCollectionErrorState({
    required this.message,
    required this.onRetry,
    this.onResetFiltersAndRetry,
  });

  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function()? onResetFiltersAndRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: _kRoomListScreenPadH,
            vertical: 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(
                    '一覧を表示できませんでした',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '状態: データの読み込みに失敗しました',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => onRetry(),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('もう一度読み込む'),
                  ),
                  if (onResetFiltersAndRetry != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => onResetFiltersAndRetry!(),
                      child: const Text('フィルタを初期化して再開'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
