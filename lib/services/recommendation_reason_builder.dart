import '../data/interest_category_definitions.dart';
import '../data/priority_rule_definitions.dart';
import '../data/room_type_definitions.dart';
import '../models/room_recommendation_profile.dart';
import '../models/rakuten_search_item.dart';
import 'recommendation_scoring_service.dart';

/// おすすめ理由文を生成する。
abstract final class RecommendationReasonBuilder {
  RecommendationReasonBuilder._();

  static String build({
    required RoomRecommendationProfile profile,
    required RakutenSearchItem item,
    RecommendationScoreResult? scoreResult,
    RecommendationSlotRole slot = RecommendationSlotRole.personalFit,
  }) {
    final typeName = RoomTypeDefinitions.displayNameFor(profile.primaryTypeId);
    final priorityLabels = profile.priorityRuleIds
        .map(PriorityRuleDefinitions.displayNameFor)
        .where((e) => e.isNotEmpty)
        .toList();
    final categoryNames = InterestCategoryDefinitions.displayNamesFor(
      profile.interestCategoryIds,
    );

    final matched = scoreResult?.matchedKeywords ?? const [];
    final hasReview = item.reviewCount >= 20 && item.reviewAverage >= 4.0;

    final buffer = StringBuffer();

    switch (slot) {
      case RecommendationSlotRole.personalFit:
        if (priorityLabels.isNotEmpty) {
          buffer.write('あなたの「$typeName」と「${_shortPriority(priorityLabels.first)}」に合わせて選びました。');
        } else {
          buffer.write('あなたの「$typeName」に合わせて選びました。');
        }
      case RecommendationSlotRole.trustedPick:
        buffer.write('レビューや価格のバランスを重視して選びました。');
        if (hasReview) {
          buffer.write('評価${item.reviewAverage.toStringAsFixed(1)}（${item.reviewCount}件）の安心候補です。');
        }
      case RecommendationSlotRole.discovery:
        buffer.write('少し視点を変えた発見候補です。');
        if (categoryNames.isNotEmpty) {
          buffer.write('${categoryNames.first}まわりで紹介しやすい商品です。');
        }
    }

    if (slot == RecommendationSlotRole.personalFit) {
      if (categoryNames.isNotEmpty) {
        buffer.write('${categoryNames.first}まわりで使いやすく、');
      }
      if (matched.isNotEmpty) {
        buffer.write('${matched.take(2).join('・')}を伝えやすい候補です。');
      } else if (priorityLabels.isNotEmpty &&
          profile.priorityRuleIds.contains('visual_sns')) {
        buffer.write('写真で雰囲気が伝わりやすく、ROOMでも紹介しやすい候補です。');
      } else if (hasReview) {
        buffer.write('レビュー評価も高く、紹介しやすい候補です。');
      } else {
        buffer.write('紹介しやすい候補です。');
      }
    }

    return buffer.toString();
  }

  static String _shortPriority(String full) {
    if (full.contains('実用性')) return '実用性重視';
    if (full.contains('見た目')) return '見た目・映え重視';
    if (full.contains('レビュー')) return 'レビュー重視';
    if (full.contains('バランス')) return 'コスパ重視';
    if (full.contains('プレゼント')) return 'ギフト重視';
    if (full.contains('季節')) return '季節感重視';
    return full;
  }
}
