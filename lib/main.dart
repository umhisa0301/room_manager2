import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'app_shell.dart';
import 'services/rakuten_api_service.dart';
import 'repository/product_repository.dart';
import 'repository/comment_template_repository.dart';
import 'repository/activity_log_repository.dart';
import 'repository/rakuten_managed_product_repository.dart';
import 'repository/rakuten_search_repository.dart';
import 'state/product_list_provider.dart';
import 'state/comment_template_provider.dart';
import 'state/activity_log_provider.dart';
import 'state/rakuten_managed_product_provider.dart';
import 'state/rakuten_search_provider.dart';
import 'app_messenger.dart';
import 'widgets/pending_collect_resume_notice_host.dart';
import 'widgets/room_url_extraction_host.dart';
import 'navigation/app_route_observer.dart';
import 'repository/pending_collect_notice_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final productRepository = ProductRepository(prefs);
  final commentRepository = CommentTemplateRepository(prefs);
  final activityRepository = ActivityLogRepository(prefs);
  final rakutenSearchRepository =
      RakutenSearchRepository(apiService: RakutenApiService());
  final rakutenManagedProductRepository =
      RakutenManagedProductRepository(prefs);
  final pendingCollectNoticeRepository =
      PendingCollectNoticeRepository(prefs);
  runApp(
    MyApp(
      productRepository: productRepository,
      commentRepository: commentRepository,
      activityRepository: activityRepository,
      rakutenSearchRepository: rakutenSearchRepository,
      rakutenManagedProductRepository: rakutenManagedProductRepository,
      pendingCollectNoticeRepository: pendingCollectNoticeRepository,
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
    required this.pendingCollectNoticeRepository,
  });

  final ProductRepository productRepository;
  final CommentTemplateRepository commentRepository;
  final ActivityLogRepository activityRepository;
  final RakutenSearchRepository rakutenSearchRepository;
  final RakutenManagedProductRepository rakutenManagedProductRepository;
  final PendingCollectNoticeRepository pendingCollectNoticeRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PendingCollectNoticeRepository>.value(
          value: pendingCollectNoticeRepository,
        ),
        ChangeNotifierProvider(
          create: (_) => ProductListProvider(repository: productRepository),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              CommentTemplateProvider(repository: commentRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ActivityLogProvider(repository: activityRepository),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              RakutenSearchProvider(repository: rakutenSearchRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => RakutenManagedProductProvider(
            repository: rakutenManagedProductRepository,
            pendingCollectNoticeRepository: pendingCollectNoticeRepository,
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
        home: const AppShell(),
      ),
    );
  }
}
