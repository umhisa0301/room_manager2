import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_config.dart';

/// Firebase Analytics への送信を抽象化するサービス。
///
/// 画面・Provider からは [FirebaseAnalytics.instance] を直接呼ばず、
/// 必ずこのサービス経由でイベントを送る。
abstract class AnalyticsService {
  Future<void> setConsentGranted(bool granted);

  Future<void> logAppOpen();

  Future<void> logLegalConsentAccepted();

  Future<void> logOnboardingRoute({required String route});
}

/// テストや Firebase 未初期化時に使う no-op 実装。
class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  Future<void> setConsentGranted(bool granted) async {}

  @override
  Future<void> logAppOpen() async {}

  @override
  Future<void> logLegalConsentAccepted() async {}

  @override
  Future<void> logOnboardingRoute({required String route}) async {}
}

/// グローバル参照用レジストリ（Provider 外からも NoOp がデフォルト）。
abstract final class AnalyticsServiceRegistry {
  static AnalyticsService _instance = const NoOpAnalyticsService();

  static AnalyticsService get instance => _instance;

  static void install(AnalyticsService service) {
    _instance = service;
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance = const NoOpAnalyticsService();
  }
}

/// Firebase Analytics 実装（consent gate + release-only 送信）。
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({
    required FirebaseAnalytics analytics,
    bool? telemetryEnabled,
  }) : _analytics = analytics,
       _telemetryEnabled = telemetryEnabled ?? FirebaseConfig.isTelemetryEnabled;

  final FirebaseAnalytics _analytics;
  final bool _telemetryEnabled;

  bool _consentGranted = false;
  bool _appOpenLogged = false;
  String? _lastOnboardingRouteSignature;

  bool get _canSend => _telemetryEnabled && _consentGranted;

  @override
  Future<void> setConsentGranted(bool granted) async {
    _consentGranted = granted;
    if (!_telemetryEnabled) {
      return;
    }
    try {
      await _analytics.setAnalyticsCollectionEnabled(granted);
    } catch (error, stackTrace) {
      _logSendFailure('setConsentGranted', error, stackTrace);
    }
  }

  @override
  Future<void> logAppOpen() async {
    if (!_canSend || _appOpenLogged) {
      return;
    }
    _appOpenLogged = true;
    await _logEvent(FirebaseConfig.eventAppOpen);
  }

  @override
  Future<void> logLegalConsentAccepted() async {
    if (!_canSend) {
      return;
    }
    await _logEvent(FirebaseConfig.eventLegalConsentAccepted);
  }

  @override
  Future<void> logOnboardingRoute({required String route}) async {
    if (!_canSend) {
      return;
    }
    final normalizedRoute = _normalizeOnboardingRoute(route);
    if (normalizedRoute == null) {
      return;
    }
    final signature = normalizedRoute;
    if (_lastOnboardingRouteSignature == signature) {
      return;
    }
    _lastOnboardingRouteSignature = signature;
    await _logEvent(
      FirebaseConfig.eventOnboardingRoute,
      parameters: {FirebaseConfig.paramRoute: normalizedRoute},
    );
  }

  String? _normalizeOnboardingRoute(String route) {
    switch (route) {
      case FirebaseConfig.onboardingRouteLegal:
      case FirebaseConfig.onboardingRouteHome:
        return route;
      default:
        if (kDebugMode) {
          debugPrint('[ANALYTICS] ignored onboarding_route=$route');
        }
        return null;
    }
  }

  Future<void> _logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (error, stackTrace) {
      _logSendFailure(name, error, stackTrace);
    }
  }

  void _logSendFailure(String context, Object error, StackTrace stackTrace) {
    debugPrint('[ANALYTICS] send failed context=$context error=$error');
    if (kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
