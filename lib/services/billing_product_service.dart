import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/billing_product_config.dart';

/// Google Play Billing から取得した商品情報（アプリ内モデル）。
class BillingProductDetails {
  const BillingProductDetails({
    required this.productId,
    required this.title,
    required this.description,
    required this.price,
    required this.rawPrice,
    required this.currencyCode,
    this.available = true,
  });

  final String productId;
  final String title;
  final String description;

  /// ローカライズ済みの表示用価格（例: ¥500）。
  final String price;
  final double rawPrice;
  final String currencyCode;
  final bool available;

  factory BillingProductDetails.fromStoreProduct(ProductDetails details) {
    return BillingProductDetails(
      productId: details.id,
      title: details.title,
      description: details.description,
      price: details.price,
      rawPrice: details.rawPrice,
      currencyCode: details.currencyCode,
    );
  }
}

/// 商品照会の結果。画面側が安全に扱えるよう常に完結した値を返す。
class BillingProductQueryResult {
  const BillingProductQueryResult({
    required this.available,
    this.basic,
    this.pro,
    this.notFoundIds = const [],
    this.errorMessage,
  });

  /// Billing（in_app_purchase）が利用可能だったか。
  final bool available;
  final BillingProductDetails? basic;
  final BillingProductDetails? pro;
  final List<String> notFoundIds;
  final String? errorMessage;

  factory BillingProductQueryResult.unavailable() {
    return const BillingProductQueryResult(
      available: false,
      notFoundIds: [],
    );
  }

  factory BillingProductQueryResult.fromProducts({
    required List<BillingProductDetails> products,
    List<String> notFoundIds = const [],
    String? errorMessage,
  }) {
    BillingProductDetails? basic;
    BillingProductDetails? pro;
    for (final product in products) {
      if (product.productId == BillingProductConfig.basicMonthlyProductId) {
        basic = product;
      } else if (product.productId == BillingProductConfig.proMonthlyProductId) {
        pro = product;
      }
    }
    return BillingProductQueryResult(
      available: true,
      basic: basic,
      pro: pro,
      notFoundIds: List.unmodifiable(notFoundIds),
      errorMessage: errorMessage,
    );
  }
}

/// in_app_purchase 依存を薄くラップするゲートウェイ（テスト差し替え用）。
abstract class InAppPurchaseGateway {
  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> productIds);
}

class DefaultInAppPurchaseGateway implements InAppPurchaseGateway {
  DefaultInAppPurchaseGateway([InAppPurchase? instance])
      : _instance = instance ?? InAppPurchase.instance;

  final InAppPurchase _instance;

  @override
  Future<bool> isAvailable() => _instance.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> productIds) {
    return _instance.queryProductDetails(productIds);
  }
}

/// Billing 商品情報の照会サービス（購入処理は行わない）。
class BillingProductService {
  BillingProductService({InAppPurchaseGateway? gateway})
      : _gateway = gateway ?? DefaultInAppPurchaseGateway();

  final InAppPurchaseGateway _gateway;

  /// [BillingProductConfig.allProductIds] を照会し、結果を返す。
  Future<BillingProductQueryResult> queryProducts() async {
    if (kDebugMode) {
      debugPrint('[BILLING_PRODUCT] query started');
    }

    try {
      final storeAvailable = await _gateway.isAvailable();
      if (!storeAvailable) {
        if (kDebugMode) {
          debugPrint('[BILLING_PRODUCT] query unavailable');
        }
        return BillingProductQueryResult.unavailable();
      }

      final response = await _gateway.queryProductDetails(
        BillingProductConfig.allProductIds.toSet(),
      );

      final products = response.productDetails
          .map(BillingProductDetails.fromStoreProduct)
          .toList(growable: false);

      if (kDebugMode) {
        debugPrint(
          '[BILLING_PRODUCT] query completed found=${products.length} notFound=${response.notFoundIDs.length} available=true',
        );
        if (response.error != null) {
          debugPrint('[BILLING_PRODUCT] query store error present');
        }
      }

      return BillingProductQueryResult.fromProducts(
        products: products,
        notFoundIds: response.notFoundIDs,
        errorMessage: response.error?.message,
      );
    } catch (_) {
      if (kDebugMode) {
        debugPrint('[BILLING_PRODUCT] query failed');
      }
      return BillingProductQueryResult.unavailable();
    }
  }
}
