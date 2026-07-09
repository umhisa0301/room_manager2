import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_shell.dart';
import '../config/firebase_config.dart';
import '../repository/easy_initial_setup_repository.dart';
import '../repository/legal_consent_repository.dart';
import '../screens/legal_consent_screen.dart';
import '../services/analytics_service.dart';
import '../services/room_profile_url_validation_service.dart';
import '../state/saved_shop_provider.dart';
import '../state/user_profile_provider.dart';
import '../utils/onboarding_ui_log.dart';

/// 規約同意済みなら [AppShell]、未なら [LegalConsentScreen]。
class AppEntryHost extends StatefulWidget {
  const AppEntryHost({super.key});

  @override
  State<AppEntryHost> createState() => _AppEntryHostState();
}

class _AppEntryHostState extends State<AppEntryHost> {
  String? _lastOnboardingUiLogSignature;
  bool _appOpenLogged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLogAppOpen());
  }

  void _maybeLogAppOpen() {
    if (!mounted || _appOpenLogged) {
      return;
    }
    final legal = context.read<LegalConsentRepository>();
    if (!legal.isAccepted) {
      return;
    }
    _appOpenLogged = true;
    unawaited(context.read<AnalyticsService>().logAppOpen());
  }

  void _logOnboarding({
    required bool termsAccepted,
    required EasyInitialSetupRepository setup,
    required String route,
    required bool missingRoomUrl,
    required bool missingGenre,
    required bool missingSavedShop,
    required bool showMyPageSetupCard,
    required String roomUrlValidationResult,
    required String roomProfileExists,
  }) {
    final signature = [
      route,
      termsAccepted,
      setup.initialSetupCompleted,
      setup.initialSetupSkipped,
      missingRoomUrl,
      missingGenre,
      missingSavedShop,
      showMyPageSetupCard,
      roomUrlValidationResult,
      roomProfileExists,
    ].join('|');
    if (_lastOnboardingUiLogSignature == signature) return;
    _lastOnboardingUiLogSignature = signature;
    unawaited(
      context.read<AnalyticsService>().logOnboardingRoute(route: route),
    );
    logOnboardingUi(
      route: route,
      termsAccepted: termsAccepted,
      initialSetupCompleted: setup.initialSetupCompleted,
      initialSetupSkipped: setup.initialSetupSkipped,
      missingRoomUrl: missingRoomUrl,
      missingGenre: missingGenre,
      missingSavedShop: missingSavedShop,
      showMyPageSetupCard: showMyPageSetupCard,
      roomUrlValidationResult: roomUrlValidationResult,
      roomProfileExists: roomProfileExists,
    );
  }

  @override
  Widget build(BuildContext context) {
    final legal = context.watch<LegalConsentRepository>();
    final setup = context.watch<EasyInitialSetupRepository>();
    final profile = context.watch<UserProfileProvider>().profile;
    final savedShopCount = context.watch<SavedShopProvider>().shops.length;
    final missingRoomUrl = !profile.hasRoomUrl;
    final missingGenre = profile.favoriteGenreIdList.isEmpty;
    final missingSavedShop = savedShopCount <= 0;
    final showMyPageSetupCard =
        !setup.initialSetupCompleted &&
        (missingRoomUrl || missingGenre || missingSavedShop);
    final roomUrlFormat = RoomProfileUrlValidationService.validateFormat(
      profile.roomUrl,
    );
    final roomProfileExists = missingRoomUrl ? 'skipped' : 'unknown';

    if (!legal.isAccepted) {
      _logOnboarding(
        termsAccepted: false,
        setup: setup,
        route: FirebaseConfig.onboardingRouteLegal,
        missingRoomUrl: missingRoomUrl,
        missingGenre: missingGenre,
        missingSavedShop: missingSavedShop,
        showMyPageSetupCard: false,
        roomUrlValidationResult: roomUrlFormat.logValue,
        roomProfileExists: roomProfileExists,
      );
      return const LegalConsentScreen();
    }
    _maybeLogAppOpen();
    _logOnboarding(
      termsAccepted: true,
      setup: setup,
      route: FirebaseConfig.onboardingRouteHome,
      missingRoomUrl: missingRoomUrl,
      missingGenre: missingGenre,
      missingSavedShop: missingSavedShop,
      showMyPageSetupCard: showMyPageSetupCard,
      roomUrlValidationResult: roomUrlFormat.logValue,
      roomProfileExists: roomProfileExists,
    );
    return const AppShell();
  }
}
