import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/models/rakuten_product_search_condition.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/today_recommendation.dart';
import 'package:room_manager2/models/user_profile.dart';
import 'package:room_manager2/navigation/app_shell_controller.dart';
import 'package:room_manager2/repository/pending_collect_notice_repository.dart';
import 'package:room_manager2/repository/post_style_settings_repository.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/repository/room_activity_event_repository.dart';
import 'package:room_manager2/repository/room_recommendation_profile_repository.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/repository/today_recommendation_repository.dart';
import 'package:room_manager2/repository/user_profile_repository.dart';
import 'package:room_manager2/screens/today_recommendations_screen.dart';
import 'package:room_manager2/services/analytics_service.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/bulk_operation_state_controller.dart';
import 'package:room_manager2/state/post_style_settings_provider.dart';
import 'package:room_manager2/state/rakuten_managed_product_provider.dart';
import 'package:room_manager2/state/room_activity_event_provider.dart';
import 'package:room_manager2/state/room_recommendation_profile_provider.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
import 'package:room_manager2/state/today_recommendation_provider.dart';
import 'package:room_manager2/state/user_profile_provider.dart';
import 'package:room_manager2/theme/app_motion.dart';
import 'package:room_manager2/widgets/app_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodayRecommendationEntry _entry({
  String productId = 'shop:item001',
  String itemName = 'おすすめ商品',
}) {
  return TodayRecommendationEntry(
    section: TodayRecommendationSection.popular,
    item: RakutenSearchItem(
      productId: productId,
      itemName: itemName,
      itemPrice: 1980,
      itemUrl: 'https://item.rakuten.co.jp/shop/item001/',
      affiliateUrl: '',
      imageUrl: 'https://example.com/p.jpg',
      shopName: 'テストショップ',
      shopCode: 'shop',
      shopUrl: 'https://www.rakuten.co.jp/shop/',
      genreId: '100227',
      genreName: 'ジャンル',
      reviewCount: 5,
      reviewAverage: 4.2,
    ),
  );
}

TodayRecommendationBundle _bundle({
  String localDateKey = '2024-06-01',
  DateTime? generatedAt,
  List<TodayRecommendationEntry>? entries,
}) {
  return TodayRecommendationBundle(
    localDateKey: localDateKey,
    generatedAt: generatedAt ?? DateTime.parse('2024-06-01T08:00:00.000Z'),
    entries:
        entries ??
        [
          _entry(productId: 'shop:item001', itemName: '旧おすすめA'),
          _entry(productId: 'shop:item002', itemName: '旧おすすめB'),
          _entry(productId: 'shop:item003', itemName: '旧おすすめC'),
        ],
  );
}

class _HangingSearchRepository extends RakutenSearchRepository {
  _HangingSearchRepository() : super(apiService: RakutenApiService());

  final Completer<void> gate = Completer<void>();

  @override
  Future<List<RakutenSearchItem>> search({
    required RakutenProductSearchCondition condition,
    int maxPages = 4,
    int startPage = 1,
    RakutenSearchPurpose searchPurpose = RakutenSearchPurpose.normal,
    String fetchScreen = 'productSearch',
  }) async {
    await gate.future;
    return const [];
  }
}

class _FailingSearchRepository extends RakutenSearchRepository {
  _FailingSearchRepository() : super(apiService: RakutenApiService());

  @override
  Future<List<RakutenSearchItem>> search({
    required RakutenProductSearchCondition condition,
    int maxPages = 4,
    int startPage = 1,
    RakutenSearchPurpose searchPurpose = RakutenSearchPurpose.normal,
    String fetchScreen = 'productSearch',
  }) async {
    throw Exception('forced regenerate failure');
  }
}

class _EmptySearchRepository extends RakutenSearchRepository {
  _EmptySearchRepository() : super(apiService: RakutenApiService());

  @override
  Future<List<RakutenSearchItem>> search({
    required RakutenProductSearchCondition condition,
    int maxPages = 4,
    int startPage = 1,
    RakutenSearchPurpose searchPurpose = RakutenSearchPurpose.normal,
    String fetchScreen = 'productSearch',
  }) async {
    return const [];
  }
}

class _StubSearchRepository extends RakutenSearchRepository {
  _StubSearchRepository() : super(apiService: RakutenApiService());

