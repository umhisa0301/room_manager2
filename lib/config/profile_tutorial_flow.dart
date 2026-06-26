import '../models/operation_tutorial_flow.dart';
import '../models/operation_tutorial_id.dart';
import '../models/operation_tutorial_step.dart';
import '../widgets/tutorial/tutorial_target_keys.dart';

/// マイページ「ROOMプロフィール」向けプロフィール登録ガイド。
const OperationTutorialFlow profileTutorialFlow = OperationTutorialFlow(
  id: OperationTutorialId.profile,
  steps: [
    OperationTutorialStep(
      targetKey: TutorialTargetKeys.roomSettingsCard,
      title: 'ROOMプロフィール',
      body: 'ここでニックネームやROOM URLなど、ROOM運用に必要な基本設定を行います。',
    ),
    OperationTutorialStep(
      targetKey: TutorialTargetKeys.roomTypeDiagnosisCard,
      title: 'ROOMタイプ診断',
      body: 'あなたに合うコレ候補や投稿文の方向性を提案しやすくします。',
    ),
  ],
);
