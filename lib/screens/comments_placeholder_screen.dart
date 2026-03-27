import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/comment_template_provider.dart';
import '../models/comment_template.dart';
import '../services/app_action_service.dart';
import 'comment_template_edit_screen.dart';

/// コメントテンプレ一覧画面。
/// ・最近コピーしたコメント
/// ・テンプレ一覧
/// ・テンプレ追加 FAB
class CommentsPlaceholderScreen extends StatelessWidget {
  const CommentsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('コメント'),
      ),
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
                _RecentCopiedCard(text: provider.lastCopiedComment),
                const SizedBox(height: AppDimensions.spacingMd),
                if (templates.isEmpty)
                  Text(
                    'まだコメントテンプレがありません。\n右下のボタンから追加できます。',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  )
                else
                  ..._buildTemplateCards(context, provider, templates),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
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
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child:
                        Text('削除', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            );
            if (ok == true) {
              provider.deleteTemplate(t);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('削除しました')),
                );
              }
            }
          },
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _RecentCopiedCard extends StatelessWidget {
  const _RecentCopiedCard({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '最近コピーしたコメント',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text == null || text!.isEmpty
                ? 'まだコピー履歴がありません。テンプレか商品のコメントをコピーするとここに表示されます。'
                : text!,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textPrimary),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
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
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
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
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
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
                              template.category!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.accentPrimary,
                                    fontSize: 11,
                                  ),
                            ),
                          )
                        else
                          Text(
                            'カテゴリーなし',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
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
              Column(
                mainAxisSize: MainAxisSize.min,
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
            ],
          ),
        ),
      ),
    );
  }
}

