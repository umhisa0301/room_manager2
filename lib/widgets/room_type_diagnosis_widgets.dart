import 'package:flutter/material.dart';

import '../theme/home_screen_colors.dart';
import '../theme/mypage_screen_tokens.dart';
import '../widgets/mypage/mypage_widgets.dart';

/// 未診断時にホームへ表示する診断促進カード。
class HomeRoomTypeDiagnosisCard extends StatelessWidget {
  const HomeRoomTypeDiagnosisCard({
    super.key,
    required this.onStartDiagnosis,
    required this.onLater,
  });

  final VoidCallback onStartDiagnosis;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: HomeScreenColors.homeCardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeScreenColors.homeCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'あなたに合うコレ候補を見つけませんか？',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomeScreenColors.homeTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '簡単な質問に答えると、おすすめコレや投稿文の方向性に反映できます。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: HomeScreenColors.homeTextSecondary,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          MyPagePrimaryButton(
            label: 'かんたん診断する',
            height: 44,
            onPressed: onStartDiagnosis,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: onLater,
              child: Text(
                'あとで',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 診断済み時にホームへ表示するタイプ表示カード。
class HomeRoomTypeSummaryCard extends StatelessWidget {
  const HomeRoomTypeSummaryCard({
    super.key,
    required this.typeDisplayName,
  });

  final String typeDisplayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: HomeScreenColors.homeCardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeScreenColors.homeCardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: MyPageScreenUi.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'あなたのROOMタイプ：$typeDisplayName',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: HomeScreenColors.homeTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'おすすめコレに反映されています。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: HomeScreenColors.homeTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// おすすめコレ押下時の未診断促進BottomSheet。
class RoomTypeDiagnosisPromptSheet extends StatelessWidget {
  const RoomTypeDiagnosisPromptSheet({
    super.key,
    required this.onStartDiagnosis,
    required this.onSkip,
  });

  final VoidCallback onStartDiagnosis;
  final VoidCallback onSkip;

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MyPageScreenUi.cardFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => RoomTypeDiagnosisPromptSheet(
        onStartDiagnosis: () => Navigator.pop(ctx, true),
        onSkip: () => Navigator.pop(ctx, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MyPageScreenUi.cardBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ROOMタイプを設定すると、あなたに合ったコレ候補を出しやすくなります。',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: MyPageScreenUi.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '診断はあとからマイページでやり直せます。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: MyPageScreenUi.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          MyPagePrimaryButton(
            label: 'かんたん診断する',
            onPressed: onStartDiagnosis,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onSkip,
            style: MyPageScreenUi.outlineButtonStyle(height: 48),
            child: const Text('診断せずに見る'),
          ),
        ],
      ),
    );
  }
}

/// マイページのROOMタイプ診断セクション。
class MyPageRoomTypeDiagnosisCard extends StatelessWidget {
  const MyPageRoomTypeDiagnosisCard({
    super.key,
    required this.isDiagnosed,
    required this.typeDisplayName,
    required this.interestLabel,
    required this.priorityLabel,
    required this.onAction,
    this.actionLabel = '診断する',
  });

  final bool isDiagnosed;
  final String typeDisplayName;
  final String interestLabel;
  final String priorityLabel;
  final VoidCallback onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MyPageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MyPageSectionHeaderRow(title: 'ROOMタイプ診断'),
          const SizedBox(height: 8),
          if (!isDiagnosed)
            Text(
              'あなたに合うコレ候補や投稿文の方向性を提案しやすくします。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: MyPageScreenUi.textSecondary,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            )
          else ...[
            Text(
              '現在：$typeDisplayName',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: MyPageScreenUi.textPrimary,
              ),
            ),
            if (interestLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '関心ジャンル：$interestLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (priorityLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '重視する条件：$priorityLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          MyPagePrimaryButton(
            label: actionLabel,
            height: 44,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}
