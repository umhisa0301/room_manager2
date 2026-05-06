import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_shell.dart';
import '../repository/easy_initial_setup_repository.dart';
import '../repository/legal_consent_repository.dart';
import '../screens/easy_initial_setup_screen.dart';
import '../screens/legal_consent_screen.dart';

/// 規約同意済みなら [AppShell]、未なら [LegalConsentScreen]。
/// 初期設定ウィザード未完了なら [EasyInitialSetupScreen] を優先。
class AppEntryHost extends StatefulWidget {
  const AppEntryHost({super.key});

  @override
  State<AppEntryHost> createState() => _AppEntryHostState();
}

class _AppEntryHostState extends State<AppEntryHost> {
  String? _lastOnboardingRouteLogged;

  void _logOnboarding({
    required bool termsAccepted,
    required EasyInitialSetupRepository setup,
    required String route,
  }) {
    if (_lastOnboardingRouteLogged == route) return;
    _lastOnboardingRouteLogged = route;
    final shouldShow = termsAccepted && !setup.isDismissed;
    debugPrint('[ONBOARDING] termsAccepted=$termsAccepted');
    debugPrint(
      '[ONBOARDING] initialSetupCompleted=${setup.initialSetupCompleted}',
    );
    debugPrint('[ONBOARDING] initialSetupSkipped=${setup.initialSetupSkipped}');
    debugPrint('[ONBOARDING] shouldShowInitialSetup=$shouldShow');
    debugPrint('[ONBOARDING] route=$route');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LegalConsentRepository>(
      builder: (context, legal, _) {
        if (!legal.isAccepted) {
          _logOnboarding(
            termsAccepted: false,
            setup: context.read<EasyInitialSetupRepository>(),
            route: 'legal_consent',
          );
          return const LegalConsentScreen();
        }
        return Consumer<EasyInitialSetupRepository>(
          builder: (context, setup, _) {
            if (!setup.isDismissed) {
              _logOnboarding(
                termsAccepted: true,
                setup: setup,
                route: 'easy_initial_setup',
              );
              return const EasyInitialSetupScreen(embeddedInEntryHost: true);
            }
            _logOnboarding(
              termsAccepted: true,
              setup: setup,
              route: 'app_shell',
            );
            return const AppShell();
          },
        );
      },
    );
  }
}
