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

  test('noimage URL は品質ゲートで除外される', () {
    const item = RakutenSearchItem(
      productId: 'code:2',
      itemName: '画像なし',
      itemPrice: 1000,
      itemUrl: 'https://example.com/item2',
      affiliateUrl: '',
      imageUrl: 'https://thumbnail.image.rakuten.co.jp/noimage.jpg',
      shopName: 'テスト店',
      reviewCount: 20,
      reviewAverage: 4.0,
    );
    expect(SearchResultQualityFilter.hasDisplayableImage(item), isFalse);
  });
}
