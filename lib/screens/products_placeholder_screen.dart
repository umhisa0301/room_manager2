import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../models/room_colle_list_filters.dart';
import '../navigation/app_shell_controller.dart';
import '../repository/genre_master_repository.dart';
import '../repository/room_colle_ui_state_repository.dart';
import '../services/rakuten_genre_master_service.dart';
import '../services/room_collect_post_limit.dart';
import '../services/room_import_metadata_enrichment.dart';
import '../state/bulk_operation_state_controller.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/room_activity_event_provider.dart';
import '../state/room_import_controller.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/room_colle_list_accent.dart';
import '../utils/rakuten_product_genre_display.dart';
import '../utils/room_colle_candidate_stale.dart';
import '../utils/app_debug_log.dart';
import '../widgets/app_button.dart';
import '../widgets/app_screen_status.dart';
import '../widgets/app_text_field.dart';
import '../widgets/rakuten_managed_product_card.dart';

/// 投稿管理一覧の左右 padding（ホーム [_HomeUi.screenPaddingH] と同一）。
const double _kRoomListScreenPadH = 16;
const double _kRoomListCardGap = 8;

enum RoomColleListSortPreset { recentFirst, oldFirst, priceHigh, priceLow }

/// ROOM取り込みメタの表示絞り込み（コレ済タブのみ）。
enum _RoomImportMetaListFilter { all, incompleteOnly, completeOnly }

/// [AppShellController.currentIndex] の ROOMコレ（下部ナビ「投稿」）タブ。
/// IndexedStack 上は 1。下部ナビの見た目上 3 番目（0=ホーム, 1=探す, 2=投稿…）だが、
/// 「探す」はシートのみでシェル index を変えない。
const int _roomColleShellIndex = 1;

/// ROOMコレ画面のレイアウト・面色・装飾（ホーム完成版と同一デザイン言語。ロジックとは分離）。
abstract final class _RoomColleUi {
  const _RoomColleUi._();

  /// ホーム [_HomeUi.gapSection] と同じ（投稿管理はやや詰める）。
  static const double gapSection = 8;

  static const double tabInnerPad = 3;
  static const double gapFieldStack = 8;

  static const double gapListAfterDivider = 4;
  static const double listBottomPad = 72;

  static const double radiusSectionInner = 12;

  /// 投稿管理：検索欄の通常枠線。
  static const Color searchFieldBorder = Color(0xFFCBD5E1);

  /// 投稿管理：検索欄プレースホルダー。
  static const Color searchFieldHint = Color(0xFF94A3B8);

  /// 投稿管理：検索欄・フィルターボタンの高さ。
  static const double searchRowHeight = 48;

  /// 投稿管理：フィルターボタンの固定幅（横 overflow 防止）。
  static const double filterButtonWidth = 92;

  static BoxDecoration tabSegmentTrackDecoration() {
    return BoxDecoration(
      color: HomeScreenColors.homeCardFill,
      borderRadius: BorderRadius.circular(radiusSectionInner),
      border: Border.all(color: HomeScreenColors.homeCardBorder),
    );
  }
}

/// タブをレール状に乗せる外周の角丸。
const double _kRoomColleTabTrackRadius = 14;

class _RoomColleFilterButton extends StatelessWidget {
  const _RoomColleFilterButton({
    required this.active,
    required this.activeCount,
    required this.onPressed,
    this.onClear,
  });

