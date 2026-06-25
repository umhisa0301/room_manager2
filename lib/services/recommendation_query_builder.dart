import '../data/interest_category_definitions.dart';
import '../data/priority_rule_definitions.dart';
import '../data/room_type_definitions.dart';
import '../models/room_recommendation_profile.dart';

/// 診断プロファイルから検索クエリを生成する。
abstract final class RecommendationQueryBuilder {
  RecommendationQueryBuilder._();

  static const int maxQueries = 9;

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

    final categoryTerms = <String>[];
    for (final cat in categories) {
      if (cat.searchTerms.isNotEmpty) {
        categoryTerms.add(cat.searchTerms.first);
      } else {
        categoryTerms.add(cat.displayName);
      }
    }

    if (priorityRules.isNotEmpty && categoryTerms.isNotEmpty) {
      final primaryWords = priorityRules.first.searchKeywords
          .where(_isUsableWord)
          .toList(growable: false);

      // 先頭2語を全カテゴリへ展開（手土産×各カテゴリ、便利グッズ×各カテゴリなど）。
      for (var w = 0; w < 2 && w < primaryWords.length; w++) {
        _expandKeywordAcrossCategories(
          queries,
          seen,
          categoryTerms,
          primaryWords[w],
        );
      }

      // カテゴリごとに3語目以降をずらして追加（時短×キッチン、内祝い×雑貨など）。
      final passBCategoryCount = categoryTerms.length >= 3
          ? categoryTerms.length - 1
          : categoryTerms.length;
      for (var ci = 0; ci < passBCategoryCount; ci++) {
        if (queries.length >= maxQueries) break;
        final wordIndex = ci + 2;
        if (wordIndex >= primaryWords.length) break;
        _addQuery(queries, seen, '${primaryWords[wordIndex]} ${categoryTerms[ci]}');
      }

      // 3語目を末尾カテゴリへ（内祝い×ベビー、時短×掃除等）。
      if (queries.length < maxQueries &&
          primaryWords.length > 2 &&
          categoryTerms.isNotEmpty) {
        _addQuery(
          queries,
          seen,
          '${primaryWords[2]} ${categoryTerms.last}',
        );
      }

      // 第2優先以降は先頭キーワードを1カテゴリ分だけ追加（API枠の節約）。
      for (var ri = 1; ri < priorityRules.length; ri++) {
        if (queries.length >= maxQueries) break;
        final word = priorityRules[ri].searchKeywords
            .firstWhere(_isUsableWord, orElse: () => '');
        if (word.isEmpty) continue;
        _addQuery(queries, seen, '$word ${categoryTerms.first}');
      }
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

  static void _expandKeywordAcrossCategories(
    List<String> queries,
    Set<String> seen,
    List<String> categoryTerms,
    String word,
  ) {
    if (!_isUsableWord(word)) return;
    for (final term in categoryTerms) {
      if (queries.length >= maxQueries) return;
      _addQuery(queries, seen, '$word $term');
    }
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
