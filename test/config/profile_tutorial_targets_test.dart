import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/profile_tutorial_targets.dart';
import 'package:room_manager2/widgets/tutorial/tutorial_target_keys.dart';

void main() {
  group('resolveProfileTutorialStepTargetKey', () {
    test('未設定時 step0 は設定完了カード', () {
      expect(
        resolveProfileTutorialStepTargetKey(
          stepIndex: 0,
          showMyPageSetupCard: true,
        ),
        TutorialTargetKeys.setupIncompleteCard,
      );
    });

    test('設定済み時 step0 は ROOMプロフィールカード', () {
      expect(
        resolveProfileTutorialStepTargetKey(
          stepIndex: 0,
          showMyPageSetupCard: false,
        ),
        TutorialTargetKeys.roomSettingsCard,
      );
    });

    test('step1 は ROOMタイプ診断カード', () {
      expect(
        resolveProfileTutorialStepTargetKey(
          stepIndex: 1,
          showMyPageSetupCard: true,
        ),
        TutorialTargetKeys.roomTypeDiagnosisCard,
      );
      expect(
        resolveProfileTutorialStepTargetKey(
          stepIndex: 1,
          showMyPageSetupCard: false,
        ),
        TutorialTargetKeys.roomTypeDiagnosisCard,
      );
    });
  });
}
