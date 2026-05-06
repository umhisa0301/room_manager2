import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_shell.dart';
import '../repository/legal_consent_repository.dart';
import '../screens/legal_consent_screen.dart';

/// 規約同意済みなら [AppShell]、未なら [LegalConsentScreen]。
class AppEntryHost extends StatelessWidget {
  const AppEntryHost({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LegalConsentRepository>(
      builder: (context, legal, _) {
        if (!legal.isAccepted) {
          return const LegalConsentScreen();
        }
        return const AppShell();
      },
    );
  }
}
