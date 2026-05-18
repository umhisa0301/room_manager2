import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';

/// 探し方セレクター（ROOMコレの SegmentedButton 風・横スクロール可）。
class SearchModeSegmentBar extends StatelessWidget {
  const SearchModeSegmentBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.savedShopMode = false,
  });

  final SearchModeSegment selected;
  final ValueChanged<SearchModeSegment> onChanged;
  final bool savedShopMode;

  static const _labels = {
    SearchModeSegment.product: '商品名',
    SearchModeSegment.genre: 'ジャンル',
    SearchModeSegment.savedShop: '保存ショップ',
    SearchModeSegment.shopDiscovery: 'ショップ発掘',
  };

  static const double _segmentHeight = 46;
  static const double _trackRadius = 14;
  static const double _innerPad = 4;

  @override
  Widget build(BuildContext context) {
    final modes = SearchModeSegment.values;
    if (kDebugMode) {
      debugPrint(
        '[SEARCH_MODE_SEGMENT_STYLE_AUDIT] usesRoomColleLikeSegment=true '
        'modeCount=${modes.length} selectedMode=${selected.name} '
        'height=$_segmentHeight horizontalScroll=${modes.length > 3}',
      );
    }
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < modes.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _SegmentTile(
                      label: _labels[modes[i]]!,
                      selected: modes[i] == selected,
                      onTap: () => onChanged(modes[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
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
          constraints: const BoxConstraints(minWidth: 72, minHeight: 46),
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
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
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
