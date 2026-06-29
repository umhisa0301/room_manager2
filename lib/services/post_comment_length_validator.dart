import '../models/post_style_settings.dart';

/// 生成済み投稿文が [PostStyleSettings.generationLimits] を満たすか検証する。
///
/// TODO(API接続時): OpenAI 応答の後処理で利用。スタブ生成は [StubPostCommentBuilder] 内で
/// 長さ調整済みのため、現段階では未使用。
abstract final class PostCommentLengthValidator {
  PostCommentLengthValidator._();

  static bool isWithinLimits({
    required String text,
    required PostGenerationLimits limits,
    bool hasHashtags = true,
  }) {
    if (text.length > limits.maxTotalChars) return false;
    if (!hasHashtags) {
      return text.length >= limits.minBodyChars &&
          text.length <= limits.maxBodyChars;
    }
    // ハッシュタグ行を除いた本文長の厳密検証は API 接続時に実装する。
    return text.length <= limits.maxTotalChars;
  }
}
