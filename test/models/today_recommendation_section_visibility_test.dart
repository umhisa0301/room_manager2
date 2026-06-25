import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/today_recommendation.dart';

RakutenSearchItem _item(String id) => RakutenSearchItem(
      productId: id,
      itemName: '商品$id',
      itemPrice: 1000,
      itemUrl: 'https://example.com/$id',
      affiliateUrl: '',
      imageUrl: '',
      shopName: 'shop',
    );

void main() {
  group('TodayRecommendationSectionVisibility', () {
    test('保存ショップ未登録時は保存ショップからセクションを表示しない', () {
      final entries = [
        TodayRecommendationEntry(
          item: _item('1'),
          section: TodayRecommendationSection.sellable,
        ),
        TodayRecommendationEntry(
          item: _item('2'),
          section: TodayRecommendationSection.popular,
        ),
      ];

      final visible = TodayRecommendationSectionVisibility.visibleSections(
        entries: entries,
        savedShopCount: 0,
      ).toList();

      expect(visible, [TodayRecommendationSection.popular]);
    });

    test('保存ショップ登録済みかつ候補ありのとき保存ショップからを表示する', () {
      final entries = [
        TodayRecommendationEntry(
          item: _item('1'),
          section: TodayRecommendationSection.sellable,
        ),
        TodayRecommendationEntry(
          item: _item('2'),
          section: TodayRecommendationSection.popular,
        ),
      ];

      final visible = TodayRecommendationSectionVisibility.visibleSections(
        entries: entries,
        savedShopCount: 2,
      ).toList();

      expect(visible, [
        TodayRecommendationSection.sellable,
        TodayRecommendationSection.popular,
      ]);
    });
  });
}
