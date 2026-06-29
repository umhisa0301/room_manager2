import 'package:flutter/foundation.dart';

import '../models/post_style_settings.dart';
import '../repository/post_style_settings_repository.dart';

class PostStyleSettingsProvider extends ChangeNotifier {
  PostStyleSettingsProvider({required PostStyleSettingsRepository repository})
    : _repository = repository,
      _settings = repository.load();

  final PostStyleSettingsRepository _repository;
  PostStyleSettings _settings;

  PostStyleSettings get settings => _settings;

  Future<void> saveSettings(PostStyleSettings next) async {
    final stamped = next.copyWith(updatedAt: DateTime.now().toUtc());
    await _repository.save(stamped);
    _settings = stamped;
    notifyListeners();
  }

  Future<void> reload() async {
    _settings = _repository.load();
    notifyListeners();
  }
}
