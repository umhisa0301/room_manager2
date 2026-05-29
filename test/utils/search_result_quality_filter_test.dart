import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/utils/search_result_quality_filter.dart';

RakutenSearchItem _item({
  String name = 'テスト商品',
  int price = 1980,
  String image = 'https://thumbnail.image.rakuten.co.jp/@0_mall/example/cabinet/a.jpg',
  String url = 'https://item.rakuten.co.jp/shop/item/',
}) {
  return RakutenSearchItem(
    productId: 'shop:item1',
    itemName: name,
    itemPrice: price,
    itemUrl: url,
    affiliateUrl: '',
    imageUrl: image,
    shopName: 'テストショップ',
  );
}

void main() {
  group('SearchResultQualityFilter', () {
    test('有効な商品は通す', () {
      expect(SearchResultQualityFilter.passesDisplayQuality(_item()), isTrue);
    });

    test('画像なしは除外', () {
      expect(
        SearchResultQualityFilter.exclusionReason(
          _item(image: ''),
        ),
        SearchQualityExcludeReason.noImage,
      );
    });

    test('価格なしは除外', () {
      expect(
        SearchResultQualityFilter.exclusionReason(
          _item(price: 0),
        ),
        SearchQualityExcludeReason.noPrice,
      );
    });

    test('商品URLなしは除外', () {
      expect(
        SearchResultQualityFilter.exclusionReason(
          _item(url: ''),
        ),
        SearchQualityExcludeReason.noUrl,
      );
    });

    test('プレースホルダ商品名は除外', () {
      expect(
        SearchResultQualityFilter.exclusionReason(
          _item(name: '（商品名なし）'),
        ),
        SearchQualityExcludeReason.noName,
      );
    });

    test('大人のおもちゃは安全フィルタで除外', () {
      expect(
        SearchResultQualityFilter.exclusionReason(
          _item(name: '大人のおもちゃ 初心者向け'),
        ),
        SearchQualityExcludeReason.safety,
      );
    });

    test('木のおもちゃは通す', () {
      expect(
        SearchResultQualityFilter.passesDisplayQuality(
          _item(name: '木のおもちゃ 積み木'),
        ),
        isTrue,
      );
    });
  });
}
