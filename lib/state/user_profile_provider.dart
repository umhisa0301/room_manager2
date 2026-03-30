import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../repository/user_profile_repository.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfileProvider({required UserProfileRepository repository})
      : _repository = repository,
        _profile = repository.load();

  final UserProfileRepository _repository;
  UserProfile _profile;

  UserProfile get profile => _profile;

  Future<void> saveProfile(UserProfile next) async {
    await _repository.save(next);
    _profile = next;
    notifyListeners();
  }

  /// 永続化から再読込（デバッグ・同期用）
  Future<void> reload() async {
    _profile = _repository.load();
    notifyListeners();
  }
}
