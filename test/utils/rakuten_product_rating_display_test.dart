import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/rakuten_product_rating_display.dart';

void main() {
  group('RakutenProductRatingDisplay.formatProductCardLabel', () {
    test('reviewAverage と reviewCount 両方あり', () {
      expect(
        RakutenProductRatingDisplay.formatProductCardLabel(
          reviewAverage: 4.52,
          reviewCount: 268,
        ),
        '評価 ★4.5（268件）',
      );
    });

    test('reviewAverage のみ', () {
      expect(
        RakutenProductRatingDisplay.formatProductCardLabel(
          reviewAverage: 4.2,
          reviewCount: 0,
        ),
        '評価 ★4.2',
      );
    });

    test('reviewCount のみ', () {
      expect(
        RakutenProductRatingDisplay.formatProductCardLabel(
          reviewAverage: 0,
          reviewCount: 12,
        ),
        'レビュー12件',
      );
    });

    test('どちらもない', () {
      expect(
        RakutenProductRatingDisplay.formatProductCardLabel(
          reviewAverage: 0,
          reviewCount: 0,
        ),
        '評価未取得',
      );
    });
  });
}
