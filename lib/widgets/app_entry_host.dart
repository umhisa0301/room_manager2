import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_shell.dart';
import '../repository/easy_initial_setup_repository.dart';
import '../repository/legal_consent_repository.dart';
import '../screens/easy_initial_setup_screen.dart';
import '../screens/legal_consent_screen.dart';
import '../services/room_profile_url_validation_service.dart';
import '../state/saved_shop_provider.dart';
import '../state/user_profile_provider.dart';
import '../utils/onboarding_ui_log.dart';

/// 規約同意済みなら [AppShell]、未なら [LegalConsentScreen]。
/// 初期設定ウィザード未完了なら [EasyInitialSetupScreen] を優先。
class AppEntryHost extends StatefulWidget {
  const AppEntryHost({super.key});

  @override
  State<AppEntryHost> createState() => _AppEntryHostState();
}

class _AppEntryHostState extends State<AppEntryHost> {
  String? _lastOnboardingUiLogSignature;

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
        route: 'legal',
        missingRoomUrl: missingRoomUrl,
        missingGenre: missingGenre,
        missingSavedShop: missingSavedShop,
        showMyPageSetupCard: false,
        roomUrlValidationResult: roomUrlFormat.logValue,
        roomProfileExists: roomProfileExists,
      );
      return const LegalConsentScreen();
    }
    if (!setup.isDismissed) {
      _logOnboarding(
        termsAccepted: true,
        setup: setup,
        route: 'easySetup',
        missingRoomUrl: missingRoomUrl,
        missingGenre: missingGenre,
        missingSavedShop: missingSavedShop,
        showMyPageSetupCard: false,
        roomUrlValidationResult: roomUrlFormat.logValue,
        roomProfileExists: roomProfileExists,
      );
      return const EasyInitialSetupScreen(embeddedInEntryHost: true);
    }
    _logOnboarding(
      termsAccepted: true,
      setup: setup,
      route: 'home',
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
