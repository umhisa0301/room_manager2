import '../models/operation_tutorial_flow.dart';
import '../models/operation_tutorial_id.dart';
import '../models/operation_tutorial_step.dart';
import '../widgets/tutorial/tutorial_target_keys.dart';

/// マイページ「ROOM運用の設定」向けプロフィール登録ガイド。
const OperationTutorialFlow profileTutorialFlow = OperationTutorialFlow(
  id: OperationTutorialId.profile,
  steps: [
    OperationTutorialStep(
      targetKey: TutorialTargetKeys.roomSettingsCard,
      title: 'ROOM運用の設定',
      body: 'ここでニックネームやROOM URLなど、ROOM運用に必要な基本設定を行います。',
    ),
    OperationTutorialStep(
      targetKey: TutorialTargetKeys.nicknameRow,
      title: 'ニックネーム',
      body: '表示名として使われます。任意ですが、設定しておくとホーム画面などで名前が表示されます。',
    ),
    OperationTutorialStep(
      targetKey: TutorialTargetKeys.roomUrlRow,
      title: 'ROOM URL',
      body: 'あなたの楽天ROOMのURLを登録します。コレ同期や反応チェックなどに使われます。',
    ),
    OperationTutorialStep(
      title: 'ガイド完了',
      body: '基本設定の場所は把握できました。各項目をタップして、いつでも編集できます。',
    ),
  ],
);
