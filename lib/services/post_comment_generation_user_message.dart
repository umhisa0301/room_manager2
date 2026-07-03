import 'post_comment_generation_exception.dart';

/// VPS停止・AI生成停止・503系。
const String kPostCommentGenerationDisabledMessage =
    '現在AI生成は停止しています。時間をおいてもう一度お試しください。';

/// 通信エラー・タイムアウト。
const String kPostCommentGenerationNetworkMessage =
    '通信が不安定です。接続を確認して、もう一度お試しください。';

/// 1日上限到達（クライアント・サーバー共通）。
const String kPostCommentGenerationDailyLimitMessage =
    '本日のAI生成回数の上限に達しました。明日またお試しください。';

/// 同一商品の当日再生成ブロック。
const String kPostCommentGenerationProductAlreadyGeneratedMessage =
    'この商品のAI投稿文は本日すでに生成済みです。';

/// その他の失敗。
const String kPostCommentGenerationGenericErrorMessage =
    '投稿文を作成できませんでした。時間をおいてもう一度お試しください。';

/// エラーコード・HTTP ステータスからユーザー向け文言を返す。
String postCommentGenerationUserMessage(PostCommentGenerationException error) {
  switch (error.code) {
    case 'RATE_LIMIT_EXCEEDED':
    case 'daily_limit_reached':
      return kPostCommentGenerationDailyLimitMessage;
    case 'product_already_generated':
      return kPostCommentGenerationProductAlreadyGeneratedMessage;
    case 'AI_GENERATION_DISABLED':
    case 'SERVICE_UNAVAILABLE':
      return kPostCommentGenerationDisabledMessage;
    case 'TIMEOUT':
    case 'NETWORK_ERROR':
      return kPostCommentGenerationNetworkMessage;
    case 'LLM_REQUEST_FAILED':
      final lower = error.message.toLowerCase();
      if (lower.contains('timed out') || lower.contains('timeout')) {
        return kPostCommentGenerationNetworkMessage;
      }
      return kPostCommentGenerationGenericErrorMessage;
    default:
      final status = error.httpStatus;
      if (status == 503 || status == 502 || status == 504) {
        return kPostCommentGenerationDisabledMessage;
      }
      return kPostCommentGenerationGenericErrorMessage;
  }
}

/// 投稿スタイル設定のプレビュー更新失敗向け（文言は共通ポリシーに合わせる）。
String postCommentPreviewUserMessage(PostCommentGenerationException error) {
  final base = postCommentGenerationUserMessage(error);
  if (base == kPostCommentGenerationGenericErrorMessage) {
    return '生成イメージの更新に失敗しました。';
  }
  return base;
}
