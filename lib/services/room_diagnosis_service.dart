import '../data/comment_tone_definitions.dart';
import '../data/interest_category_definitions.dart';
import '../data/priority_rule_definitions.dart';
import '../data/room_type_definitions.dart';
import '../models/room_recommendation_profile.dart';
import 'recommendation_query_builder.dart';

/// 診断回答から [RoomRecommendationProfile] を組み立てる。
abstract final class RoomDiagnosisService {
  RoomDiagnosisService._();

  static RoomRecommendationProfile buildProfile(RoomDiagnosisAnswers answers) {
    final primary = answers.primaryTypeId.trim();
    final priorityIds = answers.priorityRuleIds.take(3).toList(growable: false);
    final categoryIds = answers.interestCategoryIds.take(5).toList(growable: false);
    final toneId = answers.commentToneId.trim();

    final draft = RoomRecommendationProfile(
      primaryTypeId: primary,
      secondaryTypeIds: const [],
      interestCategoryIds: categoryIds,
      priorityRuleIds: priorityIds,
      searchKeywordPresets: const [],
      positiveKeywordIds: _collectPositiveKeywordIds(priorityIds),
      preferredGenreGroupIds: categoryIds,
      commentAngleId: _primaryCommentAngle(priorityIds),
      commentToneId: toneId,
      diagnosedAt: DateTime.now(),
      exclusionPreferenceIds: answers.exclusionPreferenceIds,
    );

    final queries = RecommendationQueryBuilder.buildQueries(draft);
    return draft.copyWith(searchKeywordPresets: queries);
  }

  static List<String> _collectPositiveKeywordIds(List<String> priorityIds) {
    final ids = <String>[];
    for (final id in priorityIds) {
      final rule = PriorityRuleDefinitions.byId(id);
      if (rule == null) continue;
      for (final word in rule.boostKeywords) {
        if (PriorityRuleDefinitions.bannedKeywords.contains(word)) continue;
        ids.add(word);
      }
    }
    return ids.toSet().toList(growable: false);
  }

  static String _primaryCommentAngle(List<String> priorityIds) {
    for (final id in priorityIds) {
      final rule = PriorityRuleDefinitions.byId(id);
      if (rule != null && rule.commentAngles.isNotEmpty) {
        return rule.commentAngles.first;
      }
    }
    return '';
  }

  static String primaryTypeLabel(String typeId) =>
      RoomTypeDefinitions.displayNameFor(typeId);

  static String interestCategoriesLabel(Iterable<String> ids) =>
      InterestCategoryDefinitions.displayNamesFor(ids).join('、');

  static String priorityRulesLabel(Iterable<String> ids) {
    return PriorityRuleDefinitions.displayNamesFor(ids)
        .map(_shortPriorityLabel)
        .join('、');
  }

  static String _shortPriorityLabel(String full) {
    if (full.contains('実用性')) return '実用性が高い';
    if (full.contains('見た目')) return '見た目・映え';
    if (full.contains('レビュー')) return 'レビューが多い';
    if (full.contains('バランス')) return 'コスパ重視';
    if (full.contains('プレゼント')) return 'ギフト向け';
    if (full.contains('季節')) return '季節感・トレンド';
    return full;
  }

  static String commentToneLabel(String toneId) =>
      CommentToneDefinitions.displayNameFor(toneId);

  /// 診断結果画面向け：タイプ・関心ジャンル・重視条件をつなげた説明文。
  static String buildResultNarrative({
    required String primaryTypeId,
    required Iterable<String> interestCategoryIds,
    required Iterable<String> priorityRuleIds,
  }) {
    final typeName = RoomTypeDefinitions.displayNameFor(primaryTypeId);
    final interests =
        InterestCategoryDefinitions.displayNamesFor(interestCategoryIds);
    final priorities = priorityRuleIds
        .map(PriorityRuleDefinitions.byId)
        .whereType<PriorityRuleDefinition>()
        .map((e) => _shortPriorityLabel(e.displayName))
        .toList(growable: false);

    final buffer = StringBuffer('$typeNameをベースに');
    if (interests.isNotEmpty) {
      buffer.write('、${_interestPhrase(interests)}の商品を中心に提案します。');
    } else {
      buffer.write('、あなたに合う商品を中心に提案します。');
    }
    if (priorities.isNotEmpty) {
      buffer.write(_priorityNarrative(priorities));
    }
    return buffer.toString();
  }

  static String _interestPhrase(List<String> interests) {
    if (interests.length == 1) return interests.first;
    final head = interests.sublist(0, interests.length - 1).join('・');
    final tail = interests.last;
    if (head.isEmpty) return '$tailまわり';
    return '$head・$tailまわり';
  }

  static String _priorityNarrative(List<String> priorities) {
    if (priorities.any((p) => p.contains('レビュー'))) {
      return 'レビューが多く、安心して紹介しやすい候補を優先します。';
    }
    if (priorities.any((p) => p.contains('見た目') || p.contains('映え'))) {
      return '見た目や雰囲気が伝わりやすく、投稿しやすい候補を優先します。';
    }
    if (priorities.any((p) => p.contains('コスパ') || p.contains('バランス'))) {
      return '価格と満足感のバランスが良く、紹介しやすい候補を優先します。';
    }
    if (priorities.any((p) => p.contains('ギフト'))) {
      return '贈り物やイベント向けに選びやすい候補を優先します。';
    }
    if (priorities.any((p) => p.contains('実用'))) {
      return '暮らしの役立ちが伝わりやすい候補を優先します。';
    }
    if (priorities.any((p) => p.contains('季節'))) {
      return '季節感やトレンドが伝わりやすい候補を優先します。';
    }
    return '${priorities.first}条件に合いやすい候補を優先します。';
  }
}
