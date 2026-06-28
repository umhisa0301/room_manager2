import 'package:flutter/material.dart';

import '../widgets/tutorial/tutorial_target_keys.dart';

import '../theme/home_screen_colors.dart';
import '../theme/mypage_screen_tokens.dart';
import '../widgets/mypage/mypage_widgets.dart';

/// 診断タイプ名のバッジ表示。
class RoomTypeBadge extends StatelessWidget {
  const RoomTypeBadge({
    super.key,
    required this.typeDisplayName,
    this.compact = false,
  });

  final String typeDisplayName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: MyPageScreenUi.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyPageScreenUi.primaryBorder),
      ),
      child: Text(
        typeDisplayName,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: MyPageScreenUi.primary,
          height: 1.25,
        ),
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
            'あなたに合うコレ候補を見つけやすくします',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: MyPageScreenUi.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'かんたんな質問に答えると、興味のあるジャンルや重視したい条件をもとに、おすすめコレを提案できます。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: MyPageScreenUi.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.45,
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
class MyPageRoomTypeDiagnosisCard extends StatefulWidget {
  const MyPageRoomTypeDiagnosisCard({
    super.key,
    required this.isDiagnosed,
    required this.typeDisplayName,
    required this.interestLabel,
    required this.priorityLabel,
    required this.commentToneLabel,
    required this.onStartDiagnosis,
    required this.onRetakeDiagnosis,
  });

  final bool isDiagnosed;
  final String typeDisplayName;
  final String interestLabel;
  final String priorityLabel;
  final String commentToneLabel;
  final VoidCallback onStartDiagnosis;
  final VoidCallback onRetakeDiagnosis;

  @override
  State<MyPageRoomTypeDiagnosisCard> createState() =>
      _MyPageRoomTypeDiagnosisCardState();
}

class _MyPageRoomTypeDiagnosisCardState extends State<MyPageRoomTypeDiagnosisCard> {
  bool _detailsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MyPageCard(
      key: TutorialTargetKeys.roomTypeDiagnosisCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MyPageSectionHeaderRow(
            title: 'ROOMタイプ診断',
            trailingChip: widget.isDiagnosed
                ? const MyPageStatusChip(
                    label: '診断済み',
                    variant: MyPageStatusChipVariant.set,
                  )
                : null,
          ),
          if (!widget.isDiagnosed) ...[
            const SizedBox(height: 6),
            Text(
              'あなたに合うコレ候補や投稿文の方向性が分かりやすくなります。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: MyPageScreenUi.textSecondary,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            MyPagePrimaryButton(
              label: '診断する',
              height: 44,
              onPressed: widget.onStartDiagnosis,
            ),
          ] else ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'あなたのタイプ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: MyPageScreenUi.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.typeDisplayName,
                      key: const Key('room_type_diagnosis_result_name'),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: MyPageScreenUi.primary,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: MyPageScreenUi.cardBorder),
            if (_detailsExpanded) ...[
              if (widget.interestLabel.isNotEmpty)
                _DetailRow(label: '関心ジャンル', value: widget.interestLabel),
              if (widget.priorityLabel.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DetailRow(label: '重視する条件', value: widget.priorityLabel),
              ],
              if (widget.commentToneLabel.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DetailRow(
                  label: '投稿文の雰囲気',
                  value: widget.commentToneLabel,
                ),
              ],
              const SizedBox(height: 8),
              Divider(height: 1, color: MyPageScreenUi.cardBorder),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const Key('room_type_diagnosis_details_button'),
                      onPressed: () =>
                          setState(() => _detailsExpanded = !_detailsExpanded),
                      style: MyPageScreenUi.linkTextButtonStyle(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_detailsExpanded ? '詳細を閉じる' : '詳細を見る'),
                          Icon(
                            _detailsExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      key: const Key('room_type_diagnosis_retake_button'),
                      onPressed: widget.onRetakeDiagnosis,
                      style: MyPageScreenUi.linkTextButtonStyle(),
                      child: const Text('診断をやり直す'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: MyPageScreenUi.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: MyPageScreenUi.textSecondary,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// ホームのおすすめコレ導線向け、診断タイプの控えめな補足文言。
class HomeRoomTypeHintText extends StatelessWidget {
  const HomeRoomTypeHintText({super.key, required this.typeDisplayName});

  final String typeDisplayName;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$typeDisplayNameに合わせて提案',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: HomeScreenColors.homeTextSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
    );
  }
}
