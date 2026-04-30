import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comment_template.dart';
import '../state/comment_template_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

/// コメントテンプレートの追加・編集画面。
class CommentTemplateEditScreen extends StatefulWidget {
  const CommentTemplateEditScreen({super.key, required this.initialTemplate});

  final CommentTemplate? initialTemplate;

  @override
  State<CommentTemplateEditScreen> createState() =>
      _CommentTemplateEditScreenState();
}

class _CommentTemplateEditScreenState extends State<CommentTemplateEditScreen> {
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
      SnackBar(content: Text(_isEdit ? '保存しました' : 'テンプレートを追加しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final bottomPad = 16 + viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isEdit ? 'テンプレートを編集' : 'テンプレートを追加'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppPrimaryButton(
              label: '保存',
              onPressed: _save,
              height: 40,
              expand: false,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.screenPaddingH,
              12,
              AppDimensions.screenPaddingH,
              bottomPad,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ROOMの投稿欄に貼り付ける文を入力します',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                        fontSize: 14,
                      ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _titleController,
                  labelText: 'タイトル',
                  hintText: '一覧で見分けやすい名前',
                  textInputAction: TextInputAction.next,
                  semanticLabel: 'テンプレートのタイトル',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'タイトルを入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _bodyController,
                  labelText: '本文',
                  hintText: '複数行のコメントをそのまま入力できます',
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  maxLines: 12,
                  minHeight: 140,
                  semanticLabel: 'コメント本文',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return '本文を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _categoryController,
                  labelText: 'カテゴリー（任意）',
                  hintText: '例：フォローお礼 / 投稿コメント',
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 8),
                Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: SwitchListTile.adaptive(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    title: Text(
                      'お気に入り',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    subtitle: Text(
                      '一覧の上に表示しやすくなります',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    value: _isFavorite,
                    activeThumbColor: AppColors.accentPrimary,
                    onChanged: (v) => setState(() => _isFavorite = v),
                  ),
                ),
                const SizedBox(height: 20),
                AppPrimaryButton(
                  label: '保存して一覧へ戻る',
                  icon: const Icon(Icons.check_rounded),
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
