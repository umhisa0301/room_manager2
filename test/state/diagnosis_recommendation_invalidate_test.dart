import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/today_recommendation.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/repository/today_recommendation_repository.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/today_recommendation_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubSearchRepository extends RakutenSearchRepository {
  _StubSearchRepository() : super(apiService: RakutenApiService());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TodayRecommendationProvider profile invalidation', () {
    test('invalidateForRecommendationProfileChange clears saved bundle', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = TodayRecommendationRepository(prefs);
      final now = DateTime.now();
      final bundle = TodayRecommendationBundle(
        localDateKey:
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        generatedAt: now,
        entries: const [],
      );
      await repository.save(bundle);

      final provider = TodayRecommendationProvider(
        repository: repository,
        searchRepository: _StubSearchRepository(),
      );
      expect(provider.bundle, isNotNull);

      await provider.invalidateForRecommendationProfileChange();

      expect(provider.bundle, isNull);
      expect(repository.load(), isNull);
    });
  });
}
