import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/room_type_definitions.dart';
import '../models/room_recommendation_profile.dart';
import '../navigation/app_shell_controller.dart';
import '../services/room_diagnosis_service.dart';
import '../theme/mypage_screen_tokens.dart';
import '../widgets/mypage/mypage_widgets.dart';
import '../widgets/room_type_diagnosis_widgets.dart';

/// 診断完了後にタイプ結果を表示する画面。
class RoomTypeDiagnosisResultScreen extends StatelessWidget {
  const RoomTypeDiagnosisResultScreen({
    super.key,
    required this.profile,
  });

  final RoomRecommendationProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeDef = RoomTypeDefinitions.byId(profile.primaryTypeId);
    final typeName = typeDef?.displayName ??
        RoomTypeDefinitions.displayNameFor(profile.primaryTypeId);
    final interestLabel =
        RoomDiagnosisService.interestCategoriesLabel(profile.interestCategoryIds);
    final priorityLabel =
        RoomDiagnosisService.priorityRulesLabel(profile.priorityRuleIds);
    final narrative = RoomDiagnosisService.buildResultNarrative(
      primaryTypeId: profile.primaryTypeId,
      interestCategoryIds: profile.interestCategoryIds,
      priorityRuleIds: profile.priorityRuleIds,
    );

    return PopScope(
      canPop: true,
      child: Scaffold(
      backgroundColor: MyPageScreenUi.canvas,
      appBar: AppBar(
        title: const Text('診断結果'),
        backgroundColor: MyPageScreenUi.canvas,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'あなたは',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: MyPageScreenUi.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            RoomTypeBadge(typeDisplayName: typeName),
            const SizedBox(height: 14),
            Text(
              narrative,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: MyPageScreenUi.textSecondary,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (interestLabel.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '関心ジャンル',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: MyPageScreenUi.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                interestLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (priorityLabel.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '重視する条件',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: MyPageScreenUi.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                priorityLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 28),
            MyPagePrimaryButton(
              key: const Key('diagnosis_result_go_home'),
              label: 'ホームへ戻る',
              onPressed: () => _goHome(context),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('diagnosis_result_go_mypage'),
              onPressed: () => _goMyPage(context),
              style: MyPageScreenUi.outlineButtonStyle(height: 48),
              child: const Text('マイページへ戻る'),
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _goHome(BuildContext context) {
    context.read<AppShellController>().selectTab(0);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _goMyPage(BuildContext context) {
    context.read<AppShellController>().selectTab(4);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
