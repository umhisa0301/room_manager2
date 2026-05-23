import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../utils/app_debug_log.dart';

/// 探し方セレクター（ROOMコレの SegmentedButton 風・横スクロール可）。
class SearchModeSegmentBar extends StatefulWidget {
  const SearchModeSegmentBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.savedShopMode = false,
    this.auditPhase = 'input',
  });

  final SearchModeSegment selected;
  final ValueChanged<SearchModeSegment> onChanged;
  final bool savedShopMode;

  /// [SEARCH_MODE_SEGMENT_VISIBILITY_AUDIT] の phase フィールド用。
  final String auditPhase;

  @override
  State<SearchModeSegmentBar> createState() => _SearchModeSegmentBarState();
}

class _SearchModeSegmentBarState extends State<SearchModeSegmentBar> {
  static const _labels = {
    SearchModeSegment.product: '商品名',
    SearchModeSegment.genre: 'ジャンル',
    SearchModeSegment.savedShop: '保存ショップ',
    SearchModeSegment.shopDiscovery: 'ショップ発掘',
  };

  static const double _segmentHeight = 46;
  static const double _trackRadius = 14;
  static const double _innerPad = 4;

  final ScrollController _scrollController = ScrollController();
  final Map<SearchModeSegment, GlobalKey> _tileKeys = {
    for (final m in SearchModeSegment.values) m: GlobalKey(),
  };

  SearchModeSegment? _lastScrolledSelection;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _scrollSelectedIntoView());
  }

  @override
  void didUpdateWidget(SearchModeSegmentBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _scrollSelectedIntoView());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollSelectedIntoView() {
    if (!mounted) return;
    final key = _tileKeys[widget.selected];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    _lastScrolledSelection = widget.selected;
    _logSegmentVisibility(scrolledToSelected: true);
  }

  void _logSegmentVisibility({required bool scrolledToSelected}) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final selectedCtx = _tileKeys[widget.selected]?.currentContext;
    var selectedTabLeft = -1.0;
    var selectedTabRight = -1.0;
    var selectedTabFullyVisible = false;
    var clippedByRightEdge = false;
    if (selectedCtx != null) {
      final box = selectedCtx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final offset = box.localToGlobal(Offset.zero);
        selectedTabLeft = offset.dx;
        selectedTabRight = offset.dx + box.size.width;
        selectedTabFullyVisible =
            selectedTabLeft >= 0 && selectedTabRight <= screenWidth;
        clippedByRightEdge = selectedTabRight > screenWidth + 0.5;
      }
    }
    final scrollCtx = _scrollController.hasClients ? context : null;
    var availableTabWidth = screenWidth;
    if (scrollCtx != null) {
      final parentBox = context.findRenderObject() as RenderBox?;
      if (parentBox != null && parentBox.hasSize) {
        availableTabWidth = parentBox.size.width;
      }
    }
    AuditLogDeduper.logOnce(
      'segment_visibility_${widget.auditPhase}_${widget.selected.name}',
      '[SEARCH_MODE_SEGMENT_VISIBILITY_AUDIT] phase=${widget.auditPhase} '
      'selectedMode=${widget.selected.name} screenWidth=$screenWidth '
      'availableTabWidth=$availableTabWidth selectedTabLeft=$selectedTabLeft '
      'selectedTabRight=$selectedTabRight '
      'selectedTabFullyVisible=$selectedTabFullyVisible '
      'scrolledToSelected=$scrolledToSelected clippedByRightEdge=$clippedByRightEdge',
      searchAuditLog,
    );
  }

  @override
  Widget build(BuildContext context) {
    final modes = SearchModeSegment.values;
    AuditLogDeduper.logOnce(
      'segment_style_${widget.selected.name}',
      '[SEARCH_MODE_SEGMENT_STYLE_AUDIT] usesRoomColleLikeSegment=true '
      'modeCount=${modes.length} selectedMode=${widget.selected.name} '
      'height=$_segmentHeight horizontalScroll=${modes.length > 3}',
      searchAuditLog,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeScreenColors.roomContentWellFill,
        borderRadius: BorderRadius.circular(_trackRadius),
        border: Border.all(color: HomeScreenColors.deckOutline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_innerPad),
        child: SizedBox(
          height: _segmentHeight,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sw = MediaQuery.sizeOf(context).width;
                AuditLogDeduper.logOnce(
                  'segment_overflow_${widget.selected.name}',
                  '[SEARCH_MODE_SEGMENT_OVERFLOW_AUDIT] screenWidth=$sw '
                  'totalTabWidth=${constraints.maxWidth} selectedMode=${widget.selected.name} '
                  'clipped=${constraints.maxWidth < 360} horizontalScrollable=true',
                  searchAuditLog,
                );
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (_lastScrolledSelection != widget.selected) {
                    _scrollSelectedIntoView();
                  } else {
                    _logSegmentVisibility(scrolledToSelected: false);
                  }
                });
                return SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      for (var i = 0; i < modes.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        _SegmentTile(
                          key: _tileKeys[modes[i]],
                          label: _labels[modes[i]]!,
                          selected: modes[i] == widget.selected,
                          onTap: () => widget.onChanged(modes[i]),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accentPrimary.withValues(alpha: 0.14)
          : HomeScreenColors.roomGroupedShellFill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: BoxConstraints(
            minWidth: selected ? 88 : 68,
            minHeight: 46,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.accentPrimary
                  : HomeScreenColors.sectionOutlineNeutral,
              width: selected ? 1.75 : 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: selected ? TextOverflow.visible : TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: selected
                      ? AppColors.accentPrimary
                      : HomeScreenColors.leadOnSection,
                ),
          ),
        ),
      ),
    );
  }
}

enum SearchModeSegment { product, genre, savedShop, shopDiscovery }
