import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/admob_config.dart';
import '../config/monetization_config.dart';

/// AdMob SDK の起動時初期化（[MonetizationFlags.isAdsEnabled] のときのみ）。
abstract final class AdMobInitializer {
  static bool _started = false;
  static bool _completed = false;
  static bool _failed = false;

  static bool get isCompleted => _completed;

  static bool get isFailed => _failed;

  static bool get hasStarted => _started;

  static Future<void> initializeIfNeeded() async {
    if (!MonetizationFlags.isAdsEnabled) {
      if (kDebugMode) {
        debugPrint('[ADMOB] initialization skipped ads=false');
      }
      return;
    }

    if (kReleaseMode && !kProfileMode && AdMobConfig.resolveEnvironment() == null) {
      debugPrint(
        '[ADMOB] initialization skipped: release build without production '
        'banner ad unit ID (set AdMobConfig.production* and '
        'kReleaseAdMobIdsEnabled=true)',
      );
      return;
    }

    if (_started) {
      return;
    }
    _started = true;

    if (kDebugMode) {
      debugPrint('[ADMOB] initialization started');
    }

    try {
      await MobileAds.instance.initialize();
      _completed = true;
      if (kDebugMode) {
        debugPrint('[ADMOB] initialization completed');
      }
    } catch (error, stackTrace) {
      _failed = true;
      debugPrint('[ADMOB] initialization failed $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _started = false;
    _completed = false;
    _failed = false;
  }
}
