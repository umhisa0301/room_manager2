import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';

/// 商品管理画面。タイトル・空状態・FAB を実装。
class ProductsPlaceholderScreen extends StatelessWidget {
  const ProductsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('商品管理'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: const EmptyStateView(
        message: 'まだ商品がありません',
        detail: '右下ボタンから追加',
        icon: Icons.shopping_bag_outlined,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未実装')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
