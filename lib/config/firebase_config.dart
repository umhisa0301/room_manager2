import 'package:flutter/foundation.dart';

/// Firebase / Crashlytics / Analytics の送信可否を集約する設定。
abstract final class FirebaseConfig {
  /// 本番 release ビルドでのみ Firebase 送信を有効にする。
  static bool get isTelemetryEnabled => kReleaseMode;

  /// Analytics イベント名（Firebase 予約語・既存アプリ内 analytics 命名と衝突しない接頭辞）。
  static const String eventAppOpen = 'rm_app_open';
  static const String eventLegalConsentAccepted = 'legal_consent_accepted';
  static const String eventOnboardingRoute = 'onboarding_route';

  /// [eventOnboardingRoute] の route パラメータ値。
  static const String onboardingRouteLegal = 'legal';
  static const String onboardingRouteHome = 'home';

  static const String paramRoute = 'route';
}
