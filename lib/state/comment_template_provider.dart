import 'package:flutter/foundation.dart';

import '../models/comment_template.dart';
import '../repository/comment_template_repository.dart';

/// コメントテンプレート一覧と「直近コピーしたコメント」を管理する Provider。
class CommentTemplateProvider extends ChangeNotifier {
  CommentTemplateProvider({required CommentTemplateRepository repository})
      : _repository = repository,
        _templates = List.from(repository.loadTemplates()),
        _lastCopiedComment = repository.loadLastCopiedComment();

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

