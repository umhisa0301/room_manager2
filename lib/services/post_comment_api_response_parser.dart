import '../models/post_comment_generation_result.dart';
import 'post_comment_generation_exception.dart';

/// stepbyte-api-server `/api/ai/generate` のレスポンス JSON を変換する。
class PostCommentApiResponseParser {
  const PostCommentApiResponseParser();

  PostCommentGenerationResult parse(Map<String, dynamic> json) {
    if (json['success'] == true) {
      return _parseSuccess(json);
    }
    throw _parseFailure(json);
  }

  PostCommentGenerationResult _parseSuccess(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map) {
      throw const PostCommentGenerationException(
        'INVALID_RESPONSE',
        'Response data is missing or invalid.',
      );
    }

    final body = data['body'];
    if (body is! String || body.isEmpty) {
      throw const PostCommentGenerationException(
        'MISSING_BODY',
        'Response data.body is missing.',
      );
    }

    final hashtags = _parseHashtags(data['hashtags']);
    final fullText = data['full_text'];
    final truncated = _parseTruncated(json['meta']);

    return PostCommentGenerationResult(
      body: body,
      hashtags: hashtags,
      fullText: fullText is String ? fullText : null,
      truncated: truncated,
    );
  }

  List<String> _parseHashtags(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList(growable: false);
  }

  bool _parseTruncated(dynamic meta) {
    if (meta is! Map) return false;
    return meta['truncated'] == true;
  }

  PostCommentGenerationException _parseFailure(Map<String, dynamic> json) {
    final error = json['error'];
    if (error is Map) {
      final code = error['code']?.toString().trim();
      final message = error['message']?.toString().trim();
      if (code != null && code.isNotEmpty) {
        return PostCommentGenerationException(
          code,
          (message != null && message.isNotEmpty)
              ? message
              : 'Post comment generation failed.',
        );
      }
    }
    return const PostCommentGenerationException(
      'UNKNOWN_ERROR',
      'Post comment generation failed.',
    );
  }
}
