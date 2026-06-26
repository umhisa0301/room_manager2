import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:room_manager2/config/billing_product_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/services/billing_product_service.dart';
import 'package:room_manager2/services/billing_purchase_service.dart';
import 'package:room_manager2/services/subscription_entitlement_store.dart';
import 'package:room_manager2/services/subscription_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePurchaseGateway implements InAppPurchasePurchaseGateway {
  _FakePurchaseGateway({
    this.available = true,
    this.productDetails = const [],
    this.buyNonConsumableResult = true,
    this.throwOnRestore = false,
  });

  final bool available;
  final List<ProductDetails> productDetails;
  final bool buyNonConsumableResult;
  final bool throwOnRestore;

  final StreamController<List<PurchaseDetails>> _purchaseStreamController =
      StreamController<List<PurchaseDetails>>.broadcast();

  int buyNonConsumableCallCount = 0;
  int completePurchaseCallCount = 0;
  PurchaseParam? lastPurchaseParam;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseStreamController.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> productIds,
  ) async {
    return ProductDetailsResponse(
      productDetails: productDetails
          .where((details) => productIds.contains(details.id))
          .toList(growable: false),
      notFoundIDs: productIds
          .where((id) => !productDetails.any((details) => details.id == id))
          .toList(growable: false),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyNonConsumableCallCount += 1;
    lastPurchaseParam = purchaseParam;
    return buyNonConsumableResult;
  }

  @override
  Future<void> restorePurchases() async {
    if (throwOnRestore) {
      throw StateError('restore failed');
    }
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchaseDetails) async {
    completePurchaseCallCount += 1;
  }

  void emitPurchases(List<PurchaseDetails> purchases) {
    _purchaseStreamController.add(purchases);
  }

  Future<void> close() async {
    await _purchaseStreamController.close();
  }
}

ProductDetails _basicStoreProduct() {
  return ProductDetails(
    id: BillingProductConfig.basicMonthlyProductId,
    title: 'Basic',
    description: 'Basic monthly',
    price: '¥500',
    rawPrice: 500,
    currencyCode: 'JPY',
  );
}

BillingProductDetails _basicBillingProduct() {
  return BillingProductDetails(
    productId: BillingProductConfig.basicMonthlyProductId,
    title: 'Basic',
    description: 'Basic monthly',
    price: '¥500',
    rawPrice: 500,
    currencyCode: 'JPY',
  );
}

PurchaseDetails _purchaseDetails({
  required PurchaseStatus status,
  String productId = BillingProductConfig.basicMonthlyProductId,
  bool pendingCompletePurchase = false,
  String? errorMessage,
}) {
  final details = PurchaseDetails(
    productID: productId,
    purchaseID: 'test-purchase-id',
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'google_play',
    ),
    transactionDate: '2026-01-01',
    status: status,
  );
  details.pendingCompletePurchase = pendingCompletePurchase;
  if (errorMessage != null) {
    details.error = IAPError(
      source: 'google_play',
      code: 'error',
      message: errorMessage,
      details: const {},
    );
  }
  return details;
}

