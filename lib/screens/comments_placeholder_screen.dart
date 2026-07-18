import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comment_template.dart';
import '../services/app_action_service.dart';
import '../state/activity_log_provider.dart';
import '../state/comment_template_provider.dart';
import '../theme/app_theme.dart';
import '../theme/comment_screen_tokens.dart';
import '../ui/feedback/app_feedback.dart';
import '../widgets/app_card.dart';
import 'comment_template_edit_screen.dart';

/// 楽天ROOM投稿用コメントの作成・保存・コピーを行う画面。
class CommentsPlaceholderScreen extends StatefulWidget {
  const CommentsPlaceholderScreen({super.key});

  @override
  State<CommentsPlaceholderScreen> createState() =>
      _CommentsPlaceholderScreenState();
}

class _CommentsPlaceholderScreenState extends State<CommentsPlaceholderScreen> {
  /// 直近にコピー操作したテンプレート（自己フィードバック用）。
  String? _feedbackCopiedTemplateId;
  Timer? _copyFeedbackTimer;

  static const _copyFeedbackHold = Duration(milliseconds: 1500);

  @override
  void dispose() {
    _copyFeedbackTimer?.cancel();
    super.dispose();
  }

  List<CommentTemplate> _sortedTemplates(List<CommentTemplate> raw) {
    final list = [...raw]
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) {
          return a.isFavorite ? -1 : 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return list;
  }

  void _armCopyFeedback(String templateId) {
    _copyFeedbackTimer?.cancel();
    setState(() => _feedbackCopiedTemplateId = templateId);
    _copyFeedbackTimer = Timer(_copyFeedbackHold, () {
      if (!mounted) return;
      setState(() => _feedbackCopiedTemplateId = null);
    });
  }

