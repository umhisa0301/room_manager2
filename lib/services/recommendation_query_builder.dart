import '../data/interest_category_definitions.dart';
import '../data/priority_rule_definitions.dart';
import '../data/room_type_definitions.dart';
import '../models/room_recommendation_profile.dart';

/// 診断プロファイルから検索クエリを生成する。
abstract final class RecommendationQueryBuilder {
  RecommendationQueryBuilder._();

  static const int maxQueries = 8;

  /// 優先条件ワード × 関心カテゴリでクエリを組み立てる。
  static List<String> buildQueries(RoomRecommendationProfile profile) {
    final queries = <String>[];
    final seen = <String>{};

    final priorityRules = profile.priorityRuleIds
        .map(PriorityRuleDefinitions.byId)
        .whereType<PriorityRuleDefinition>()
        .toList();
    final categories = profile.interestCategoryIds
        .map(InterestCategoryDefinitions.byId)
        .whereType<InterestCategoryDefinition>()
        .toList();

    final searchWords = <String>[];
    for (final rule in priorityRules) {
      for (final word in rule.searchKeywords) {
        if (_isUsableWord(word)) searchWords.add(word);
      }
    }

    final categoryTerms = <String>[];
    for (final cat in categories) {
      if (cat.searchTerms.isNotEmpty) {
        categoryTerms.add(cat.searchTerms.first);
      } else {
        categoryTerms.add(cat.displayName);
      }
    }

    // 優先条件 × カテゴリの組み合わせ（主軸）。
    for (final word in searchWords) {
      for (final term in categoryTerms) {
        if (queries.length >= maxQueries) break;
        _addQuery(queries, seen, '$word $term');
      }
      if (queries.length >= maxQueries) break;
    }

    // タイプ方向 × カテゴリで補完。
    if (queries.length < maxQueries) {
      final type = RoomTypeDefinitions.byId(profile.primaryTypeId);
      final typeWords = type?.searchDirectionKeywords ?? const [];
      for (final word in typeWords) {
        for (final term in categoryTerms) {
          if (queries.length >= maxQueries) break;
          _addQuery(queries, seen, '$word $term');
        }
        if (queries.length >= maxQueries) break;
      }
    }

    return queries;
  }

  static void _addQuery(List<String> out, Set<String> seen, String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    if (seen.contains(normalized)) return;
    if (!_isUsableQuery(normalized)) return;
    seen.add(normalized);
    out.add(normalized);
  }

  static bool _isUsableWord(String word) {
    final w = word.trim();
    if (w.isEmpty) return false;
    if (PriorityRuleDefinitions.bannedKeywords.contains(w)) return false;
    return true;
  }

  static bool _isUsableQuery(String query) {
    if (PriorityRuleDefinitions.bannedKeywords.any(query.contains)) {
      return false;
    }
    final parts = query.split(RegExp(r'\s+'));
    if (parts.length < 2) return false;
    final bannedSingles = {'人気', 'おすすめ', '売れ筋', '便利', 'かわいい', '送料無料'};
    if (parts.every(bannedSingles.contains)) return false;
    return true;
  }
}
