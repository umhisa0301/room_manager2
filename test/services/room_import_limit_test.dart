import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/monetization_config.dart';
import 'package:room_manager2/config/monetization_plan_config.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';
import 'package:room_manager2/services/room_import_limit.dart';

MonetizationFlagSnapshot _limitsOnFlags() => resolveMonetizationFlags(
      monetizationEnabled: true,
      adsEnabled: false,
      subscriptionEnabled: true,
      freePlanLimitsEnabled: true,
      proPlanEnabled: true,
    );

MonetizationPlanContext _contextFor(
  MonetizationPlan plan,
  MonetizationFlagSnapshot flags,
) =>
    resolvePlanLimits(plan, flags);

RakutenManagedProduct _managedProduct({
  RakutenManagedProductStatus status = RakutenManagedProductStatus.candidate,
}) {
  final now = DateTime(2026, 6, 16);
  return RakutenManagedProduct(
    productId: 'pid_${status.name}_${now.microsecondsSinceEpoch}',
    itemName: 'item',
    itemPrice: 1000,
    itemUrl: 'https://example.com/item',
    imageUrl: 'https://example.com/img.jpg',
    shopName: 'shop',
    shopCode: 'shop',
    shopUrl: 'https://example.com/shop',
    genreId: '1',
    status: status,
    createdAt: now,
    updatedAt: now,
    addedAt: now,
    extractedUrl: '',
    extractionStatus: RakutenUrlExtractionStatus.notStarted,
    extractionErrorMessage: '',
  );
}

List<RakutenManagedProduct> _managedItems(int count) => List.generate(
      count,
      (i) => _managedProduct().copyWith(productId: 'pid_$i'),
    );

void main() {
  group('resolveRoomImportAvailability', () {
    final flags = _limitsOnFlags();

    test('FREE_PLAN_LIMITS_ENABLED=false allows regardless of count', () {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: true,
        adsEnabled: false,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: false,
        proPlanEnabled: true,
      );
      final state = resolveRoomImportAvailability(
        currentImportedCount: 10,
        planContext: _contextFor(MonetizationPlan.free, offFlags),
      );
      expect(state.allowed, isTrue);
      expect(state.limitsEnforcementEnabled, isFalse);
      expect(state.unlimited, isTrue);
      expect(state.reasonCode, isNull);
    });

    test('MONETIZATION_ENABLED=false allows regardless of count', () {
      final offFlags = resolveMonetizationFlags(
        monetizationEnabled: false,
        adsEnabled: true,
        subscriptionEnabled: true,
        freePlanLimitsEnabled: true,
        proPlanEnabled: true,
      );
      final state = resolveRoomImportAvailability(
        currentImportedCount: 10,
        planContext: _contextFor(MonetizationPlan.free, offFlags),
      );
      expect(state.allowed, isTrue);
      expect(state.limitsEnforcementEnabled, isFalse);
    });

    test('free + 0 items allows', () {
      final state = resolveRoomImportAvailability(
        currentImportedCount: 0,
        planContext: _contextFor(MonetizationPlan.free, flags),
      );
      expect(state.allowed, isTrue);
      expect(state.limit, 10);
      expect(state.unlimited, isFalse);
    });

    test('free + 9 items allows', () {
      final state = resolveRoomImportAvailability(
        currentImportedCount: 9,
        planContext: _contextFor(MonetizationPlan.free, flags),
      );
      expect(state.allowed, isTrue);
      expect(state.currentImportedCount, 9);
    });

    test('free + 10 items is not allowed', () {
      final state = resolveRoomImportAvailability(
        currentImportedCount: 10,
        planContext: _contextFor(MonetizationPlan.free, flags),
      );
      expect(state.allowed, isFalse);
      expect(state.reasonCode, 'room_import_limit_reached');
      expect(state.limit, 10);
    });

    test('basic + 10 items allows with unlimited', () {
      final state = resolveRoomImportAvailability(
        currentImportedCount: 10,
        planContext: _contextFor(MonetizationPlan.basic, flags),
      );
      expect(state.allowed, isTrue);
      expect(state.unlimited, isTrue);
      expect(state.limit, isNull);
    });

    test('pro + 10 items allows with unlimited', () {
      final state = resolveRoomImportAvailability(
        currentImportedCount: 10,
        planContext: _contextFor(MonetizationPlan.pro, flags),
      );
      expect(state.allowed, isTrue);
      expect(state.unlimited, isTrue);
    });
  });

  group('countManagedProductsForRoomImportLimit', () {
    test('counts candidate, done, and none-without-doneAt as managed', () {
      final items = [
        _managedProduct(status: RakutenManagedProductStatus.candidate),
        _managedProduct(status: RakutenManagedProductStatus.done),
        _managedProduct(status: RakutenManagedProductStatus.none),
      ];
      expect(countManagedProductsForRoomImportLimit(items), 3);
    });
  });

  group('resolveRoomImportBatchSize', () {
    final flags = _limitsOnFlags();

    test('free with 7 items leaves 3 batch slots', () {
      final state = resolveRoomImportAvailability(
        currentImportedCount: 7,
        planContext: _contextFor(MonetizationPlan.free, flags),
      );
      expect(resolveRoomImportBatchSize(state), 3);
    });

    test('free at limit returns 0', () {
      final state = resolveRoomImportAvailability(
        currentImportedCount: 10,
        planContext: _contextFor(MonetizationPlan.free, flags),
      );
      expect(resolveRoomImportBatchSize(state), 0);
    });

    test('basic returns pro batch limit', () {
      final state = resolveRoomImportAvailability(
        currentImportedCount: 100,
        planContext: _contextFor(MonetizationPlan.basic, flags),
      );
      expect(state.unlimited, isTrue);
      expect(resolveRoomImportBatchSize(state), 50);
    });
  });

  group('canRefreshRoomDataForManagedItems', () {
    test('returns false when free limit reached with limits on', () {
      expect(
        canRefreshRoomDataForManagedItems(
          items: _managedItems(10),
          flags: _limitsOnFlags(),
        ),
        isFalse,
      );
    });
  });

  group('user messages', () {
    test('blocked message mentions free limit and basic plan', () {
      expect(roomImportLimitBlockedMessage(), contains('10件まで'));
      expect(roomImportLimitBlockedMessage(), contains('Basicプラン'));
    });

    test('trial hint describes free trial limit', () {
      expect(roomImportLimitTrialHint(), contains('10件までお試し'));
    });

    test('usage hint shows current count for free plan', () {
      const state = RoomImportAvailabilityState(
        allowed: true,
        currentImportedCount: 3,
        limit: 10,
        unlimited: false,
        plan: MonetizationPlan.free,
        limitsEnforcementEnabled: true,
      );
      final hint = roomImportLimitUsageHint(state);
      expect(hint, contains('3 / 10件'));
    });
  });
}
