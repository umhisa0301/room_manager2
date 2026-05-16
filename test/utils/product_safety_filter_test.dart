import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/product_safety_filter.dart';

void main() {
  group('ProductSafetyFilter', () {
    test('木のおもちゃは通す', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: '木のおもちゃ 積み木'),
        isFalse,
      );
    });

    test('大人のオモチャは除外', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: '大人のオモチャ 初心者向け'),
        isTrue,
      );
      expect(
        ProductSafetyFilter.blockedReasons(itemName: '大人のオモチャ')
            .contains(ProductSafetyBlockReason.adultKeyword),
        isTrue,
      );
    });

    test('オトナのおもちゃは除外', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: 'オトナのおもちゃ'),
        isTrue,
      );
    });

    test('BLCDコレクションは除外', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(
          itemName: 'BLCDコレクション 人気作品',
          genreName: 'CD・DVD',
        ),
        isTrue,
      );
    });

    test('濡れトロは除外', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: '濡れトロ 小説'),
        isTrue,
      );
    });

    test('おもちゃ/宮本真希[DVD]は adultKeyword がなければ通す', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(
          itemName: 'おもちゃ/宮本真希[DVD]',
        ),
        isFalse,
      );
    });

    test('ベビー おもちゃは通す', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: 'ベビー おもちゃ ラトル'),
        isFalse,
      );
    });
  });
}