  final bool active;
  final int activeCount;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final accent = HomeScreenColors.homeAccentTeal;
    return SizedBox(
      width: _RoomColleUi.filterButtonWidth,
      height: _RoomColleUi.searchRowHeight,
      child: Semantics(
        button: true,
        label: active
            ? 'post_management_filter_button_active'
            : 'post_management_filter_button',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active
                ? HomeScreenColors.homeAccentTealLight
                : HomeScreenColors.homeCardFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent, width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onPressed,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(11),
                    ),
                    child: SizedBox(
                      height: _RoomColleUi.searchRowHeight,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded, size: 16, color: accent),
                              if (!active) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '絞込',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.1,
                                    color: accent,
                                  ),
                                ),
                              ] else if (activeCount > 0) ...[
                                const SizedBox(width: 4),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    child: Text(
                                      '$activeCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (active && onClear != null)
                Semantics(
                  button: true,
                  label: 'post_management_filter_clear_button',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onClear,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(11),
                      ),
                      child: SizedBox(
                        width: 28,
                        height: _RoomColleUi.searchRowHeight,
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: accent.withValues(alpha: 0.92),
                        ),
                      ),
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

bool _roomColleHasActiveSheetFilters({
  required bool isCandidate,
  required RoomColleListFilterCriteria criteria,
  required bool excludeUrlNotReady,
  required RoomColleListSortPreset sortPreset,
  DateTime? doneAtLocalDayFilter,
}) {
  return criteria.hasNonKeywordConstraints ||
      excludeUrlNotReady ||
      sortPreset != RoomColleListSortPreset.recentFirst ||
      (!isCandidate && doneAtLocalDayFilter != null);
}

int _roomColleActiveFilterCount({
  required bool isCandidate,
  required RoomColleListFilterCriteria criteria,
  required bool excludeUrlNotReady,
  required RoomColleListSortPreset sortPreset,
  DateTime? doneAtLocalDayFilter,
}) {
  var count = _roomColleFilterSummaryChips(criteria).length;
  if (excludeUrlNotReady) count++;
  if (sortPreset != RoomColleListSortPreset.recentFirst) count++;
  if (!isCandidate && doneAtLocalDayFilter != null) count++;
  return count;
}

/// 7日超の候補が一定件数以上のときの整理ナッジ（閉じた状態は永続化）。
class _RoomColleStalePileNoticeBar extends StatelessWidget {
  const _RoomColleStalePileNoticeBar({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    const accent = HomeScreenColors.homeWarning;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: accent.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '7日以上経過した候補があります',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: accent,
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: '閉じる',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: accent.withValues(alpha: 0.75),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

bool _roomColleScreenHasExplicitRouteArgs(ProductsPlaceholderScreen widget) {
  return widget.initialDoneFilterLocalDay != null ||
      (widget.initialFocusCandidateProductId?.isNotEmpty ?? false) ||
      widget.initialTabIndex != 0;
}

/// 登録から 7 暦日以上経過したコレ候補の件数。
int _roomColleStale7PlusCandidateCount(RakutenManagedProductProvider p) {
  final now = DateTime.now();
  var n = 0;
  for (final e in p.sortedItemsForStatus(
    RakutenManagedProductStatus.candidate,
  )) {
    try {
      if (RoomColleCandidateStaleSpec.calendarDaysElapsed(e.addedAt, now) >=
          7) {
        n++;
      }
    } catch (_) {}
  }
  return n;
}

/// 一覧に現れる非空の楽天 genreId 一覧（商品データ由来）。
List<String> _roomColleDistinctGenreIds(List<RakutenManagedProduct> items) {
  final s = <String>{};
  for (final e in items) {
    try {
      final g = e.genreId.trim();
      if (g.isNotEmpty) s.add(g);
    } catch (_) {}
  }
  final out = s.toList()..sort();
  return out;
}

List<String> _roomColleDistinctShopNames(List<RakutenManagedProduct> items) {
  final s = <String>{};
  for (final e in items) {
    try {
      final name = e.shopName.trim();
      if (name.isNotEmpty) s.add(name);
    } catch (_) {}
  }
  final out = s.toList()..sort();
  return out;
}

String _roomColleGenreFilterMenuText(String id) {
  final raw = RakutenGenreMasterService.instance.roomColleGenreFilterMenuLabel(
    id,
  );
  if (raw.length > 42) return '${raw.substring(0, 40)}…';
  return raw;
}

String _roomColleGenreLabelForProduct(
  RakutenManagedProduct product, {
  Map<String, String>? prefetchedGenreLabels,
}) {
  return RakutenProductGenreDisplay.resolve(
    apiGenreName: null,
    persistedGenreName: product.persistedGenreDisplayName,
    prefetchedGenreName: prefetchedGenreLabels?[product.genreId.trim()],
    genreId: product.genreId,
    traceItemCode: product.productId,
  );
}

Set<String> _savedShopIdSet(BuildContext context) {
  return context
      .watch<SavedShopProvider>()
      .shops
      .map((e) => e.shopId.trim())
      .where((e) => e.isNotEmpty)
      .toSet();
}

Set<String> _todayRecommendationIdSet(BuildContext context) {
  final bundle = context.watch<TodayRecommendationProvider>().bundle;
  return bundle?.entries
          .map((e) => e.item.productId.trim())
          .where((e) => e.isNotEmpty)
          .toSet() ??
      <String>{};
}

List<Widget> _roomColleFilterSummaryChips(RoomColleListFilterCriteria c) {
  final out = <Widget>[];
  switch (c.registeredDatePreset) {
    case RoomColleRegisteredDatePreset.all:
      break;
    case RoomColleRegisteredDatePreset.today:
      out.add(
        Chip(
          label: const Text('今日'),
          visualDensity: VisualDensity.compact,
          backgroundColor: HomeScreenColors.roomMetricTileFill,
          side: BorderSide(color: HomeScreenColors.metricTileOutline),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: HomeScreenColors.metricTileTitleColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
      break;
    case RoomColleRegisteredDatePreset.last3Days:
      out.add(
        Chip(
          label: const Text('3日以内'),
          visualDensity: VisualDensity.compact,
          backgroundColor: HomeScreenColors.roomMetricTileFill,
          side: BorderSide(color: HomeScreenColors.metricTileOutline),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: HomeScreenColors.metricTileTitleColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
      break;
    case RoomColleRegisteredDatePreset.last7Days:
      out.add(
        Chip(
          label: const Text('7日以内'),
          visualDensity: VisualDensity.compact,
          backgroundColor: HomeScreenColors.roomMetricTileFill,
          side: BorderSide(color: HomeScreenColors.metricTileOutline),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: HomeScreenColors.metricTileTitleColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
      break;
    case RoomColleRegisteredDatePreset.last30Days:
      out.add(
        Chip(
          label: const Text('30日以内'),
          visualDensity: VisualDensity.compact,
          backgroundColor: HomeScreenColors.roomMetricTileFill,
          side: BorderSide(color: HomeScreenColors.metricTileOutline),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: HomeScreenColors.metricTileTitleColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
      break;
    case RoomColleRegisteredDatePreset.olderThan30Days:
      out.add(
        Chip(
          label: const Text('30日以上前'),
          visualDensity: VisualDensity.compact,
          backgroundColor: HomeScreenColors.roomMetricTileFill,
          side: BorderSide(color: HomeScreenColors.metricTileOutline),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: HomeScreenColors.metricTileTitleColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
      break;
  }
  final g = c.genreId?.trim();
  if (g != null && g.isNotEmpty) {
    final labelFull = RakutenGenreMasterService.instance
        .roomColleGenreFilterMenuLabel(g);
    final short = labelFull.length > 22
        ? '${labelFull.substring(0, 20)}…'
        : labelFull;
    out.add(
      Chip(
        label: Text(short),
        visualDensity: VisualDensity.compact,
        backgroundColor: HomeScreenColors.roomMetricTileFill,
        side: BorderSide(color: HomeScreenColors.metricTileOutline),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: HomeScreenColors.metricTileTitleColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
  if (c.priceMinYen != null || c.priceMaxYen != null) {
    final min = c.priceMinYen;
    final max = c.priceMaxYen;
    final String s;
    if (min != null && max != null) {
      s = '¥$min〜¥$max';
    } else if (min != null) {
      s = '¥$min〜';
    } else {
      s = '〜¥$max';
    }
    out.add(
      Chip(
        label: Text('価格 $s'),
        visualDensity: VisualDensity.compact,
        backgroundColor: HomeScreenColors.roomMetricTileFill,
        side: BorderSide(color: HomeScreenColors.metricTileOutline),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: HomeScreenColors.metricTileTitleColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
  switch (c.shopFilterMode) {
    case RoomColleShopFilterMode.all:
      break;
    case RoomColleShopFilterMode.saved:
      out.add(
        Chip(
          label: const Text('保存ショップ'),
          visualDensity: VisualDensity.compact,
          backgroundColor: HomeScreenColors.roomMetricTileFill,
          side: BorderSide(color: HomeScreenColors.metricTileOutline),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: HomeScreenColors.metricTileTitleColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
      break;
    case RoomColleShopFilterMode.shopName:
      final name = c.shopName?.trim();
      if (name != null && name.isNotEmpty) {
        out.add(
          Chip(
            label: Text(name),
            visualDensity: VisualDensity.compact,
            backgroundColor: HomeScreenColors.roomMetricTileFill,
            side: BorderSide(color: HomeScreenColors.metricTileOutline),
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: HomeScreenColors.metricTileTitleColor,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        );
      }
      break;
  }
  void addBoolChip(String label) {
    out.add(
      Chip(
        label: Text(label),
        visualDensity: VisualDensity.compact,
        backgroundColor: HomeScreenColors.roomMetricTileFill,
        side: BorderSide(color: HomeScreenColors.metricTileOutline),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: HomeScreenColors.metricTileTitleColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  if (c.candidateHasRoomUrlOnly) addBoolChip('ROOM URLあり');
  if (c.candidateTodayRecommendationOnly) addBoolChip('今日のおすすめ');
  if (c.candidateUnpostedOnly) addBoolChip('未投稿');
  switch (c.doneQuickFilter) {
    case RoomColleDoneQuickFilterPreset.all:
      if (c.doneFeedbackSold) addBoolChip('売れた');
      if (c.doneFeedbackLiked) addBoolChip('反応あり');
      if (c.doneFeedbackWeak) addBoolChip('微妙');
      if (c.doneFeedbackUnrated) addBoolChip('未評価');
      break;
    case RoomColleDoneQuickFilterPreset.sold:
      addBoolChip('売れた');
      break;
    case RoomColleDoneQuickFilterPreset.roomReaction:
      addBoolChip('反応あり');
      break;
    case RoomColleDoneQuickFilterPreset.roomCommentOnly:
      addBoolChip('コメントあり');
      break;
    case RoomColleDoneQuickFilterPreset.roomLikeOnly:
      addBoolChip('いいねあり');
      break;
    case RoomColleDoneQuickFilterPreset.roomPosted:
      addBoolChip('ROOM投稿済み');
      break;
  }
  if (c.doneRoomConfirmedOnly) addBoolChip('ROOMで確認済み');
  switch (c.postedDatePreset) {
    case RoomCollePostedDatePreset.all:
      break;
    case RoomCollePostedDatePreset.today:
      addBoolChip('今日');
      break;
    case RoomCollePostedDatePreset.last3Days:
      addBoolChip('3日以内');
      break;
    case RoomCollePostedDatePreset.last7Days:
      addBoolChip('7日以内');
      break;
    case RoomCollePostedDatePreset.last30Days:
      addBoolChip('30日以内');
      break;
  }
  return out;
}

/// 絞り込みシートの適用結果。[includesCandidateUrlOption] が false のときは
/// [candidateExcludeUrlNotReady] を親で無視する（コレ済タブ用シート）。
class _RoomColleFilterSheetApplyResult {
  const _RoomColleFilterSheetApplyResult({
    required this.criteria,
    required this.candidateExcludeUrlNotReady,
    required this.includesCandidateUrlOption,
  });

  final RoomColleListFilterCriteria criteria;
  final bool candidateExcludeUrlNotReady;
  final bool includesCandidateUrlOption;
}

/// キーワード以外の条件をボトムシートで編集。キーワードは [initial] に含め親が保持する。
/// 候補タブ（[isCandidateTab]）では ROOM用URLの絞り込みを同シート内に配置する。
class _RoomColleFilterEditorSheet extends StatefulWidget {
  const _RoomColleFilterEditorSheet({
    required this.sectionTitle,
    required this.initial,
    required this.genreIds,
    required this.shopNames,
    required this.isCandidateTab,
    this.initialExcludeUrlNotReady = false,
  });

  final String sectionTitle;
  final RoomColleListFilterCriteria initial;
  final List<String> genreIds;
  final List<String> shopNames;
  final bool isCandidateTab;
  final bool initialExcludeUrlNotReady;

  @override
  State<_RoomColleFilterEditorSheet> createState() =>
      _RoomColleFilterEditorSheetState();
}

enum _RoomColleCandidateStateFilter {
  all,
  unposted,
  roomUrl,
  todayRecommendation,
}

class _RoomColleFilterEditorSheetState
    extends State<_RoomColleFilterEditorSheet> {
  static const String _shopAll = '__all__';
  static const String _shopSaved = '__saved__';

  late RoomColleRegisteredDatePreset _datePreset;
  late String _shopValue;
  String? _genreId;
  late final TextEditingController _minPriceCtrl;
  late final TextEditingController _maxPriceCtrl;
  late _RoomColleCandidateStateFilter _candidateState;
  late RoomColleDoneQuickFilterPreset _doneQuickFilterPreset;

  @override
  void initState() {
    super.initState();
    _datePreset = widget.isCandidateTab
        ? _simpleDatePreset(widget.initial.registeredDatePreset)
        : _datePresetFromPosted(widget.initial.postedDatePreset);
    _shopValue = _shopValueFromCriteria(widget.initial);
    final g = widget.initial.genreId?.trim();
    _genreId = (g != null && g.isNotEmpty) ? g : null;
    _minPriceCtrl = TextEditingController(
      text: _formatYenInput(widget.initial.priceMinYen?.toString() ?? ''),
    );
    _maxPriceCtrl = TextEditingController(
      text: _formatYenInput(widget.initial.priceMaxYen?.toString() ?? ''),
    );
    _candidateState = _candidateStateFromCriteria(widget.initial);
    _doneQuickFilterPreset = _doneQuickFilterPresetFromCriteria(widget.initial);
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  RoomColleRegisteredDatePreset _simpleDatePreset(
    RoomColleRegisteredDatePreset preset,
  ) {
    return preset == RoomColleRegisteredDatePreset.olderThan30Days
        ? RoomColleRegisteredDatePreset.all
        : preset;
  }

  RoomColleRegisteredDatePreset _datePresetFromPosted(
    RoomCollePostedDatePreset preset,
  ) {
    switch (preset) {
      case RoomCollePostedDatePreset.all:
        return RoomColleRegisteredDatePreset.all;
      case RoomCollePostedDatePreset.today:
        return RoomColleRegisteredDatePreset.today;
      case RoomCollePostedDatePreset.last3Days:
        return RoomColleRegisteredDatePreset.last3Days;
      case RoomCollePostedDatePreset.last7Days:
        return RoomColleRegisteredDatePreset.last7Days;
      case RoomCollePostedDatePreset.last30Days:
        return RoomColleRegisteredDatePreset.last30Days;
    }
  }

  RoomCollePostedDatePreset _postedPresetFromDate(
    RoomColleRegisteredDatePreset preset,
  ) {
    switch (_simpleDatePreset(preset)) {
      case RoomColleRegisteredDatePreset.all:
      case RoomColleRegisteredDatePreset.olderThan30Days:
        return RoomCollePostedDatePreset.all;
      case RoomColleRegisteredDatePreset.today:
        return RoomCollePostedDatePreset.today;
      case RoomColleRegisteredDatePreset.last3Days:
        return RoomCollePostedDatePreset.last3Days;
      case RoomColleRegisteredDatePreset.last7Days:
        return RoomCollePostedDatePreset.last7Days;
      case RoomColleRegisteredDatePreset.last30Days:
        return RoomCollePostedDatePreset.last30Days;
    }
  }

  String _shopValueFromCriteria(RoomColleListFilterCriteria criteria) {
    switch (criteria.shopFilterMode) {
      case RoomColleShopFilterMode.all:
        return _shopAll;
      case RoomColleShopFilterMode.saved:
        return _shopSaved;
      case RoomColleShopFilterMode.shopName:
        final name = criteria.shopName?.trim();
        return (name == null || name.isEmpty) ? _shopAll : name;
    }
  }

  _RoomColleCandidateStateFilter _candidateStateFromCriteria(
    RoomColleListFilterCriteria criteria,
  ) {
    if (criteria.candidateUnpostedOnly) {
      return _RoomColleCandidateStateFilter.unposted;
    }
    if (criteria.candidateHasRoomUrlOnly || widget.initialExcludeUrlNotReady) {
      return _RoomColleCandidateStateFilter.roomUrl;
    }
    if (criteria.candidateTodayRecommendationOnly) {
      return _RoomColleCandidateStateFilter.todayRecommendation;
    }
    return _RoomColleCandidateStateFilter.all;
  }

  RoomColleDoneQuickFilterPreset _doneQuickFilterPresetFromCriteria(
    RoomColleListFilterCriteria criteria,
  ) {
    if (criteria.doneQuickFilter != RoomColleDoneQuickFilterPreset.all) {
      return criteria.doneQuickFilter;
    }
    if (criteria.doneFeedbackSold) return RoomColleDoneQuickFilterPreset.sold;
    return RoomColleDoneQuickFilterPreset.all;
  }

  int? _tryParseYenField(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '');
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  String _formatYenInput(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }

  void _formatPriceController(TextEditingController controller) {
    final formatted = _formatYenInput(controller.text);
    if (controller.text == formatted) return;
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _resetDraftExtended() {
    setState(() {
      _datePreset = RoomColleRegisteredDatePreset.all;
      _shopValue = _shopAll;
      _genreId = null;
      _candidateState = _RoomColleCandidateStateFilter.all;
      _doneQuickFilterPreset = RoomColleDoneQuickFilterPreset.all;
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
    });
  }

  void _apply() {
    var minY = _tryParseYenField(_minPriceCtrl);
    var maxY = _tryParseYenField(_maxPriceCtrl);
    if ((_minPriceCtrl.text.trim().isNotEmpty && minY == null) ||
        (_maxPriceCtrl.text.trim().isNotEmpty && maxY == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('価格は数値で入力してください')));
      return;
    }
    if (minY != null && maxY != null && minY > maxY) {
      final t = minY;
      minY = maxY;
      maxY = t;
    }

    final shopMode = _shopValue == _shopSaved
        ? RoomColleShopFilterMode.saved
        : _shopValue == _shopAll
        ? RoomColleShopFilterMode.all
        : RoomColleShopFilterMode.shopName;
    final shopName = shopMode == RoomColleShopFilterMode.shopName
        ? _shopValue
        : null;

    final merged = widget.initial.copyWith(
      registeredDatePreset: widget.isCandidateTab
          ? _datePreset
          : RoomColleRegisteredDatePreset.all,
      postedDatePreset: widget.isCandidateTab
          ? RoomCollePostedDatePreset.all
          : _postedPresetFromDate(_datePreset),
      shopFilterMode: shopMode,
      shopName: shopName,
      clearShopName: shopName == null,
      staleCandidatePreset: RoomColleStaleCandidatePreset.none,
      genreId: _genreId,
      clearGenreId: _genreId == null || _genreId!.isEmpty,
      priceMinYen: minY,
      priceMaxYen: maxY,
      clearPriceMin: minY == null,
      clearPriceMax: maxY == null,
      candidateHasRoomUrlOnly:
          widget.isCandidateTab &&
          _candidateState == _RoomColleCandidateStateFilter.roomUrl,
      candidateTodayRecommendationOnly:
          widget.isCandidateTab &&
          _candidateState == _RoomColleCandidateStateFilter.todayRecommendation,
      candidateUnpostedOnly:
          widget.isCandidateTab &&
          _candidateState == _RoomColleCandidateStateFilter.unposted,
      doneQuickFilter: widget.isCandidateTab
          ? widget.initial.doneQuickFilter
          : _doneQuickFilterPreset,
      doneFeedbackSold: widget.isCandidateTab
          ? widget.initial.doneFeedbackSold
          : (_doneQuickFilterPreset == RoomColleDoneQuickFilterPreset.all
                ? widget.initial.doneFeedbackSold
                : false),
      doneFeedbackLiked: widget.isCandidateTab
          ? widget.initial.doneFeedbackLiked
          : (_doneQuickFilterPreset == RoomColleDoneQuickFilterPreset.all
                ? widget.initial.doneFeedbackLiked
                : false),
      doneFeedbackWeak: widget.isCandidateTab
          ? widget.initial.doneFeedbackWeak
          : (_doneQuickFilterPreset == RoomColleDoneQuickFilterPreset.all
                ? widget.initial.doneFeedbackWeak
                : false),
      doneFeedbackUnrated: widget.isCandidateTab
          ? widget.initial.doneFeedbackUnrated
          : (_doneQuickFilterPreset == RoomColleDoneQuickFilterPreset.all
                ? widget.initial.doneFeedbackUnrated
                : false),
      doneRoomConfirmedOnly: false,
    );
    Navigator.of(context).pop(
      _RoomColleFilterSheetApplyResult(
        criteria: merged,
        candidateExcludeUrlNotReady: false,
        includesCandidateUrlOption: widget.isCandidateTab,
      ),
    );
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: HomeScreenColors.homeAccentTeal,
          width: 1.3,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(label),
        DropdownButtonFormField<T>(
          key: ValueKey<Object?>(value),
          initialValue: value,
          isExpanded: true,
          decoration: _fieldDecoration(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  List<DropdownMenuItem<RoomColleRegisteredDatePreset>> _dateItems() {
    return const [
      DropdownMenuItem(
        value: RoomColleRegisteredDatePreset.all,
        child: Text('すべて'),
      ),
      DropdownMenuItem(
        value: RoomColleRegisteredDatePreset.today,
        child: Text('今日'),
      ),
      DropdownMenuItem(
        value: RoomColleRegisteredDatePreset.last3Days,
        child: Text('3日以内'),
      ),
      DropdownMenuItem(
        value: RoomColleRegisteredDatePreset.last7Days,
        child: Text('7日以内'),
      ),
      DropdownMenuItem(
        value: RoomColleRegisteredDatePreset.last30Days,
        child: Text('30日以内'),
      ),
    ];
  }

  List<DropdownMenuItem<String>> _shopItems() {
    return [
      const DropdownMenuItem(value: _shopAll, child: Text('すべて')),
      const DropdownMenuItem(value: _shopSaved, child: Text('保存したショップ')),
      if (widget.shopNames.isNotEmpty)
        const DropdownMenuItem<String>(
          enabled: false,
          value: '__divider__',
          child: Divider(height: 1),
        ),
      ...widget.shopNames.map(
        (name) => DropdownMenuItem(
          value: name,
          child: Text(name, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];
  }

  List<DropdownMenuItem<String>> _genreItems() {
    final choices = List<String>.of(widget.genreIds);
    final gCur = _genreId;
    if (gCur != null && gCur.isNotEmpty && !choices.contains(gCur)) {
      choices.add(gCur);
    }
    choices.sort();
    return [
      const DropdownMenuItem(value: '', child: Text('すべて')),
      ...choices.map(
        (id) => DropdownMenuItem(
          value: id,
          child: Text(
            _roomColleGenreFilterMenuText(id),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
  }

  List<DropdownMenuItem<_RoomColleCandidateStateFilter>>
  _candidateStateItems() {
    return const [
      DropdownMenuItem(
        value: _RoomColleCandidateStateFilter.all,
        child: Text('すべて'),
      ),
      DropdownMenuItem(
        value: _RoomColleCandidateStateFilter.unposted,
        child: Text('未投稿'),
      ),
      DropdownMenuItem(
        value: _RoomColleCandidateStateFilter.roomUrl,
        child: Text('ROOM URLあり'),
      ),
      DropdownMenuItem(
        value: _RoomColleCandidateStateFilter.todayRecommendation,
        child: Text('今日のおすすめ'),
      ),
    ];
  }

  List<DropdownMenuItem<RoomColleDoneQuickFilterPreset>>
  _doneQuickFilterPresetItems() {
    return const [
      DropdownMenuItem(
        value: RoomColleDoneQuickFilterPreset.all,
        child: Text('すべて'),
      ),
      DropdownMenuItem(
        value: RoomColleDoneQuickFilterPreset.sold,
        child: Text('売れた'),
      ),
      DropdownMenuItem(
        value: RoomColleDoneQuickFilterPreset.roomReaction,
        child: Text('反応あり'),
      ),
      DropdownMenuItem(
        value: RoomColleDoneQuickFilterPreset.roomCommentOnly,
        child: Text('コメントあり'),
      ),
      DropdownMenuItem(
        value: RoomColleDoneQuickFilterPreset.roomLikeOnly,
        child: Text('いいねあり'),
      ),
      DropdownMenuItem(
        value: RoomColleDoneQuickFilterPreset.roomPosted,
        child: Text('ROOM投稿済み'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.8;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: sheetHeight,
            child: Material(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(top: 10, bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.sectionTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ),
                          TextButton(
                            onPressed: _resetDraftExtended,
                            style: TextButton.styleFrom(
                              foregroundColor: HomeScreenColors.homeAccentTeal,
                              textStyle: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            child: const Text('リセット'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _dropdown<RoomColleRegisteredDatePreset>(
                              label: '日付',
                              value: _datePreset,
                              items: _dateItems(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _datePreset = v);
                                }
                              },
                            ),
                            const SizedBox(height: 24),
                            _dropdown<String>(
                              label: 'ショップ',
                              value: _shopValue,
                              items: _shopItems(),
                              onChanged: (v) {
                                if (v != null && v != '__divider__') {
                                  setState(() => _shopValue = v);
                                }
                              },
                            ),
                            const SizedBox(height: 24),
                            _dropdown<String>(
                              label: 'ジャンル',
                              value: _genreId ?? '',
                              items: _genreItems(),
                              onChanged: (v) {
                                setState(
                                  () => _genreId = (v == null || v.isEmpty)
                                      ? null
                                      : v,
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            _label('価格'),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: _minPriceCtrl,
                                    keyboardType: TextInputType.number,
                                    hintText: '最低価格',
                                    fillColor: HomeScreenColors.homeCardFill,
                                    enabledBorderColor:
                                        _RoomColleUi.searchFieldBorder,
                                    hintColor: _RoomColleUi.searchFieldHint,
                                    focusedBorderColor:
                                        HomeScreenColors.homeAccentTeal,
                                    onChanged: (_) =>
                                        _formatPriceController(_minPriceCtrl),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 14,
                                  ),
                                  child: Text('〜'),
                                ),
                                Expanded(
                                  child: AppTextField(
                                    controller: _maxPriceCtrl,
                                    keyboardType: TextInputType.number,
                                    hintText: '最高価格',
                                    fillColor: HomeScreenColors.homeCardFill,
                                    enabledBorderColor:
                                        _RoomColleUi.searchFieldBorder,
                                    hintColor: _RoomColleUi.searchFieldHint,
                                    focusedBorderColor:
                                        HomeScreenColors.homeAccentTeal,
                                    onChanged: (_) =>
                                        _formatPriceController(_maxPriceCtrl),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (widget.isCandidateTab)
                              _dropdown<_RoomColleCandidateStateFilter>(
                                label: '状態',
                                value: _candidateState,
                                items: _candidateStateItems(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _candidateState = v);
                                  }
                                },
                              )
                            else
                              _dropdown<RoomColleDoneQuickFilterPreset>(
                                label: '評価',
                                value: _doneQuickFilterPreset,
                                items: _doneQuickFilterPresetItems(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _doneQuickFilterPreset = v);
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          top: BorderSide(
                            color: AppColors.divider.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          14,
                          20,
                          12 + bottomPadding,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton(
                                onPressed: _apply,
                                style: FilledButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor:
                                      HomeScreenColors.homeAccentTeal,
                                  disabledForegroundColor: Colors.white
                                      .withValues(alpha: 0.72),
                                  disabledBackgroundColor: HomeScreenColors
                                      .homeAccentTeal
                                      .withValues(alpha: 0.34),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.15,
                                      ),
                                ),
                                child: const Text('この条件で検索'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                minimumSize: const Size(0, 44),
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              child: const Text('閉じる'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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

List<RakutenManagedProduct> _applyRoomImportMetaLineFilter(
  List<RakutenManagedProduct> items,
  _RoomImportMetaListFilter mode,
) {
  if (mode == _RoomImportMetaListFilter.all) return items;
  final out = <RakutenManagedProduct>[];
  for (final e in items) {
    if (e.coredActivitySource != RakutenCoredActivitySource.roomImport) {
      continue;
    }
    final incomplete =
        RoomImportMetadataEnrichmentService.needFlagsForProduct(e).willEnrich;
    switch (mode) {
      case _RoomImportMetaListFilter.all:
        out.add(e);
        break;
      case _RoomImportMetaListFilter.incompleteOnly:
        if (incomplete) out.add(e);
        break;
      case _RoomImportMetaListFilter.completeOnly:
        if (!incomplete) out.add(e);
        break;
    }
  }
  return out;
}

/// 一覧タブと同じ管線で表示リストを求める（URL未取得除外はコレ候補タブのみ適用）。
List<RakutenManagedProduct> _roomListVisibleItems({
  required RakutenManagedProductProvider provider,
  required RakutenManagedProductStatus status,
  required RoomColleListFilterCriteria listFilters,
  required bool excludeUrlNotReady,
  Set<String> savedShopIds = const <String>{},
  Set<String> todayRecommendationProductIds = const <String>{},
  String Function(RakutenManagedProduct product)? genreLabelForProduct,
  DateTime? doneAtLocalDayFilter,
  _RoomImportMetaListFilter roomImportMetaFilter = _RoomImportMetaListFilter.all,
}) {
  final baseList = provider.sortedItemsForStatus(status);
  final day = doneAtLocalDayFilter;
  final scoped = status == RakutenManagedProductStatus.done && day != null
      ? _filterDoneOnLocalCalendarDay(baseList, day)
      : baseList;
  final urlActive =
      status == RakutenManagedProductStatus.candidate && excludeUrlNotReady;
  final urlScoped = _filterExcludeUrlNotReady(scoped, urlActive);
  final queried = applyRoomColleListFilters(
    urlScoped,
    listFilters.copyWith(
      candidateHasRoomUrlOnly:
          listFilters.candidateHasRoomUrlOnly || excludeUrlNotReady,
    ),
    savedShopIds: savedShopIds,
    todayRecommendationProductIds: todayRecommendationProductIds,
    genreLabelForProduct: genreLabelForProduct,
  );
  final deduped = _dedupeManagedProductsPreserveOrder(queried);
  final metaFiltered =
      status == RakutenManagedProductStatus.done &&
          roomImportMetaFilter != _RoomImportMetaListFilter.all
      ? _applyRoomImportMetaLineFilter(deduped, roomImportMetaFilter)
      : deduped;
  if (metaFiltered.isEmpty && baseList.isNotEmpty) {
    final urlHidAll =
        status == RakutenManagedProductStatus.candidate &&
        excludeUrlNotReady &&
        scoped.isNotEmpty &&
        _filterExcludeUrlNotReady(scoped, true).isEmpty;
    final reducingActive = listFilters.hasAnyReducingFilter;
    final searchHidAll = reducingActive && scoped.isNotEmpty;
    final metaHidAll =
        status == RakutenManagedProductStatus.done &&
        roomImportMetaFilter != _RoomImportMetaListFilter.all &&
        deduped.isNotEmpty &&
        _applyRoomImportMetaLineFilter(deduped, roomImportMetaFilter).isEmpty;
    if (!urlHidAll && !searchHidAll && !metaHidAll) {
      final rawScoped =
          status == RakutenManagedProductStatus.done && day != null
          ? _filterDoneOnLocalCalendarDay(baseList, day)
          : baseList;
      final fallback = _dedupeManagedProductsPreserveOrder(rawScoped);
      if (fallback.isNotEmpty) return fallback;
    }
  }
  return metaFiltered;
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
        (e.affiliateUrl?.trim().isNotEmpty ?? false) ||
        e.itemUrl.trim().isNotEmpty ||
        (e.rakutenUrl?.trim().isNotEmpty ?? false);
  }).toList();
}

List<RakutenManagedProduct> _sortRoomColleListItems(
  List<RakutenManagedProduct> items,
  RakutenManagedProductStatus status,
  RoomColleListSortPreset preset,
) {
  final out = List<RakutenManagedProduct>.from(items);
  int byPriceAsc(RakutenManagedProduct a, RakutenManagedProduct b) =>
      a.itemPrice.compareTo(b.itemPrice);
  int byAddedAsc(RakutenManagedProduct a, RakutenManagedProduct b) =>
      a.addedAt.compareTo(b.addedAt);
  int byDoneAsc(RakutenManagedProduct a, RakutenManagedProduct b) {
    final ad = a.doneAt;
    final bd = b.doneAt;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  // 将来: ROOMいいね順は lib/models/room_colle_advanced_query.dart の比較関数へ配線予定。

  switch (preset) {
    case RoomColleListSortPreset.recentFirst:
      out.sort(
        status == RakutenManagedProductStatus.done
            ? (a, b) => byDoneAsc(b, a)
            : (a, b) => byAddedAsc(b, a),
      );
      return out;
    case RoomColleListSortPreset.oldFirst:
      out.sort(
        status == RakutenManagedProductStatus.done ? byDoneAsc : byAddedAsc,
      );
      return out;
    case RoomColleListSortPreset.priceHigh:
      out.sort((a, b) => byPriceAsc(b, a));
      return out;
    case RoomColleListSortPreset.priceLow:
      out.sort(byPriceAsc);
      return out;
  }
}

/// 各タブ一覧エリアの表面状態（読込 / 表示成功の内訳 / 失敗）。デバッグは [debugLabel]。
enum _RoomColleListSurface {
  loading,
  loadError,
  readyEmptyNoData,
  readyEmptyFilteredByDay,
  readyEmptyFilteredByUrl,
  readyEmptyFilteredBySearch,
  readyEmptyFilteredByMeta,
  readyEmptyFilteredByReaction,
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
      case _RoomColleListSurface.readyEmptyFilteredByMeta:
        return 'ok_empty_filter_meta';
      case _RoomColleListSurface.readyEmptyFilteredByReaction:
        return 'ok_empty_filter_reaction';
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
  required RoomColleListFilterCriteria listFilters,
  required bool hasDayFilter,
  required bool canShowDayEmptyMessage,
  bool metaFilterHidAll = false,
  bool reactionFilterHidAll = false,
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

  if (hasDayFilter && scoped.isEmpty && canShowDayEmptyMessage) {
    return _RoomColleListSurface.readyEmptyFilteredByDay;
  }

  if (list.isEmpty) {
    if (urlActive && scoped.isNotEmpty && urlScoped.isEmpty) {
      return _RoomColleListSurface.readyEmptyFilteredByUrl;
    }
    if (metaFilterHidAll) {
      return _RoomColleListSurface.readyEmptyFilteredByMeta;
    }
    if (reactionFilterHidAll) {
      return _RoomColleListSurface.readyEmptyFilteredByReaction;
    }
    if (scoped.isNotEmpty && listFilters.hasAnyReducingFilter) {
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
  late final TextEditingController _candidateSearchController;
  late final TextEditingController _doneSearchController;
  final ScrollController _candidateScrollController = ScrollController();
  final Map<String, GlobalKey> _candidateRowKeys = <String, GlobalKey>{};
  // 一覧絞り込み（キーワード＋拡張条件）。永続化は [RoomColleUiStateSnapshot] 経由。
  RoomColleListFilterCriteria _candidateListFilters =
      RoomColleListFilterCriteria.defaults;
  RoomColleListFilterCriteria _doneListFilters =
      RoomColleListFilterCriteria.defaults;
  DateTime? _doneLocalDayFilter;
  Timer? _flashTimer;
  String? _flashProductId;
  bool _candidateFocusHandled = false;
  String? _shellFocusCandidateProductId;
  late final AppShellController _shellCtrl;
  late final RoomColleUiStateRepository _roomColleUiRepo;
  bool _candidateExcludeUrlNotReady = false;
  RoomColleListSortPreset _candidateSortPreset =
      RoomColleListSortPreset.recentFirst;
  RoomColleListSortPreset _doneSortPreset = RoomColleListSortPreset.recentFirst;

  _RoomImportMetaListFilter _doneRoomImportMetaFilter =
      _RoomImportMetaListFilter.all;

  /// [RoomColleUiStateSnapshot.staleCandidatePileBannerDismissed] と同期。
  bool _stalePileBannerDismissed = false;

  /// [RoomColleUiStateSnapshot.doneReactionQuickAutoAppliedOnce] と同期。
  bool _doneReactionQuickAutoAppliedOnce = false;
  Timer? _persistSearchDebounce;
  int _lastShellIndex = _roomColleShellIndex;

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
    // コレ済タブ表示中やレイアウト中に ensureVisible すると sliver 整合が崩れる。
    // 候補タブ選択時のみ、2フレーム後に実行する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tabController.index != 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tabController.index != 0) return;
        final ctx = _candidateRowKeys[productId]?.currentContext;
        if (ctx == null) {
          _runScrollToCandidate(productId, attempt + 1);
          return;
        }
        final ro = ctx.findRenderObject();
        if (ro is! RenderBox || !ro.hasSize || !ro.attached) {
          _runScrollToCandidate(productId, attempt + 1);
          return;
        }
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
        if (!mounted || _tabController.index != 0) return;
        setState(() => _flashProductId = productId);
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) setState(() => _flashProductId = null);
        });
      });
    });
  }

  void _maybeAutoSelectDoneRoomReactionFilter(
    RakutenManagedProductProvider managed,
  ) {
    if (_doneReactionQuickAutoAppliedOnce) return;
    if (!_doneListFilters.isDoneFilterDefaultForAutoReaction) return;
    final doneItems = managed.sortedItemsForStatus(
      RakutenManagedProductStatus.done,
    );
    final hasReaction = doneItems.any((e) {
      final lc = e.roomLikeCount;
      final cc = e.roomCommentCount;
      return (lc != null && lc > 0) || (cc != null && cc > 0);
    });
    if (!mounted) return;
    setState(() {
      _doneReactionQuickAutoAppliedOnce = true;
      if (hasReaction) {
        _doneListFilters = _doneListFilters.copyWith(
          doneQuickFilter: RoomColleDoneQuickFilterPreset.roomReaction,
          doneFeedbackSold: false,
          doneFeedbackLiked: false,
          doneFeedbackWeak: false,
          doneFeedbackUnrated: false,
        );
      }
    });
    _persistRoomColleUiNow();
  }

  TextEditingController get _activeRoomColleSearchController =>
      _tabController.index == 0
      ? _candidateSearchController
      : _doneSearchController;

  bool get _activeRoomColleSearchHasText =>
      _activeRoomColleSearchController.text.trim().isNotEmpty;

  void _onRoomColleSearchChanged(String value) {
    if (!mounted) return;
    final idx = _tabController.index;
    setState(() {
      if (idx == 0) {
        _candidateListFilters = _candidateListFilters.copyWith(keyword: value);
      } else {
        _doneListFilters = _doneListFilters.copyWith(keyword: value);
      }
    });
    _schedulePersistRoomColleSearch();
  }

  void _clearActiveRoomColleSearch() {
    if (!mounted) return;
    _persistSearchDebounce?.cancel();
    final idx = _tabController.index;
    setState(() {
      if (idx == 0) {
        _candidateSearchController.clear();
        _candidateListFilters = _candidateListFilters.copyWith(keyword: '');
      } else {
        _doneSearchController.clear();
        _doneListFilters = _doneListFilters.copyWith(keyword: '');
      }
    });
    _persistRoomColleUiNow();
  }

  /// フィルター画面を開かず、検索・絞り込み条件のみ解除（メイン/サブタブは維持）。
  void _clearActiveRoomColleSheetFilters() {
    if (!mounted) return;
    _persistSearchDebounce?.cancel();
    setState(() {
      _candidateSearchController.clear();
      _doneSearchController.clear();
      _candidateListFilters = RoomColleListFilterCriteria.defaults;
      _doneListFilters = RoomColleListFilterCriteria.defaults;
      _candidateExcludeUrlNotReady = false;
      _candidateSortPreset = RoomColleListSortPreset.recentFirst;
      _doneSortPreset = RoomColleListSortPreset.recentFirst;
      _doneLocalDayFilter = null;
    });
    _persistRoomColleUiNow();
  }

  /// BottomNavigation で投稿画面を離れる／他タブから戻るとき、表示用の検索・フィルターのみ初期化。
  /// メインタブ・コレ済サブタブ（すべて/未確認/確認済）は維持する。
  void _resetRoomColleDisplayStateForShellLeave() {
    if (!mounted) return;
    _persistSearchDebounce?.cancel();
    setState(() {
      _candidateExcludeUrlNotReady = false;
      _candidateSortPreset = RoomColleListSortPreset.recentFirst;
      _doneSortPreset = RoomColleListSortPreset.recentFirst;
      _candidateListFilters = RoomColleListFilterCriteria.defaults;
      _doneListFilters = RoomColleListFilterCriteria.defaults;
      _candidateSearchController.clear();
      _doneSearchController.clear();
      _doneLocalDayFilter = null;
    });
    _persistRoomColleUiNow();
  }

  RoomColleUiStateSnapshot _snapshotForPersist() {
    return RoomColleUiStateSnapshot(
      tabIndex: _tabController.index.clamp(0, 1),
      candidateListFilters: _candidateListFilters,
      doneListFilters: _doneListFilters,
      candidateExcludeUrlNotReady: _candidateExcludeUrlNotReady,
      doneLocalDay: _doneLocalDayFilter,
      staleCandidatePileBannerDismissed: _stalePileBannerDismissed,
      doneReactionQuickAutoAppliedOnce: _doneReactionQuickAutoAppliedOnce,
    );
  }

  Future<void> _openRoomColleFilterEditor({required bool isCandidate}) async {
    final managed = context.read<RakutenManagedProductProvider>();
    final status = isCandidate
        ? RakutenManagedProductStatus.candidate
        : RakutenManagedProductStatus.done;
    final base = managed.sortedItemsForStatus(status);
    final genreIds = _roomColleDistinctGenreIds(base);
    final shopNames = _roomColleDistinctShopNames(base);
    final current = isCandidate ? _candidateListFilters : _doneListFilters;
    const title = 'フィルター';
    final result = await showModalBottomSheet<_RoomColleFilterSheetApplyResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (ctx) => _RoomColleFilterEditorSheet(
        sectionTitle: title,
        initial: current,
        genreIds: genreIds,
        shopNames: shopNames,
        isCandidateTab: isCandidate,
        initialExcludeUrlNotReady: isCandidate
            ? _candidateExcludeUrlNotReady
            : false,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (isCandidate) {
        _candidateListFilters = result.criteria;
        if (result.includesCandidateUrlOption) {
          _candidateExcludeUrlNotReady = result.candidateExcludeUrlNotReady;
        }
      } else {
        _doneListFilters = result.criteria;
      }
    });
    _persistRoomColleUiNow();
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
    _persistSearchDebounce?.cancel();
    setState(() {
      _candidateExcludeUrlNotReady = false;
      _candidateSortPreset = RoomColleListSortPreset.recentFirst;
      _doneSortPreset = RoomColleListSortPreset.recentFirst;
      _candidateListFilters = RoomColleListFilterCriteria.defaults;
      _doneListFilters = RoomColleListFilterCriteria.defaults;
      _candidateSearchController.clear();
      _doneSearchController.clear();
      _doneLocalDayFilter = null;
      _doneReactionQuickAutoAppliedOnce = false;
    });
    await _roomColleUiRepo.clearPersisted();
    await _roomColleUiRepo.saveSanitized(RoomColleUiStateSnapshot.defaults);
    if (!mounted) return;
    final managed = context.read<RakutenManagedProductProvider>();
    managed.recoverListUiSilently();
    await managed.refreshManagedProductList(showLoadingIndicator: true);
  }

  @override
  void initState() {
    super.initState();
    _candidateSearchController = TextEditingController();
    _doneSearchController = TextEditingController();
    _roomColleUiRepo = context.read<RoomColleUiStateRepository>();
    final persisted = _roomColleUiRepo.loadSanitized();
    _doneReactionQuickAutoAppliedOnce =
        persisted.doneReactionQuickAutoAppliedOnce;

    if (_roomColleScreenHasExplicitRouteArgs(widget)) {
      _doneLocalDayFilter = _normalizeDoneDayFilter(
        widget.initialDoneFilterLocalDay,
      );
    } else {
      _candidateListFilters = persisted.candidateListFilters;
      _candidateSearchController.text = persisted.candidateListFilters.keyword;
      _doneListFilters = persisted.doneListFilters;
      _doneSearchController.text = persisted.doneListFilters.keyword;
      _candidateExcludeUrlNotReady = persisted.candidateExcludeUrlNotReady;
      _doneLocalDayFilter = _normalizeDoneDayFilter(persisted.doneLocalDay);
    }
    _stalePileBannerDismissed = persisted.staleCandidatePileBannerDismissed;

    final focusId = widget.initialFocusCandidateProductId;
    final idx0 = widget.initialTabIndex.clamp(0, 1);
    if (focusId != null && focusId.isNotEmpty && idx0 == 0) {
      _candidateSearchController.clear();
      _candidateListFilters = _candidateListFilters.copyWith(keyword: '');
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
    _lastShellIndex = _shellCtrl.currentIndex;
    _shellCtrl.addListener(_onShellCtrlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final managed = context.read<RakutenManagedProductProvider>();
      if (managed.listUiStatus == RakutenManagedProductListUiStatus.error) {
        if (kDebugMode) {
          debugPrint('[ROOMコレ] init_post_frame: recover list UI from error');
        }
        managed.recoverListUiSilently();
      }
      _tryConsumeRoomCollectIntent();
      await managed.refreshManagedProductList(
        showLoadingIndicator: false,
        loadSource: 'screen',
        tab: _tabController.index == 0 ? 'candidate' : 'done',
      );
      if (!mounted) return;
      _maybeAutoSelectDoneRoomReactionFilter(managed);
      if (kDebugMode) {
        final m = context.read<RakutenManagedProductProvider>();
        final nCand = m
            .sortedItemsForStatus(RakutenManagedProductStatus.candidate)
            .length;
        final nDone = m
            .sortedItemsForStatus(RakutenManagedProductStatus.done)
            .length;
        roomAuditLog(
          '[ROOMコレ診断] ROOMコレ画面起動後 total=${m.items.length} candidate=$nCand '
          'done=$nDone listUi=${m.listUiStatus} tabIdx=${_tabController.index}',
        );
      }
      if (!mounted) return;
      unawaited(
        context
            .read<RoomImportController>()
            .tickSlowRoomMetadataEnrichmentIfNeeded(context),
      );
    });
  }

  void _onShellCtrlChanged() {
    if (!mounted) return;
    final current = _shellCtrl.currentIndex;
    final wasOnRoomColle = _lastShellIndex == _roomColleShellIndex;
    final isOnRoomColle = current == _roomColleShellIndex;
    if (wasOnRoomColle && !isOnRoomColle) {
      _resetRoomColleDisplayStateForShellLeave();
    } else if (!wasOnRoomColle && isOnRoomColle) {
      _resetRoomColleDisplayStateForShellLeave();
    }
    _lastShellIndex = current;
    // IndexedStack 維持のため initState は1回のみ。タブ再表示時に一覧とエラー状態を復旧する。
    if (isOnRoomColle) {
      final managed = context.read<RakutenManagedProductProvider>();
      if (managed.listUiStatus == RakutenManagedProductListUiStatus.error) {
        if (kDebugMode) {
          debugPrint('[ROOMコレ] shell_tab_focus: recover list UI from error');
        }
        managed.recoverListUiSilently();
      }
      _tryConsumeRoomCollectIntent();
      managed.refreshManagedProductList(
        showLoadingIndicator: false,
        loadSource: 'screen',
        tab: _tabController.index == 0 ? 'candidate' : 'done',
      );
      unawaited(
        context
            .read<RoomImportController>()
            .tickSlowRoomMetadataEnrichmentIfNeeded(context),
      );
    } else {
      _tryConsumeRoomCollectIntent();
    }
  }

  /// ホーム等からの [openRoomCollect] のインテントのみ消費する。
  /// 適用は次フレームへ逃がし、シェル通知中の同期的 setState 連鎖を避ける。
  void _tryConsumeRoomCollectIntent() {
    if (!mounted) return;
    final intent = _shellCtrl.takePendingRoomCollectIntent();
    if (intent == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyRoomCollectIntent(intent);
    });
  }

  void _applyRoomCollectIntent(RoomCollectNavigationIntent intent) {
    final idx = intent.initialTabIndex.clamp(0, 1);
    var focusRaw = intent.focusCandidateProductId?.trim();
    if (focusRaw != null && focusRaw.isEmpty) focusRaw = null;
    final focusId = (focusRaw != null && focusRaw.isNotEmpty && idx == 0)
        ? focusRaw
        : null;

    _persistSearchDebounce?.cancel();
    final staleFromIntent = intent.candidateStalePreset;
    setState(() {
      _candidateExcludeUrlNotReady = false;
      _candidateSortPreset = RoomColleListSortPreset.recentFirst;
      _doneSortPreset = RoomColleListSortPreset.recentFirst;
      _candidateSearchController.clear();
      _doneSearchController.clear();
      _candidateListFilters = RoomColleListFilterCriteria.defaults.copyWith(
        staleCandidatePreset:
            idx == 0 &&
                staleFromIntent != null &&
                staleFromIntent != RoomColleStaleCandidatePreset.none
            ? staleFromIntent
            : RoomColleStaleCandidatePreset.none,
      );
      _doneListFilters = RoomColleListFilterCriteria.defaults;
      if (idx == 0) {
        _doneLocalDayFilter = null;
      } else {
        _doneLocalDayFilter = _normalizeDoneDayFilter(
          intent.doneFilterLocalDay,
        );
      }
      _shellFocusCandidateProductId = focusId;
      _candidateFocusHandled = false;
    });

    if (_tabController.index != idx) {
      _tabController.animateTo(
        idx,
        duration: Duration.zero,
        curve: Curves.linear,
      );
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
    _candidateSearchController.dispose();
    _doneSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: HomeScreenColors.canvas,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _kRoomListScreenPadH,
                  6,
                  _kRoomListScreenPadH,
                  2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (canPop)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded, size: 22),
                            color: HomeScreenColors.homeTextPrimary,
                            tooltip: '戻る',
                          ),
                        ),
                      ),
                    Text(
                      '投稿管理',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: HomeScreenColors.homeTextPrimary,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'コレ候補と投稿済み商品を管理できます',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: HomeScreenColors.homeTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _kRoomListScreenPadH,
                  6,
                  _kRoomListScreenPadH,
                  0,
                ),
                child: SizedBox(
                  height: _RoomColleUi.searchRowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: AppTextField(
                          key: ValueKey<int>(_tabController.index),
                          controller: _activeRoomColleSearchController,
                          onChanged: _onRoomColleSearchChanged,
                          textInputAction: TextInputAction.search,
                          hintText: '商品・ショップ・ジャンルを検索',
                          semanticLabel: 'post_management_search_field',
                          fixedHeight: _RoomColleUi.searchRowHeight,
                          fillColor: HomeScreenColors.homeCardFill,
                          enabledBorderColor: _RoomColleUi.searchFieldBorder,
                          hintColor: _RoomColleUi.searchFieldHint,
                          focusedBorderColor: HomeScreenColors.homeAccentTeal,
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: const Color(0xFF64748B),
                          ),
                          suffixIcon: _activeRoomColleSearchHasText
                              ? IconButton(
                                  tooltip: '検索文字を消去',
                                  onPressed: _clearActiveRoomColleSearch,
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: _RoomColleUi.filterButtonWidth,
                        height: _RoomColleUi.searchRowHeight,
                        child: _RoomColleFilterButton(
                          active: _roomColleHasActiveSheetFilters(
                            isCandidate: _tabController.index == 0,
                            criteria: _tabController.index == 0
                                ? _candidateListFilters
                                : _doneListFilters,
                            excludeUrlNotReady: _tabController.index == 0 &&
                                _candidateExcludeUrlNotReady,
                            sortPreset: _tabController.index == 0
                                ? _candidateSortPreset
                                : _doneSortPreset,
                            doneAtLocalDayFilter: _doneLocalDayFilter,
                          ),
                          activeCount: _roomColleActiveFilterCount(
                            isCandidate: _tabController.index == 0,
                            criteria: _tabController.index == 0
                                ? _candidateListFilters
                                : _doneListFilters,
                            excludeUrlNotReady: _tabController.index == 0 &&
                                _candidateExcludeUrlNotReady,
                            sortPreset: _tabController.index == 0
                                ? _candidateSortPreset
                                : _doneSortPreset,
                            doneAtLocalDayFilter: _doneLocalDayFilter,
                          ),
                          onPressed: () => _openRoomColleFilterEditor(
                            isCandidate: _tabController.index == 0,
                          ),
                          onClear: _roomColleHasActiveSheetFilters(
                            isCandidate: _tabController.index == 0,
                            criteria: _tabController.index == 0
                                ? _candidateListFilters
                                : _doneListFilters,
                            excludeUrlNotReady: _tabController.index == 0 &&
                                _candidateExcludeUrlNotReady,
                            sortPreset: _tabController.index == 0
                                ? _candidateSortPreset
                                : _doneSortPreset,
                            doneAtLocalDayFilter: _doneLocalDayFilter,
                          )
                              ? _clearActiveRoomColleSheetFilters
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _kRoomListScreenPadH,
                  6,
                  _kRoomListScreenPadH,
                  0,
                ),
                child: DecoratedBox(
                  decoration: _RoomColleUi.tabSegmentTrackDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(_RoomColleUi.tabInnerPad),
                    child: Consumer<RakutenManagedProductProvider>(
                      builder: (context, managed, _) {
                        final nCand = managed
                            .sortedItemsForStatus(
                              RakutenManagedProductStatus.candidate,
                            )
                            .length;
                        final nDone = managed
                            .sortedItemsForStatus(
                              RakutenManagedProductStatus.done,
                            )
                            .length;
                        final idx = _tabController.index;
                        final segmentShape = RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _kRoomColleTabTrackRadius - 4,
                          ),
                        );
                        return Semantics(
                          container: true,
                          label: idx == 0
                              ? 'post_management_tab_candidates'
                              : 'post_management_tab_posted',
                          child: SegmentedButton<int>(
                            showSelectedIcon: false,
                            expandedInsets: EdgeInsets.zero,
                            segments: <ButtonSegment<int>>[
                              ButtonSegment<int>(
                                value: 0,
                                label: Text(
                                  'コレ候補（$nCand件）',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                tooltip: 'コレ候補の一覧',
                              ),
                              ButtonSegment<int>(
                                value: 1,
                                label: Text(
                                  'コレ済（$nDone件）',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
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
                              visualDensity: VisualDensity.standard,
                              tapTargetSize: MaterialTapTargetSize.padded,
                              minimumSize: WidgetStateProperty.all(
                                const Size(48, 44),
                              ),
                              side: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return BorderSide.none;
                                }
                                return const BorderSide(
                                  color: HomeScreenColors.homeCardBorder,
                                );
                              }),
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 10,
                                ),
                              ),
                              shape: WidgetStateProperty.all(segmentShape),
                              foregroundColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return HomeScreenColors.homeMutedText;
                              }),
                              backgroundColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return HomeScreenColors.homeAccentTeal;
                                }
                                return HomeScreenColors.homeCardFill;
                              }),
                              textStyle: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                final base =
                                    Theme.of(context).textTheme.labelLarge;
                                final selected = states.contains(
                                  WidgetState.selected,
                                );
                                return base?.copyWith(
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  height: 1.2,
                                );
                              }),
                              overlayColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white.withValues(alpha: 0.12);
                                }
                                return HomeScreenColors.inkNeutralSplash;
                              }),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: _RoomColleUi.gapSection),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: _RoomColleUi.gapListAfterDivider),
                        Consumer<RakutenManagedProductProvider>(
                          builder: (context, managed, _) {
                            final pile = _roomColleStale7PlusCandidateCount(
                              managed,
                            );
                            if (pile < 5 && _stalePileBannerDismissed) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted || !_stalePileBannerDismissed) {
                                  return;
                                }
                                setState(
                                  () => _stalePileBannerDismissed = false,
                                );
                                _persistRoomColleUiNow();
                              });
                            }
                            if (pile < 5 || _stalePileBannerDismissed) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                _kRoomListScreenPadH,
                                0,
                                _kRoomListScreenPadH,
                                _RoomColleUi.gapFieldStack,
                              ),
                              child: _RoomColleStalePileNoticeBar(
                                onDismiss: () {
                                  setState(
                                    () => _stalePileBannerDismissed = true,
                                  );
                                  _persistRoomColleUiNow();
                                },
                              ),
                            );
                          },
                        ),
                        Expanded(
                          child: _RoomManagedProductListTab(
                            status: RakutenManagedProductStatus.candidate,
                            variant: RakutenManagedProductCardVariant.candidate,
                            listFilters: _candidateListFilters,
                            sortPreset: _candidateSortPreset,
                            excludeUrlNotReady: _candidateExcludeUrlNotReady,
                            candidateFocusHandled: _candidateFocusHandled,
                            onRecoverFromListError:
                                _recoverRoomColleListAndFilters,
                            emptyTitle: 'コレ候補はまだありません',
                            emptySubtitle:
                                '「探す」や「今日のおすすめ」から候補に追加できます。',
                            emptyHint: '',
                            accentColor: RoomColleListAccent.candidate,
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
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: _RoomColleUi.gapListAfterDivider),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            _kRoomListScreenPadH,
                            0,
                            _kRoomListScreenPadH,
                            2,
                          ),
                          child: SegmentedButton<_RoomImportMetaListFilter>(
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: WidgetStateProperty.all(
                                const Size(48, 34),
                              ),
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                  vertical: 5,
                                  horizontal: 8,
                                ),
                              ),
                              foregroundColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return HomeScreenColors.homeMutedText;
                              }),
                              backgroundColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return HomeScreenColors.homeAccentTeal;
                                }
                                return HomeScreenColors.homeCardFill;
                              }),
                              side: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return BorderSide.none;
                                }
                                return const BorderSide(
                                  color: HomeScreenColors.homeCardBorder,
                                );
                              }),
                              textStyle: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                final selected = states.contains(
                                  WidgetState.selected,
                                );
                                return TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  height: 1.15,
                                );
                              }),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: _RoomImportMetaListFilter.all,
                                label: Text('すべて'),
                              ),
                              ButtonSegment(
                                value:
                                    _RoomImportMetaListFilter.incompleteOnly,
                                label: Text('未確認'),
                              ),
                              ButtonSegment(
                                value: _RoomImportMetaListFilter.completeOnly,
                                label: Text('確認済'),
                              ),
                            ],
                            selected: <_RoomImportMetaListFilter>{
                              _doneRoomImportMetaFilter,
                            },
                            onSelectionChanged: (s) {
                              if (s.isEmpty) return;
                              setState(() {
                                _doneRoomImportMetaFilter = s.first;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: _RoomManagedProductListTab(
                            status: RakutenManagedProductStatus.done,
                            variant: RakutenManagedProductCardVariant.done,
                            listFilters: _doneListFilters,
                            sortPreset: _doneSortPreset,
                            roomImportMetaFilter: _doneRoomImportMetaFilter,
                            excludeUrlNotReady: false,
                            candidateFocusHandled: true,
                            onRecoverFromListError:
                                _recoverRoomColleListAndFilters,
                            doneAtLocalDayFilter: _doneLocalDayFilter,
                            onClearDoneDayFilter: _doneLocalDayFilter == null
                                ? null
                                : () {
                                    setState(() => _doneLocalDayFilter = null);
                                    _persistRoomColleUiNow();
                                  },
                            emptyTitle: 'コレ済の商品はまだありません',
                            emptySubtitle:
                                'ROOMに投稿した商品や、候補からコレ済に移した商品がここに表示されます。',
                            emptyHint: '',
                            dayFilterEmptyTitle: 'この日にコレした商品はありません',
                            dayFilterEmptySubtitle:
                                '表示は端末の日付（このアプリでコレ済にした日時）に基づきます。',
                            accentColor: RoomColleListAccent.done,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomManagedProductListTab extends StatefulWidget {
  const _RoomManagedProductListTab({
    required this.status,
    required this.variant,
    required this.listFilters,
    required this.sortPreset,
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
    this.roomImportMetaFilter = _RoomImportMetaListFilter.all,
  });

  final RakutenManagedProductStatus status;
  final RakutenManagedProductCardVariant variant;
  final RoomColleListFilterCriteria listFilters;
  final RoomColleListSortPreset sortPreset;
  final _RoomImportMetaListFilter roomImportMetaFilter;
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

class _RoomManagedProductListTabState
    extends State<_RoomManagedProductListTab> {
  bool _candidateFocusCallbackEnqueued = false;
  String? _lastSeenFocusProductId;
  _RoomColleListSurface? _lastDebugSurface;

  /// [GenreMasterRepository] プリフェッチ結果（genreId 文字列キー）。
  Map<String, String> _genrePrefetchLabels = const {};

  String? _lastGenrePrefetchSig;

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

  void _scheduleCandidateFocusKickOnce(BuildContext context) {
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
        if (p.listUiStatus == RakutenManagedProductListUiStatus.loading ||
            p.listUiStatus == RakutenManagedProductListUiStatus.error) {
          return;
        }
        if (widget.candidateFocusHandled) return;

        final listNow = _roomListVisibleItems(
          provider: p,
          status: RakutenManagedProductStatus.candidate,
          listFilters: widget.listFilters,
          excludeUrlNotReady: widget.excludeUrlNotReady,
          savedShopIds: context
              .read<SavedShopProvider>()
              .shops
              .map((e) => e.shopId.trim())
              .where((e) => e.isNotEmpty)
              .toSet(),
          todayRecommendationProductIds:
              context
                  .read<TodayRecommendationProvider>()
                  .bundle
                  ?.entries
                  .map((e) => e.item.productId.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet() ??
              <String>{},
          genreLabelForProduct: _roomColleGenreLabelForProduct,
          doneAtLocalDayFilter: null,
          roomImportMetaFilter: widget.roomImportMetaFilter,
        );
        final baseCand = p.sortedItemsForStatus(
          RakutenManagedProductStatus.candidate,
        );

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

  void _scheduleGenrePrefetchIfNeeded(List<RakutenManagedProduct> list) {
    final sig = list.map((e) => '${e.productId}:${e.genreId}').join('|');
    if (sig == _lastGenrePrefetchSig) return;
    _lastGenrePrefetchSig = sig;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ids = <int>{};
      for (final p in list) {
        final n = int.tryParse(p.genreId.trim());
        if (n != null && n > 0) ids.add(n);
      }
      if (ids.isEmpty) {
        if (mounted) {
          setState(() => _genrePrefetchLabels = const {});
        }
        return;
      }
      final toPrefetch = RakutenGenreMasterService.instance
          .genreIdsNeedingApiPrefetch(ids);
      if (toPrefetch.isEmpty) {
        if (mounted) {
          setState(() => _genrePrefetchLabels = const {});
        }
        return;
      }
      try {
        final repo = context.read<GenreMasterRepository>();
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
          setState(() => _genrePrefetchLabels = next);
        }
        if (kDebugMode && list.isNotEmpty) {
          final e = list.first;
          RakutenProductGenreDisplay.debugLogResolution(
            itemCode: e.productId,
            genreId: e.genreId,
            apiGenreName: e.genreName,
            finalLabel: RakutenProductGenreDisplay.resolve(
              apiGenreName: null,
              persistedGenreName: e.persistedGenreDisplayName,
              prefetchedGenreName: next[e.genreId.trim()],
              genreId: e.genreId,
            ),
          );
        }
      } catch (_) {}
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
    return Consumer3<
      RakutenManagedProductProvider,
      RoomActivityEventProvider,
      BulkOperationStateController
    >(
      builder: (context, provider, act, bulk, _) {
        final ui = provider.listUiStatus;
        final collectSnap = RoomCollectPostLimitSnapshot.compute(
          items: provider.items,
          events: act.events,
          now: DateTime.now(),
        );
        final postingBlocked =
            widget.status == RakutenManagedProductStatus.candidate &&
            !collectSnap.canAcceptAnotherCollect;
        var postingBlockedUserMessage = '';
        if (postingBlocked) {
          postingBlockedUserMessage = collectSnap.userBlockMessage ?? '';
          if (collectSnap.isHourlyReached) {
            postingBlockedUserMessage +=
                '\n${collectSnap.recoveryFootnote(DateTime.now())}';
          }
        }
        final savedShopIds = _savedShopIdSet(context);
        final todayRecommendationIds = _todayRecommendationIdSet(context);
        final baseList = provider.sortedItemsForStatus(widget.status);

        final listRaw = _roomListVisibleItems(
          provider: provider,
          status: widget.status,
          listFilters: widget.listFilters,
          excludeUrlNotReady: widget.excludeUrlNotReady,
          savedShopIds: savedShopIds,
          todayRecommendationProductIds: todayRecommendationIds,
          genreLabelForProduct: (product) => _roomColleGenreLabelForProduct(
            product,
            prefetchedGenreLabels: _genrePrefetchLabels,
          ),
          doneAtLocalDayFilter: widget.doneAtLocalDayFilter,
          roomImportMetaFilter: widget.roomImportMetaFilter,
        );
        final listWithoutMetaFilter = widget.roomImportMetaFilter !=
                _RoomImportMetaListFilter.all
            ? _roomListVisibleItems(
                provider: provider,
                status: widget.status,
                listFilters: widget.listFilters,
                excludeUrlNotReady: widget.excludeUrlNotReady,
                savedShopIds: savedShopIds,
                todayRecommendationProductIds: todayRecommendationIds,
                genreLabelForProduct: (product) => _roomColleGenreLabelForProduct(
                  product,
                  prefetchedGenreLabels: _genrePrefetchLabels,
                ),
                doneAtLocalDayFilter: widget.doneAtLocalDayFilter,
                roomImportMetaFilter: _RoomImportMetaListFilter.all,
              )
            : listRaw;
        final metaFilterHidAll =
            widget.roomImportMetaFilter != _RoomImportMetaListFilter.all &&
            listWithoutMetaFilter.isNotEmpty &&
            listRaw.isEmpty;
        final reactionFilterHidAll =
            widget.status == RakutenManagedProductStatus.done &&
            widget.listFilters.doneQuickFilter ==
                RoomColleDoneQuickFilterPreset.roomReaction &&
            widget.listFilters.keyword.trim().isEmpty &&
            listRaw.isEmpty &&
            baseList.isNotEmpty;
        final list = _sortRoomColleListItems(
          listRaw,
          widget.status,
          widget.sortPreset,
        );

        final day = widget.doneAtLocalDayFilter;
        final scoped =
            widget.status == RakutenManagedProductStatus.done && day != null
            ? _filterDoneOnLocalCalendarDay(baseList, day)
            : baseList;
        final urlActive =
            widget.status == RakutenManagedProductStatus.candidate &&
            widget.excludeUrlNotReady;
        final urlScoped = _filterExcludeUrlNotReady(scoped, urlActive);

        final canShowDayEmpty =
            widget.dayFilterEmptyTitle != null &&
            widget.dayFilterEmptySubtitle != null;

        final surface = _resolveRoomColleListSurface(
          ui: ui,
          baseList: baseList,
          scoped: scoped,
          list: list,
          urlScoped: urlScoped,
          urlActive: urlActive,
          listFilters: widget.listFilters,
          hasDayFilter: widget.doneAtLocalDayFilter != null,
          canShowDayEmptyMessage: canShowDayEmpty,
          metaFilterHidAll: metaFilterHidAll,
          reactionFilterHidAll: reactionFilterHidAll,
        );
        _debugLogSurface(surface);
        roomAuditLog(
          '[ROOMコレ診断] 一覧直前 tab=${widget.status.name} kw="${widget.listFilters.keyword}" '
          'more=${widget.listFilters.hasNonKeywordConstraints} '
          'urlExcl=${widget.excludeUrlNotReady} day=${widget.doneAtLocalDayFilter != null} '
          'baseLen=${baseList.length} afterFilterLen=${list.length} '
          'surface=${surface.debugLabel} ui=${ui.name}',
        );
        if (list.isNotEmpty) {
          final f = list.first;
          verboseItemLog(
            '[ROOMコレ診断] 描画リスト先頭 productId=${f.productId} title=${f.itemName} '
            'status=${f.status.name} len=${list.length}',
          );
        }

        switch (surface) {
          case _RoomColleListSurface.loading:
            return const AppScreenLoadingCenter(
              title: '一覧を読み込み中',
              subtitle: '端末に保存した一覧を読み込んでいます。しばらくお待ちください。',
            );

          case _RoomColleListSurface.loadError:
            return _RoomCollectionErrorState(
              message: provider.listUiErrorMessage ?? '一覧データの読み込みに失敗しました。',
              onRetry: () => provider.refreshManagedProductList(
                showLoadingIndicator: true,
              ),
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
                    actionLabel: widget.onClearDoneDayFilter != null
                        ? 'すべて表示'
                        : null,
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

          case _RoomColleListSurface.readyEmptyFilteredByMeta:
            return _roomColleRefreshableScroll(
              provider,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RoomImportMetaFilterEmptyState(
                    accentColor: widget.accentColor,
                    metaFilter: widget.roomImportMetaFilter,
                    embedInListView: false,
                  ),
                ],
              ),
            );

          case _RoomColleListSurface.readyEmptyFilteredByReaction:
            return _roomColleRefreshableScroll(
              provider,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RoomReactionFilterEmptyState(
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
            _scheduleGenrePrefetchIfNeeded(list);
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
            padding: EdgeInsets.fromLTRB(
              _kRoomListScreenPadH,
              0,
              _kRoomListScreenPadH,
              _RoomColleUi.listBottomPad,
            ),
            children: [
              if (showDayBanner) ...[
                _DoneDayFilterBanner(
                  filterDay: widget.doneAtLocalDayFilter!,
                  onClear: widget.onClearDoneDayFilter!,
                ),
                const SizedBox(height: _kRoomListCardGap),
              ],
              for (var i = 0; i < list.length; i++) ...[
                _KeyedCandidateProductRow(
                  product: list[i],
                  variant: widget.variant,
                  genrePrefetchLabels: _genrePrefetchLabels,
                  isSavedShop: savedShopIds.contains(list[i].shopCode.trim()),
                  isTodayRecommendationCandidate: todayRecommendationIds
                      .contains(list[i].productId.trim()),
                  collectPostingBlocked: postingBlocked,
                  collectPostingBlockedMessage: postingBlockedUserMessage,
                  rowKey: widget.rowKeyFor?.call(list[i].productId),
                  flash: widget.flashHighlightProductId == list[i].productId,
                  roomImportEnrichHighlight: bulk.isRoomImportEnrichHighlighted(
                    list[i].productId,
                  ),
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
    required this.genrePrefetchLabels,
    required this.isSavedShop,
    required this.isTodayRecommendationCandidate,
    this.collectPostingBlocked = false,
    this.collectPostingBlockedMessage = '',
    this.rowKey,
    this.flash = false,
    this.roomImportEnrichHighlight = false,
  });

  final RakutenManagedProduct product;
  final RakutenManagedProductCardVariant variant;
  final Map<String, String> genrePrefetchLabels;
  final bool isSavedShop;
  final bool isTodayRecommendationCandidate;
  final bool collectPostingBlocked;
  final String collectPostingBlockedMessage;
  final GlobalKey? rowKey;
  final bool flash;
  final bool roomImportEnrichHighlight;

  @override
  Widget build(BuildContext context) {
    try {
      Widget card = RakutenManagedProductCard(
        product: product,
        variant: variant,
        genrePrefetchLabels: genrePrefetchLabels,
        isSavedShop: isSavedShop,
        isTodayRecommendationCandidate: isTodayRecommendationCandidate,
        collectPostingBlocked: collectPostingBlocked,
        collectPostingBlockedMessage: collectPostingBlockedMessage,
        roomImportEnrichHighlight: roomImportEnrichHighlight,
      );
      if (flash) {
        card = AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              HomeScreenColors.homeAccentTealLight.withValues(alpha: 0.85),
              HomeScreenColors.roomContentWellFill,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: HomeScreenColors.homeAccentTeal.withValues(alpha: 0.42),
              width: 1.5,
            ),
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
      color: HomeScreenColors.roomMetricTileFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: HomeScreenColors.roomMetricTileBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: HomeScreenColors.inkNeutralSplash,
        highlightColor: HomeScreenColors.inkNeutralHighlight,
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
                    color: HomeScreenColors.metricTileTitleColor,
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
      color: HomeScreenColors.subActionRowFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: HomeScreenColors.sectionOutlineNeutral),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: HomeScreenColors.homeAccentTeal,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '本日（${filterDay.month}/${filterDay.day}）コレした分のみ表示中',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: HomeScreenColors.leadOnSection,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  fontSize: 12,
                ),
              ),
            ),
            AppSecondaryButton(label: 'すべて表示', onPressed: onClear, height: 32),
          ],
        ),
      ),
    );
  }
}

/// コレ済タブの「未確認」「確認済」セグメントで0件のとき。
class _RoomImportMetaFilterEmptyState extends StatelessWidget {
  const _RoomImportMetaFilterEmptyState({
    required this.accentColor,
    required this.metaFilter,
    this.embedInListView = true,
  });

  final Color accentColor;
  final _RoomImportMetaListFilter metaFilter;
  final bool embedInListView;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    switch (metaFilter) {
      case _RoomImportMetaListFilter.incompleteOnly:
        title = '未確認の商品はありません';
        subtitle = '現在表示中の商品は確認済みです。価格・ショップ名などはカード上の補足で確認できます。';
        break;
      case _RoomImportMetaListFilter.completeOnly:
        title = '確認済の商品はありません';
        subtitle = 'ROOM取り込み商品のうち、価格やショップ名の確認が必要なものが「未確認」に表示されます。';
        break;
      case _RoomImportMetaListFilter.all:
        title = '一致する商品がありません';
        subtitle = '';
        break;
    }
    final pane = SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.35,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kRoomListScreenPadH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fact_check_outlined,
                size: 44,
                color: accentColor.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HomeScreenColors.groupedSectionBody,
                    height: 1.4,
                    fontSize: 13,
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

/// コレ済タブの「反応あり」チップで0件のとき。
class _RoomReactionFilterEmptyState extends StatelessWidget {
  const _RoomReactionFilterEmptyState({
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
                Icons.favorite_border_rounded,
                size: 44,
                color: accentColor.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 10),
              Text(
                '反応ありの商品はまだありません',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ROOM投稿の反応を確認すると、いいね・コメントがある商品をここで絞り込めます。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HomeScreenColors.groupedSectionBody,
                  height: 1.4,
                  fontSize: 13,
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
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'キーワードを変えるか、絞り込みを解除してください。読み込み自体は成功しています。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HomeScreenColors.groupedSectionBody,
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

/// 「取得済みURLのみ表示」により表示対象が0件（データは存在する）。候補タブ専用。
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
                '「ROOM URLあり」に一致する商品がありません',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'フィルターを変更すると、URL未準備の候補も表示できます。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HomeScreenColors.groupedSectionBody,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'データの読み込みは成功しています（コレ候補をURL条件で絞り込んだ結果が0件です）。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HomeScreenColors.footnoteMuted,
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
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '読み込みエラーではなく、画面上の整合が取れていない可能性（描画・データの不整合）があります。下に引っ張って再読み込みするか、フィルタを初期化してください。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HomeScreenColors.groupedSectionBody,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              if (onResetFilters != null) ...[
                const SizedBox(height: 12),
                AppSecondaryButton(
                  label: 'フィルタを初期化',
                  onPressed: () => onResetFilters!(),
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
                  color: HomeScreenColors.titlePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HomeScreenColors.groupedSectionBody,
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
                    color: HomeScreenColors.footnoteMuted,
                    height: 1.35,
                  ),
                ),
              ],
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 12),
                AppSecondaryButton(label: actionLabel!, onPressed: onAction),
              ],
              if (stateFootnote != null &&
                  stateFootnote!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  stateFootnote!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: HomeScreenColors.footnoteMuted,
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
                      fontWeight: FontWeight.w800,
                      color: HomeScreenColors.accentSectionHeading,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '状態: データの読み込みに失敗しました',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: HomeScreenColors.footnoteMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HomeScreenColors.groupedSectionBody,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => onRetry(),
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: HomeScreenColors.homeAccentTeal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('もう一度読み込む'),
                    ),
                  ),
                  if (onResetFiltersAndRetry != null) ...[
                    const SizedBox(height: 12),
                    AppSecondaryButton(
                      label: 'フィルタを初期化して再開',
                      onPressed: () => onResetFiltersAndRetry!(),
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
