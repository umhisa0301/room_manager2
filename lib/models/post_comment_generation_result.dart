/// API から返る投稿文生成結果。
class PostCommentGenerationResult {
  const PostCommentGenerationResult({
    required this.body,
    this.hashtags = const [],
    this.fullText,
    this.truncated = false,
  });

  final String body;
  final List<String> hashtags;
  final String? fullText;
  final bool truncated;
}
