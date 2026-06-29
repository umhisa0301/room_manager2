import '../utils/product_price_display.dart';

/// AI投稿文生成の入力。
class PostCommentGenerationInput {
  const PostCommentGenerationInput({
    required this.itemName,
    required this.recommendationReason,
    required this.itemPrice,
    required this.reviewAverage,
    required this.reviewCount,
  });

  final String itemName;
  final String recommendationReason;
  final int itemPrice;
  final double reviewAverage;
  final int reviewCount;
}

/// 投稿文のAI生成（OpenAI 等の実装は将来差し替え）。
abstract class PostCommentGenerationService {
  Future<String> generate(PostCommentGenerationInput input);
}

/// API未接続段階のスタブ。商品情報から仮の投稿文を返す。
class StubPostCommentGenerationService implements PostCommentGenerationService {
  const StubPostCommentGenerationService({
    this.delay = const Duration(milliseconds: 500),
  });

  final Duration delay;

  @override
  Future<String> generate(PostCommentGenerationInput input) async {
    await Future<void>.delayed(delay);
    final name = input.itemName.trim().isNotEmpty ? input.itemName.trim() : 'この商品';
    final reason = input.recommendationReason.trim().isNotEmpty
        ? input.recommendationReason.trim()
        : '気になった一品です';
    final price = ProductPriceDisplay.formatYen(input.itemPrice);
    final rating = input.reviewAverage.toStringAsFixed(2);
    final count = input.reviewCount;

    return '【$name】\n\n'
        '$reason\n'
        '価格は$price。レビュー平均 $rating（$count件）も参考になります。\n'
        '気になった方はぜひチェックしてみてください！';
  }
}
