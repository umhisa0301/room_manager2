import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/saved_shop.dart';
import 'package:room_manager2/utils/favorite_genre_selection_policy.dart';
import 'package:room_manager2/utils/today_recommendation_policy.dart';

void main() {
  group('FavoriteGenreSelectionPolicy', () {
    test('保存ジャンル上限は3件', () {
      expect(FavoriteGenreSelectionPolicy.maxSelectable, 3);
      expect(FavoriteGenreSelectionPolicy.maxForRecommendGeneration, 3);
    });
  });

  group('TodayRecommendationPolicy', () {
    test('既定 sort はレビュー件数順で null ではない', () {
      expect(TodayRecommendationPolicy.defaultApiSort, '-reviewCount');
      expect(
        TodayRecommendationPolicy.apiSortForPostStyles({'balance'}),
        '-reviewCount',
      );
    });

    test('API上限は10より小さい', () {
      expect(TodayRecommendationPolicy.maxApiCallsPerGeneration, lessThan(10));
      expect(TodayRecommendationPolicy.maxApiCallsPerGeneration, 4);
    });
  });

  group('TodayRecommendationPlanBuilder', () {
    test('buildPlanSet は保存ジャンル必須と補助を分割する', () {
      final set = TodayRecommendationPlanBuilder.buildPlanSet(
        favoriteGenreIds: const ['100026', '100227', '100316'],
        savedShops: const [],
        doneItems: const [],
        candidateItems: const [],
        keywords: const ['フォールバック'],
        reactionCommentGenreIds: const {},
        reactionLikeGenreIds: const {},
        reactionCommentShopIds: const {},
        reactionLikeShopIds: const {},
        historyGenreIdsFiltered: const [],
      );
      expect(set.favoriteGenrePlans.length, 3);
      expect(set.assistPlan, isNull);
      expect(set.fallbackPlan, isNull);
      expect(
        set.favoriteGenrePlans.map((p) => p.genreId).toList(),
        ['100026', '100227', '100316'],
      );
      expect(set.favoriteGenrePlans.first.keyword, isNot('フォールバック'));
    });

    test('保存ジャンル3件でジャンルプラン3＋補助最大1', () {
      final plans = TodayRecommendationPlanBuilder.build(
        favoriteGenreIds: const ['g1', 'g2', 'g3'],
        savedShops: const [],
        doneItems: const [],
        candidateItems: const [],
        keywords: const ['水筒'],
        reactionCommentGenreIds: const {},
        reactionLikeGenreIds: const {},
        reactionCommentShopIds: const {},
        reactionLikeShopIds: const {},
        historyGenreIdsFiltered: const [],
      );
      expect(plans.where((p) => p.source == 'genre').length, 3);
      expect(plans.length, lessThanOrEqualTo(4));
      for (final p in plans) {
        expect(p.sort, '-reviewCount');
        expect(p.sort, isNotNull);
      }
    });

    test('保存ジャンル5件指定でもジャンルプランは3件まで', () {
      final plans = TodayRecommendationPlanBuilder.build(
        favoriteGenreIds: const ['g1', 'g2', 'g3', 'g4', 'g5'],
        savedShops: const [],
        doneItems: const [],
        candidateItems: const [],
        keywords: const ['人気'],
        reactionCommentGenreIds: const {},
        reactionLikeGenreIds: const {},
        reactionCommentShopIds: const {},
        reactionLikeShopIds: const {},
        historyGenreIdsFiltered: const [],
      );
      expect(plans.where((p) => p.source == 'genre').length, 3);
    });

    test('保存ジャンルなしのときフォールバック1件', () {
      final plans = TodayRecommendationPlanBuilder.build(
        favoriteGenreIds: const [],
        savedShops: const [],
        doneItems: const [],
        candidateItems: const [],
        keywords: const [],
        reactionCommentGenreIds: const {},
        reactionLikeGenreIds: const {},
        reactionLikeShopIds: const {},
        reactionCommentShopIds: const {},
        historyGenreIdsFiltered: const [],
      );
      expect(plans.any((p) => p.phase == 'fallback'), isTrue);
      expect(plans.length, 1);
    });

    test('補助プランは最大1件（反応ジャンル）', () {
      final plans = TodayRecommendationPlanBuilder.build(
        favoriteGenreIds: const ['g1'],
        savedShops: const [],
        doneItems: const [],
        candidateItems: const [],
        keywords: const ['人気'],
        reactionCommentGenreIds: const {'g9'},
        reactionLikeGenreIds: const {},
        reactionCommentShopIds: const {},
        reactionLikeShopIds: const {},
        historyGenreIdsFiltered: const ['g8'],
      );
      final assist = plans
          .where(
            (p) =>
                p.source == 'reactionGenre' ||
                p.source == 'reactionShop' ||
                p.source == 'savedShop' ||
                p.source == 'historyGenre',
          )
          .toList();
      expect(assist.length, 1);
      expect(assist.first.genreId, 'g9');
    });

    test('保存ジャンルと同じ補助条件は追加しない', () {
      final plans = TodayRecommendationPlanBuilder.build(
        favoriteGenreIds: const ['g1'],
        savedShops: [
          SavedShop(
            shopId: 'shop1',
            shopName: 'S',
            shopUrl: 'https://example.com',
            savedAt: DateTime(2024),
          ),
        ],
        doneItems: const [],
        candidateItems: const [],
        keywords: const ['人気'],
        reactionCommentGenreIds: const {'g1'},
        reactionLikeGenreIds: const {},
        reactionCommentShopIds: const {},
        reactionLikeShopIds: const {},
        historyGenreIdsFiltered: const [],
      );
      expect(
        plans.where((p) => p.source == 'reactionGenre').length,
        0,
      );
      expect(plans.where((p) => p.source == 'genre').length, 1);
    });

    test('maxPlanCount は API 上限を超えない', () {
      final count = TodayRecommendationPlanBuilder.maxPlanCount(
        favoriteGenreCount: 5,
        hasAssist: true,
        needsFallback: false,
      );
      expect(count, lessThanOrEqualTo(5));
      expect(count, 4);
    });
  });
}
