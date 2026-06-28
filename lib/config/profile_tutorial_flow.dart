import '../models/operation_tutorial_flow.dart';
import '../models/operation_tutorial_id.dart';
import '../models/operation_tutorial_step.dart';
import '../models/operation_tutorial_target_action_id.dart';
import '../widgets/tutorial/tutorial_target_keys.dart';

/// マイページ「ROOMプロフィール」向けプロフィール登録ガイド。
const OperationTutorialFlow profileTutorialFlow = OperationTutorialFlow(
  id: OperationTutorialId.profile,
  steps: [
    OperationTutorialStep(
      targetKey: TutorialTargetKeys.roomSettingsCard,
      title: 'ROOMプロフィール',
      body:
          'ニックネームとROOM URLを登録します。URLを登録すると、投稿済み商品や反応を確認しやすくなります。',
    ),
    OperationTutorialStep(
      targetKey: TutorialTargetKeys.roomTypeDiagnosisCard,
      targetActionId: OperationTutorialTargetActionId.roomTypeDiagnosis,
      title: 'ROOMタイプ診断',
      body: 'おすすめ候補や投稿文の方向性が分かりやすくなります。',
    ),
  ],
);
