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

    test('おとなのおもちゃは除外', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: 'おとなのおもちゃ'),
        isTrue,
      );
    });

    test('sex toy は除外', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: 'sex toy set'),
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

    test('ビール10本セットは除外', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: 'ビール10本セット'),
        isTrue,
      );
      expect(
        ProductSafetyFilter.primaryLogReason(
          ProductSafetyFilter.blockedReasons(itemName: 'ビール10本セット'),
        ),
        'alcohol',
      );
    });

    test('名入れワインは除外', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: '名入れワイン ギフト'),
        isTrue,
      );
    });

    test('シャンパングラスは通す', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: 'シャンパングラス 2個セット'),
        isFalse,
      );
    });

    test('ワイングラスは通す', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: 'ワイングラス ペア'),
        isFalse,
      );
    });

    test('子供服は通す', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(
          itemName: '子供服 トレーナー',
          genreName: 'キッズファッション',
        ),
        isFalse,
      );
    });

    test('アダルトグッズは除外', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: 'アダルトグッズ'),
        isTrue,
      );
    });

    test('グラビア写真集は除外', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(itemName: 'グラビア写真集'),
        isTrue,
      );
    });

    test('ジャンル名がビール・洋酒なら除外', () {
      expect(
        ProductSafetyFilter.isBlockedProduct(
          itemName: 'おすすめセット',
          genreName: 'ビール・洋酒',
        ),
        isTrue,
      );
    });
  });
}
