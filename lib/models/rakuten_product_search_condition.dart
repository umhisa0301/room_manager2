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
    this.genreId,
  });

  final String keyword;
  final int? minPrice;
  final int? maxPrice;
  final String excludeKeyword;
  final int? minReviewCount;
  final double? minReviewAverage;
  final int? minCommentCount;
  final String? shopCode;
  final String? genreId;

  RakutenProductSearchCondition normalized() {
    return RakutenProductSearchCondition(
      keyword: keyword.trim(),
      minPrice: minPrice,
      maxPrice: maxPrice,
      excludeKeyword: excludeKeyword.trim(),
      minReviewCount: minReviewCount,
      minReviewAverage: minReviewAverage,
      minCommentCount: minCommentCount,
      shopCode: _normalizeOptional(shopCode),
      genreId: _normalizeOptional(genreId),
    );
  }

  static String? _normalizeOptional(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }
}
