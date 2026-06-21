import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/billing_product_config.dart';
import 'billing_product_service.dart';
import 'subscription_entitlement_store.dart';
import 'subscription_status.dart';

/// 購入アクションの結果ステータス。
enum PurchaseActionStatus {
  started,
  success,
  canceled,
  error,
  unavailable,
  productNotFound,
}

/// 購入 / 復元アクションの結果。
class PurchaseActionResult {
  const PurchaseActionResult({
    required this.status,
    this.message,
  });

  final PurchaseActionStatus status;
  final String? message;

  bool get isSuccess => status == PurchaseActionStatus.success;
}

/// 購入サービスの公開状態。
class PurchaseState {
  const PurchaseState({
    required this.isAvailable,
    required this.isLoading,
    required this.isPurchasing,
    required this.isRestoring,
    required this.entitlement,
    this.latestErrorMessage,
    this.pendingPurchase,
    this.lastUpdatedAt,
    this.lastUserMessage,
  });

  final bool isAvailable;
  final bool isLoading;
  final bool isPurchasing;
  final bool isRestoring;
  final PurchaseEntitlement entitlement;
  final String? latestErrorMessage;
  final PurchaseDetails? pendingPurchase;
  final DateTime? lastUpdatedAt;
  final String? lastUserMessage;

  factory PurchaseState.initial() {
    return const PurchaseState(
      isAvailable: false,
      isLoading: true,
      isPurchasing: false,
      isRestoring: false,
      entitlement: PurchaseEntitlement.none(),
    );
  }
}

/// in_app_purchase の購入系 API をラップするゲートウェイ（テスト差し替え用）。
abstract class InAppPurchasePurchaseGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> productIds);

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});

  Future<void> restorePurchases();

  Future<void> completePurchase(PurchaseDetails purchaseDetails);
}

class DefaultInAppPurchasePurchaseGateway implements InAppPurchasePurchaseGateway {
  DefaultInAppPurchasePurchaseGateway([InAppPurchase? instance])
      : _instance = instance ?? InAppPurchase.instance;

  final InAppPurchase _instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _instance.purchaseStream;

  @override
  Future<bool> isAvailable() => _instance.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> productIds) {
    return _instance.queryProductDetails(productIds);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) {
    return _instance.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<void> restorePurchases() => _instance.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchaseDetails) {
    return _instance.completePurchase(purchaseDetails);
  }
}

/// Basic プランの購入・復元を管理するサービス。
class BillingPurchaseService extends ChangeNotifier {
  BillingPurchaseService({
    InAppPurchasePurchaseGateway? gateway,
    SubscriptionEntitlementStore? entitlementStore,
  })  : _gateway = gateway ?? DefaultInAppPurchasePurchaseGateway(),
        _entitlementStore = entitlementStore;

  static const Duration _restoreIdleTimeout = Duration(seconds: 5);
  static const String entitlementSource = 'google_play_billing';

  final InAppPurchasePurchaseGateway _gateway;
  SubscriptionEntitlementStore? _entitlementStore;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _purchaseStreamAttached = false;
  bool _initialized = false;
  bool _restoreAwaitingUpdates = false;
  bool _restoreReceivedBasic = false;
  Timer? _restoreIdleTimer;

  bool _isAvailable = false;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  PurchaseEntitlement _entitlement = const PurchaseEntitlement.none();
  String? _latestErrorMessage;
  PurchaseDetails? _pendingPurchase;
  DateTime? _lastUpdatedAt;
  String? _lastUserMessage;

  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  bool get isPurchasing => _isPurchasing;
  bool get isRestoring => _isRestoring;
  PurchaseEntitlement get entitlement => _entitlement;
  String? get latestErrorMessage => _latestErrorMessage;
  PurchaseDetails? get pendingPurchase => _pendingPurchase;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  String? get lastUserMessage => _lastUserMessage;

  PurchaseState get state => PurchaseState(
        isAvailable: _isAvailable,
        isLoading: _isLoading,
        isPurchasing: _isPurchasing,
        isRestoring: _isRestoring,
        entitlement: _entitlement,
        latestErrorMessage: _latestErrorMessage,
        pendingPurchase: _pendingPurchase,
        lastUpdatedAt: _lastUpdatedAt,
        lastUserMessage: _lastUserMessage,
      );

  /// 起動時初期化。purchaseStream の購読を1回だけ張る。
  Future<void> initialize({SubscriptionEntitlementStore? entitlementStore}) async {
    if (_initialized) return;
    _entitlementStore = entitlementStore ?? _entitlementStore;

    if (_entitlementStore != null) {
      await _entitlementStore!.load();
      _entitlement = _entitlementStore!.entitlement;
      if (_entitlement.isActive) {
        _lastUpdatedAt = DateTime.now().toUtc();
      }
    }

    _attachPurchaseStreamListener();

    try {
      _isAvailable = await _gateway.isAvailable();
    } catch (_) {
      _isAvailable = false;
    }

    _isLoading = false;
    _initialized = true;
    notifyListeners();

    if (kDebugMode) {
      debugPrint(
        '[BILLING_PURCHASE] initialized available=$_isAvailable active=${_entitlement.isActive}',
      );
    }
  }

