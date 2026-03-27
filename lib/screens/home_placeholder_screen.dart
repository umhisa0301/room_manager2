import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity_log.dart';
import '../models/product.dart';
import '../models/product_status.dart';
import '../screens/comments_placeholder_screen.dart';
import '../screens/activity_placeholder_screen.dart';
import '../screens/product_add_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/products_placeholder_screen.dart';
import '../services/app_action_service.dart';
import '../state/activity_log_provider.dart';
import '../state/comment_template_provider.dart';
import '../state/product_list_provider.dart';
import '../theme/app_theme.dart';

/// ホーム（ダッシュボード）画面。
/// 現在の運用状況を把握し、次の操作へ素早く遷移できる構成にする。
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ホーム'),
      ),
      body: SafeArea(
        child: Consumer2<ProductListProvider, CommentTemplateProvider>(
          builder: (context, productProvider, commentProvider, _) {
            final products = productProvider.products;
            final candidateCount =
                productProvider.byStatus(ProductStatus.candidate).length;
            final collectedCount =
                productProvider.byStatus(ProductStatus.collected).length;
            final archivedCount =
                productProvider.byStatus(ProductStatus.archived).length;
            final templateCount = commentProvider.templates.length;
            final recentCopied = commentProvider.lastCopiedComment;
            final recentProducts = _recentProducts(products);
            final activityProvider = context.watch<ActivityLogProvider>();
            final todayLog = activityProvider.getTodayLog();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenPaddingH,
                AppDimensions.spacingMd,
                AppDimensions.screenPaddingH,
                90,
              ),
              children: [
                _HeaderSection(),
                const SizedBox(height: 12),
                _SummaryGrid(
                  candidateCount: candidateCount,
                  collectedCount: collectedCount,
                  archivedCount: archivedCount,
                  templateCount: templateCount,
                ),
                const SizedBox(height: 12),
                _TodayActivitySection(todayLog: todayLog),
                const SizedBox(height: 12),
                _SectionCard(
                  title: '最近追加した商品',
                  child: recentProducts.isEmpty
                      ? _EmptyHint(
                          text: 'まだ商品がありません。まずは商品を追加してみましょう。',
                        )
                      : Column(
                          children: [
                            for (int i = 0; i < recentProducts.length; i++) ...[
                              _RecentProductTile(product: recentProducts[i]),
                              if (i != recentProducts.length - 1)
                                const Divider(height: 12),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: '最近コピーしたコメント',
                  child: (recentCopied ?? '').trim().isEmpty
                      ? _EmptyHint(text: '最近コピーしたコメントはありません')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recentCopied!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textPrimary),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => AppActionService.copyText(
                                context,
                                text: recentCopied,
                                onSuccess: () => context
                                    .read<CommentTemplateProvider>()
                                    .setLastCopiedComment(recentCopied),
                              ),
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('再コピー'),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'ショートカット',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProductAddScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('商品を追加'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProductsPlaceholderScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                        label: const Text('商品管理へ'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CommentsPlaceholderScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('コメントへ'),
                      ),
                    ],
                  ),
                ),
                if (products.isEmpty && templateCount == 0) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'はじめの一歩',
                    child: _EmptyHint(
                      text: '商品とコメントテンプレを1件ずつ作ると、ROOM運用をすぐ再開できます。',
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<Product> _recentProducts(List<Product> all) {
    final items = List<Product>.from(all);
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items.take(3).toList();
  }
}

class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.accentLightest,
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ROOM運用をすぐ再開',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '今日やることをすぐ確認して、次の操作へ進みましょう。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.candidateCount,
    required this.collectedCount,
    required this.archivedCount,
    required this.templateCount,
  });

  final int candidateCount;
  final int collectedCount;
  final int archivedCount;
  final int templateCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('候補', candidateCount, Icons.lightbulb_outline),
      ('コレ済', collectedCount, Icons.bookmark_added_outlined),
      ('アーカイブ', archivedCount, Icons.archive_outlined),
      ('テンプレ', templateCount, Icons.chat_bubble_outline),
    ];
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.9,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _SummaryCard(
          label: item.$1,
          count: item.$2,
          icon: item.$3,
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.accentLightest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.accentPrimary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
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

class _RecentProductTile extends StatelessWidget {
  const _RecentProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProductDetailScreen(productId: product.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.productName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _TinyChip(label: product.status.label),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    product.tags.isEmpty
                        ? 'タグなし'
                        : product.tags.take(2).join(' / '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentLightest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.accentPrimary,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
    );
  }
}

class _TodayActivitySection extends StatelessWidget {
  const _TodayActivitySection({required this.todayLog});

  final ActivityLog? todayLog;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '今日の活動',
      child: todayLog == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日はまだ活動ログがありません。\nコレ件数やコメント件数を記録しましょう。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      ActivityPlaceholderScreen.createRecordRoute(),
                    );
                  },
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('今日の活動を記録する'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TinyChip(label: 'コレ ${todayLog!.collectedCount}'),
                    const SizedBox(width: 6),
                    _TinyChip(label: 'コメント ${todayLog!.commentCount}'),
                  ],
                ),
                if ((todayLog!.memo ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    todayLog!.memo!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ActivityPlaceholderScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('活動を見る'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          ActivityPlaceholderScreen.createRecordRoute(),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('編集する'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
