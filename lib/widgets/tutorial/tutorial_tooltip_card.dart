import 'package:flutter/material.dart';

import '../../theme/mypage_screen_tokens.dart';

/// 操作ガイドの説明カード（「次へ」「スキップ」）。
class TutorialTooltipCard extends StatelessWidget {
  const TutorialTooltipCard({
    super.key,
    required this.title,
    required this.body,
    required this.stepLabel,
    required this.isLastStep,
    required this.onNext,
    required this.onSkip,
  });

  final String title;
  final String body;
  final String stepLabel;
  final bool isLastStep;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(MyPageScreenUi.cardRadius),
      color: MyPageScreenUi.cardFill,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MyPageScreenUi.cardRadius),
          border: Border.all(color: MyPageScreenUi.cardBorder),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: MyPageScreenUi.textPrimary,
                    ),
                  ),
                ),
                Text(
                  stepLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: MyPageScreenUi.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: MyPageScreenUi.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  key: const Key('tutorial_skip_button'),
                  onPressed: onSkip,
                  child: const Text('スキップ'),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('tutorial_next_button'),
                  onPressed: onNext,
                  style: MyPageScreenUi.primaryButtonStyle(height: 40).copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(120, 40)),
                  ),
                  child: Text(isLastStep ? '完了' : '次へ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
