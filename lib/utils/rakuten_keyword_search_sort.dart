import '../models/rakuten_search_item.dart';

/// キーワード検索タブの結果一覧に対する並び替えモード（表示文言は画面側で付与する）。
enum RakutenKeywordSearchSortMode {
  /// 後方互換用。API にはレビュー件数順を渡し、UI では選択肢に出さない。
  defaultOrder,

  /// 価格の安い順（同額は元の順を維持）。
  priceAscending,

  /// 価格の高い順。
  priceDescending,

  /// 評価の高い順。レビューが無い・評価が欠ける商品は後方へ。
  ratingDescending,

  /// レビュー件数の多い順。件数0は後方へ。
  reviewCountDescending,

  /// 新着順（楽天 API `updateTimestamp`）。
  newestFirst,
}

/// 探すタブの並び順メニューに表示するモード（おすすめ／デフォルトは含めない）。
const List<RakutenKeywordSearchSortMode> rakutenKeywordSearchUserSelectableSortModes =
    <RakutenKeywordSearchSortMode>[
  RakutenKeywordSearchSortMode.reviewCountDescending,
  RakutenKeywordSearchSortMode.ratingDescending,
  RakutenKeywordSearchSortMode.priceAscending,
  RakutenKeywordSearchSortMode.priceDescending,
  RakutenKeywordSearchSortMode.newestFirst,
];

/// 探すタブの既定並び順。
const RakutenKeywordSearchSortMode rakutenKeywordSearchDefaultSortMode =
    RakutenKeywordSearchSortMode.reviewCountDescending;

/// 保存値などで [defaultOrder] が残っていてもレビュー件数順へ寄せる。
RakutenKeywordSearchSortMode normalizeRakutenKeywordSearchSortMode(
  RakutenKeywordSearchSortMode mode,
) {
  if (mode == RakutenKeywordSearchSortMode.defaultOrder) {
    return RakutenKeywordSearchSortMode.reviewCountDescending;
  }
  return mode;
}

/// ユーザー向けの並び順ラベル（API 内部名は出さない）。
String rakutenKeywordSearchSortDisplayLabel(
  RakutenKeywordSearchSortMode mode, {
  bool menuItem = false,
}) {
  switch (normalizeRakutenKeywordSearchSortMode(mode)) {
    case RakutenKeywordSearchSortMode.defaultOrder:
      return menuItem ? 'レビューが多い順' : 'レビューが多い';
    case RakutenKeywordSearchSortMode.priceAscending:
      return menuItem ? '価格が安い順' : '価格が安い';
    case RakutenKeywordSearchSortMode.priceDescending:
      return menuItem ? '価格が高い順' : '価格が高い';
    case RakutenKeywordSearchSortMode.ratingDescending:
      return menuItem ? '評価が高い順' : '評価が高い';
    case RakutenKeywordSearchSortMode.reviewCountDescending:
      return menuItem ? 'レビューが多い順' : 'レビューが多い';
    case RakutenKeywordSearchSortMode.newestFirst:
      return menuItem ? '新着順' : '新着';
  }
}

/// 結果ヘッダー向け「並び順：◯◯」。
String rakutenKeywordSearchSortHeaderLabel(RakutenKeywordSearchSortMode mode) {
  return '並び順：${rakutenKeywordSearchSortDisplayLabel(mode)}';
}

/// API sort パラメータ文字列のユーザー向け表示。
String rakutenApiSortDisplayLabel(String? apiSort) {
  final s = apiSort?.trim() ?? '';
  if (s.isEmpty || s == 'standard') {
    return 'レビューが多い';
  }
  return switch (s) {
    'defaultOrder' => 'レビューが多い',
    '+itemPrice' || 'itemPriceAsc' => '価格が安い',
    '-itemPrice' || 'itemPriceDesc' => '価格が高い',
    '-reviewAverage' || 'reviewAverage' => '評価が高い',
    '-reviewCount' || 'reviewCount' => 'レビューが多い',
    '-updateTimestamp' || 'updateTimestamp' => '新着',
    _ => 'レビューが多い',
  };
}

/// 楽天 Ichiba Item Search API の sort クエリ値。
String? rakutenKeywordSearchApiSortParam(RakutenKeywordSearchSortMode mode) {
  switch (normalizeRakutenKeywordSearchSortMode(mode)) {
    case RakutenKeywordSearchSortMode.defaultOrder:
    case RakutenKeywordSearchSortMode.reviewCountDescending:
      return '-reviewCount';
    case RakutenKeywordSearchSortMode.priceAscending:
      return '+itemPrice';
    case RakutenKeywordSearchSortMode.priceDescending:
      return '-itemPrice';
    case RakutenKeywordSearchSortMode.ratingDescending:
      return '-reviewAverage';
    case RakutenKeywordSearchSortMode.newestFirst:
      return '-updateTimestamp';
  }
}

/// [source] の順序を保ったまま、必要なら並び替えた新しいリストを返す。
///
/// 欠損値は落とさず、比較不能な商品は一覧の後方に寄せる。
List<RakutenSearchItem> sortedRakutenKeywordSearchItems(
  List<RakutenSearchItem> source,
  RakutenKeywordSearchSortMode mode,
) {
  final effective = normalizeRakutenKeywordSearchSortMode(mode);
  if (effective == RakutenKeywordSearchSortMode.reviewCountDescending &&
      mode == RakutenKeywordSearchSortMode.defaultOrder) {
    // API 側で既に reviewCount 順のときはクライアント並び替え不要。
    return List<RakutenSearchItem>.from(source);
  }

  final indexed = source.indexed.toList();

  int compareByOriginalIndex(
    (int, RakutenSearchItem) ea,
    (int, RakutenSearchItem) eb,
  ) {
    final ai = ea.$1;
    final bi = eb.$1;
    final a = ea.$2;
    final b = eb.$2;

    switch (effective) {
      case RakutenKeywordSearchSortMode.defaultOrder:
      case RakutenKeywordSearchSortMode.reviewCountDescending:
        final c = b.reviewCount.compareTo(a.reviewCount);
        if (c != 0) return c;
        return ai.compareTo(bi);
      case RakutenKeywordSearchSortMode.priceAscending:
        final c = a.itemPrice.compareTo(b.itemPrice);
        if (c != 0) return c;
        return ai.compareTo(bi);
      case RakutenKeywordSearchSortMode.priceDescending:
        final c = b.itemPrice.compareTo(a.itemPrice);
        if (c != 0) return c;
        return ai.compareTo(bi);
      case RakutenKeywordSearchSortMode.ratingDescending:
        final ka = _ratingDescendingSortKey(a);
        final kb = _ratingDescendingSortKey(b);
        final c = kb.compareTo(ka);
        if (c != 0) return c;
        return ai.compareTo(bi);
      case RakutenKeywordSearchSortMode.newestFirst:
        return ai.compareTo(bi);
    }
  }

  indexed.sort(compareByOriginalIndex);
  return indexed.map((e) => e.$2).toList();
}

/// 高い評価ほど大きい値。レビューなし・評価欠損は最も小さくして後方へ回す。
double _ratingDescendingSortKey(RakutenSearchItem e) {
  final count = e.reviewCount;
  if (count <= 0) return double.negativeInfinity;
  final avg = e.reviewAverage;
  if (avg.isNaN) return double.negativeInfinity;
  return avg;
}
