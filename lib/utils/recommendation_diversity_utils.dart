import '../models/rakuten_search_item.dart';
import '../models/today_recommendation.dart';

/// おすすめコレ最終選定向けの類似・分散判定。
abstract final class RecommendationDiversityUtils {
  /// 商品名から記号・価格・クーポン・サイズ数字などを除いた比較用文字列。
  static String normalizeTitleForSimilarity(String title) {
    var t = title.toLowerCase();
    t = t.replaceAll(RegExp(r'[【】\[\]（）()]'), ' ');
    t = t.replaceAll(
      RegExp(r'送料無料|クーポン|ポイント|%off|%\s*off|セール|限定|特価'),
      '',
    );
    t = t.replaceAll(
      RegExp(r'\d+\s*(cm|mm|m|ml|l|インチ|"|幅|×|x)\d*', caseSensitive: false),
      ' ',
    );
    t = t.replaceAll(RegExp(r'[\d,.]+円'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  static bool areTitlesSimilar(String a, String b) {
    final na = normalizeTitleForSimilarity(a);
    final nb = normalizeTitleForSimilarity(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    final shorter = na.length < nb.length ? na : nb;
    final longer = na.length >= nb.length ? na : nb;
    if (shorter.length >= 4) {
      final prefixLen = (shorter.length * 0.7).floor().clamp(4, shorter.length);
      if (longer.startsWith(shorter.substring(0, prefixLen))) return true;
    }
    return false;
  }

  static bool hasDuplicateShop({
    required RakutenSearchItem item,
    required Iterable<TodayRecommendationEntry> picked,
  }) {
    final shop = item.shopCode.trim();
    if (shop.isEmpty) return false;
    return picked.any((e) => e.item.shopCode.trim() == shop);
  }

  static bool hasDuplicateImage({
    required RakutenSearchItem item,
    required Iterable<TodayRecommendationEntry> picked,
  }) {
    final image = item.imageUrl.trim();
    if (image.isEmpty) return false;
    return picked.any((e) => e.item.imageUrl.trim() == image);
  }

  static bool isTooSimilarToPicked({
    required RakutenSearchItem item,
    required Iterable<TodayRecommendationEntry> picked,
  }) {
    for (final entry in picked) {
      if (areTitlesSimilar(entry.item.itemName, item.itemName)) return true;
      if (hasDuplicateImage(item: item, picked: [entry])) return true;
    }
    return false;
  }

  static bool passesDiversityGate({
    required RakutenSearchItem item,
    required Iterable<TodayRecommendationEntry> picked,
    required bool allowDuplicateShop,
  }) {
    if (!allowDuplicateShop &&
        hasDuplicateShop(item: item, picked: picked)) {
      return false;
    }
    if (isTooSimilarToPicked(item: item, picked: picked)) return false;
    return true;
  }
}
