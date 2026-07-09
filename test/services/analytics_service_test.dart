import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/firebase_config.dart';
import 'package:room_manager2/services/analytics_service.dart';

void main() {
  group('NoOpAnalyticsService', () {
    test('does not throw for phase 1 events', () async {
      const service = NoOpAnalyticsService();
      await service.setConsentGranted(true);
      await service.logAppOpen();
      await service.logLegalConsentAccepted();
      await service.logOnboardingRoute(
        route: FirebaseConfig.onboardingRouteHome,
      );
    });
  });

  group('AnalyticsServiceRegistry', () {
    tearDown(AnalyticsServiceRegistry.resetForTesting);

    test('defaults to NoOpAnalyticsService', () {
      AnalyticsServiceRegistry.resetForTesting();
      expect(AnalyticsServiceRegistry.instance, isA<NoOpAnalyticsService>());
    });

    test('install replaces instance', () {
      const replacement = NoOpAnalyticsService();
      AnalyticsServiceRegistry.install(replacement);
      expect(identical(AnalyticsServiceRegistry.instance, replacement), isTrue);
    });
  });
}
