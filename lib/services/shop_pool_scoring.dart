import 'dart:math' as math;

/// ShopPool 簡易スコア（将来調整しやすいよう定数化）。
abstract final class ShopPoolScoring {
  static const double itemCountWeight = 18;
  static const double reviewCountLogWeight = 12;
  static const double reviewAverageWeight = 22;
  static const double safeRatioBonusMax = 15;
  static const double genreDensityBonusMax = 10;

  static double compute({
    required int itemCount,
    required int safeItemCount,
    required int maxReviewCount,
    required double averageReviewAverage,
    required int primaryGenreItemCount,
  }) {
    final safeRatio = itemCount <= 0 ? 0.0 : safeItemCount / itemCount;
    final genreRatio = itemCount <= 0
        ? 0.0
        : primaryGenreItemCount / itemCount;
    final safeRatioBonus = safeRatio * safeRatioBonusMax;
    final genreDensityBonus = genreRatio * genreDensityBonusMax;
    return itemCount * itemCountWeight +
        math.log(maxReviewCount + 1) * reviewCountLogWeight +
        averageReviewAverage * reviewAverageWeight +
        safeRatioBonus +
        genreDensityBonus;
  }
}
