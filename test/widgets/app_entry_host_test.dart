import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/repository/activity_log_repository.dart';
import 'package:room_manager2/repository/comment_template_repository.dart';
import 'package:room_manager2/repository/done_tab_notice_repository.dart';
import 'package:room_manager2/repository/easy_initial_setup_repository.dart';
import 'package:room_manager2/repository/genre_master_repository.dart';
import 'package:room_manager2/repository/legal_consent_repository.dart';
import 'package:room_manager2/repository/operation_tutorial_repository.dart';
import 'package:room_manager2/repository/pending_collect_notice_repository.dart';
import 'package:room_manager2/repository/product_catalog_repository.dart';
import 'package:room_manager2/repository/product_repository.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/repository/room_activity_event_repository.dart';
import 'package:room_manager2/repository/room_colle_ui_state_repository.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/repository/shop_catalog_repository.dart';
import 'package:room_manager2/repository/today_recommendation_repository.dart';
import 'package:room_manager2/repository/user_profile_repository.dart';
import 'package:room_manager2/screens/easy_initial_setup_screen.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/activity_log_provider.dart';
import 'package:room_manager2/navigation/app_shell_controller.dart';
import 'package:room_manager2/state/bulk_operation_state_controller.dart';
import 'package:room_manager2/state/comment_template_provider.dart';
import 'package:room_manager2/state/operation_tutorial_controller.dart';
import 'package:room_manager2/state/product_list_provider.dart';
import 'package:room_manager2/state/rakuten_managed_product_provider.dart';
import 'package:room_manager2/state/rakuten_search_provider.dart';
import 'package:room_manager2/state/room_activity_event_provider.dart';
import 'package:room_manager2/state/room_import_controller.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
import 'package:room_manager2/state/today_recommendation_provider.dart';
import 'package:room_manager2/state/user_profile_provider.dart';
import 'package:room_manager2/repository/room_recommendation_profile_repository.dart';
import 'package:room_manager2/services/analytics_service.dart';
import 'package:room_manager2/state/room_recommendation_profile_provider.dart';
import 'package:room_manager2/widgets/app_entry_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapAppEntryHost({
  required SharedPreferences prefs,
  required Widget child,
}) {
  final productRepository = ProductRepository(prefs);
  final commentRepository = CommentTemplateRepository(prefs);
  final activityRepository = ActivityLogRepository(prefs);
  final rakutenSearchRepository = RakutenSearchRepository(
    apiService: RakutenApiService(),
  );
  final productCatalogRepository = ProductCatalogRepository(prefs);
  final shopCatalogRepository = ShopCatalogRepository(prefs);
  final rakutenManagedProductRepository = RakutenManagedProductRepository(
    prefs,
  );
  final roomActivityEventRepository = RoomActivityEventRepository(prefs);
  final pendingCollectNoticeRepository = PendingCollectNoticeRepository(prefs);
  final doneTabNoticeRepository = DoneTabNoticeRepository(prefs);
  final roomColleUiStateRepository = RoomColleUiStateRepository(prefs);
  final userProfileRepository = UserProfileRepository(prefs);
  final savedShopRepository = SavedShopRepository(prefs);
  final todayRecommendationRepository = TodayRecommendationRepository(prefs);
  final roomRecommendationProfileRepository =
      RoomRecommendationProfileRepository(prefs);
  final genreMasterRepository = GenreMasterRepository(prefs: prefs);

  return MultiProvider(
    providers: [
      Provider<AnalyticsService>.value(value: const NoOpAnalyticsService()),
      ChangeNotifierProvider(
        create: (_) => LegalConsentRepository(prefs),
      ),
      ChangeNotifierProvider(
        create: (_) => EasyInitialSetupRepository(prefs),
      ),
      ChangeNotifierProvider(
        create: (_) => OperationTutorialRepository(prefs),
      ),
      ChangeNotifierProvider(
        create: (ctx) => OperationTutorialController(
          ctx.read<OperationTutorialRepository>(),
        ),
      ),
      ChangeNotifierProvider(create: (_) => BulkOperationStateController()),
      Provider<GenreMasterRepository>.value(value: genreMasterRepository),
      Provider<RakutenSearchRepository>.value(value: rakutenSearchRepository),
      Provider<ProductCatalogRepository>.value(
        value: productCatalogRepository,
      ),
      Provider<ShopCatalogRepository>.value(value: shopCatalogRepository),
      Provider<RakutenManagedProductRepository>.value(
        value: rakutenManagedProductRepository,
      ),
      ChangeNotifierProvider(create: (_) => AppShellController()),
      ChangeNotifierProvider(
        create: (ctx) => RoomImportController(
          bulkOperationState: ctx.read<BulkOperationStateController>(),
        ),
      ),
      Provider<PendingCollectNoticeRepository>.value(
        value: pendingCollectNoticeRepository,
      ),
      Provider<DoneTabNoticeRepository>.value(value: doneTabNoticeRepository),
      Provider<RoomColleUiStateRepository>.value(
        value: roomColleUiStateRepository,
      ),
      ChangeNotifierProvider(
        create: (_) => ProductListProvider(repository: productRepository),
      ),
      ChangeNotifierProvider(
        create: (_) => CommentTemplateProvider(repository: commentRepository),
      ),
      ChangeNotifierProvider(
        create: (_) => ActivityLogProvider(repository: activityRepository),
      ),
      ChangeNotifierProvider(
        create: (_) => RakutenSearchProvider(
          repository: rakutenSearchRepository,
          genreMasterRepository: genreMasterRepository,
          productCatalogRepository: productCatalogRepository,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => RoomActivityEventProvider(
          repository: roomActivityEventRepository,
        ),
      ),
      ChangeNotifierProvider(
        create: (ctx) => RakutenManagedProductProvider(
          repository: rakutenManagedProductRepository,
          pendingCollectNoticeRepository: pendingCollectNoticeRepository,
          activityEventProvider: ctx.read<RoomActivityEventProvider>(),
          rakutenSearchRepository: rakutenSearchRepository,
          bulkOperationState: ctx.read<BulkOperationStateController>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => UserProfileProvider(repository: userProfileRepository),
      ),
      ChangeNotifierProvider(
        create: (_) => RoomRecommendationProfileProvider(
          repository: roomRecommendationProfileRepository,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => SavedShopProvider(repository: savedShopRepository),
      ),
      ChangeNotifierProvider(
        create: (_) => TodayRecommendationProvider(
          repository: todayRecommendationRepository,
          searchRepository: rakutenSearchRepository,
          productCatalogRepository: productCatalogRepository,
        ),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppEntryHost', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('shows LegalConsentScreen when terms not accepted', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapAppEntryHost(prefs: prefs, child: const AppEntryHost()),
      );
      await tester.pump();

      expect(find.text('はじめる前に'), findsOneWidget);
      expect(find.byType(EasyInitialSetupScreen), findsNothing);
      expect(find.byKey(const Key('app_shell_nav_home')), findsNothing);
    });

    testWidgets(
      'shows AppShell when terms accepted and easy setup not dismissed',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          LegalConsentRepository.acceptedKey: true,
          EasyInitialSetupRepository.dismissedKey: false,
        });
        prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          _wrapAppEntryHost(prefs: prefs, child: const AppEntryHost()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('はじめる前に'), findsNothing);
        expect(find.byType(EasyInitialSetupScreen), findsNothing);
        expect(find.text('かんたん初期設定'), findsNothing);
        expect(find.byKey(const Key('app_shell_nav_home')), findsOneWidget);
      },
    );

    testWidgets(
      'shows AppShell when terms accepted and easy setup dismissed',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          LegalConsentRepository.acceptedKey: true,
          EasyInitialSetupRepository.dismissedKey: true,
        });
        prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          _wrapAppEntryHost(prefs: prefs, child: const AppEntryHost()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('はじめる前に'), findsNothing);
        expect(find.byType(EasyInitialSetupScreen), findsNothing);
        expect(find.byKey(const Key('app_shell_nav_home')), findsOneWidget);
      },
    );
  });
}
