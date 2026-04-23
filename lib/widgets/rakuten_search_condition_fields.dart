import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/saved_shop.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import '../validation/rakuten_keyword_detail_conditions_validation.dart';

/// ジャンルプルダウン用の選択肢（ID null は「指定なし」など）。
class RakutenSearchGenreOption {
  const RakutenSearchGenreOption({this.id, required this.label});

  final String? id;
  final String label;
}

/// 価格帯（最低・最高）。キーワード／ジャンル詳細シートで共通。
class RakutenSearchPriceRangeRow extends StatelessWidget {
  const RakutenSearchPriceRangeRow({
    super.key,
    required this.minPriceController,
    required this.maxPriceController,
    required this.digitsOnlyFormatters,
  });

  final TextEditingController minPriceController;
  final TextEditingController maxPriceController;
  final List<TextInputFormatter> digitsOnlyFormatters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: minPriceController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: false,
              signed: false,
            ),
            inputFormatters: digitsOnlyFormatters,
            decoration: RakutenSearchScreenUi.searchField(
              labelText: '最低価格（任意）',
              hintText: '1000',
              prefixIcon: Icon(
                Icons.currency_yen,
                color: HomeScreenColors.leadOnSection,
              ),
            ),
          ),
        ),
        SizedBox(width: RakutenSearchScreenUi.gapFieldStack),
        Expanded(
          child: TextField(
            controller: maxPriceController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: false,
              signed: false,
            ),
            inputFormatters: digitsOnlyFormatters,
            decoration: RakutenSearchScreenUi.searchField(
              labelText: '最高価格（任意）',
              hintText: '5000',
              prefixIcon: Icon(
                Icons.currency_yen,
                color: HomeScreenColors.leadOnSection,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 最低評価数・最低評価点数のプルダウン行（選択肢は [RakutenKeywordDetailConditionsValidation] と同一）。
class RakutenSearchMinReviewDropdownRow extends StatelessWidget {
  const RakutenSearchMinReviewDropdownRow({
    super.key,
    required this.selectedReviewCount,
    required this.selectedReviewAverage,
    required this.onReviewCountChanged,
    required this.onReviewAverageChanged,
  });

  final int? selectedReviewCount;
  final double? selectedReviewAverage;
  final ValueChanged<int?> onReviewCountChanged;
  final ValueChanged<double?> onReviewAverageChanged;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = RakutenSearchScreenUi.searchFieldValueStyle(context);
    final noneStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: HomeScreenColors.groupedSectionBody,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InputDecorator(
            decoration: RakutenSearchScreenUi.searchField(
              labelText: '最低評価数（任意）',
              prefixIcon: Icon(
                Icons.reviews_outlined,
                color: HomeScreenColors.leadOnSection,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                isExpanded: true,
                value: selectedReviewCount,
                style: bodyStyle,
                padding: EdgeInsets.zero,
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('指定なし', style: noneStyle),
                  ),
                  ...RakutenKeywordDetailConditionsValidation
                      .keywordMinReviewCountChoices
                      .map(
                        (n) => DropdownMenuItem<int?>(
                          value: n,
                          child: Text('$n〜'),
                        ),
                      ),
                ],
                onChanged: onReviewCountChanged,
              ),
            ),
          ),
        ),
        SizedBox(width: RakutenSearchScreenUi.gapFieldStack),
        Expanded(
          child: InputDecorator(
            decoration: RakutenSearchScreenUi.searchField(
              labelText: '最低評価点数（任意）',
              prefixIcon: Icon(
                Icons.star_outline_rounded,
                color: HomeScreenColors.leadOnSection,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<double?>(
                isExpanded: true,
                value: selectedReviewAverage,
                style: bodyStyle,
                padding: EdgeInsets.zero,
                items: [
                  DropdownMenuItem<double?>(
                    value: null,
                    child: Text('指定なし', style: noneStyle),
                  ),
                  ...RakutenKeywordDetailConditionsValidation
                      .keywordMinReviewAverageChoices
                      .map(
                        (x) => DropdownMenuItem<double?>(
                          value: x,
                          child: Text('${x.toStringAsFixed(1)}〜'),
                        ),
                      ),
                ],
                onChanged: onReviewAverageChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 保存済ショップによる絞り込み（一覧が空のときの導線つき）。
class RakutenSearchSavedShopPicker extends StatelessWidget {
  const RakutenSearchSavedShopPicker({
    super.key,
    required this.shops,
    required this.selectedShopCode,
    required this.onShopChanged,
    required this.onNavigateToSavedShops,
  });

  final List<SavedShop> shops;
  final String? selectedShopCode;
  final ValueChanged<String?> onShopChanged;
  final VoidCallback onNavigateToSavedShops;

  @override
  Widget build(BuildContext context) {
    if (shops.isEmpty) {
      return InputDecorator(
        decoration: RakutenSearchScreenUi.searchField(
          labelText: 'ショップで絞り込み（保存済・任意）',
          prefixIcon: Icon(
            Icons.storefront_outlined,
            color: HomeScreenColors.leadOnSection,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '保存したショップがまだありません',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: HomeScreenColors.titlePrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '店を保存するとここから選べます（発掘・商品カードなど）。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: HomeScreenColors.groupedSectionBody,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onNavigateToSavedShops,
                icon: Icon(
                  Icons.bookmark_outline_rounded,
                  size: 18,
                  color: HomeScreenColors.leadOnSection,
                ),
                label: const Text('保存ショップを見る・追加'),
              ),
            ),
          ],
        ),
      );
    }

    final dropdownValue =
        selectedShopCode != null &&
            shops.any((s) => s.shopId == selectedShopCode)
        ? selectedShopCode
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: RakutenSearchScreenUi.searchField(
            labelText: 'ショップで絞り込み（保存済・任意）',
            prefixIcon: Icon(
              Icons.storefront_outlined,
              color: HomeScreenColors.leadOnSection,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: dropdownValue,
              style: RakutenSearchScreenUi.searchFieldValueStyle(context),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    '指定なし（すべてのショップ）',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HomeScreenColors.groupedSectionBody,
                    ),
                  ),
                ),
                ...shops.map(
                  (e) => DropdownMenuItem<String?>(
                    value: e.shopId,
                    child: Text(
                      e.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onShopChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// ジャンル選択（ラベルだけ呼び出し側で必須／任意を出し分け）。
class RakutenSearchGenreDropdownField extends StatelessWidget {
  const RakutenSearchGenreDropdownField({
    super.key,
    required this.labelText,
    required this.value,
    required this.options,
    required this.onChanged,
    this.focusNode,
  });

  final String labelText;
  final String? value;
  final List<RakutenSearchGenreOption> options;
  final ValueChanged<String?> onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: RakutenSearchScreenUi.searchField(
            labelText: labelText,
            prefixIcon: Icon(
              Icons.category_outlined,
              color: HomeScreenColors.leadOnSection,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              focusNode: focusNode,
              value: value,
              style: RakutenSearchScreenUi.searchFieldValueStyle(context),
              items: options
                  .map(
                    (e) => DropdownMenuItem<String?>(
                      value: e.id,
                      child: Text(e.label),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
