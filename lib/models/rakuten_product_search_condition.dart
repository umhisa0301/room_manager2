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
    this.sort,
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
  final String? sort;

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
      genreId: _normalizeOptional(genreId),
      sort: _normalizeOptional(sort),
    );
  }

  static String? _normalizeOptional(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  /// 末尾や先頭に付きがちな句読点・記号を取り除き、検索語の実体を安定化する。
  /// 例: `アンパンマン、` -> `アンパンマン`
  static String _normalizeKeyword(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) return '';
    normalized = normalized.replaceAll(RegExp(r'^[\s、。,.!！?？:：;；/／\\]+'), '');
    normalized = normalized.replaceAll(RegExp(r'[\s、。,.!！?？:：;；/／\\]+$'), '');
    return normalized;
  }
}
