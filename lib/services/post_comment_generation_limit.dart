import '../config/ai_gateway_config.dart';
import 'post_comment_generation_count_store.dart';

/// AI投稿文生成の利用可否スナップショット。
class PostCommentGenerationLimitState {
  const PostCommentGenerationLimitState({
    required this.allowed,
    required this.usedCount,
    required this.limit,
    this.reasonCode,
  });

  final bool allowed;
  final int usedCount;
  final int limit;

  /// 制限到達時は `daily_limit_reached`。
  final String? reasonCode;
}

/// MVP: 全ユーザー 1日1回（Remote 利用時のみクライアント側で適用）。
const int kPostCommentGenerationDailyLimit = 1;

const String kPostCommentDailyLimitReasonCode = 'daily_limit_reached';

/// Remote AI 利用時に日次制限を適用するか。
bool isPostCommentGenerationLimitEnforced() =>
    AiGatewayConfig.useRemotePostCommentGeneration;

/// 利用回数から生成可否を解決する（純粋関数・テスト用）。
PostCommentGenerationLimitState resolvePostCommentGenerationAvailability({
  required int usedCount,
  bool? enforcementEnabled,
  int dailyLimit = kPostCommentGenerationDailyLimit,
}) {
  final enforced = enforcementEnabled ?? isPostCommentGenerationLimitEnforced();
  if (!enforced) {
    return PostCommentGenerationLimitState(
      allowed: true,
      usedCount: usedCount,
      limit: dailyLimit,
    );
  }

  final allowed = usedCount < dailyLimit;
  return PostCommentGenerationLimitState(
    allowed: allowed,
    usedCount: usedCount,
    limit: dailyLimit,
    reasonCode: allowed ? null : kPostCommentDailyLimitReasonCode,
  );
}

/// 端末保存の今日の回数から生成可否を解決する。
Future<PostCommentGenerationLimitState>
    resolvePostCommentGenerationAvailabilityForToday({
  DateTime? now,
  bool? enforcementEnabled,
  int dailyLimit = kPostCommentGenerationDailyLimit,
}) async {
  final usedCount = await PostCommentGenerationCountStore.readTodayCount(
    now: now,
  );
  return resolvePostCommentGenerationAvailability(
    usedCount: usedCount,
    enforcementEnabled: enforcementEnabled,
    dailyLimit: dailyLimit,
  );
}

/// 生成成功後に今日の回数を 1 増やす。
Future<int> recordSuccessfulPostCommentGeneration({DateTime? now}) =>
    PostCommentGenerationCountStore.incrementTodayCount(now: now);

/// 1日1回上限到達時のユーザー向けメッセージ。
String buildPostCommentGenerationDailyLimitBlockedMessage() =>
    '本日のAI生成回数の上限に達しました。明日またお試しください。';
