import 'package:flutter/foundation.dart';

/// 初回導線まわりの状態を1行で追えるようにする。
void logOnboardingUi({
  required String route,
  required bool termsAccepted,
  required bool initialSetupCompleted,
  required bool initialSetupSkipped,
  required bool missingRoomUrl,
  required bool missingGenre,
  required bool missingSavedShop,
  required bool showMyPageSetupCard,
}) {
  debugPrint(
    '[ONBOARDING_UI] '
    'route=$route '
    'termsAccepted=$termsAccepted '
    'initialSetupCompleted=$initialSetupCompleted '
    'initialSetupSkipped=$initialSetupSkipped '
    'missingRoomUrl=$missingRoomUrl '
    'missingGenre=$missingGenre '
    'missingSavedShop=$missingSavedShop '
    'showMyPageSetupCard=$showMyPageSetupCard',
  );
}
