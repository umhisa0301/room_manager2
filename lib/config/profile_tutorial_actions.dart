import 'package:flutter/material.dart';

import '../models/operation_tutorial_target_action_id.dart';
import '../screens/easy_initial_setup_screen.dart';
import '../screens/mypage_placeholder_screen.dart';
import '../screens/room_type_diagnosis_screen.dart';

/// プロフィール操作ガイドの targetAction に対応する画面遷移を実行する。
Future<void> executeProfileTutorialTargetAction(
  BuildContext context,
  OperationTutorialTargetActionId action,
) async {
  switch (action) {
    case OperationTutorialTargetActionId.profileSetup:
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const EasyInitialSetupScreen(
            embeddedInEntryHost: false,
            initialPageIndex: 0,
          ),
        ),
      );
    case OperationTutorialTargetActionId.profileEdit:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const ProfileEditSheet(),
      );
    case OperationTutorialTargetActionId.roomTypeDiagnosis:
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const RoomTypeDiagnosisScreen(),
        ),
      );
  }
}
