import '../models/post_comment_generation_result.dart';
import '../models/post_comment_profile_context.dart';
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
    this.genreName = '',
    this.genreId = '',
    this.shopName = '',
    this.styleSettings,
    this.profileContext,
  });

  final String itemName;
  final String recommendationReason;
  final int itemPrice;
  final double reviewAverage;
  final int reviewCount;
  final String genreName;
  final String genreId;
  final String shopName;

  /// 未指定時は [PostStyleSettings.defaults] を利用。
  final PostStyleSettings? styleSettings;

  /// ROOM診断プロファイル由来のコンテキスト。API 送信時のみ利用。
  final PostCommentProfileContext? profileContext;

  PostStyleSettings get effectiveStyleSettings =>
      styleSettings ?? PostStyleSettings.defaults();
}

/// 投稿文のAI生成（OpenAI 等の実装は将来差し替え）。
abstract class PostCommentGenerationService {
  Future<PostCommentGenerationResult> generate(PostCommentGenerationInput input);
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
  Future<PostCommentGenerationResult> generate(
    PostCommentGenerationInput input,
  ) async {
    await Future<void>.delayed(delay);
    final style =
        input.styleSettings ?? defaultStyleSettings ?? PostStyleSettings.defaults();
    final text = StubPostCommentBuilder.build(input: input, style: style);
    return PostCommentGenerationResult(body: text, fullText: text);
  }
}
