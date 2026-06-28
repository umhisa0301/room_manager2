import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/repository/pending_collect_notice_repository.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/repository/room_activity_event_repository.dart';
import 'package:room_manager2/state/bulk_operation_state_controller.dart';
import 'package:room_manager2/state/rakuten_managed_product_provider.dart';
import 'package:room_manager2/state/room_activity_event_provider.dart';
import 'package:room_manager2/state/user_profile_provider.dart';
import 'package:room_manager2/repository/user_profile_repository.dart';
import 'package:room_manager2/theme/rakuten_search_screen_tokens.dart';
import 'package:room_manager2/widgets/rakuten_managed_product_card.dart';
import 'package:room_manager2/widgets/rakuten_search_result_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t = DateTime.parse('2024-06-01T12:00:00.000Z');

RakutenManagedProduct _managedProduct({
  int itemPrice = 1980,
  RakutenManagedProductStatus status = RakutenManagedProductStatus.candidate,
  String roomUrl = '',
  String extractedUrl = 'https://room.rakuten.co.jp/r/post/1',
}) {
  return RakutenManagedProduct(
    productId: 'shop:item001',
    itemName: 'テスト商品',
    itemPrice: itemPrice,
    itemUrl: 'https://item.rakuten.co.jp/shop/item001/',
    imageUrl: 'https://example.com/p.jpg',
    shopName: 'テストショップ',
    shopCode: 'shop',
    shopUrl: 'https://www.rakuten.co.jp/shop/',
    genreId: '100',
    genreName: 'ジャンル',
    status: status,
    createdAt: _t,
    updatedAt: _t,
    addedAt: _t,
    extractedUrl: extractedUrl,
    extractionStatus: RakutenUrlExtractionStatus.success,
    extractionErrorMessage: '',
    roomUrl: roomUrl,
  );
}

RakutenSearchItem _searchItem({int itemPrice = 1980}) {
  return RakutenSearchItem(
    productId: 'shop:item001',
    itemName: '検索商品',
    itemPrice: itemPrice,
    itemUrl: 'https://item.rakuten.co.jp/shop/item001/',
    affiliateUrl: '',
    imageUrl: 'https://example.com/p.jpg',
    shopName: 'テストショップ',
    shopCode: 'shop',
    shopUrl: 'https://www.rakuten.co.jp/shop/',
    genreId: '100',
    genreName: 'ジャンル',
    reviewCount: 10,
    reviewAverage: 4.5,
  );
}

Widget _wrapManagedCard({
  required Widget child,
  required SharedPreferences prefs,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => RoomActivityEventProvider(
          repository: RoomActivityEventRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(
        create: (ctx) => RakutenManagedProductProvider(
          repository: RakutenManagedProductRepository(prefs),
          pendingCollectNoticeRepository: PendingCollectNoticeRepository(prefs),
          activityEventProvider: ctx.read<RoomActivityEventProvider>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => UserProfileProvider(
          repository: UserProfileRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(create: (_) => BulkOperationStateController()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 400, child: child),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('RakutenManagedProductCard Phase2a', () {
    testWidgets('price=0 shows ￥ー not ¥0', (tester) async {
      await tester.pumpWidget(
        _wrapManagedCard(
          prefs: prefs,
          child: RakutenManagedProductCard(
            product: _managedProduct(itemPrice: 0),
            variant: RakutenManagedProductCardVariant.candidate,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('￥ー'), findsOneWidget);
      expect(find.textContaining('¥0'), findsNothing);
      expect(find.textContaining('￥0'), findsNothing);
    });

    testWidgets('done without roomUrl shows ROOMで投稿', (tester) async {
      await tester.pumpWidget(
        _wrapManagedCard(
          prefs: prefs,
          child: RakutenManagedProductCard(
            product: _managedProduct(
              status: RakutenManagedProductStatus.done,
              roomUrl: '',
            ),
            variant: RakutenManagedProductCardVariant.done,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ROOMで投稿'), findsOneWidget);
      expect(find.text('ROOM投稿へ'), findsNothing);
    });
  });

  group('RakutenSearchResultCard Phase2a', () {
    testWidgets('price=0 shows ￥ー', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: RakutenSearchResultCard(
                item: _searchItem(itemPrice: 0),
                localStatus: RakutenManagedProductStatus.none,
                isRegistering: false,
                onRegisterCandidate: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('￥ー'), findsOneWidget);
    });

    testWidgets('register buttons use 44px height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: RakutenSearchResultCard(
                item: _searchItem(),
                localStatus: RakutenManagedProductStatus.none,
                isRegistering: false,
                onRegisterCandidate: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final outline = tester.widget<RakutenSearchOutlineButton>(
        find.widgetWithText(RakutenSearchOutlineButton, '楽天で見る'),
      );
      final primary = tester.widget<RakutenSearchPrimaryButton>(
        find.widgetWithText(RakutenSearchPrimaryButton, '候補に追加'),
      );
      expect(outline.height, 44);
      expect(primary.height, 44);
    });
  });
}
