import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/operation_tutorial_controller.dart';
import 'tutorial_spotlight_layer.dart';

/// 操作ガイドの Overlay 表示ホスト。非表示時は [child] をそのまま返す。
class TutorialOverlayHost extends StatelessWidget {
  const TutorialOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<OperationTutorialController>(
      builder: (context, tutorial, _) {
        final step = tutorial.currentStep;
        if (!tutorial.isActive || step == null) {
          return child;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            TutorialSpotlightLayer(
              key: ValueKey<int>(tutorial.stepIndex),
              targetKey: step.targetKey,
              title: step.title,
              body: step.body,
              stepLabel: '${tutorial.stepIndex + 1} / ${tutorial.stepCount}',
              isLastStep: tutorial.isLastStep,
              onNext: tutorial.nextStep,
              onSkip: tutorial.skip,
            ),
          ],
        );
      },
    );
  }
}
