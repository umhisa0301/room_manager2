import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/profile_tutorial_targets.dart';
import 'package:room_manager2/models/operation_tutorial_target_action_id.dart';

void main() {
  group('resolveProfileTutorialStepTargetAction', () {
    test('未設定時 step0 は profileSetup', () {
      expect(
        resolveProfileTutorialStepTargetAction(
          stepIndex: 0,
          showMyPageSetupCard: true,
        ),
        OperationTutorialTargetActionId.profileSetup,
      );
    });

    test('設定済み step0 は profileEdit', () {
      expect(
        resolveProfileTutorialStepTargetAction(
          stepIndex: 0,
          showMyPageSetupCard: false,
        ),
        OperationTutorialTargetActionId.profileEdit,
      );
    });

    test('step1 は roomTypeDiagnosis', () {
      expect(
        resolveProfileTutorialStepTargetAction(
          stepIndex: 1,
          showMyPageSetupCard: false,
        ),
        OperationTutorialTargetActionId.roomTypeDiagnosis,
      );
    });
  });
}
