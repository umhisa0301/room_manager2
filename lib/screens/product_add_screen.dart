import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../models/product_status.dart';
import '../state/product_list_provider.dart';

/// 商品追加画面。入力後はメモリの一覧に追加し、戻ると一覧に反映される。
class ProductAddScreen extends StatefulWidget {
  const ProductAddScreen({super.key});

  @override
  State<ProductAddScreen> createState() => _ProductAddScreenState();
}

class _ProductAddScreenState extends State<ProductAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _memoController = TextEditingController();
  final _tagsController = TextEditingController();
  final _quickCommentController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _memoController.dispose();
    _tagsController.dispose();
    _quickCommentController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final tags = _tagsController.text
        .split(RegExp(r'[,，\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final now = DateTime.now();
    final id = 'product_${now.millisecondsSinceEpoch}';

    final product = Product(
      id: id,
      productName: _nameController.text.trim(),
      productUrl: _urlController.text.trim(),
      imageUrl: null,
      memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
      tags: tags,
      status: ProductStatus.candidate,
      createdAt: now,
      updatedAt: now,
      quickComment: _quickCommentController.text.trim().isEmpty
          ? null
          : _quickCommentController.text.trim(),
    );

    context.read<ProductListProvider>().addProduct(product);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品を追加しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('商品を追加'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '商品名',
                hintText: '例：ベビー布団 洗える',
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '商品名を入力してください';
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '商品URL',
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '商品URLを入力してください';
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                hintText: 'メモがあれば',
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'タグ（任意）',
                hintText: 'カンマ区切り 例：育児, インテリア',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            TextFormField(
              controller: _quickCommentController,
              decoration: const InputDecoration(
                labelText: 'ひとことコメント（任意）',
                hintText: '短くメモ',
              ),
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }
}
