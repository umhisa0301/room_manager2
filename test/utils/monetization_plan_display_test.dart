import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/billing_product_config.dart';
import 'package:room_manager2/services/billing_product_service.dart';
import 'package:room_manager2/utils/monetization_plan_display.dart';

void main() {
  group('resolveBasicPlanPriceDisplay', () {
    test('returns loading label while querying', () {
      final display = resolveBasicPlanPriceDisplay(isLoading: true);

      expect(display.source, MonetizationPlanPriceSource.loading);
      expect(display.label, MonetizationPlanDisplayCopy.basicPriceLoadingLabel);
      expect(display.showPlannedSuffix, isFalse);
    });

    test('uses store price when basic product is available', () {
      final display = resolveBasicPlanPriceDisplay(
        isLoading: false,
        queryResult: BillingProductQueryResult.fromProducts(
          products: [
            BillingProductDetails(
              productId: BillingProductConfig.basicMonthlyProductId,
              title: 'Basic',
              description: 'desc',
              price: '¥500',
              rawPrice: 500,
              currencyCode: 'JPY',
            ),
          ],
        ),
      );

      expect(display.source, MonetizationPlanPriceSource.store);
      expect(display.label, '¥500');
      expect(display.useStorePriceFormat, isTrue);
      expect(display.showPlannedSuffix, isFalse);
    });

    test('falls back to planned price when basic is missing', () {
      final display = resolveBasicPlanPriceDisplay(
        isLoading: false,
        queryResult: BillingProductQueryResult.fromProducts(
          products: const [],
          notFoundIds: BillingProductConfig.allProductIds,
        ),
      );

      expect(display.source, MonetizationPlanPriceSource.planned);
      expect(display.label, MonetizationPlanDisplayCopy.basicPriceAmount);
      expect(display.showPlannedSuffix, isTrue);
    });
  });

  group('resolveProPlanPriceLabel', () {
    test('uses store price when pro product is available', () {
      final label = resolveProPlanPriceLabel(
        isLoading: false,
        queryResult: BillingProductQueryResult.fromProducts(
          products: [
            BillingProductDetails(
              productId: BillingProductConfig.proMonthlyProductId,
              title: 'Pro',
              description: 'desc',
              price: '¥900',
              rawPrice: 900,
              currencyCode: 'JPY',
            ),
          ],
        ),
      );

      expect(label, '¥900');
    });

    test('falls back to planned label when pro is missing', () {
      final label = resolveProPlanPriceLabel(
        isLoading: false,
        queryResult: createPlannedFallbackBillingQueryResult(),
      );

      expect(label, MonetizationPlanDisplayCopy.proPlannedMonthlyPriceLabel);
    });
  });

  group('resolveBillingStatusMessage', () {
    test('returns checking message while loading', () {
      expect(
        resolveBillingStatusMessage(isLoading: true),
        MonetizationPlanDisplayCopy.billingStatusChecking,
      );
    });

    test('returns fetch failed when store unavailable', () {
      expect(
        resolveBillingStatusMessage(
          isLoading: false,
          queryResult: BillingProductQueryResult.unavailable(),
        ),
        MonetizationPlanDisplayCopy.billingStatusFetchFailed,
      );
    });

    test('returns null when at least one product is found', () {
      expect(
        resolveBillingStatusMessage(
          isLoading: false,
          queryResult: BillingProductQueryResult.fromProducts(
            products: [
              BillingProductDetails(
                productId: BillingProductConfig.basicMonthlyProductId,
                title: 'Basic',
                description: 'desc',
                price: '¥500',
                rawPrice: 500,
                currencyCode: 'JPY',
              ),
            ],
          ),
        ),
        isNull,
      );
    });
  });
}
