import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/product_list_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/product_form_content.dart';

/// 商品追加画面。共通フォームを使い、保存で一覧に追加・ローカル保存される。
class ProductAddScreen extends StatefulWidget {
  const ProductAddScreen({super.key});

  @override
  State<ProductAddScreen> createState() => _ProductAddScreenState();
}

class _ProductAddScreenState extends State<ProductAddScreen> {
  final _formKey = GlobalKey<ProductFormContentState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('商品を追加'),
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
        initialProduct: null,
        onSubmit: (product) {
          context.read<ProductListProvider>().addProduct(product);
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('商品を追加しました')));
          }
        },
      ),
    );
  }
}
