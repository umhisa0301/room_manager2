import 'package:flutter/material.dart';

import '../models/saved_shop.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import 'app_card.dart';

/// 保存ショップ選択（コンパクト Dropdown 風）。
class SavedShopCompactSelector extends StatelessWidget {
  const SavedShopCompactSelector({
    super.key,
    required this.shops,
    required this.selectedShopCode,
    required this.onChangeShop,
    this.onDiscoverShops,
  });

  final List<SavedShop> shops;
  final String? selectedShopCode;
  final VoidCallback onChangeShop;
  final VoidCallback? onDiscoverShops;

  @override
  Widget build(BuildContext context) {
    SavedShop? picked;
    final sc = selectedShopCode?.trim();
    if (sc != null && sc.isNotEmpty) {
      for (final s in shops) {
        if (s.shopId.trim() == sc) {
          picked = s;
          break;
        }
      }
    }
    final title = picked?.shopName.trim().isNotEmpty == true
        ? picked!.shopName.trim()
        : 'ショップを選択';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          backgroundColor: HomeScreenColors.roomGroupedShellFill,
          borderColor: HomeScreenColors.sectionOutlineNeutral,
          radius: 12,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: picked == null
                            ? HomeScreenColors.groupedSectionBody
                            : HomeScreenColors.titlePrimary,
                      ),
                ),
              ),
              TextButton(
                style: RakutenSearchScreenUi.linkTextButtonStyle(),
                onPressed: onChangeShop,
                child: const Text('変更'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          shops.isEmpty
              ? '保存済みショップがありません。ショップ発掘から保存できます。'
              : '保存済みショップから選んでください',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: HomeScreenColors.groupedSectionBody,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (shops.isEmpty && onDiscoverShops != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: RakutenSearchScreenUi.linkTextButtonStyle(),
              onPressed: onDiscoverShops,
              icon: const Icon(Icons.travel_explore_rounded, size: 18),
              label: const Text('ショップを発掘する'),
            ),
          ),
        ],
      ],
    );
  }
}