  void _attachPurchaseStreamListener() {
    if (_purchaseStreamAttached) return;
    _purchaseSubscription = _gateway.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: _onPurchaseStreamError,
    );
    _purchaseStreamAttached = true;
  }

  void _onPurchaseStreamError(Object error) {
    if (kDebugMode) {
      debugPrint('[BILLING_PURCHASE] purchase stream error');
    }
    _latestErrorMessage = 'purchase_stream_error';
    if (_isPurchasing || _isRestoring) {
      _finishPurchaseFlow(
        userMessage: '購入処理を完了できませんでした',
      );
      _finishRestoreFlow(restoredBasic: false);
    }
    notifyListeners();
  }

  /// Basic 商品の購入フローを開始する。
  Future<PurchaseActionResult> purchaseBasic({
    BillingProductDetails? basicProduct,
  }) async {
    _lastUserMessage = null;

    if (!_isAvailable) {
      return const PurchaseActionResult(
        status: PurchaseActionStatus.unavailable,
        message: 'store_unavailable',
      );
    }

    if (basicProduct == null || !basicProduct.available) {
      return const PurchaseActionResult(
        status: PurchaseActionStatus.productNotFound,
        message: 'basic_product_not_found',
      );
    }

    if (basicProduct.productId != BillingProductConfig.basicMonthlyProductId) {
      return const PurchaseActionResult(
        status: PurchaseActionStatus.productNotFound,
        message: 'not_basic_product',
      );
    }

    if (_isPurchasing || _isRestoring) {
      return const PurchaseActionResult(
        status: PurchaseActionStatus.unavailable,
        message: 'purchase_in_progress',
      );
    }

    ProductDetails? storeProduct;
    try {
      final response = await _gateway.queryProductDetails(
        {BillingProductConfig.basicMonthlyProductId},
      );
      if (response.productDetails.isEmpty) {
        return const PurchaseActionResult(
          status: PurchaseActionStatus.productNotFound,
          message: 'basic_product_not_found',
        );
      }
      storeProduct = response.productDetails.first;
    } catch (_) {
      return const PurchaseActionResult(
        status: PurchaseActionStatus.error,
        message: 'product_query_failed',
      );
    }

    _isPurchasing = true;
    _latestErrorMessage = null;
    notifyListeners();

    if (kDebugMode) {
      debugPrint('[BILLING_PURCHASE] purchase started');
    }

    try {
      final started = await _gateway.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: storeProduct),
      );
      if (!started) {
        _isPurchasing = false;
        notifyListeners();
        return const PurchaseActionResult(
          status: PurchaseActionStatus.error,
          message: 'purchase_not_started',
        );
      }
      return const PurchaseActionResult(status: PurchaseActionStatus.started);
    } catch (_) {
      _isPurchasing = false;
      _latestErrorMessage = 'purchase_start_failed';
      notifyListeners();
      return const PurchaseActionResult(
        status: PurchaseActionStatus.error,
        message: 'purchase_start_failed',
      );
    }
  }

  /// 購入を復元する。
  Future<PurchaseActionResult> restorePurchases() async {
    _lastUserMessage = null;

    if (!_isAvailable) {
      return const PurchaseActionResult(
        status: PurchaseActionStatus.unavailable,
        message: 'store_unavailable',
      );
    }

    if (_isPurchasing || _isRestoring) {
      return const PurchaseActionResult(
        status: PurchaseActionStatus.unavailable,
        message: 'restore_in_progress',
      );
    }

    _isRestoring = true;
    _restoreAwaitingUpdates = true;
    _restoreReceivedBasic = false;
    _latestErrorMessage = null;
    notifyListeners();

    if (kDebugMode) {
      debugPrint('[BILLING_PURCHASE] restore started');
    }

    _restoreIdleTimer?.cancel();
    _restoreIdleTimer = Timer(_restoreIdleTimeout, _onRestoreIdleTimeout);

    try {
      await _gateway.restorePurchases();
      return const PurchaseActionResult(status: PurchaseActionStatus.started);
    } catch (_) {
      _finishRestoreFlow(restoredBasic: false);
      _latestErrorMessage = 'restore_failed';
      _lastUserMessage = '購入処理を完了できませんでした';
      notifyListeners();
      return const PurchaseActionResult(
        status: PurchaseActionStatus.error,
        message: 'restore_failed',
      );
    }
  }

  void _onRestoreIdleTimeout() {
    if (!_restoreAwaitingUpdates) return;
    _finishRestoreFlow(restoredBasic: _restoreReceivedBasic);
    if (!_restoreReceivedBasic) {
      _lastUserMessage = '復元できる購入はありませんでした';
    }
    notifyListeners();
  }

  void _finishRestoreFlow({required bool restoredBasic}) {
    _restoreIdleTimer?.cancel();
    _restoreIdleTimer = null;
    _restoreAwaitingUpdates = false;
    _isRestoring = false;
    if (restoredBasic) {
      _lastUserMessage = null;
    }
  }

  void _finishPurchaseFlow({String? userMessage}) {
    _isPurchasing = false;
    _pendingPurchase = null;
    if (userMessage != null) {
      _lastUserMessage = userMessage;
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      await _handlePurchaseDetails(purchase);
    }
  }

  @visibleForTesting
  Future<void> handlePurchaseDetailsForTest(PurchaseDetails purchase) {
    return _handlePurchaseDetails(purchase);
  }

  Future<void> _handlePurchaseDetails(PurchaseDetails purchase) async {
    if (!_isBasicProduct(purchase.productID)) {
      if (purchase.pendingCompletePurchase) {
        await _safeCompletePurchase(purchase);
      }
      return;
    }

    switch (purchase.status) {
      case PurchaseStatus.pending:
        _pendingPurchase = purchase;
        if (kDebugMode) {
          debugPrint('[BILLING_PURCHASE] status=pending');
        }
        notifyListeners();
        return;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final entitlement = entitlementFromBasicPurchase(purchase);
        if (entitlement != null) {
          await _applyBasicEntitlement(entitlement);
          if (purchase.status == PurchaseStatus.restored) {
            _restoreReceivedBasic = true;
            if (_restoreAwaitingUpdates) {
              _finishRestoreFlow(restoredBasic: true);
            }
          } else {
            _lastUserMessage = null;
          }
          _finishPurchaseFlow();
        }
        if (purchase.pendingCompletePurchase) {
          await _safeCompletePurchase(purchase);
        }
        notifyListeners();
        return;

      case PurchaseStatus.canceled:
        if (kDebugMode) {
          debugPrint('[BILLING_PURCHASE] status=canceled');
        }
        _finishPurchaseFlow(userMessage: '購入はキャンセルされました');
        _finishRestoreFlow(restoredBasic: false);
        if (purchase.pendingCompletePurchase) {
          await _safeCompletePurchase(purchase);
        }
        notifyListeners();
        return;

      case PurchaseStatus.error:
        if (kDebugMode) {
          debugPrint('[BILLING_PURCHASE] status=error');
        }
        _latestErrorMessage = purchase.error?.message ?? 'purchase_error';
        _finishPurchaseFlow(userMessage: '購入処理を完了できませんでした');
        _finishRestoreFlow(restoredBasic: false);
        if (purchase.pendingCompletePurchase) {
          await _safeCompletePurchase(purchase);
        }
        notifyListeners();
        return;
    }
  }

  Future<void> _applyBasicEntitlement(PurchaseEntitlement entitlement) async {
    _entitlement = entitlement;
    _lastUpdatedAt = DateTime.now().toUtc();
    await _entitlementStore?.save(entitlement);
    if (kDebugMode) {
      debugPrint('[BILLING_PURCHASE] basic entitlement applied');
    }
  }

  Future<void> _safeCompletePurchase(PurchaseDetails purchase) async {
    try {
      await _gateway.completePurchase(purchase);
      if (kDebugMode) {
        debugPrint('[BILLING_PURCHASE] completePurchase called');
      }
    } catch (_) {
      if (kDebugMode) {
        debugPrint('[BILLING_PURCHASE] completePurchase failed');
      }
    }
  }

  @override
  void dispose() {
    _restoreIdleTimer?.cancel();
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _purchaseStreamAttached = false;
    super.dispose();
  }
}

/// Basic 商品の [PurchaseDetails] から [PurchaseEntitlement] を生成する。
///
/// purchased / restored かつ Basic 商品 ID の場合のみ Basic entitlement を返す。
PurchaseEntitlement? entitlementFromBasicPurchase(PurchaseDetails purchase) {
  if (!_isBasicProduct(purchase.productID)) {
    return null;
  }

  if (purchase.status != PurchaseStatus.purchased &&
      purchase.status != PurchaseStatus.restored) {
    return null;
  }

  return const PurchaseEntitlement(
    status: SubscriptionStatus.basicActive,
    source: BillingPurchaseService.entitlementSource,
  );
}

bool _isBasicProduct(String productId) {
  return productId == BillingProductConfig.basicMonthlyProductId;
}
