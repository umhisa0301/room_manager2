import 'package:flutter/foundation.dart';

/// 1 ステップ分のハイライト対象と説明文。
@immutable
class OperationTutorialStep {
  const OperationTutorialStep({
    this.targetKey,
    required this.title,
    required this.body,
  });

  /// ハイライト対象。`null` のときは説明カードのみ（全体案内・完了など）。
  final Key? targetKey;

  final String title;
  final String body;
}
