import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comment_template.dart';
import '../services/app_action_service.dart';
import '../state/comment_template_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import 'comment_template_edit_screen.dart';

/// 楽天ROOM投稿用コメントの作成・保存・コピーを行う画面。
class CommentsPlaceholderScreen extends StatelessWidget {
  const CommentsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('コメント')),
      body: SafeArea(
        child: Consumer<CommentTemplateProvider>(
          builder: (context, provider, _) {
            final templates = provider.templates;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenPaddingH,
                AppDimensions.spacingSm,
                AppDimensions.screenPaddingH,
                80,
              ),
              children: [
                const _CommentScreenPurposeHeader(),
                const SizedBox(height: AppDimensions.spacingMd),
                const _AiSuggestionFuturePlaceholder(),
                const SizedBox(height: AppDimensions.spacingSm),
                _RecentCopiedCard(text: provider.lastCopiedComment),
                const SizedBox(height: AppDimensions.spacingMd),
                if (templates.isEmpty)
                  _CommentTemplatesEmptyGuide()
                else
                  ..._buildTemplateCards(context, provider, templates),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_comments_template_add',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) =>
                  const CommentTemplateEditScreen(initialTemplate: null),
            ),
          );
        },
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }

  List<Widget> _buildTemplateCards(
    BuildContext context,
    CommentTemplateProvider provider,
    List<CommentTemplate> templates,
  ) {
    return [
      for (final t in templates) ...[
        _CommentTemplateCard(
          template: t,
          onCopy: () async {
            await AppActionService.copyText(
              context,
              text: t.body,
              onSuccess: () => provider.setLastCopiedComment(t.body),
            );
          },
          onEdit: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) =>
                    CommentTemplateEditScreen(initialTemplate: t),
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
                  AppSecondaryButton(
                    label: 'キャンセル',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                  AppSecondaryButton(
                    label: '削除',
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ],
              ),
            );
            if (ok == true) {
              provider.deleteTemplate(t);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('削除しました')));
              }
            }
          },
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

/// この画面の目的を冒頭で伝える。
class _CommentScreenPurposeHeader extends StatelessWidget {
  const _CommentScreenPurposeHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 26,
              color: AppColors.accentPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '楽天ROOMに投稿するコメントを作成・保存できます',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '保存した文は一覧からワンタップでコピーし、ROOMの投稿欄に貼り付けられます。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
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

/// テンプレート活用のヒント欄。
class _AiSuggestionFuturePlaceholder extends StatelessWidget {
  const _AiSuggestionFuturePlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 18,
              color: AppColors.accentPrimary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'テンプレートをジャンルや用途別に分けておくと、投稿のたびに迷いにくくなります。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// テンプレがまだないときのガイド。
class _CommentTemplatesEmptyGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        borderColor: AppColors.accentLight.withValues(alpha: 0.6),
        child: Column(
          children: [
            Icon(
              Icons.post_add_outlined,
              size: 40,
              color: AppColors.accentPrimary.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 12),
            Text(
              'コメントを作成して保存すると、すぐにコピーできます',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '右下の＋ボタンから、よく使う投稿文をテンプレートとして登録してください。'
              '一覧ではタップまたはコピーアイコンでクリップボードに送れます。'
              'ジャンルごとに登録しておくと、あとから整理しやすくなります。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentCopiedCard extends StatelessWidget {
  const _RecentCopiedCard({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '最近コピーしたコメント',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text == null || text!.isEmpty
                ? 'まだコピー履歴がありません。テンプレか商品のコメントをコピーするとここに表示されます。'
                : text!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _CommentTemplateCard extends StatelessWidget {
  const _CommentTemplateCard({
    required this.template,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  final CommentTemplate template;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onCopy,
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      elevated: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        template.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (template.isFavorite)
                      Icon(
                        Icons.star,
                        size: 18,
                        color: AppColors.accentSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  template.body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if ((template.category ?? '').isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentLightest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'ジャンル: ${template.category!}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.accentPrimary,
                                fontSize: 11,
                              ),
                        ),
                      )
                    else
                      Text(
                        'ジャンル未設定',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      'タップでコピー',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: onCopy,
                  tooltip: 'コピー',
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: '編集',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                  tooltip: '削除',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