void main() {
  group('BillingPurchaseService', () {
    late _FakePurchaseGateway gateway;
    late SubscriptionEntitlementStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = SubscriptionEntitlementStore(prefs);
      gateway = _FakePurchaseGateway(productDetails: [_basicStoreProduct()]);
    });

    tearDown(() async {
      await gateway.close();
    });

    BillingPurchaseService createService() {
      return BillingPurchaseService(gateway: gateway, entitlementStore: store);
    }

    test('does not start purchase when basic product is missing', () async {
      final service = createService();
      await service.initialize();

      final result = await service.purchaseBasic();

      expect(result.status, PurchaseActionStatus.productNotFound);
      expect(gateway.buyNonConsumableCallCount, 0);
    });

    test(
      'starts purchase with buyNonConsumable when basic product exists',
      () async {
        final service = createService();
        await service.initialize();

        final result = await service.purchaseBasic(
          basicProduct: _basicBillingProduct(),
        );

        expect(result.status, PurchaseActionStatus.started);
        expect(gateway.buyNonConsumableCallCount, 1);
        expect(
          gateway.lastPurchaseParam?.productDetails.id,
          BillingProductConfig.basicMonthlyProductId,
        );
        expect(service.isPurchasing, isTrue);
      },
    );

    test('does not purchase pro product', () async {
      final service = createService();
      await service.initialize();

      final result = await service.purchaseBasic(
        basicProduct: BillingProductDetails(
          productId: BillingProductConfig.proMonthlyProductId,
          title: 'Pro',
          description: 'Pro monthly',
          price: '¥900',
          rawPrice: 900,
          currencyCode: 'JPY',
        ),
      );

      expect(result.status, PurchaseActionStatus.productNotFound);
      expect(gateway.buyNonConsumableCallCount, 0);
    });

    test('pending keeps purchasing state', () async {
      final service = createService();
      await service.initialize();
      unawaited(service.purchaseBasic(basicProduct: _basicBillingProduct()));

      gateway.emitPurchases([_purchaseDetails(status: PurchaseStatus.pending)]);
      await Future<void>.delayed(Duration.zero);

      expect(service.isPurchasing, isTrue);
      expect(service.pendingPurchase, isNotNull);
      expect(service.entitlement.isBasicActive, isFalse);
    });

    test('purchased applies basicActive entitlement and saves', () async {
      final service = createService();
      await service.initialize();

      await service.handlePurchaseDetailsForTest(
        _purchaseDetails(
          status: PurchaseStatus.purchased,
          pendingCompletePurchase: true,
        ),
      );

      expect(service.entitlement.isBasicActive, isTrue);
      expect(service.entitlement.adsRemoved, isTrue);
      expect(service.entitlement.resolvedPlan, MonetizationPlan.basic);
      expect(gateway.completePurchaseCallCount, 1);
      await store.load();
      expect(store.entitlement.isBasicActive, isTrue);
    });

    test('restored applies basicActive entitlement', () async {
      final service = createService();
      await service.initialize();

      await service.handlePurchaseDetailsForTest(
        _purchaseDetails(status: PurchaseStatus.restored),
      );

      expect(service.entitlement.isBasicActive, isTrue);
    });

    test('canceled does not activate basic', () async {
      final service = createService();
      await service.initialize();

      final purchaseFuture = service.purchaseBasic(
        basicProduct: _basicBillingProduct(),
      );
      await Future<void>.delayed(Duration.zero);
      await service.handlePurchaseDetailsForTest(
        _purchaseDetails(status: PurchaseStatus.canceled),
      );
      await purchaseFuture;

      expect(service.entitlement.isBasicActive, isFalse);
      expect(service.isPurchasing, isFalse);
      expect(service.lastUserMessage, '購入はキャンセルされました');
    });

    test('error does not activate basic', () async {
      final service = createService();
      await service.initialize();

      await service.handlePurchaseDetailsForTest(
        _purchaseDetails(status: PurchaseStatus.error, errorMessage: 'failed'),
      );

      expect(service.entitlement.isBasicActive, isFalse);
      expect(service.lastUserMessage, '購入処理を完了できませんでした');
    });

    test('ignores pro purchase details', () async {
      final service = createService();
      await service.initialize();

      await service.handlePurchaseDetailsForTest(
        _purchaseDetails(
          status: PurchaseStatus.purchased,
          productId: BillingProductConfig.proMonthlyProductId,
        ),
      );

      expect(service.entitlement.isBasicActive, isFalse);
    });

    test('restorePurchases sets restoring state', () async {
      final service = createService();
      await service.initialize();

      final result = await service.restorePurchases();

      expect(result.status, PurchaseActionStatus.started);
      expect(service.isRestoring, isTrue);
    });

    test('restore idle timeout shows nothing found message', () async {
      final service = BillingPurchaseService(
        gateway: gateway,
        entitlementStore: store,
      );
      await service.initialize();

      await service.restorePurchases();
      await Future<void>.delayed(const Duration(seconds: 6));

      expect(service.isRestoring, isFalse);
      expect(service.lastUserMessage, '復元できる購入はありませんでした');
    });

    test('attaches purchase stream only once', () async {
      final service = createService();
      await service.initialize();
      await service.initialize();

      gateway.emitPurchases([
        _purchaseDetails(status: PurchaseStatus.purchased),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(service.entitlement.isBasicActive, isTrue);
    });
  });

  group('entitlementFromBasicPurchase', () {
    test('returns basic entitlement for purchased basic product', () {
      final entitlement = entitlementFromBasicPurchase(
        _purchaseDetails(status: PurchaseStatus.purchased),
      );

      expect(entitlement?.status, SubscriptionStatus.basicActive);
      expect(entitlement?.source, BillingPurchaseService.entitlementSource);
    });

    test('returns null for canceled basic product', () {
      final entitlement = entitlementFromBasicPurchase(
        _purchaseDetails(status: PurchaseStatus.canceled),
      );

      expect(entitlement, isNull);
    });
  });
}
