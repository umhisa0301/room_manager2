import 'package:flutter/foundation.dart';

import '../config/monetization_config.dart';
import '../config/monetization_plan_config.dart';
import '../models/rakuten_product_search_condition.dart';
import '../utils/app_debug_log.dart';

/// 楽天検索の詳細条件（価格・並び順・付加条件）の利用可否スナップショット。
class RakutenSearchConditionAvailabilityState {
  const RakutenSearchConditionAvailabilityState({
    required this.allowed,
    required this.plan,
    required this.limitsEnforcementEnabled,
    this.reasonCode,
  });

  final bool allowed;
  final MonetizationPlan plan;
  final bool limitsEnforcementEnabled;

  /// 利用不可時は `plan_locked`。
  final String? reasonCode;
}

/// 詳細検索条件ガードの適用範囲。
enum RakutenSearchAdvancedConditionScope {
  productKeyword,
  genreExplore,
  savedShopKeyword,
}

/// 現在プランから楽天検索詳細条件の可否を解決する（純粋関数・テスト用）。
RakutenSearchConditionAvailabilityState resolveRakutenSearchConditionAvailability({
  MonetizationPlanContext? planContext,
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) {
  final snapshot = flags ?? MonetizationFlagSnapshot.fromCompileTime();
  final context = planContext ??
      resolvePlanLimitsForCurrentUser(
        flags: snapshot,
        purchasedPlanOverride: purchasedPlanOverride,
      );

  if (!context.limitsEnforcementEnabled) {
    return RakutenSearchConditionAvailabilityState(
      allowed: true,
      plan: context.plan,
      limitsEnforcementEnabled: false,
    );
  }

  final allowed = context.limits.advancedRakutenSearchSortEnabled;
  return RakutenSearchConditionAvailabilityState(
    allowed: allowed,
    plan: context.plan,
    limitsEnforcementEnabled: true,
    reasonCode: allowed ? null : 'plan_locked',
  );
}

/// 楽天検索詳細条件可否のエイリアス。
bool canUseAdvancedRakutenSearchConditions({
  MonetizationFlagSnapshot? flags,
  MonetizationPlan? purchasedPlanOverride,
}) {
  final state = resolveRakutenSearchConditionAvailability(
    flags: flags,
    purchasedPlanOverride: purchasedPlanOverride,
  );
  if (kDebugMode) {
    importantDebugLog(
      '[MONETIZATION_LIMIT] advancedRakutenSearch allowed=${state.allowed} '
      'plan=${state.plan.name}',
    );
  }
  return state.allowed;
}

/// 無料版向けの詳細検索ロック本文。
String rakutenSearchConditionLockedMessage() =>
    '価格や並び順などの詳細検索はBasicプラン向けの機能です。'
    '無料版では通常のキーワード検索をお使いいただけます。';

/// Basic プラン向けの補足（購入導線なし）。
String rakutenSearchConditionLockedBasicHint() =>
    'Basicプランでは、価格帯や並び順を調整して商品を探しやすくできます。';

/// ロック時の全文（シート・ヒント用）。
String buildRakutenSearchConditionLockedBody(
  RakutenSearchConditionAvailabilityState state,
) {
  final base = rakutenSearchConditionLockedMessage();
  if (state.plan == MonetizationPlan.free) {
    return '$base\n\n${rakutenSearchConditionLockedBasicHint()}';
  }
  return base;
}

/// プラン制限下で詳細条件フィールドを除去した検索条件を返す。
RakutenProductSearchCondition stripAdvancedRakutenSearchConditionFields({
  required RakutenProductSearchCondition condition,
  required RakutenSearchAdvancedConditionScope scope,
}) {
  return RakutenProductSearchCondition(
    keyword: condition.keyword,
    minPrice: null,
    maxPrice: null,
    excludeKeyword: '',
    minReviewCount: null,
    minReviewAverage: null,
    minCommentCount: null,
    shopCode: scope == RakutenSearchAdvancedConditionScope.savedShopKeyword
        ? condition.shopCode
        : null,
    itemCode: condition.itemCode,
    genreId: scope == RakutenSearchAdvancedConditionScope.genreExplore
        ? condition.genreId
        : null,
    sort: null,
    shopItemQueryStyle: condition.shopItemQueryStyle,
  ).normalized();
}

/// 詳細条件が許可されていないとき、検索リクエストから付加条件を除去する。
RakutenProductSearchCondition guardRakutenSearchConditionForPlan({
  required RakutenProductSearchCondition condition,
  required bool advancedAllowed,
  required RakutenSearchAdvancedConditionScope scope,
}) {
  if (advancedAllowed) return condition;
  return stripAdvancedRakutenSearchConditionFields(
    condition: condition,
    scope: scope,
  );
}
