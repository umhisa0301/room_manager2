import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/rakuten_search_provider.dart';

void main() {
  RakutenSearchProvider newProvider() => RakutenSearchProvider(
        repository: RakutenSearchRepository(apiService: RakutenApiService()),
      );

  test('beginSearchSession increments active request id', () {
    final provider = newProvider();
    final first = provider.beginSearchSession(modeTag: 'product');
    final second = provider.beginSearchSession(modeTag: 'product');
    expect(second, greaterThan(first));
    expect(provider.activeSearchSessionId, second);
  });

  test('clearErrorForNewSearch clears error and retry banner', () {
    final provider = newProvider();
    provider.restoreFromSnapshot(
      status: RakutenSearchStatus.error,
      results: const [],
      errorMessage: '通信エラー',
      lastKeyword: 'さかな',
      keywordSearchHadApiHitsButNoVisibleResults: false,
      errorModeTag: 'savedShop',
    );
    final requestId = provider.beginSearchSession(modeTag: 'savedShop');
    provider.clearErrorForNewSearch(modeTag: 'savedShop', requestId: requestId);
    expect(provider.errorMessage, isEmpty);
    expect(provider.retryFailureBannerMessage, isNull);
  });

  test('clearErrorIfModeMismatch clears error owned by another mode', () {
    final provider = newProvider();
    provider.restoreFromSnapshot(
      status: RakutenSearchStatus.error,
      results: const [],
      errorMessage: '保存ショップ失敗',
      lastKeyword: 'さかな',
      keywordSearchHadApiHitsButNoVisibleResults: false,
      errorModeTag: 'savedShop',
    );
    provider.clearErrorIfModeMismatch('product');
    expect(provider.status, RakutenSearchStatus.idle);
    expect(provider.isErrorVisibleForMode('savedShop'), isFalse);
  });

  test('isErrorVisibleForMode is true only for matching tag', () {
    final provider = newProvider();
    provider.restoreFromSnapshot(
      status: RakutenSearchStatus.error,
      results: const [],
      errorMessage: 'err',
      lastKeyword: '',
      keywordSearchHadApiHitsButNoVisibleResults: false,
      errorModeTag: 'savedShop',
    );
    expect(provider.isErrorVisibleForMode('savedShop'), isTrue);
    expect(provider.isErrorVisibleForMode('product'), isFalse);
  });
}
