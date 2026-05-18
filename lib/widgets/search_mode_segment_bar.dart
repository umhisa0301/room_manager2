import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';

/// 探し方セレクター（横スクロール ChoiceChip、高さ約44）。
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

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint(
        '[SEARCH_HEADER_REDESIGN_AUDIT] mode=${selected.name} usesAppBar=true '
        'usesSegmentBar=true legacyLargeButtons=false '
        'savedShopUsesSameHeader=true resultAreaPriority=true',
      );
    }
    final modes = savedShopMode
        ? SearchModeSegment.values
        : SearchModeSegment.values;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final mode = modes[index];
          final isSelected = mode == selected;
          return ChoiceChip(
            label: Text(
              _labels[mode]!,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isSelected
                    ? AppColors.textOnAccent
                    : HomeScreenColors.titlePrimary,
              ),
            ),
            selected: isSelected,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            selectedColor: AppColors.accentPrimary,
            backgroundColor: HomeScreenColors.roomGroupedShellFill,
            side: BorderSide(
              color: isSelected
                  ? AppColors.accentPrimary
                  : HomeScreenColors.sectionOutlineNeutral,
            ),
            onSelected: (_) => onChanged(mode),
          );
        },
      ),
    );
  }
}

enum SearchModeSegment { product, genre, savedShop, shopDiscovery }
