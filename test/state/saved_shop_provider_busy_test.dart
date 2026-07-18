import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/saved_shop.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GatedSavedShopRepository extends SavedShopRepository {
  _GatedSavedShopRepository(super.prefs);

  Completer<void>? gate;
  bool holdNextSave = false;

  @override
  Future<void> saveAll(List<SavedShop> shops) async {
    if (holdNextSave) {
      holdNextSave = false;
      final pending = gate;
      if (pending != null) {
        await pending.future;
      }
    }
    await super.saveAll(shops);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _GatedSavedShopRepository repository;
  late SavedShopProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = _GatedSavedShopRepository(prefs);
    provider = SavedShopProvider(repository: repository);
  });

  test('same shop cannot be saved twice while busy', () async {
    repository.gate = Completer<void>();
    repository.holdNextSave = true;

    final first = provider.upsertShop(
      shopId: 'shop-a',
      shopName: 'A店',
      shopUrl: 'https://www.rakuten.co.jp/shop-a/',
    );
    await Future<void>.delayed(Duration.zero);
    expect(provider.isShopBusy('shop-a'), isTrue);

    final second = await provider.upsertShop(
      shopId: 'shop-a',
      shopName: 'A店',
      shopUrl: 'https://www.rakuten.co.jp/shop-a/',
    );
    expect(second, isFalse);

    repository.gate!.complete();
    final firstOk = await first;
    expect(firstOk, isTrue);
    expect(provider.isShopBusy('shop-a'), isFalse);
    expect(provider.isSaved('shop-a'), isTrue);
  });

  test('different shop remains operable while another is busy', () async {
    repository.gate = Completer<void>();
    repository.holdNextSave = true;

    final first = provider.upsertShop(
      shopId: 'shop-a',
      shopName: 'A店',
      shopUrl: 'https://www.rakuten.co.jp/shop-a/',
    );
    await Future<void>.delayed(Duration.zero);
    expect(provider.isShopBusy('shop-a'), isTrue);
    expect(provider.isShopBusy('shop-b'), isFalse);

    // holdNextSave は1回限りなので、別ショップの save は待たされない。
    final other = await provider.upsertShop(
      shopId: 'shop-b',
      shopName: 'B店',
      shopUrl: 'https://www.rakuten.co.jp/shop-b/',
    );
    expect(other, isTrue);
    expect(provider.isSaved('shop-b'), isTrue);
    expect(provider.isShopBusy('shop-a'), isTrue);

    repository.gate!.complete();
    await first;
    expect(provider.isShopBusy('shop-a'), isFalse);
    expect(provider.isSaved('shop-a'), isTrue);
    expect(provider.isSaved('shop-b'), isTrue);
  });

  test('failed busy shop can be retried after completion', () async {
    await provider.upsertShop(
      shopId: 'shop-a',
      shopName: 'A店',
      shopUrl: 'https://www.rakuten.co.jp/shop-a/',
    );
    expect(provider.isSaved('shop-a'), isTrue);

    repository.gate = Completer<void>();
    repository.holdNextSave = true;
    final removing = provider.removeShop('shop-a');
    await Future<void>.delayed(Duration.zero);
    expect(provider.isShopBusy('shop-a'), isTrue);

    final blocked = await provider.removeShop('shop-a');
    expect(blocked, isFalse);

    repository.gate!.complete();
    expect(await removing, isTrue);
    expect(provider.isSaved('shop-a'), isFalse);
    expect(provider.isShopBusy('shop-a'), isFalse);

    final again = await provider.upsertShop(
      shopId: 'shop-a',
      shopName: 'A店',
      shopUrl: 'https://www.rakuten.co.jp/shop-a/',
    );
    expect(again, isTrue);
    expect(provider.isSaved('shop-a'), isTrue);
  });
}