  @override
  Future<List<RakutenSearchItem>> search({
    required RakutenProductSearchCondition condition,
    int maxPages = 4,
    int startPage = 1,
    RakutenSearchPurpose searchPurpose = RakutenSearchPurpose.normal,
    String fetchScreen = 'productSearch',
  }) async {
    return List<RakutenSearchItem>.generate(
      3,
      (i) => RakutenSearchItem(
        productId: 'stub-shop:new$i',
        itemName: '新おすすめ$i',
        itemPrice: 2000 + i,
        itemUrl: 'https://item.rakuten.co.jp/stub-shop/new$i/',
        affiliateUrl: '',
        imageUrl: 'https://example.com/n$i.jpg',
        shopName: 'Stub Shop',
        shopCode: 'stub-shop',
        shopUrl: 'https://www.rakuten.co.jp/stub-shop/',
        genreId: '100227',
        genreName: '水・ソフトドリンク',
        reviewCount: 10,
        reviewAverage: 4.5,
      ),
    );
  }
}

Future<(Widget, TodayRecommendationProvider)> _wrapTodayScreen({
  required SharedPreferences prefs,
  TodayRecommendationBundle? bundle,
  RakutenSearchRepository? searchRepository,
  bool disableAnimations = false,
}) async {
  final todayRepo = TodayRecommendationRepository(prefs);
  if (bundle != null) {
    await todayRepo.save(bundle);
  }
  final profileRepo = UserProfileRepository(prefs);
  await profileRepo.save(
    const UserProfile(favoriteGenreIds: '100227', favoriteGenres: '水'),
  );

  final rec = TodayRecommendationProvider(
    repository: todayRepo,
    searchRepository:
        searchRepository ??
        RakutenSearchRepository(apiService: RakutenApiService()),
  );

  final app = MaterialApp(
    builder: disableAnimations
        ? (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(disableAnimations: true),
              child: child ?? const SizedBox.shrink(),
            );
          }
        : null,
    home: const TodayRecommendationsScreen(skipInitialEnsure: true),
  );

  final widget = MultiProvider(
    providers: [
      Provider<AnalyticsService>.value(value: const NoOpAnalyticsService()),
      ChangeNotifierProvider(create: (_) => AppShellController()),
      ChangeNotifierProvider(create: (_) => BulkOperationStateController()),
      ChangeNotifierProvider(
        create: (_) => PostStyleSettingsProvider(
          repository: PostStyleSettingsRepository(prefs),
        ),
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
        create: (_) => UserProfileProvider(repository: profileRepo),
      ),
      ChangeNotifierProvider(
        create: (_) => RoomRecommendationProfileProvider(
          repository: RoomRecommendationProfileRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            SavedShopProvider(repository: SavedShopRepository(prefs)),
      ),
      ChangeNotifierProvider.value(value: rec),
    ],
    child: app,
  );

  return (widget, rec);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('AppMotion', () {
    testWidgets('durationOf returns zero when animations disabled', (
      tester,
    ) async {
      late Duration resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              resolved = AppMotion.durationOf(context, AppMotion.normal);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, Duration.zero);
      expect(AppMotion.fast.inMilliseconds, 160);
      expect(AppMotion.normal.inMilliseconds, 240);
      expect(AppMotion.emphasized.inMilliseconds, 360);
    });

    testWidgets('durationOf keeps duration when animations enabled', (
      tester,
    ) async {
      late Duration resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(
            builder: (context) {
              resolved = AppMotion.durationOf(context, AppMotion.normal);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, AppMotion.normal);
    });
  });

  group('TodayRecommendationsScreen regenerate UX', () {
    testWidgets('initial loading shows full-screen status when no entries', (
      tester,
    ) async {
      final (widget, rec) = await _wrapTodayScreen(prefs: prefs);
      addTearDown(rec.dispose);
      await tester.pumpWidget(widget);
      rec.debugSetLoading(true);
      await tester.pump();

      expect(
        find.byKey(const Key('today_recommendation_status_area')),
        findsOneWidget,
      );
      expect(find.text('おすすめコレを準備しています'), findsOneWidget);
      expect(
        find.byKey(const Key('today_recommendation_result_area')),
        findsNothing,
      );
    });

    testWidgets('regenerating keeps old entries and shows inline status', (
      tester,
    ) async {
      final (widget, rec) = await _wrapTodayScreen(
        prefs: prefs,
        bundle: _bundle(),
      );
      addTearDown(rec.dispose);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('旧おすすめA'), findsOneWidget);
      expect(
        find.byKey(const Key('today_recommendation_result_area')),
        findsOneWidget,
      );
      expect(rec.bundle!.entries.length, 3);

      rec.debugSetLoading(true);
      await tester.pump();

      expect(
        find.byKey(const Key('today_recommendation_status_area')),
        findsNothing,
      );
      expect(find.text('旧おすすめA'), findsOneWidget);
      expect(find.text('旧おすすめB'), findsOneWidget);
      expect(
        find.byKey(const Key('today_recommendation_regenerating_status')),
        findsOneWidget,
      );
      expect(find.text('おすすめを選び直しています'), findsOneWidget);

      final button = tester.widget<AppSecondaryButton>(
        find.byKey(const Key('today_recommendation_regenerate_button')),
      );
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);
    });

    testWidgets('manual regenerate success shows update snackbar', (
      tester,
    ) async {
      final (widget, rec) = await _wrapTodayScreen(
        prefs: prefs,
        bundle: _bundle(),
        searchRepository: _StubSearchRepository(),
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('today_recommendation_regenerate_button')),
      );
      await tester.pump();
      // pumpAndSettle はクールダウン Timer で終わらないため、十分に進める。
      await tester.pump(const Duration(seconds: 2));

      expect(
        find.byKey(const Key('today_recommendation_updated_snackbar')),
        findsOneWidget,
      );
      expect(find.text('おすすめを更新しました'), findsOneWidget);
      expect(rec.isLoading, isFalse);
      expect(rec.bundle!.entries.isNotEmpty, isTrue);

      // Provider のクールダウン Timer と Widget を先に破棄する。
      await tester.pumpWidget(const SizedBox.shrink());
      rec.dispose();
    });

    testWidgets('regenerate failure keeps previous entries', (tester) async {
      final (widget, rec) = await _wrapTodayScreen(
        prefs: prefs,
        bundle: _bundle(),
        searchRepository: _FailingSearchRepository(),
      );
      addTearDown(rec.dispose);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      final beforeIds = rec.bundle!.entries
          .map((e) => e.item.productId)
          .toList();

      await tester.tap(
        find.byKey(const Key('today_recommendation_regenerate_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(rec.isLoading, isFalse);
      expect(
        rec.bundle!.entries.map((e) => e.item.productId).toList(),
        beforeIds,
      );
      expect(find.text('旧おすすめA'), findsOneWidget);
      expect(
        find.byKey(const Key('today_recommendation_error_message')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('today_recommendation_status_area')),
        findsNothing,
      );

      final button = tester.widget<AppSecondaryButton>(
        find.byKey(const Key('today_recommendation_regenerate_button')),
      );
      // 失敗直後はクールダウン中で disabled になり得るが、loading は解除済み。
      expect(button.isLoading, isFalse);
    });

    testWidgets(
      'empty regenerate result keeps previous bundle without success snackbar',
      (tester) async {
        final before = _bundle();
        final (widget, rec) = await _wrapTodayScreen(
          prefs: prefs,
          bundle: before,
          searchRepository: _EmptySearchRepository(),
        );
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        final beforeIds = before.entries.map((e) => e.item.productId).toList();
        final beforeGeneratedAt = before.generatedAt;

        await tester.tap(
          find.byKey(const Key('today_recommendation_regenerate_button')),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        expect(rec.isLoading, isFalse);
        expect(rec.errorMessage, isNull);
        expect(rec.bundle!.generatedAt, beforeGeneratedAt);
        expect(
          rec.bundle!.entries.map((e) => e.item.productId).toList(),
          beforeIds,
        );
        expect(
          rec.generationStatus,
          TodayRecommendationGenerationStatus.partialSuccess,
        );
        expect(find.text('旧おすすめA'), findsOneWidget);
        expect(
          find.byKey(const Key('today_recommendation_updated_snackbar')),
          findsNothing,
        );
        expect(find.text('おすすめを更新しました'), findsNothing);
        expect(
          find.byKey(const Key('today_recommendation_error_message')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('today_recommendation_empty_message')),
          findsNothing,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        rec.dispose();
      },
    );

    testWidgets('reduce motion still renders recommendation list', (
      tester,
    ) async {
      final (widget, rec) = await _wrapTodayScreen(
        prefs: prefs,
        bundle: _bundle(),
        disableAnimations: true,
      );
      addTearDown(rec.dispose);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('旧おすすめA'), findsOneWidget);
      expect(
        find.byKey(const Key('today_recommendation_result_area')),
        findsOneWidget,
      );
    });

    testWidgets('hanging regenerate does not replace list with full loading', (
      tester,
    ) async {
      final hanging = _HangingSearchRepository();
      final (widget, rec) = await _wrapTodayScreen(
        prefs: prefs,
        bundle: _bundle(),
        searchRepository: hanging,
      );
      addTearDown(rec.dispose);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // regenerateToday を直接呼び、UI が一覧維持することを確認する。
      final future = rec.regenerateToday(
        profile: const UserProfile(favoriteGenreIds: '100227'),
        managedItems: const [],
        savedShops: const [],
        trigger: 'manual',
        manual: true,
      );
      // monetization 解決後に isLoading が立つまで進める。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(rec.isLoading, isTrue);
      expect(find.text('旧おすすめA'), findsOneWidget);
      expect(
        find.byKey(const Key('today_recommendation_status_area')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('today_recommendation_regenerating_status')),
        findsOneWidget,
      );

      hanging.gate.complete();
      await future;
      await tester.pump();
      expect(rec.isLoading, isFalse);
    });
  });
}
