import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/today_recommendation.dart';
import 'package:room_manager2/navigation/app_shell_controller.dart';
import 'package:room_manager2/repository/pending_collect_notice_repository.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/repository/room_activity_event_repository.dart';
import 'package:room_manager2/repository/room_recommendation_profile_repository.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/repository/today_recommendation_repository.dart';
import 'package:room_manager2/repository/user_profile_repository.dart';
import 'package:room_manager2/screens/today_recommendations_screen.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/bulk_operation_state_controller.dart';
import 'package:room_manager2/state/rakuten_managed_product_provider.dart';
import 'package:room_manager2/state/room_activity_event_provider.dart';
import 'package:room_manager2/state/room_recommendation_profile_provider.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
import 'package:room_manager2/state/today_recommendation_provider.dart';
import 'package:room_manager2/state/user_profile_provider.dart';
import 'package:room_manager2/theme/home_screen_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodayRecommendationEntry _entry({
  int itemPrice = 1980,
  TodayRecommendationDecision decision = TodayRecommendationDecision.pending,
  String productId = 'shop:item001',
}) {
  return TodayRecommendationEntry(
    section: TodayRecommendationSection.popular,
    decision: decision,
    item: RakutenSearchItem(
      productId: productId,
      itemName: 'おすすめ商品',
      itemPrice: itemPrice,
      itemUrl: 'https://item.rakuten.co.jp/shop/item001/',
      affiliateUrl: '',
      imageUrl: 'https://example.com/p.jpg',
      shopName: 'テストショップ',
      shopCode: 'shop',
      shopUrl: 'https://www.rakuten.co.jp/shop/',
      genreId: '100',
      genreName: 'ジャンル',
      reviewCount: 5,
      reviewAverage: 4.2,
    ),
  );
}

