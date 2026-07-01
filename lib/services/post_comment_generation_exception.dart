/// 投稿文生成 API のエラー応答。
class PostCommentGenerationException implements Exception {
  const PostCommentGenerationException(
    this.code,
    this.message, {
    this.httpStatus,
  });

  final String code;
  final String message;
  final int? httpStatus;

  @override
  String toString() => 'PostCommentGenerationException($code): $message';
}
