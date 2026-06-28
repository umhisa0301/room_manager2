import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/product_price_display.dart';
import 'package:room_manager2/widgets/room_colle_product_list_card_layout.dart';

void main() {
  group('ProductPriceDisplay.formatYen', () {
    test('1980 → ￥1,980', () {
      expect(ProductPriceDisplay.formatYen(1980), '￥1,980');
    });

    test('0 → ￥ー', () {
      expect(ProductPriceDisplay.formatYen(0), '￥ー');
    });

    test('-1 → ￥ー', () {
      expect(ProductPriceDisplay.formatYen(-1), '￥ー');
    });

    test('null → ￥ー', () {
      expect(ProductPriceDisplay.formatYen(null), '￥ー');
    });
  });

  group('RoomColleProductListCardLayout.formatPriceYen', () {
    test('delegates to ProductPriceDisplay', () {
      expect(RoomColleProductListCardLayout.formatPriceYen(1980), '￥1,980');
      expect(RoomColleProductListCardLayout.formatPriceYen(0), '￥ー');
    });
  });
}
