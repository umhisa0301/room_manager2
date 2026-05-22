import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../utils/rakuten_keyword_search_sort.dart';

/// 探す画面のモード別検索結果メタ（表示許可・復元の照合用）。
class SearchResultEnvelope {
  const SearchResultEnvelope({
    required this.ownerMode,
    required this.searchKey,
    required this.keyword,
    this.genreId,
    this.shopCode,
    this.sort,
    required this.resultItems,
    required this.createdAt,
  });

  /// [RakutenSearchSessionCache] の mode キー（例: productSearch）。
  final String ownerMode;

  /// 検索条件の安定ハッシュ相当（モード＋正規化条件）。
  final String searchKey;
  final String keyword;
  final String? genreId;
  final String? shopCode;
  final String? sort;
  final List<RakutenSearchItem> resultItems;
  final DateTime createdAt;

  int get resultCount => resultItems.length;

  SearchResultEnvelope copyWithResultItems(List<RakutenSearchItem> items) {
    return SearchResultEnvelope(
      ownerMode: ownerMode,
      searchKey: searchKey,
      keyword: keyword,
      genreId: genreId,
      shopCode: shopCode,
      sort: sort,
      resultItems: items,
      createdAt: createdAt,
    );
  }
}

/// モード別の検索条件から表示照合用 [searchKey] を生成する。
String buildSearchResultSearchKey({
  required String ownerMode,
  required RakutenProductSearchCondition condition,
  RakutenKeywordSearchSortMode? clientSort,
}) {
  final c = condition.normalized();
  final parts = <String>[
    'mode=$ownerMode',
    'kw=${c.keyword}',
    'gid=${c.genreId ?? ''}',
    'shop=${c.shopCode ?? ''}',
    'item=${c.itemCode ?? ''}',
    'min=${c.minPrice ?? ''}',
    'max=${c.maxPrice ?? ''}',
    'ex=${c.excludeKeyword}',
    'mrc=${c.minReviewCount ?? ''}',
    'mra=${c.minReviewAverage ?? ''}',
    'mcc=${c.minCommentCount ?? ''}',
    'sort=${c.sort ?? ''}',
    'csort=${clientSort?.name ?? ''}',
  ];
  return parts.join('|');
}
