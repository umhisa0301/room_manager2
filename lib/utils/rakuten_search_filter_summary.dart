/// 商品検索結果画面の条件チップ行に表示するラベル（タブ・並び順ボタンと重複しないもの）。
List<String> rakutenSearchFilterSummaryChipLabels({
  required bool hasReviewFilter,
  required bool reviewAverageAtLeastFour,
  required bool hasExcludeKeyword,
  required bool hasPriceRange,
  required String priceRangeLabel,
}) {
  final labels = <String>[];
  if (hasReviewFilter) {
    labels.add(reviewAverageAtLeastFour ? 'レビュー4以上' : 'レビューあり');
  }
  if (hasExcludeKeyword) {
    labels.add('除外条件あり');
  }
  if (hasPriceRange) {
    labels.add(priceRangeLabel);
  }
  return labels;
}
