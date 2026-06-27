import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/profile_tutorial_actions.dart';
import '../../config/profile_tutorial_targets.dart';
import '../../models/operation_tutorial_id.dart';
import '../../models/operation_tutorial_target_action_id.dart';
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

  OperationTutorialTargetActionId? _resolveTargetAction(
    BuildContext context,
    OperationTutorialController tutorial,
  ) {
    final step = tutorial.currentStep;
    if (step == null) return null;
    if (tutorial.activeFlow?.id == OperationTutorialId.profile) {
      final profile = context.read<UserProfileProvider>().profile;
      final setup = context.read<EasyInitialSetupRepository>();
      final showMyPageSetupCard =
          !setup.initialSetupCompleted && !profile.hasRoomUrl;
      return resolveProfileTutorialStepTargetAction(
        stepIndex: tutorial.stepIndex,
        showMyPageSetupCard: showMyPageSetupCard,
      );
    }
    return step.targetActionId;
  }

  Future<void> _handleTargetTap(
    BuildContext context,
    OperationTutorialController tutorial,
    OperationTutorialTargetActionId action,
  ) async {
    await tutorial.closeForTargetAction();
    if (!context.mounted) return;
    await executeProfileTutorialTargetAction(context, action);
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
        final targetAction = _resolveTargetAction(context, tutorial);
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
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
              onTargetTap: targetAction == null
                  ? null
                  : () => _handleTargetTap(context, tutorial, targetAction),
            ),
          ],
        );
      },
    );
  }
}
