import 'package:flutter/foundation.dart';

import '../models/comment_template.dart';
import '../repository/comment_template_repository.dart';

List<CommentTemplate> _builtInDefaultCommentTemplates() {
  final now = DateTime.now();
  return [
    CommentTemplate(
      id: 'comment_builtin_follow_thanks_v2',
      title: 'フォローありがとう',
      body: 'フォローありがとうございます😊\n素敵な投稿楽しみにしています✨',
      category: 'フォロー',
      isFavorite: true,
      createdAt: now,
      updatedAt: now,
    ),
    CommentTemplate(
      id: 'comment_builtin_follow_done_v2',
      title: 'フォローしました',
      body: '素敵なROOMですね😊\nフォローさせていただきました✨',
      category: 'フォロー',
      isFavorite: true,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

void _seedBuiltinTemplatesOnce({
  required CommentTemplateRepository repository,
  required List<CommentTemplate> templates,
}) {
  if (repository.loadBuiltinTemplatesSeeded()) return;
  final candidates = _builtInDefaultCommentTemplates();
  for (final c in candidates) {
    final dup = templates.any(
      (e) =>
          e.title.trim() == c.title.trim() || e.body.trim() == c.body.trim(),
    );
    if (!dup) {
      templates.add(c);
    }
  }
  repository.saveTemplates(templates);
  repository.saveBuiltinTemplatesSeeded(true);
}

/// コメントテンプレート一覧と「直近コピーしたコメント」を管理する Provider。
class CommentTemplateProvider extends ChangeNotifier {
  CommentTemplateProvider({required CommentTemplateRepository repository})
    : _repository = repository,
      _templates = [] {
    _lastCopiedComment = repository.loadLastCopiedComment();
    _templates.addAll(repository.loadTemplates());
    final n0 = _templates.length;
    _seedBuiltinTemplatesOnce(repository: repository, templates: _templates);
    if (_templates.length != n0) {
      Future.microtask(notifyListeners);
    }
  }

  final CommentTemplateRepository _repository;
  final List<CommentTemplate> _templates;
  String? _lastCopiedComment;

  List<CommentTemplate> get templates => List.unmodifiable(_templates);
  String? get lastCopiedComment => _lastCopiedComment;

  void _persist() {
    _repository.saveTemplates(_templates);
  }

  void _persistLastCopied() {
    _repository.saveLastCopiedComment(_lastCopiedComment);
  }

  void addTemplate(CommentTemplate template) {
    _templates.add(template);
    _persist();
    notifyListeners();
  }

  void updateTemplate(CommentTemplate template) {
    final i = _templates.indexWhere((t) => t.id == template.id);
    if (i >= 0) {
      _templates[i] = template;
      _persist();
      notifyListeners();
    }
  }

  void deleteTemplate(CommentTemplate template) {
    final had = _templates.any((t) => t.id == template.id);
    if (had) {
      _templates.removeWhere((t) => t.id == template.id);
      _persist();
      notifyListeners();
    }
  }

  CommentTemplate? findById(String id) {
    try {
      return _templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// コメントをコピーしたときに呼び出す（テンプレ・商品 quickComment 共通）。
  void setLastCopiedComment(String text) {
    _lastCopiedComment = text;
    _persistLastCopied();
    notifyListeners();
  }
}
