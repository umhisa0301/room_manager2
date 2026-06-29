import '../models/post_style_settings.dart';
import 'stub_post_comment_builder.dart';

/// AI投稿文生成の入力。
class PostCommentGenerationInput {
  const PostCommentGenerationInput({
    required this.itemName,
    required this.recommendationReason,
    required this.itemPrice,
    required this.reviewAverage,
    required this.reviewCount,
    this.styleSettings,
  });

  final String itemName;
  final String recommendationReason;
  final int itemPrice;
  final double reviewAverage;
  final int reviewCount;

  /// 未指定時は [PostStyleSettings.defaults] を利用。
  final PostStyleSettings? styleSettings;

  PostStyleSettings get effectiveStyleSettings =>
      styleSettings ?? PostStyleSettings.defaults();
}

/// 投稿文のAI生成（OpenAI 等の実装は将来差し替え）。
abstract class PostCommentGenerationService {
  Future<String> generate(PostCommentGenerationInput input);
}

/// API未接続段階のスタブ。商品情報と投稿スタイル設定から仮の投稿文を返す。
class StubPostCommentGenerationService implements PostCommentGenerationService {
  const StubPostCommentGenerationService({
    this.delay = const Duration(milliseconds: 500),
    this.defaultStyleSettings,
  });

  final Duration delay;

  /// 入力にスタイル未指定のときのフォールバック（Provider 注入用）。
  final PostStyleSettings? defaultStyleSettings;

  @override
  Future<String> generate(PostCommentGenerationInput input) async {
    await Future<void>.delayed(delay);
    final style =
        input.styleSettings ?? defaultStyleSettings ?? PostStyleSettings.defaults();
    return StubPostCommentBuilder.build(input: input, style: style);
  }
}
