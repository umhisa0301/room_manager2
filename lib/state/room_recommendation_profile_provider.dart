import 'package:flutter/foundation.dart';

import '../models/room_recommendation_profile.dart';
import '../repository/room_recommendation_profile_repository.dart';
import '../services/room_diagnosis_service.dart';

class RoomRecommendationProfileProvider extends ChangeNotifier {
  RoomRecommendationProfileProvider({
    required RoomRecommendationProfileRepository repository,
  })  : _repository = repository,
        _profile = repository.load();

  /// アプリ起動中のみ有効な BottomSheet スキップ（永続フラグと併用）。
  static bool _sessionDiagnosisPromptSkipped = false;

  final RoomRecommendationProfileRepository _repository;
  RoomRecommendationProfile? _profile;

  RoomRecommendationProfile? get profile => _profile;

  bool get isDiagnosed => _profile?.isDiagnosed ?? false;

  bool get isDiagnosisPromptSkipped =>
      _sessionDiagnosisPromptSkipped ||
      _repository.isDiagnosisPromptSkipped();

  Future<void> markDiagnosisPromptSkipped() async {
    _sessionDiagnosisPromptSkipped = true;
    await _repository.setDiagnosisPromptSkipped(true);
    notifyListeners();
  }

  Future<RoomRecommendationProfile> saveFromDiagnosis(
    RoomDiagnosisAnswers answers,
  ) async {
    final built = RoomDiagnosisService.buildProfile(answers);
    await _repository.save(built);
    await _repository.setDiagnosisPromptSkipped(false);
    _sessionDiagnosisPromptSkipped = false;
    _profile = built;
    notifyListeners();
    return built;
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
