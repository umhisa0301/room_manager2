import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../models/product_status.dart';
import 'app_text_field.dart';

/// 商品追加・編集で共通利用するフォーム。
/// initialProduct が null なら追加、非 null なら編集（ステータス選択あり）。
class ProductFormContent extends StatefulWidget {
  const ProductFormContent({
    super.key,
    this.initialProduct,
    required this.onSubmit,
  });

  final Product? initialProduct;
  final void Function(Product product) onSubmit;

  @override
  State<ProductFormContent> createState() => ProductFormContentState();
}

class ProductFormContentState extends State<ProductFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _memoController = TextEditingController();
  final _tagsController = TextEditingController();
  final _quickCommentController = TextEditingController();

  late ProductStatus _status;

  bool get _isEdit => widget.initialProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    if (p != null) {
      _nameController.text = p.productName;
      _urlController.text = p.productUrl;
      _memoController.text = p.memo ?? '';
      _tagsController.text = p.tags.join(', ');
      _quickCommentController.text = p.quickComment ?? '';
      _status = p.status;
    } else {
      _status = ProductStatus.candidate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _memoController.dispose();
    _tagsController.dispose();
    _quickCommentController.dispose();
    super.dispose();
  }

  /// AppBar の保存ボタンから呼ぶ
  void submit() {
    _save();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final tags = _tagsController.text
        .split(RegExp(r'[,，\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final now = DateTime.now();
    final Product product;
    if (_isEdit) {
      product = widget.initialProduct!.copyWith(
        productName: _nameController.text.trim(),
        productUrl: _urlController.text.trim(),
        memo: _memoController.text.trim().isEmpty
            ? null
            : _memoController.text.trim(),
        tags: tags,
        status: _status,
        updatedAt: now,
        quickComment: _quickCommentController.text.trim().isEmpty
            ? null
            : _quickCommentController.text.trim(),
      );
    } else {
      product = Product(
        id: 'product_${now.millisecondsSinceEpoch}',
        productName: _nameController.text.trim(),
        productUrl: _urlController.text.trim(),
        imageUrl: null,
        memo: _memoController.text.trim().isEmpty
            ? null
            : _memoController.text.trim(),
        tags: tags,
        status: ProductStatus.candidate,
        createdAt: now,
        updatedAt: now,
        quickComment: _quickCommentController.text.trim().isEmpty
            ? null
            : _quickCommentController.text.trim(),
      );
    }
    widget.onSubmit(product);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
        children: [
          AppTextField(
            controller: _nameController,
            labelText: '商品名',
            hintText: '例：ベビー布団 洗える',
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '商品名を入力してください';
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          AppTextField(
            controller: _urlController,
            labelText: '商品URL',
            hintText: 'https://...',
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '商品URLを入力してください';
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          if (_isEdit) ...[
            _buildStatusSection(context),
            const SizedBox(height: AppDimensions.spacingMd),
          ],
          AppTextField(
            controller: _memoController,
            labelText: 'メモ（任意）',
            hintText: 'メモがあれば',
            maxLines: 2,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          AppTextField(
            controller: _tagsController,
            labelText: 'タグ（任意）',
            hintText: 'カンマ区切り 例：育児, インテリア',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          AppTextField(
            controller: _quickCommentController,
            labelText: 'ひとことコメント（任意）',
            hintText: '短くメモ',
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ステータス',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: ProductStatus.values.map((s) {
            final selected = _status == s;
            return FilterChip(
              label: Text(s.label),
              selected: selected,
              onSelected: (_) => setState(() => _status = s),
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
        ),
      ],
    );
  }
}
