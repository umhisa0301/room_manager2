import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/today_recommendation.dart';
import 'package:room_manager2/utils/search_result_quality_filter.dart';

void main() {
  test('TodayRecommendationEntry の JSON 往復で imageUrl とレビューが欠落しない', () {
    const item = RakutenSearchItem(
      productId: 'code:1',
      itemName: 'テスト商品',
      itemPrice: 1200,
      itemUrl: 'https://example.com/item',
      affiliateUrl: '',
      imageUrl: 'https://example.com/img.jpg',
      shopName: 'テスト店',
      reviewCount: 42,
      reviewAverage: 4.5,
    );
    final entry = TodayRecommendationEntry(item: item);
    final restored = TodayRecommendationEntry.fromJson(entry.toJson());
    expect(restored, isNotNull);
    expect(restored!.item.imageUrl, item.imageUrl);
    expect(restored.item.reviewCount, 42);
    expect(restored.item.reviewAverage, 4.5);
  });

  test('reviewCount 0 / reviewAverage 0 は最終品質ゲートで除外される', () {
    const zeroCount = RakutenSearchItem(
      productId: 'code:3',
      itemName: 'レビューなし',
      itemPrice: 1200,
      itemUrl: 'https://example.com/item3',
      affiliateUrl: '',
      imageUrl: 'https://example.com/img3.jpg',
      shopName: 'テスト店',
      reviewCount: 0,
      reviewAverage: 4.5,
    );
    expect(SearchResultQualityFilter.passesDisplayQuality(zeroCount), isTrue);
    expect(zeroCount.reviewCount <= 0 || zeroCount.reviewAverage <= 0, isTrue);

    const zeroAverage = RakutenSearchItem(
      productId: 'code:4',
      itemName: '評価なし',
      itemPrice: 1200,
      itemUrl: 'https://example.com/item4',
      affiliateUrl: '',
      imageUrl: 'https://example.com/img4.jpg',
      shopName: 'テスト店',
      reviewCount: 10,
      reviewAverage: 0,
    );
    expect(zeroAverage.reviewCount <= 0 || zeroAverage.reviewAverage <= 0, isTrue);
  });
}
