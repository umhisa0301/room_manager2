import 'package:flutter/foundation.dart';

import '../models/room_recommendation_profile.dart';
import '../repository/room_recommendation_profile_repository.dart';
import '../services/room_diagnosis_service.dart';

class RoomRecommendationProfileProvider extends ChangeNotifier {
  RoomRecommendationProfileProvider({
    required RoomRecommendationProfileRepository repository,
  })  : _repository = repository,
        _profile = repository.load();

  final RoomRecommendationProfileRepository _repository;
  RoomRecommendationProfile? _profile;

  RoomRecommendationProfile? get profile => _profile;

  bool get isDiagnosed => _profile?.isDiagnosed ?? false;

  bool get isDiagnosisPromptSkipped => _repository.isDiagnosisPromptSkipped();

  Future<void> markDiagnosisPromptSkipped() async {
    await _repository.setDiagnosisPromptSkipped(true);
    notifyListeners();
  }

  Future<void> saveFromDiagnosis(RoomDiagnosisAnswers answers) async {
    final built = RoomDiagnosisService.buildProfile(answers);
    await _repository.save(built);
    await _repository.setDiagnosisPromptSkipped(false);
    _profile = built;
    notifyListeners();
  }

  Future<void> reload() async {
    _profile = _repository.load();
    notifyListeners();
  }

  Future<void> clear() async {
    await _repository.clear();
    _profile = null;
    notifyListeners();
  }
}
