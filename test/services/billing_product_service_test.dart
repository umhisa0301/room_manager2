import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:room_manager2/config/billing_product_config.dart';
import 'package:room_manager2/services/billing_product_service.dart';

class _FakeInAppPurchaseGateway implements InAppPurchaseGateway {
  _FakeInAppPurchaseGateway({
    this.available = true,
    this.response,
    this.throwOnQuery = false,
  });

  final bool available;
  final ProductDetailsResponse? response;
  final bool throwOnQuery;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> productIds) async {
    if (throwOnQuery) {
      throw StateError('query failed');
    }
    return response ??
        ProductDetailsResponse(
          productDetails: const [],
          notFoundIDs: productIds.toList(growable: false),
        );
  }
}

ProductDetails _fakeProductDetails({
  required String id,
  String price = '¥500',
  double rawPrice = 500,
}) {
  return ProductDetails(
    id: id,
    title: 'Test $id',
    description: 'Test description',
    price: price,
    rawPrice: rawPrice,
    currencyCode: 'JPY',
  );
}

void main() {
  group('BillingProductService', () {
    test('queryProducts returns unavailable when store is not available', () async {
      final service = BillingProductService(
        gateway: _FakeInAppPurchaseGateway(available: false),
      );

      final result = await service.queryProducts();

      expect(result.available, isFalse);
      expect(result.basic, isNull);
      expect(result.pro, isNull);
      expect(result.notFoundIds, isEmpty);
    });

    test('queryProducts maps basic and pro products', () async {
      final service = BillingProductService(
        gateway: _FakeInAppPurchaseGateway(
          response: ProductDetailsResponse(
            productDetails: [
              _fakeProductDetails(
                id: BillingProductConfig.basicMonthlyProductId,
                price: '¥500',
                rawPrice: 500,
              ),
              _fakeProductDetails(
                id: BillingProductConfig.proMonthlyProductId,
                price: '¥900',
                rawPrice: 900,
              ),
            ],
            notFoundIDs: const [],
          ),
        ),
      );

      final result = await service.queryProducts();

      expect(result.available, isTrue);
      expect(result.basic?.price, '¥500');
      expect(result.basic?.productId, BillingProductConfig.basicMonthlyProductId);
      expect(result.pro?.price, '¥900');
      expect(result.pro?.productId, BillingProductConfig.proMonthlyProductId);
      expect(result.notFoundIds, isEmpty);
    });

    test('queryProducts keeps notFoundIds without crashing', () async {
      final service = BillingProductService(
        gateway: _FakeInAppPurchaseGateway(
          response: ProductDetailsResponse(
            productDetails: const [],
            notFoundIDs: BillingProductConfig.allProductIds,
          ),
        ),
      );

      final result = await service.queryProducts();

      expect(result.available, isTrue);
      expect(result.basic, isNull);
      expect(result.pro, isNull);
      expect(result.notFoundIds, BillingProductConfig.allProductIds);
    });

    test('queryProducts returns unavailable on exception', () async {
      final service = BillingProductService(
        gateway: _FakeInAppPurchaseGateway(throwOnQuery: true),
      );

      final result = await service.queryProducts();

      expect(result.available, isFalse);
      expect(result.basic, isNull);
      expect(result.pro, isNull);
    });
  });

  group('BillingProductQueryResult.fromProducts', () {
    test('assigns basic and pro by product id', () {
      final result = BillingProductQueryResult.fromProducts(
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
        notFoundIds: [BillingProductConfig.proMonthlyProductId],
      );

      expect(result.basic?.price, '¥500');
      expect(result.pro, isNull);
      expect(result.notFoundIds, [BillingProductConfig.proMonthlyProductId]);
    });
  });
}
