import 'package:flutter/foundation.dart';

import 'operation_tutorial_target_action_id.dart';

/// 1 ステップ分のハイライト対象と説明文。
@immutable
class OperationTutorialStep {
  const OperationTutorialStep({
    this.targetKey,
    this.targetActionId,
    required this.title,
    required this.body,
  });

  /// ハイライト対象。`null` のときは説明カードのみ（全体案内・完了など）。
  final Key? targetKey;

  /// ハイライト対象タップ時の画面遷移。`null` のときはオーバーレイ側タップ領域なし。
  final OperationTutorialTargetActionId? targetActionId;

  final String title;
  final String body;
}
