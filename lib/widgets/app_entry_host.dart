import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_shell.dart';
import '../repository/easy_initial_setup_repository.dart';
import '../repository/legal_consent_repository.dart';
import '../screens/easy_initial_setup_screen.dart';
import '../screens/legal_consent_screen.dart';

/// 規約同意済みなら [AppShell]、未なら [LegalConsentScreen]。
/// 初期設定ウィザード未完了なら [EasyInitialSetupScreen] を優先。
class AppEntryHost extends StatelessWidget {
  const AppEntryHost({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LegalConsentRepository>(
      builder: (context, legal, _) {
        if (!legal.isAccepted) {
          return const LegalConsentScreen();
        }
        return Consumer<EasyInitialSetupRepository>(
          builder: (context, setup, _) {
            if (!setup.isDismissed) {
              return const EasyInitialSetupScreen(embeddedInEntryHost: true);
            }
            return const AppShell();
          },
        );
      },
    );
  }
}
