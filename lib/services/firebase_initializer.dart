import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_config.dart';
import '../firebase_options.dart';
import 'analytics_service.dart';

/// Firebase Core / Crashlytics の起動時初期化結果。
class FirebaseInitResult {
  const FirebaseInitResult({
    required this.isInitialized,
    required this.analyticsService,
    this.error,
    this.stackTrace,
  });

  final bool isInitialized;
  final AnalyticsService analyticsService;
  final Object? error;
  final StackTrace? stackTrace;
}

/// Firebase 初期化と Crashlytics エラーハンドラのセットアップ。
abstract final class FirebaseInitializer {
  static bool _initialized = false;
  static bool _crashHandlersInstalled = false;
  static FirebaseCrashlytics? _crashlytics;
  static AnalyticsService _analyticsService = const NoOpAnalyticsService();

  static bool get isInitialized => _initialized;

  static AnalyticsService get analyticsService => _analyticsService;

  /// Firebase を初期化し、Analytics サービスを返す。失敗しても例外は投げない。
  static Future<FirebaseInitResult> initialize() async {
    if (_initialized) {
      return FirebaseInitResult(
        isInitialized: true,
        analyticsService: _analyticsService,
      );
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;

      final analytics = FirebaseAnalytics.instance;
      _analyticsService = FirebaseAnalyticsService(analytics: analytics);
      AnalyticsServiceRegistry.install(_analyticsService);

      _crashlytics = FirebaseCrashlytics.instance;
      await _configureCrashlyticsCollection();
      _installCrashHandlers();

      if (kDebugMode) {
        debugPrint('[FIREBASE] initialization completed telemetryEnabled=${FirebaseConfig.isTelemetryEnabled}');
      }

      return FirebaseInitResult(
        isInitialized: true,
        analyticsService: _analyticsService,
      );
    } catch (error, stackTrace) {
      _analyticsService = const NoOpAnalyticsService();
      AnalyticsServiceRegistry.install(_analyticsService);
      debugPrint('[FIREBASE] initialization failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      return FirebaseInitResult(
        isInitialized: false,
        analyticsService: _analyticsService,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _configureCrashlyticsCollection() async {
    final crashlytics = _crashlytics;
    if (crashlytics == null) {
      return;
    }
    try {
      await crashlytics.setCrashlyticsCollectionEnabled(
        FirebaseConfig.isTelemetryEnabled,
      );
    } catch (error, stackTrace) {
      debugPrint('[CRASHLYTICS] setCrashlyticsCollectionEnabled failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static void _installCrashHandlers() {
    if (_crashHandlersInstalled || !_initialized) {
      return;
    }
    _crashHandlersInstalled = true;

    final crashlytics = _crashlytics;
    if (crashlytics == null) {
      return;
    }

    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (_initialized && FirebaseConfig.isTelemetryEnabled) {
        unawaited(
          crashlytics.recordFlutterFatalError(details),
        );
      }
      previousFlutterOnError?.call(details);
    };

    final previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      if (_initialized && FirebaseConfig.isTelemetryEnabled) {
        unawaited(
          crashlytics.recordError(error, stack, fatal: true),
        );
      }
      if (previousPlatformOnError != null) {
        return previousPlatformOnError(error, stack);
      }
      return true;
    };
  }

  /// [runZonedGuarded] から未捕捉の非同期エラーを記録する。
  static void recordZoneError(Object error, StackTrace stack) {
    debugPrint('[FIREBASE] uncaught zone error: $error');
    if (!_initialized || !FirebaseConfig.isTelemetryEnabled) {
      if (kDebugMode) {
        debugPrintStack(stackTrace: stack);
      }
      return;
    }
    final crashlytics = _crashlytics;
    if (crashlytics == null) {
      return;
    }
    unawaited(
      crashlytics.recordError(error, stack, fatal: true),
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _crashHandlersInstalled = false;
    _crashlytics = null;
    _analyticsService = const NoOpAnalyticsService();
    AnalyticsServiceRegistry.install(const NoOpAnalyticsService());
  }
}