  Future<void> _copyTemplate(
    BuildContext context,
    CommentTemplate template,
  ) async {
    var didCopy = false;
    await AppActionService.copyText(
      context,
      text: template.body,
      successMessage: 'コピーしました',
      onSuccess: () {
        didCopy = true;
        context.read<CommentTemplateProvider>().setLastCopiedComment(
          template.body,
        );
        if (context.mounted) {
          context.read<ActivityLogProvider>().incrementTodayCommentCopyCount();
        }
      },
    );
    if (!mounted || !didCopy) return;
    _armCopyFeedback(template.id);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CommentScreenUi.overlayTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: CommentScreenUi.canvas,
        appBar: AppBar(
          title: const Text('コメント'),
          backgroundColor: CommentScreenUi.canvas,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Consumer<CommentTemplateProvider>(
            builder: (context, provider, _) {
              final templates = _sortedTemplates(provider.templates);
              final copied = provider.lastCopiedComment?.trim();
              final hasCopiedPreview = copied != null && copied.isNotEmpty;

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.screenPaddingH,
                  AppDimensions.spacingSm,
                  AppDimensions.screenPaddingH,
                  MediaQuery.paddingOf(context).bottom + 88,
                ),
                children: [
                  const _CommentScreenPurposeHeader(),
                  if (hasCopiedPreview) ...[
                    const SizedBox(height: 10),
                    _RecentCopiedStrip(text: copied),
                  ],
                  const SizedBox(height: 14),
                  if (templates.isEmpty) ...[
                    _CommentTemplatesEmptyGuide(onAdd: () => _openAdd(context)),
                  ] else ...[
                    Row(
                      children: [
                        Icon(
                          Icons.library_books_outlined,
                          size: 20,
                          color: CommentScreenUi.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'テンプレート一覧',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._buildTemplateCards(context, provider, templates),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openAdd(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            const CommentTemplateEditScreen(initialTemplate: null),
      ),
    );
  }

  List<Widget> _buildTemplateCards(
    BuildContext context,
    CommentTemplateProvider provider,
    List<CommentTemplate> templates,
  ) {
    final last = provider.lastCopiedComment?.trim();
    return [
      for (var i = 0; i < templates.length; i++) ...[
        _CommentTemplateCard(
          template: templates[i],
          justCopied: last != null && last == templates[i].body.trim(),
          showCopyFeedback: _feedbackCopiedTemplateId == templates[i].id,
          onCopy: () => _copyTemplate(context, templates[i]),
          onEdit: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) =>
                    CommentTemplateEditScreen(initialTemplate: templates[i]),
              ),
            );
          },
          onDelete: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('削除の確認'),
                content: const Text('このテンプレートを削除しますか？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('削除'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              provider.deleteTemplate(templates[i]);
              if (context.mounted) {
                AppFeedback.success(context, message: '削除しました');
              }
            }
          },
        ),
        if (i != templates.length - 1) const SizedBox(height: 8),
      ],
    ];
  }
}

/// 短い案内（説明カードはこの1枚まで）。
class _CommentScreenPurposeHeader extends StatelessWidget {
  const _CommentScreenPurposeHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        borderColor: CommentScreenUi.primaryBorder.withValues(alpha: 0.55),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.content_copy_rounded,
              size: 24,
              color: CommentScreenUi.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'よく使うROOMコメントを保存して、ワンタップでコピーできます',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'フォローのお礼・投稿コメント・定型文をここにまとめておけます。テンプレを選び「コピーする」またはカードをタップしてROOMに貼り付けましょう。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 直近コピー（控えめ・履歴があるときだけ上部に表示）。
class _RecentCopiedStrip extends StatelessWidget {
  const _RecentCopiedStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final preview = text.replaceAll('\n', ' ');
    return Material(
      color: CommentScreenUi.primaryLight.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.history_rounded,
              size: 16,
              color: CommentScreenUi.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '最近コピーしたコメント',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTemplatesEmptyGuide extends StatelessWidget {
  const _CommentTemplatesEmptyGuide({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      borderColor: CommentScreenUi.primaryBorder.withValues(alpha: 0.55),
      child: Column(
        children: [
          Icon(
            Icons.post_add_rounded,
            size: 36,
            color: CommentScreenUi.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'よく使うコメントを登録しましょう',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'フォローお礼や投稿文を保存しておくと、ROOM投稿が楽になります。右下の「テンプレートを追加」から登録できます。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_comment_rounded),
            label: const Text('テンプレートを追加'),
            style: CommentScreenUi.primaryButtonStyle(),
          ),
        ],
      ),
    );
  }
}

class _CommentTemplateCard extends StatelessWidget {
  const _CommentTemplateCard({
    required this.template,
    required this.justCopied,
    required this.showCopyFeedback,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  final CommentTemplate template;
  final bool justCopied;
  final bool showCopyFeedback;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final category = template.category?.trim();
    final switchDuration = AppMotion.durationOf(context, AppMotion.fast);
    return AppCard(
      onTap: onCopy,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      elevated: true,
      borderColor: AppColors.divider.withValues(alpha: 0.75),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  template.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
              if (template.isFavorite)
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 1),
                  child: Icon(
                    Icons.star_rounded,
                    size: 20,
                    color: CommentScreenUi.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            template.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.32,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (category != null && category.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: CommentScreenUi.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: CommentScreenUi.primaryBorder),
                  ),
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: CommentScreenUi.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Text(
                  'カテゴリー未設定',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (justCopied)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '直近にコピー',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'カードの余白をタップしてもコピーできます',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: Key('comment_template_copy_${template.id}'),
                  onPressed: onCopy,
                  icon: AnimatedSwitcher(
                    duration: switchDuration,
                    switchInCurve: AppMotion.standard,
                    switchOutCurve: AppMotion.standard,
                    child: Icon(
                      showCopyFeedback
                          ? Icons.check_rounded
                          : Icons.copy_rounded,
                      key: ValueKey<bool>(showCopyFeedback),
                      size: 20,
                    ),
                  ),
                  label: AnimatedSwitcher(
                    duration: switchDuration,
                    switchInCurve: AppMotion.standard,
                    switchOutCurve: AppMotion.standard,
                    child: Text(
                      showCopyFeedback ? 'コピー済み' : 'クリップボードにコピーする',
                      key: ValueKey<bool>(showCopyFeedback),
                    ),
                  ),
                  style: CommentScreenUi.copyButtonStyle(),
                ),
              ),
              IconButton(
                tooltip: '編集する',
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary),
              ),
              IconButton(
                tooltip: '削除する',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
