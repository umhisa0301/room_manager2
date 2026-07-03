import '../config/ai_gateway_config.dart';
import '../models/rakuten_search_item.dart';
import '../utils/catalog_product_keys.dart';
import '../utils/today_recommendation_policy.dart';
import 'post_comment_generation_count_store.dart';

/// AI投稿文生成の利用制限 bucket。
enum PostCommentGenerationBucket {
  /// おすすめコレ由来の投稿文生成。
  recommendation,
}

/// AI投稿文生成の利用可否スナップショット。
class PostCommentGenerationLimitState {
  const PostCommentGenerationLimitState({
    required this.allowed,
    required this.usedCount,
    required this.limit,
    this.reasonCode,
    this.productKey,
  });

  final bool allowed;
  final int usedCount;
  final int limit;

  /// 制限到達時は `daily_limit_reached` または `product_already_generated`。
  final String? reasonCode;

  /// 判定対象の商品キー（`shop:item` 等）。
  final String? productKey;
}

/// おすすめコレ bucket: 1日あたり最大 [TodayRecommendationPolicy.visibleDisplayCap] 商品まで（各1回）。
const int kPostCommentGenerationRecommendationDailyProductLimit =
    TodayRecommendationPolicy.visibleDisplayCap;

const String kPostCommentDailyLimitReasonCode = 'daily_limit_reached';
const String kPostCommentProductAlreadyGeneratedReasonCode =
    'product_already_generated';

/// Remote AI 利用時に日次制限を適用するか。
bool isPostCommentGenerationLimitEnforced() =>
    AiGatewayConfig.useRemotePostCommentGeneration;

/// [RakutenSearchItem] から投稿文生成制限用の安定商品キーを解決する。
///
/// 優先順: 正規化 productId（`shop:item`）→ 正規化 itemUrl（`url:...`）。
String? resolvePostCommentGenerationProductKey(RakutenSearchItem item) {
  return CatalogProductKeys.resolveCanonicalId(
    productId: item.productId,
    itemUrl: item.itemUrl,
  );
}

/// 生成済み商品キーと対象商品から生成可否を解決する（純粋関数・テスト用）。
PostCommentGenerationLimitState resolvePostCommentGenerationAvailability({
  required PostCommentGenerationBucket bucket,
  required String? productKey,
  required Set<String> generatedProductKeys,
  bool? enforcementEnabled,
  int dailyProductLimit = kPostCommentGenerationRecommendationDailyProductLimit,
}) {
  final enforced = enforcementEnabled ?? isPostCommentGenerationLimitEnforced();
  final normalizedKey = productKey?.trim();
  final usedCount = generatedProductKeys.length;

  if (!enforced) {
    return PostCommentGenerationLimitState(
      allowed: true,
      usedCount: usedCount,
      limit: dailyProductLimit,
      productKey: normalizedKey,
    );
  }

  if (normalizedKey == null || normalizedKey.isEmpty) {
    return PostCommentGenerationLimitState(
      allowed: true,
      usedCount: usedCount,
      limit: dailyProductLimit,
      productKey: normalizedKey,
    );
  }

  if (generatedProductKeys.contains(normalizedKey)) {
    return PostCommentGenerationLimitState(
      allowed: false,
      usedCount: usedCount,
      limit: dailyProductLimit,
      reasonCode: kPostCommentProductAlreadyGeneratedReasonCode,
      productKey: normalizedKey,
    );
  }

  if (usedCount >= dailyProductLimit) {
    return PostCommentGenerationLimitState(
      allowed: false,
      usedCount: usedCount,
      limit: dailyProductLimit,
      reasonCode: kPostCommentDailyLimitReasonCode,
      productKey: normalizedKey,
    );
  }

  return PostCommentGenerationLimitState(
    allowed: true,
    usedCount: usedCount,
    limit: dailyProductLimit,
    productKey: normalizedKey,
  );
}

/// 端末保存の bucket 別生成済み商品キーから生成可否を解決する。
Future<PostCommentGenerationLimitState>
    resolvePostCommentGenerationAvailabilityForToday({
  required PostCommentGenerationBucket bucket,
  required String productKey,
  DateTime? now,
  bool? enforcementEnabled,
  int dailyProductLimit = kPostCommentGenerationRecommendationDailyProductLimit,
}) async {
  final generatedProductKeys =
      await PostCommentGenerationCountStore.readTodayGeneratedProductKeys(
    bucketName: bucket.name,
    now: now,
  );
  return resolvePostCommentGenerationAvailability(
    bucket: bucket,
    productKey: productKey,
    generatedProductKeys: generatedProductKeys,
    enforcementEnabled: enforcementEnabled,
    dailyProductLimit: dailyProductLimit,
  );
}

/// 生成成功後に bucket の当日生成済み商品キーへ追加する。
Future<Set<String>> recordSuccessfulPostCommentGeneration({
  required PostCommentGenerationBucket bucket,
  required String productKey,
  DateTime? now,
}) {
  return PostCommentGenerationCountStore.recordGeneratedProductKey(
    bucketName: bucket.name,
    productKey: productKey,
    now: now,
  );
}

/// 1日上限到達時のユーザー向けメッセージ。
String buildPostCommentGenerationDailyLimitBlockedMessage() =>
    '本日のAI生成回数の上限に達しました。明日またお試しください。';

/// 同一商品の当日再生成ブロック時のユーザー向けメッセージ。
String buildPostCommentGenerationProductAlreadyGeneratedBlockedMessage() =>
    'この商品のAI投稿文は本日すでに生成済みです。';
