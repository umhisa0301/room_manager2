import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/billing_product_config.dart';

void main() {
  group('BillingProductConfig', () {
    test('basicMonthlyProductId has expected value', () {
      expect(
        BillingProductConfig.basicMonthlyProductId,
        'room_manager_basic_monthly',
      );
    });

    test('proMonthlyProductId has expected value', () {
      expect(
        BillingProductConfig.proMonthlyProductId,
        'room_manager_pro_monthly',
      );
    });

    test('allProductIds contains both product IDs', () {
      expect(BillingProductConfig.allProductIds, hasLength(2));
      expect(
        BillingProductConfig.allProductIds,
        containsAll([
          BillingProductConfig.basicMonthlyProductId,
          BillingProductConfig.proMonthlyProductId,
        ]),
      );
    });

    test('product IDs are distinct', () {
      expect(
        BillingProductConfig.basicMonthlyProductId,
        isNot(BillingProductConfig.proMonthlyProductId),
      );
    });
  });
}
