import 'post_comment_generation_result.dart';

/// 端末ローカルに保存する AI 投稿文生成結果（商品キー単位・当日のみ有効）。
class SavedPostCommentGenerationResult {
  const SavedPostCommentGenerationResult({
    required this.body,
    required this.hashtags,
    required this.fullText,
    required this.generatedAt,
    required this.productKey,
    required this.bucket,
    required this.dateKey,
  });

  final String body;
  final List<String> hashtags;
  final String? fullText;
  final String generatedAt;
  final String productKey;
  final String bucket;
  final String dateKey;

  /// 投稿準備モーダル等に表示するテキスト。
  String get displayText {
    final full = fullText?.trim();
    if (full != null && full.isNotEmpty) return full;
    if (hashtags.isEmpty) return body;
    return '$body\n\n${hashtags.join(' ')}';
  }

  factory SavedPostCommentGenerationResult.fromGenerationResult({
    required PostCommentGenerationResult result,
    required String productKey,
    required String bucket,
    required String dateKey,
    DateTime? generatedAt,
  }) {
    final at = generatedAt ?? DateTime.now();
    return SavedPostCommentGenerationResult(
      body: result.body,
      hashtags: List<String>.from(result.hashtags),
      fullText: result.fullText,
      generatedAt: at.toIso8601String(),
      productKey: productKey.trim(),
      bucket: bucket,
      dateKey: dateKey,
    );
  }

  factory SavedPostCommentGenerationResult.fromJson(Map<String, dynamic> json) {
    final hashtagsRaw = json['hashtags'];
    final hashtags = hashtagsRaw is List
        ? hashtagsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return SavedPostCommentGenerationResult(
      body: json['body']?.toString() ?? '',
      hashtags: hashtags,
      fullText: json['full_text']?.toString() ?? json['fullText']?.toString(),
      generatedAt: json['generated_at']?.toString() ??
          json['generatedAt']?.toString() ??
          '',
      productKey: json['product_key']?.toString() ??
          json['productKey']?.toString() ??
          '',
      bucket: json['bucket']?.toString() ?? '',
      dateKey: json['date_key']?.toString() ?? json['dateKey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'body': body,
      'hashtags': hashtags,
      if (fullText != null) 'full_text': fullText,
      'generated_at': generatedAt,
      'product_key': productKey,
      'bucket': bucket,
      'date_key': dateKey,
    };
  }
}