Future<Widget> _wrapTodayScreen({
  required SharedPreferences prefs,
  required TodayRecommendationBundle bundle,
}) async {
  final todayRepo = TodayRecommendationRepository(prefs);
  await todayRepo.save(bundle);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppShellController()),
      ChangeNotifierProvider(
        create: (_) => BulkOperationStateController(),
      ),
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
          bulkOperationState: ctx.read<BulkOperationStateController>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => UserProfileProvider(
          repository: UserProfileRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => RoomRecommendationProfileProvider(
          repository: RoomRecommendationProfileRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => SavedShopProvider(repository: SavedShopRepository(prefs)),
      ),
      ChangeNotifierProvider(
        create: (_) => TodayRecommendationProvider(
          repository: todayRepo,
          searchRepository: RakutenSearchRepository(
            apiService: RakutenApiService(),
          ),
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TodayRecommendationsScreen(
                      skipInitialEnsure: true,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _openTodayScreen(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('TodayRecommendationsScreen Phase2a', () {
    testWidgets('shows full CTA labels without ellipsis', (tester) async {
      final bundle = TodayRecommendationBundle(
        localDateKey: '2024-06-01',
        generatedAt: DateTime.parse('2024-06-01T08:00:00.000Z'),
        entries: [_entry()],
      );

      await tester.pumpWidget(
        await _wrapTodayScreen(prefs: prefs, bundle: bundle),
      );
      await _openTodayScreen(tester);

      expect(find.text('楽天で見る'), findsOneWidget);
      expect(find.text('候補に追加'), findsOneWidget);
      expect(find.text('見送る'), findsOneWidget);
      expect(find.textContaining('…'), findsNothing);
      expect(find.textContaining('...'), findsNothing);
    });

    testWidgets('CTA uses two-row layout instead of three-button row', (
      tester,
    ) async {
      final bundle = TodayRecommendationBundle(
        localDateKey: '2024-06-01',
        generatedAt: DateTime.parse('2024-06-01T08:00:00.000Z'),
        entries: [_entry()],
      );

      await tester.pumpWidget(
        await _wrapTodayScreen(prefs: prefs, bundle: bundle),
      );
      await _openTodayScreen(tester);

      final cta = tester.widget<Column>(
        find.byKey(const Key('today_recommendation_card_cta')),
      );
      expect(cta.children.length, 3);
      expect(cta.children[1], isA<SizedBox>());
      expect(cta.children[2], isA<Row>());

      final primaryButton = tester.widget<TextButton>(
        find.descendant(
          of: find.byKey(const Key('today_recommendation_add_candidate_button')),
          matching: find.byType(TextButton),
        ),
      );
      expect(primaryButton.style?.minimumSize?.resolve({})?.width, double.infinity);

      final addRect = tester.getRect(
        find.byKey(const Key('today_recommendation_add_candidate_button')),
      );
      final rakutenRect = tester.getRect(find.text('楽天で見る'));
      expect(addRect.top, lessThan(rakutenRect.top));
    });

    testWidgets('楽天で見る is Secondary (white background)', (tester) async {
      final bundle = TodayRecommendationBundle(
        localDateKey: '2024-06-01',
        generatedAt: DateTime.parse('2024-06-01T08:00:00.000Z'),
        entries: [_entry()],
      );

      await tester.pumpWidget(
        await _wrapTodayScreen(prefs: prefs, bundle: bundle),
      );
      await _openTodayScreen(tester);

      final rakutenButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('楽天で見る'),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        rakutenButton.style?.backgroundColor?.resolve({}),
        Colors.white,
      );

      final addButton = tester.widget<TextButton>(
        find.descendant(
          of: find.byKey(const Key('today_recommendation_add_candidate_button')),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        addButton.style?.backgroundColor?.resolve({}),
        HomeScreenColors.homeAccentTeal,
      );
    });

    testWidgets('price=0 shows ￥ー', (tester) async {
      final bundle = TodayRecommendationBundle(
        localDateKey: '2024-06-01',
        generatedAt: DateTime.parse('2024-06-01T08:00:00.000Z'),
        entries: [_entry(itemPrice: 0)],
      );

      await tester.pumpWidget(
        await _wrapTodayScreen(prefs: prefs, bundle: bundle),
      );
      await _openTodayScreen(tester);

      expect(find.text('￥ー'), findsOneWidget);
    });

    testWidgets('added candidate shows 投稿する primary CTA', (tester) async {
      final bundle = TodayRecommendationBundle(
        localDateKey: '2024-06-01',
        generatedAt: DateTime.parse('2024-06-01T08:00:00.000Z'),
        entries: [
          _entry(
            decision: TodayRecommendationDecision.addedCandidate,
          ),
        ],
      );

      await tester.pumpWidget(
        await _wrapTodayScreen(prefs: prefs, bundle: bundle),
      );
      await _openTodayScreen(tester);

      expect(find.text('投稿する'), findsOneWidget);
      expect(find.text('候補に追加'), findsNothing);
      expect(find.byKey(const Key('today_recommendation_post_button')), findsOneWidget);
    });

    test('markAddedCandidate keeps add flow working', () async {
      final todayRepo = TodayRecommendationRepository(prefs);
      final bundle = TodayRecommendationBundle(
        localDateKey: '2024-06-01',
        generatedAt: DateTime.parse('2024-06-01T08:00:00.000Z'),
        entries: [_entry()],
      );
      await todayRepo.save(bundle);

      final activityProvider = RoomActivityEventProvider(
        repository: RoomActivityEventRepository(prefs),
      );
      final bulk = BulkOperationStateController();
      final managed = RakutenManagedProductProvider(
        repository: RakutenManagedProductRepository(prefs),
        pendingCollectNoticeRepository: PendingCollectNoticeRepository(prefs),
        activityEventProvider: activityProvider,
        bulkOperationState: bulk,
      );
      final rec = TodayRecommendationProvider(
        repository: todayRepo,
        searchRepository: RakutenSearchRepository(
          apiService: RakutenApiService(),
        ),
      );

      final err = await rec.markAddedCandidate(
        managedProvider: managed,
        item: _entry().item,
      );

      expect(err, isNull);
      expect(
        rec.bundle!.entries.first.decision,
        TodayRecommendationDecision.addedCandidate,
      );
      expect(managed.items.length, 1);
    });

    testWidgets('bulk selection header is hidden', (tester) async {
      final bundle = TodayRecommendationBundle(
        localDateKey: '2024-06-01',
        generatedAt: DateTime.parse('2024-06-01T08:00:00.000Z'),
        entries: [_entry(), _entry(productId: 'shop:item002')],
      );

      await tester.pumpWidget(
        await _wrapTodayScreen(prefs: prefs, bundle: bundle),
      );
      await _openTodayScreen(tester);

      expect(
        find.byKey(const Key('today_recommendation_bulk_selection_header')),
        findsNothing,
      );
      expect(find.textContaining('選択中'), findsNothing);
      expect(find.textContaining('すべて選択'), findsNothing);
      expect(
        find.byKey(const Key('today_recommendation_bulk_add_button')),
        findsNothing,
      );
    });
  });
}
