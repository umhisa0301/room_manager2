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
import 'services/rakuten_url_extraction_scheduler.dart';
import 'services/xpath_config_loader.dart';
import 'state/product_list_provider.dart';
import 'state/comment_template_provider.dart';
import 'state/activity_log_provider.dart';
import 'state/rakuten_managed_product_provider.dart';
import 'state/rakuten_search_provider.dart';
import 'widgets/rakuten_url_extraction_host.dart';

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
  final extractionScheduler = RakutenUrlExtractionSchedulerImpl();
  final xpathLoader = XpathConfigLoader();
  runApp(
    MyApp(
      productRepository: productRepository,
      commentRepository: commentRepository,
      activityRepository: activityRepository,
      rakutenSearchRepository: rakutenSearchRepository,
      rakutenManagedProductRepository: rakutenManagedProductRepository,
      extractionScheduler: extractionScheduler,
      xpathLoader: xpathLoader,
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
    required this.extractionScheduler,
    required this.xpathLoader,
  });

  final ProductRepository productRepository;
  final CommentTemplateRepository commentRepository;
  final ActivityLogRepository activityRepository;
  final RakutenSearchRepository rakutenSearchRepository;
  final RakutenManagedProductRepository rakutenManagedProductRepository;
  final RakutenUrlExtractionSchedulerImpl extractionScheduler;
  final XpathConfigLoader xpathLoader;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
            extractionScheduler: extractionScheduler,
          ),
        ),
      ],
      child: MaterialApp(
        title: '楽天ROOM運用補助',
        theme: AppTheme.lightTheme,
        home: const AppShell(),
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (child != null) child,
              Positioned(
                left: -3200,
                top: 0,
                width: 400,
                height: 620,
                child: RakutenUrlExtractionHost(
                  scheduler: extractionScheduler,
                  repository: rakutenManagedProductRepository,
                  xpathLoader: xpathLoader,
                  onPersisted: () {
                    try {
                      Provider.of<RakutenManagedProductProvider>(
                        context,
                        listen: false,
                      ).syncAfterExtractionWrite();
                    } catch (_) {}
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
