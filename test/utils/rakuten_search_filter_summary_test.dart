import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/rakuten_search_filter_summary.dart';
import 'package:room_manager2/utils/rakuten_keyword_search_sort.dart';

void main() {
  group('rakutenSearchFilterSummaryChipLabels', () {
    test('商品名と並び順ラベルは含めない', () {
      final labels = rakutenSearchFilterSummaryChipLabels(
        hasReviewFilter: false,
        reviewAverageAtLeastFour: false,
        hasExcludeKeyword: false,
        hasPriceRange: false,
        priceRangeLabel: '価格指定なし',
      );
      expect(labels, isEmpty);
      expect(labels, isNot(contains('商品名')));
      expect(
        labels,
        isNot(contains(rakutenKeywordSearchSortHeaderLabel(
          RakutenKeywordSearchSortMode.reviewCountDescending,
        ))),
      );
    });

    test('追加条件のみチップ化する', () {
      final labels = rakutenSearchFilterSummaryChipLabels(
        hasReviewFilter: true,
        reviewAverageAtLeastFour: true,
        hasExcludeKeyword: true,
        hasPriceRange: true,
        priceRangeLabel: '¥1000〜5000',
      );
      expect(labels, ['レビュー4以上', '除外条件あり', '¥1000〜5000']);
    });
  });
}
