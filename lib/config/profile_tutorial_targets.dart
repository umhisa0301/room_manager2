import 'package:flutter/foundation.dart';

import '../widgets/tutorial/tutorial_target_keys.dart';

/// プロフィール操作ガイドのステップごとに、マイページ状態に応じたハイライト Key を返す。
Key? resolveProfileTutorialStepTargetKey({
  required int stepIndex,
  required bool showMyPageSetupCard,
}) {
  switch (stepIndex) {
    case 0:
      return showMyPageSetupCard
          ? TutorialTargetKeys.setupIncompleteCard
          : TutorialTargetKeys.roomSettingsCard;
    case 1:
      return TutorialTargetKeys.roomTypeDiagnosisCard;
    default:
      return null;
  }
}
