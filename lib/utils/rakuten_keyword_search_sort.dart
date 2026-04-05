import '../models/rakuten_search_item.dart';

/// キーワード検索タブの結果一覧に対する並び替えモード（表示文言は画面側で付与する）。
enum RakutenKeywordSearchSortMode {
  /// API・既存ロジックの順序のまま。
  defaultOrder,

  /// 価格の安い順（同額は元の順を維持）。
  priceAscending,

  /// 評価の高い順。レビューが無い・評価が欠ける商品は後方へ。
  ratingDescending,

  /// レビュー件数の多い順。件数0は後方へ。
  reviewCountDescending,
}

/// [source] の順序を保ったまま、必要なら並び替えた新しいリストを返す。
///
/// 欠損値は落とさず、比較不能な商品は一覧の後方に寄せる。
List<RakutenSearchItem> sortedRakutenKeywordSearchItems(
  List<RakutenSearchItem> source,
  RakutenKeywordSearchSortMode mode,
) {
  if (mode == RakutenKeywordSearchSortMode.defaultOrder) {
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

    switch (mode) {
      case RakutenKeywordSearchSortMode.defaultOrder:
        return ai.compareTo(bi);
      case RakutenKeywordSearchSortMode.priceAscending:
        final c = a.itemPrice.compareTo(b.itemPrice);
        if (c != 0) return c;
        return ai.compareTo(bi);
      case RakutenKeywordSearchSortMode.ratingDescending:
        final ka = _ratingDescendingSortKey(a);
        final kb = _ratingDescendingSortKey(b);
        final c = kb.compareTo(ka);
        if (c != 0) return c;
        return ai.compareTo(bi);
      case RakutenKeywordSearchSortMode.reviewCountDescending:
        final ca = a.reviewCount;
        final cb = b.reviewCount;
        final c = cb.compareTo(ca);
        if (c != 0) return c;
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
