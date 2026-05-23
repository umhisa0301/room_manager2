import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'repository/legal_consent_repository.dart';
import 'widgets/app_entry_host.dart';
import 'services/rakuten_api_service.dart';
import 'repository/product_repository.dart';
import 'repository/comment_template_repository.dart';
import 'repository/activity_log_repository.dart';
import 'repository/rakuten_managed_product_repository.dart';
import 'repository/room_activity_event_repository.dart';
import 'repository/room_sync_cursor_repository.dart';
import 'repository/genre_master_repository.dart';
import 'services/genre_master_service.dart';
import 'services/rakuten_genre_master_service.dart';
import 'repository/rakuten_search_repository.dart';
import 'repository/easy_initial_setup_repository.dart';
import 'state/bulk_operation_state_controller.dart';
import 'state/product_list_provider.dart';
import 'state/comment_template_provider.dart';
import 'state/activity_log_provider.dart';
import 'state/rakuten_managed_product_provider.dart';
import 'state/room_activity_event_provider.dart';
import 'state/rakuten_search_provider.dart';
import 'app_messenger.dart';
import 'widgets/pending_collect_resume_notice_host.dart';
import 'widgets/room_url_extraction_host.dart';
import 'navigation/app_route_observer.dart';
import 'repository/pending_collect_notice_repository.dart';
import 'repository/done_tab_notice_repository.dart';
import 'repository/room_colle_ui_state_repository.dart';
import 'repository/user_profile_repository.dart';
import 'repository/saved_shop_repository.dart';
import 'repository/today_recommendation_repository.dart';
import 'state/user_profile_provider.dart';
import 'state/room_import_controller.dart';
import 'state/saved_shop_provider.dart';
import 'state/today_recommendation_provider.dart';
import 'navigation/app_shell_controller.dart';
import 'models/genre_master.dart';
import 'config/debug_log_flags.dart';
import 'config/room_import_enrichment_verify_config.dart';
import 'utils/room_sync_log.dart';

Future<void> _bootstrapRakutenGenreNameCache(GenreMasterRepository repo) async {
  final List<GenreMaster> all;
  try {
    all = await repo.getAllCachedGenres();
  } catch (_) {
    return;
  }
  for (final g in all) {
    RakutenGenreMasterService.instance.applyGenreMaster(g);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    debugPrint(
      '[DEBUG_LOG_VOLUME] searchAudit=${DebugLogFlags.kSearchAuditLogsEnabled} '
      'roomAudit=${DebugLogFlags.kRoomAuditLogsEnabled} '
      'analyticsAudit=${DebugLogFlags.kAnalyticsAuditLogsEnabled} '
      'verboseItem=${DebugLogFlags.kVerboseItemLogsEnabled} '
      'summary=${DebugLogFlags.kDebugLogSummaryEnabled}',
    );
  }
  roomImportEnrichModeLog(RoomImportEnrichmentVerifyConfig.enabled);
  final prefs = await SharedPreferences.getInstance();
  final productRepository = ProductRepository(prefs);
  final commentRepository = CommentTemplateRepository(prefs);
  final activityRepository = ActivityLogRepository(prefs);
  final rakutenSearchRepository = RakutenSearchRepository(
    apiService: RakutenApiService(),
  );
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
  final genreMasterRepository = GenreMasterRepository(prefs: prefs);
  await _bootstrapRakutenGenreNameCache(genreMasterRepository);
  await GenreMasterService.instance.load();
  runApp(
    MyApp(
      productRepository: productRepository,
      commentRepository: commentRepository,
      activityRepository: activityRepository,
      rakutenSearchRepository: rakutenSearchRepository,
      rakutenManagedProductRepository: rakutenManagedProductRepository,
      roomActivityEventRepository: roomActivityEventRepository,
      pendingCollectNoticeRepository: pendingCollectNoticeRepository,
      doneTabNoticeRepository: doneTabNoticeRepository,
      roomColleUiStateRepository: roomColleUiStateRepository,
      userProfileRepository: userProfileRepository,
      savedShopRepository: savedShopRepository,
      todayRecommendationRepository: todayRecommendationRepository,
      genreMasterRepository: genreMasterRepository,
      prefs: prefs,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.productRepository,
    required this.commentRepository,
    required this.activityRepository,
    required this.rakutenSearchRepository,
    required this.rakutenManagedProductRepository,
    required this.roomActivityEventRepository,
    required this.pendingCollectNoticeRepository,
    required this.doneTabNoticeRepository,
    required this.roomColleUiStateRepository,
    required this.userProfileRepository,
    required this.savedShopRepository,
    required this.todayRecommendationRepository,
    required this.genreMasterRepository,
    required this.prefs,
  });

  final ProductRepository productRepository;
  final CommentTemplateRepository commentRepository;
  final ActivityLogRepository activityRepository;
  final RakutenSearchRepository rakutenSearchRepository;
  final RakutenManagedProductRepository rakutenManagedProductRepository;
  final RoomActivityEventRepository roomActivityEventRepository;
  final PendingCollectNoticeRepository pendingCollectNoticeRepository;
  final DoneTabNoticeRepository doneTabNoticeRepository;
  final RoomColleUiStateRepository roomColleUiStateRepository;
  final UserProfileRepository userProfileRepository;
  final SavedShopRepository savedShopRepository;
  final TodayRecommendationRepository todayRecommendationRepository;
  final GenreMasterRepository genreMasterRepository;
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<RoomSyncCursorRepository>(
          create: (_) => SharedPreferencesRoomSyncCursorRepository(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => LegalConsentRepository(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => EasyInitialSetupRepository(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => BulkOperationStateController(),
        ),
        Provider<GenreMasterRepository>.value(value: genreMasterRepository),
        Provider<RakutenSearchRepository>.value(value: rakutenSearchRepository),
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
          create: (_) => SavedShopProvider(repository: savedShopRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => TodayRecommendationProvider(
            repository: todayRecommendationRepository,
            searchRepository: rakutenSearchRepository,
          ),
        ),
      ],
      child: MaterialApp(
        title: '楽天ROOM運用補助',
        theme: AppTheme.lightTheme,
        scaffoldMessengerKey: appRootScaffoldMessengerKey,
        builder: (context, child) {
          return RoomUrlExtractionHost(
            child: PendingCollectResumeNoticeHost(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        navigatorObservers: <NavigatorObserver>[appRouteObserver],
        home: const AppEntryHost(),
      ),
    );
  }
}
