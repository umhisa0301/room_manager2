import 'package:flutter/foundation.dart';

import 'operation_tutorial_id.dart';
import 'operation_tutorial_step.dart';

/// 操作ガイドのステップ列。
@immutable
class OperationTutorialFlow {
  const OperationTutorialFlow({
    required this.id,
    required this.steps,
  });

  final OperationTutorialId id;
  final List<OperationTutorialStep> steps;
}
