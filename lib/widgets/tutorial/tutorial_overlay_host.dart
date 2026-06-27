import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/profile_tutorial_targets.dart';
import '../../models/operation_tutorial_id.dart';
import '../../repository/easy_initial_setup_repository.dart';
import '../../state/operation_tutorial_controller.dart';
import '../../state/user_profile_provider.dart';
import 'tutorial_spotlight_layer.dart';

/// 操作ガイドの Overlay 表示ホスト。非表示時は [child] をそのまま返す。
class TutorialOverlayHost extends StatelessWidget {
  const TutorialOverlayHost({super.key, required this.child});

  final Widget child;

  Key? _resolveTargetKey(
    BuildContext context,
    OperationTutorialController tutorial,
  ) {
    final step = tutorial.currentStep;
    if (step == null) return null;
    if (tutorial.activeFlow?.id != OperationTutorialId.profile) {
      return step.targetKey;
    }
    final profile = context.read<UserProfileProvider>().profile;
    final setup = context.read<EasyInitialSetupRepository>();
    final showMyPageSetupCard =
        !setup.initialSetupCompleted && !profile.hasRoomUrl;
    return resolveProfileTutorialStepTargetKey(
      stepIndex: tutorial.stepIndex,
      showMyPageSetupCard: showMyPageSetupCard,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OperationTutorialController>(
      builder: (context, tutorial, _) {
        final step = tutorial.currentStep;
        if (!tutorial.isActive || step == null) {
          return child;
        }
        final targetKey = _resolveTargetKey(context, tutorial);
        return Stack(
          fit: StackFit.expand,
          children: [
            AbsorbPointer(child: child),
            TutorialSpotlightLayer(
              key: ValueKey<Object?>(
                '${tutorial.stepIndex}:${targetKey?.toString() ?? ''}',
              ),
              targetKey: targetKey,
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
