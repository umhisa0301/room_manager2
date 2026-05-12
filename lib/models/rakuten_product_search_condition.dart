/// `shopCode` と純粋な `itemCode` を両方渡すときの HTTP クエリの組み方。
enum RakutenShopItemQueryStyle {
  /// 楽天公式どおり `itemCode` のみに `shop:pureItem` を載せ、`shopCode` は付けない。
  compositeItemCodeParam,

  /// 検証用: `shopCode` と純粋 `itemCode` を別パラメータで送る（パターンB）。
  separateShopAndItemParams,
}

/// 商品検索モードの検索条件。
/// UI入力値を集約し、API連携やアプリ内フィルタへ渡す。
class RakutenProductSearchCondition {
  const RakutenProductSearchCondition({
    this.keyword = '',
    this.minPrice,
    this.maxPrice,
    this.excludeKeyword = '',
    this.minReviewCount,
    this.minReviewAverage,
    this.minCommentCount,
    this.shopCode,
    this.itemCode,
    this.genreId,
    this.sort,
    this.shopItemQueryStyle,
  });

  final String keyword;
  final int? minPrice;
  final int? maxPrice;
  final String excludeKeyword;
  final int? minReviewCount;
  final double? minReviewAverage;
  final int? minCommentCount;
  final String? shopCode;
  /// 楽天商品検索 API 用の商品コード（店舗内の識別子。HTTP では `shopCode` と併せて `shop:item` に合成され得る）。
  final String? itemCode;
  final String? genreId;
  final String? sort;

  /// [shopCode] と [itemCode] 両方があるときのクエリ組み立て（未指定時は [RakutenShopItemQueryStyle.compositeItemCodeParam]）。
  final RakutenShopItemQueryStyle? shopItemQueryStyle;

  RakutenProductSearchCondition normalized() {
    return RakutenProductSearchCondition(
      keyword: _normalizeKeyword(keyword),
      minPrice: minPrice,
      maxPrice: maxPrice,
      excludeKeyword: excludeKeyword.trim(),
      minReviewCount: minReviewCount,
      minReviewAverage: minReviewAverage,
      minCommentCount: minCommentCount,
      shopCode: _normalizeOptional(shopCode),
      itemCode: _normalizeOptional(itemCode),
      genreId: _normalizeOptional(genreId),
      sort: _normalizeOptional(sort),
      shopItemQueryStyle: shopItemQueryStyle,
    );
  }

  static String? _normalizeOptional(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  /// 末尾や先頭に付きがちな句読点・記号を取り除き、検索語の実体を安定化する。
  /// 例: `水筒、` -> `水筒`
  static String _normalizeKeyword(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) return '';
    normalized = normalized.replaceAll(RegExp(r'^[\s、。,.!！?？:：;；/／\\]+'), '');
    normalized = normalized.replaceAll(RegExp(r'[\s、。,.!！?？:：;；/／\\]+$'), '');
    return normalized;
  }
}
