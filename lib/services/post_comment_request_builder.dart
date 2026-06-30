import '../models/post_style_settings.dart';
import 'post_comment_generation_service.dart';

/// stepbyte-api-server `/api/ai/generate` 向けリクエスト JSON を組み立てる。
class PostCommentRequestBuilder {
  const PostCommentRequestBuilder();

  Map<String, dynamic> build({
    required PostCommentGenerationInput input,
    String appId = 'room_management',
    String taskId = 'room_post_comment',
    String promptVersion = 'v1',
  }) {
    final style = input.effectiveStyleSettings.normalized();
    final limits = style.generationLimits;

    final payload = <String, dynamic>{
      'product': _buildProduct(input),
      'user_style': _buildUserStyle(
        style,
        includeStyleExample: input.includeStyleExample,
      ),
      'generation_options': _buildGenerationOptions(limits),
    };

    final profileContext = input.profileContext;
    if (profileContext != null) {
      payload['profile_context'] = profileContext.toJson();
    }

    return {
      'appId': appId,
      'taskId': taskId,
      'promptVersion': promptVersion,
      'payload': payload,
    };
  }

  Map<String, dynamic> _buildProduct(PostCommentGenerationInput input) {
    final product = <String, dynamic>{
      'title': input.itemName,
      'price': input.itemPrice,
      'review_average': input.reviewAverage,
      'review_count': input.reviewCount,
    };

    final rawTitle = input.rawTitle.trim();
    if (rawTitle.isNotEmpty) {
      product['raw_title'] = rawTitle;
    }

    final displayTitle = input.itemName.trim();
    if (displayTitle.isNotEmpty) {
      product['display_title'] = displayTitle;
    }

    final keywords = input.titleKeywords
        .map((keyword) => keyword.trim())
        .where((keyword) => keyword.isNotEmpty)
        .toList();
    if (keywords.isNotEmpty) {
      product['title_keywords'] = keywords;
    }

    final reason = input.recommendationReason.trim();
    if (reason.isNotEmpty) {
      product['recommendation_reason'] = reason;
    }

    final genre = input.genreName.trim();
    if (genre.isNotEmpty) {
      product['genre'] = genre;
    }

    final genreId = input.genreId.trim();
    if (genreId.isNotEmpty) {
      product['genre_id'] = genreId;
    }

    final shopName = input.shopName.trim();
    if (shopName.isNotEmpty) {
      product['shop_name'] = shopName;
    }

    final productUrl = input.productUrl.trim();
    if (productUrl.isNotEmpty) {
      product['product_url'] = productUrl;
    }

    final imageUrl = input.imageUrl.trim();
    if (imageUrl.isNotEmpty) {
      product['image_url'] = imageUrl;
    }

    return product;
  }

  Map<String, dynamic> _buildUserStyle(
    PostStyleSettings style, {
    required bool includeStyleExample,
  }) {
    final userStyle = <String, dynamic>{
      'tone': style.tone.toJsonKey(),
      'length': style.length.toJsonKey(),
      'target_length_chars': style.targetLengthChars,
      'emoji_level': style.emojiLevel.toJsonKey(),
      'kaomoji_enabled': style.kaomojiEnabled,
      'hashtag_level': style.hashtagLevel.toJsonKey(),
      'hashtag_count': style.hashtagCount,
      'focus_points': style.focusPoints.map((e) => e.toJsonKey()).toList(),
      'target_audience': style.targetAudience.toJsonKey(),
      'avoid_overstatement': style.avoidOverstatement,
    };

    if (includeStyleExample) {
      final exampleText = style.styleExample?.trim();
      if (exampleText != null && exampleText.isNotEmpty) {
        userStyle['example_text'] = exampleText;
      }
    }

    return userStyle;
  }

  Map<String, dynamic> _buildGenerationOptions(PostGenerationLimits limits) {
    return {
      'min_body_chars': limits.minBodyChars,
      'max_body_chars': limits.maxBodyChars,
      'max_hashtags': limits.maxHashtags,
      'max_output_tokens': limits.maxOutputTokens,
      'max_total_chars': limits.maxTotalChars,
    };
  }
}
