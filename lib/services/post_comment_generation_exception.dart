/// 投稿文生成 API のエラー応答。
class PostCommentGenerationException implements Exception {
  const PostCommentGenerationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PostCommentGenerationException($code): $message';
}
