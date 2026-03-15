import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comment_template.dart';
import '../state/comment_template_provider.dart';
import '../theme/app_theme.dart';

/// コメントテンプレートの追加・編集画面。
class CommentTemplateEditScreen extends StatefulWidget {
  const CommentTemplateEditScreen({super.key, required this.initialTemplate});

  final CommentTemplate? initialTemplate;

  @override
  State<CommentTemplateEditScreen> createState() =>
      _CommentTemplateEditScreenState();
}

class _CommentTemplateEditScreenState
    extends State<CommentTemplateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _isFavorite = false;

  bool get _isEdit => widget.initialTemplate != null;

  @override
  void initState() {
    super.initState();
    final t = widget.initialTemplate;
    if (t != null) {
      _titleController.text = t.title;
      _bodyController.text = t.body;
      _categoryController.text = t.category ?? '';
      _isFavorite = t.isFavorite;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final provider = context.read<CommentTemplateProvider>();

    if (_isEdit) {
      final base = widget.initialTemplate!;
      final updated = base.copyWith(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        isFavorite: _isFavorite,
        updatedAt: now,
      );
      provider.updateTemplate(updated);
    } else {
      final created = CommentTemplate(
        id: 'comment_${now.millisecondsSinceEpoch}',
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        isFavorite: _isFavorite,
        createdAt: now,
        updatedAt: now,
      );
      provider.addTemplate(created);
    }

    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEdit ? '保存しました' : 'テンプレートを追加しました'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'テンプレートを編集' : 'テンプレートを追加'),
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
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                hintText: '例：挨拶＋購入経路',
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'タイトルを入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: '本文',
                hintText: '例：ご覧いただきありがとうございます…',
              ),
              maxLines: 5,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return '本文を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'カテゴリー（任意）',
                hintText: '例：育児 / インテリア など',
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                Switch(
                  value: _isFavorite,
                  onChanged: (v) => setState(() => _isFavorite = v),
                ),
                const SizedBox(width: 8),
                Text(
                  'お気に入り',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
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

