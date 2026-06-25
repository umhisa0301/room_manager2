import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/comment_tone_definitions.dart';
import '../data/interest_category_definitions.dart';
import '../data/priority_rule_definitions.dart';
import '../data/room_type_definitions.dart';
import '../models/room_recommendation_profile.dart';
import '../state/room_recommendation_profile_provider.dart';
import '../theme/mypage_screen_tokens.dart';
import '../widgets/mypage/mypage_widgets.dart';

/// ROOMタイプ診断画面（5問以内）。
class RoomTypeDiagnosisScreen extends StatefulWidget {
  const RoomTypeDiagnosisScreen({super.key});

  @override
  State<RoomTypeDiagnosisScreen> createState() =>
      _RoomTypeDiagnosisScreenState();
}

class _RoomTypeDiagnosisScreenState extends State<RoomTypeDiagnosisScreen> {
  final PageController _controller = PageController();
  int _pageIndex = 0;

  String? _primaryTypeId;
  final Set<String> _priorityRuleIds = {};
  final Set<String> _interestCategoryIds = {};
  String? _commentToneId;

  static const int _maxPriority = 3;
  static const int _maxCategories = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canProceed {
    switch (_pageIndex) {
      case 0:
        return _primaryTypeId != null;
      case 1:
        return _priorityRuleIds.isNotEmpty;
      case 2:
        return _interestCategoryIds.isNotEmpty;
      case 3:
        return _commentToneId != null;
      default:
        return true;
    }
  }

  Future<void> _submit() async {
    final answers = RoomDiagnosisAnswers(
      primaryTypeId: _primaryTypeId ?? '',
      priorityRuleIds: _priorityRuleIds.toList(growable: false),
      interestCategoryIds: _interestCategoryIds.toList(growable: false),
      commentToneId: _commentToneId ?? '',
    );
    await context
        .read<RoomRecommendationProfileProvider>()
        .saveFromDiagnosis(answers);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _next() {
    if (_pageIndex >= 3) {
      _submit();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: MyPageScreenUi.canvas,
      appBar: AppBar(
        title: const Text('ROOMタイプ診断'),
        backgroundColor: MyPageScreenUi.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '質問 ${_pageIndex + 1} / 4',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _pageIndex = i),
                  children: [
                    _QuestionCard(
                      title: 'ROOMで紹介したい商品は、どれに近いですか？',
                      child: _SingleChoiceList(
                        options: RoomTypeDefinitions.all
                            .map(
                              (t) => _ChoiceOption(
                                id: t.id,
                                label: t.displayName,
                                subtitle: t.description,
                              ),
                            )
                            .toList(),
                        selectedId: _primaryTypeId,
                        onSelected: (id) => setState(() => _primaryTypeId = id),
                      ),
                    ),
                    _QuestionCard(
                      title: 'おすすめコレで重視したいものは？',
                      subtitle: '最大3つまで選べます',
                      child: _MultiChoiceList(
                        options: PriorityRuleDefinitions.all
                            .map(
                              (r) => _ChoiceOption(
                                id: r.id,
                                label: r.displayName,
                              ),
                            )
                            .toList(),
                        selectedIds: _priorityRuleIds,
                        maxSelection: _maxPriority,
                        onChanged: (ids) =>
                            setState(() => _priorityRuleIds..clear()..addAll(ids)),
                      ),
                    ),
                    _QuestionCard(
                      title: 'よく見たい・紹介したいジャンルを選んでください',
                      subtitle: '最大5つまで選べます',
                      child: _MultiChoiceList(
                        options: InterestCategoryDefinitions.all
                            .map(
                              (c) => _ChoiceOption(
                                id: c.id,
                                label: c.displayName,
                              ),
                            )
                            .toList(),
                        selectedIds: _interestCategoryIds,
                        maxSelection: _maxCategories,
                        onChanged: (ids) => setState(
                          () => _interestCategoryIds..clear()..addAll(ids),
                        ),
                      ),
                    ),
                    _QuestionCard(
                      title: '投稿文はどんな雰囲気が合いそうですか？',
                      child: _SingleChoiceList(
                        options: CommentToneDefinitions.all
                            .map(
                              (t) => _ChoiceOption(
                                id: t.id,
                                label: t.displayName,
                              ),
                            )
                            .toList(),
                        selectedId: _commentToneId,
                        onSelected: (id) => setState(() => _commentToneId = id),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              MyPagePrimaryButton(
                label: _pageIndex >= 3 ? '診断結果を保存' : '次へ',
                onPressed: _canProceed ? _next : null,
              ),
              if (_pageIndex > 0) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    _controller.previousPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  style: MyPageScreenUi.outlineButtonStyle(height: 44),
                  child: const Text('戻る'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MyPageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: MyPageScreenUi.textPrimary,
              height: 1.35,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: MyPageScreenUi.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ChoiceOption {
  const _ChoiceOption({
    required this.id,
    required this.label,
    this.subtitle,
  });

  final String id;
  final String label;
  final String? subtitle;
}

class _SingleChoiceList extends StatelessWidget {
  const _SingleChoiceList({
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_ChoiceOption> options;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: options.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final opt = options[index];
        final selected = selectedId == opt.id;
        return _ChoiceTile(
          label: opt.label,
          subtitle: opt.subtitle,
          selected: selected,
          onTap: () => onSelected(opt.id),
        );
      },
    );
  }
}

class _MultiChoiceList extends StatelessWidget {
  const _MultiChoiceList({
    required this.options,
    required this.selectedIds,
    required this.maxSelection,
    required this.onChanged,
  });

  final List<_ChoiceOption> options;
  final Set<String> selectedIds;
  final int maxSelection;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: options.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final opt = options[index];
        final selected = selectedIds.contains(opt.id);
        return _ChoiceTile(
          label: opt.label,
          selected: selected,
          onTap: () {
            final next = Set<String>.from(selectedIds);
            if (selected) {
              next.remove(opt.id);
            } else if (next.length < maxSelection) {
              next.add(opt.id);
            }
            onChanged(next);
          },
        );
      },
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? MyPageScreenUi.primary.withValues(alpha: 0.08)
          : MyPageScreenUi.cardFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? MyPageScreenUi.primary.withValues(alpha: 0.45)
                  : MyPageScreenUi.cardBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? MyPageScreenUi.primary
                    : MyPageScreenUi.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: MyPageScreenUi.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: MyPageScreenUi.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
