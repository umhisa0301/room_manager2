import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../models/product_status.dart';
import '../state/product_list_provider.dart';
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop();
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          _Section(title: '商品名', child: Text(product.productName, style: _bodyStyle(context))),
          const SizedBox(height: AppDimensions.spacingMd),
          _Section(
            title: '商品URL',
            child: Text(
              product.productUrl,
              style: _bodyStyle(context),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          _Section(
            title: 'メモ',
            child: Text(product.memo ?? '—', style: _bodyStyle(context)),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          _Section(
            title: 'タグ',
            child: product.tags.isEmpty
                ? Text('—', style: _bodyStyle(context))
                : Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: product.tags.map((t) => _chip(context, t)).toList(),
                  ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          _Section(
            title: 'ステータス',
            child: _StatusChunks(product: product),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          _Section(
            title: 'ひとことコメント',
            child: Text(product.quickComment ?? '—', style: _bodyStyle(context)),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          _Section(
            title: '作成日',
            child: Text(_formatDate(product.createdAt), style: _captionStyle(context)),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          _Section(
            title: '更新日',
            child: Text(_formatDate(product.updatedAt), style: _captionStyle(context)),
          ),
        ],
      ),
    );
  }

  TextStyle? _bodyStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary);

  TextStyle? _captionStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

  Widget _chip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentLightest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.accentPrimary)),
    );
  }

  Future<void> _showDeleteConfirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: const Text('本当に削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('削除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    context.read<ProductListProvider>().deleteProduct(product);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        child,
      ],
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
                provider.updateProduct(product.copyWith(status: s, updatedAt: DateTime.now()));
              },
              selectedColor: AppColors.accentLight,
              checkmarkColor: AppColors.accentPrimary,
              labelStyle: TextStyle(
                fontSize: 13,
                color: selected ? AppColors.accentPrimary : AppColors.textPrimary,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
