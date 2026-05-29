import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/rakuten_keyword_search_sort.dart';

void main() {
  group('rakutenKeywordSearchSort', () {
    test('既定並び順はレビュー件数が多い順', () {
      expect(
        rakutenKeywordSearchDefaultSortMode,
        RakutenKeywordSearchSortMode.reviewCountDescending,
      );
      expect(
        rakutenKeywordSearchApiSortParam(rakutenKeywordSearchDefaultSortMode),
        '-reviewCount',
      );
    });

    test('defaultOrder は API でもレビュー件数順', () {
      expect(
        rakutenKeywordSearchApiSortParam(
          RakutenKeywordSearchSortMode.defaultOrder,
        ),
        '-reviewCount',
      );
    });

    test('ユーザー選択肢に defaultOrder は含めない', () {
      expect(
        rakutenKeywordSearchUserSelectableSortModes,
        isNot(contains(RakutenKeywordSearchSortMode.defaultOrder)),
      );
      expect(
        rakutenKeywordSearchUserSelectableSortModes.first,
        RakutenKeywordSearchSortMode.reviewCountDescending,
      );
    });

    test('表示ラベルに「おすすめ」「デフォルト」は出さない', () {
      for (final mode in rakutenKeywordSearchUserSelectableSortModes) {
        final label = rakutenKeywordSearchSortDisplayLabel(mode, menuItem: true);
        expect(label, isNot(contains('おすすめ')));
        expect(label, isNot(contains('デフォルト')));
      }
      expect(rakutenApiSortDisplayLabel(null), 'レビューが多い');
      expect(rakutenApiSortDisplayLabel(''), 'レビューが多い');
    });

    test('レビューが多い順の表示', () {
      expect(
        rakutenKeywordSearchSortDisplayLabel(
          RakutenKeywordSearchSortMode.reviewCountDescending,
          menuItem: true,
        ),
        'レビューが多い順',
      );
    });
  });
}
