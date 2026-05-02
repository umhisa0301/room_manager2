import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../models/product_status.dart';
import '../models/comment_template.dart';
import '../state/product_list_provider.dart';
import '../state/activity_log_provider.dart';
import '../state/comment_template_provider.dart';
import '../services/app_action_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_loading.dart';
import 'product_edit_screen.dart';

/// 商品詳細画面。表示・編集・削除・ステータス変更。
class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  static Route<void> route(Product product) {
    return MaterialPageRoute<void>(
      builder: (_) => ProductDetailScreen(productId: product.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductListProvider>(
      builder: (context, provider, _) {
        final product = provider.findById(productId);
        if (product == null) {
          // 削除済みなどで商品が無い場合は一覧へ戻す（pop は 1 回だけ・mounted を確認）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.of(context).maybePop();
          });
          return const Scaffold(
            body: Center(
              child: AppLoadingView(message: '商品情報を確認しています', inline: false),
            ),
          );
        }
        return _DetailBody(product: product);
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.product});

  final Product product;

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final commentProvider = context.watch<CommentTemplateProvider>();
    final templates = commentProvider.templates;
    final recentCopied = commentProvider.lastCopiedComment;
    final hasQuickComment =
        product.quickComment != null && product.quickComment!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('商品詳細'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => ProductEditScreen(product: product),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteConfirm(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
        children: [
          _SectionCard(
            title: '商品基本情報',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => AppActionService.openUrl(
                    context,
                    url: product.productUrl,
                  ),
                  child: Text(
                    product.productUrl,
                    style: _bodyStyle(context)?.copyWith(
                      color: AppColors.accentPrimary,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 10),
                _StatusChunks(product: product),
                const SizedBox(height: 8),
                product.tags.isEmpty
                    ? Text('タグなし', style: _captionStyle(context))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: product.tags
                            .map((t) => _chip(context, t))
                            .toList(),
                      ),
                const SizedBox(height: 10),
                AppSecondaryButton(
                  label: '商品URLを開く',
                  onPressed: () => AppActionService.openUrl(
                    context,
                    url: product.productUrl,
                  ),
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'メモ',
            child: Text(
              (product.memo ?? '').trim().isEmpty
                  ? 'メモはまだありません'
                  : product.memo!,
              style: _bodyStyle(context),
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'ひとことコメント',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: AppCard(
                    padding: const EdgeInsets.all(10),
                    backgroundColor: AppColors.accentLightest,
                    borderColor: AppColors.accentLightest,
                    radius: 10,
                    child: Text(
                      hasQuickComment
                          ? product.quickComment!.trim()
                          : 'まだ設定されていません',
                      style: _bodyStyle(context),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AppSecondaryButton(
                      label: 'コピー',
                      onPressed: hasQuickComment
                          ? () => AppActionService.copyText(
                              context,
                              text: product.quickComment!.trim(),
                              onSuccess: () {
                                context
                                    .read<CommentTemplateProvider>()
                                    .setLastCopiedComment(
                                      product.quickComment!.trim(),
                                    );
                                context
                                    .read<ActivityLogProvider>()
                                    .incrementTodayCommentCopyCount();
                              },
                            )
                          : null,
                      icon: const Icon(Icons.copy),
                    ),
                    const SizedBox(width: 8),
                    AppSecondaryButton(
                      label: '編集',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                ProductEditScreen(product: product),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: '最近コピーしたコメント',
            child: Text(
              (recentCopied ?? '').trim().isEmpty
                  ? 'まだコピー履歴がありません'
                  : recentCopied!,
              style: _bodyStyle(context),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'コメント関連アクション',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSecondaryButton(
                  label: 'テンプレから選ぶ',
                  onPressed: templates.isEmpty
                      ? null
                      : () => _showTemplatePicker(context, templates),
                  icon: const Icon(Icons.article_outlined),
                  expand: true,
                  height: 44,
                ),
                const SizedBox(height: 8),
                AppPrimaryButton(
                  label: 'コメントをコピーしてURLを開く',
                  onPressed: hasQuickComment
                      ? () => AppActionService.copyThenOpenUrl(
                          context,
                          text: product.quickComment!.trim(),
                          url: product.productUrl,
                          onCopied: () {
                            context
                                .read<CommentTemplateProvider>()
                                .setLastCopiedComment(
                                  product.quickComment!.trim(),
                                );
                            context
                                .read<ActivityLogProvider>()
                                .incrementTodayCommentCopyCount();
                          },
                        )
                      : null,
                  icon: const Icon(Icons.rocket_launch_outlined),
                  height: 44,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: '管理アクション',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSecondaryButton(
                  label: '商品を編集',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            ProductEditScreen(product: product),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  expand: true,
                  height: 44,
                ),
                const SizedBox(height: 8),
                AppSecondaryButton(
                  label: '商品を削除',
                  onPressed: () => _showDeleteConfirm(context),
                  icon: const Icon(Icons.delete_outline),
                  expand: true,
                  height: 44,
                ),
                const SizedBox(height: 10),
                Text(
                  '作成: ${_formatDate(product.createdAt)}\n更新: ${_formatDate(product.updatedAt)}',
                  style: _captionStyle(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle? _bodyStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary);

  TextStyle? _captionStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

  Widget _chip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentLightest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.accentPrimary),
      ),
    );
  }

  Future<void> _showTemplatePicker(
    BuildContext context,
    List<CommentTemplate> templates,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final t = templates[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                title: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  t.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: t.isFavorite
                    ? const Icon(Icons.star, color: AppColors.accentSecondary)
                    : null,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await AppActionService.copyText(
                    context,
                    text: t.body,
                    onSuccess: () {
                      context
                          .read<CommentTemplateProvider>()
                          .setLastCopiedComment(t.body);
                      context
                          .read<ActivityLogProvider>()
                          .incrementTodayCommentCopyCount();
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('削除の確認'),
        content: const Text('本当に削除しますか？'),
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
    if (ok != true || !context.mounted) return;

    // 削除前に必要な参照を取得。pop 後に context を使わない。
    final navigator = Navigator.of(context);
    final provider = context.read<ProductListProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final productToDelete = product;

    // 1. 先に詳細画面を閉じる（削除済みデータで rebuild させない）
    navigator.pop();

    // 2. 一覧に戻ったあとで state とローカル保存から削除
    provider.deleteProduct(productToDelete);
    messenger.showSnackBar(const SnackBar(content: Text('削除しました')));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// ステータス変更チップ。タップで更新しタブに反映。
class _StatusChunks extends StatelessWidget {
  const _StatusChunks({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductListProvider>(
      builder: (context, provider, _) {
        final current = provider.findById(product.id);
        final status = current?.status ?? product.status;
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: ProductStatus.values.map((s) {
            final selected = status == s;
            return FilterChip(
              label: Text(s.label),
              selected: selected,
              onSelected: (_) {
                provider.updateProduct(
                  product.copyWith(status: s, updatedAt: DateTime.now()),
                );
              },
              selectedColor: AppColors.accentLight,
              checkmarkColor: AppColors.accentPrimary,
              labelStyle: TextStyle(
                fontSize: 13,
                color: selected
                    ? AppColors.accentPrimary
                    : AppColors.textPrimary,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
