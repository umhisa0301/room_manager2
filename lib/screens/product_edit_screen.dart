import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../state/product_list_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/product_form_content.dart';

/// 商品編集画面。共通フォームで既存商品を編集し、保存で更新・ローカル保存される。
class ProductEditScreen extends StatefulWidget {
  const ProductEditScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _formKey = GlobalKey<ProductFormContentState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('商品を編集'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppPrimaryButton(
              label: '保存',
              onPressed: () => _formKey.currentState?.submit(),
              height: 36,
              expand: false,
            ),
          ),
        ],
      ),
      body: ProductFormContent(
        key: _formKey,
        initialProduct: widget.product,
        onSubmit: (product) {
          context.read<ProductListProvider>().updateProduct(product);
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('保存しました')));
          }
        },
      ),
    );
  }
}
