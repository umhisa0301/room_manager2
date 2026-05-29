import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';

void main() {
  group('classifyKeywordSearchUnder100Reason', () {
    test('画像なし除外が多いとき noImage', () {
      expect(
        RakutenSearchRepository.classifyKeywordSearchUnder100Reason(
          displayCount: 40,
          targetVisibleCount: 100,
          stopReason: RakutenKeywordSearchStopReason.apiNoMoreResults,
          excludedCandidate: 0,
          excludedDone: 0,
          excludedDuplicate: 0,
          excludedSafety: 0,
          excludedNoImage: 80,
          excludedNoPrice: 0,
        ),
        'noImage',
      );
    });

    test('価格なし除外が多いとき noPrice', () {
      expect(
        RakutenSearchRepository.classifyKeywordSearchUnder100Reason(
          displayCount: 30,
          targetVisibleCount: 100,
          stopReason: RakutenKeywordSearchStopReason.apiNoMoreResults,
          excludedCandidate: 0,
          excludedDone: 0,
          excludedDuplicate: 0,
          excludedSafety: 0,
          excludedNoImage: 10,
          excludedNoPrice: 70,
        ),
        'noPrice',
      );
    });

    test('安全フィルタが多いとき safetyFiltered', () {
      expect(
        RakutenSearchRepository.classifyKeywordSearchUnder100Reason(
          displayCount: 20,
          targetVisibleCount: 100,
          stopReason: RakutenKeywordSearchStopReason.apiNoMoreResults,
          excludedCandidate: 0,
          excludedDone: 0,
          excludedDuplicate: 0,
          excludedSafety: 90,
          excludedNoImage: 0,
          excludedNoPrice: 0,
        ),
        'safetyFiltered',
      );
    });
  });
}
