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

  /// 投稿準備モーダル等に表示するテキスト（full_text 優先、なければ body + hashtags）。
  String get displayText {
    final full = fullText?.trim();
    if (full != null && full.isNotEmpty) return full;
    if (hashtags.isEmpty) return body;
    return '$body\n\n${hashtags.join(' ')}';
  }
}
