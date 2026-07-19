import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('投稿管理 Phase5 空状態 CTA', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/screens/products_placeholder_screen.dart',
      ).readAsStringSync();
    });

    test('コレ候補0件に「商品を探す」CTA と二重遷移ガードがある', () {
      expect(source, contains("emptyActionLabel: '商品を探す'"));
      expect(source, contains('onEmptyAction: _openSearchFromCandidateEmpty'));
      expect(source, contains('bool _isOpeningSearchFromEmpty = false'));
      expect(source, contains('if (_isOpeningSearchFromEmpty) return'));
      expect(source, contains('openRakutenSearchScreen(context)'));
    });

    test('コレ済空状態には emptyActionLabel を渡さない', () {
      final doneBlockStart = source.indexOf("emptyTitle: 'コレ済の商品はまだありません'");
      expect(doneBlockStart, greaterThan(0));
      final doneBlock = source.substring(doneBlockStart, doneBlockStart + 500);
      expect(doneBlock.contains('emptyActionLabel'), isFalse);
      expect(doneBlock.contains('onEmptyAction'), isFalse);
    });

    test('検索・URL・メタ空状態に解除CTAがある', () {
      expect(source, contains("'検索をクリア'"));
      expect(source, contains("'絞り込みを解除'"));
      expect(source, contains('onClearSearchFilter:'));
      expect(source, contains('onClearUrlFilter: _clearCandidateUrlFilter'));
      expect(
        source,
        contains('onClearMetaFilter: _clearDoneRoomImportMetaFilter'),
      );
      expect(source, contains('void _clearCandidateUrlFilter()'));
      expect(source, contains('void _clearDoneRoomImportMetaFilter()'));
      expect(source, contains('void _clearActiveRoomColleSearchEmptyCause()'));
    });

    test('フィルタ解除は該当条件のみ（並び順を無条件クリアしない）', () {
      expect(source, contains('_candidateExcludeUrlNotReady = false'));
      expect(
        source,
        contains('_doneRoomImportMetaFilter = _RoomImportMetaListFilter.all'),
      );
      // 検索空状態の解除はキーワード優先、なければ criteria defaults（sort は触らない）
      final clearCause = source.substring(
        source.indexOf('void _clearActiveRoomColleSearchEmptyCause()'),
        source.indexOf('void _clearCandidateUrlFilter()'),
      );
      expect(clearCause.contains('_candidateSortPreset'), isFalse);
      expect(clearCause.contains('_doneSortPreset'), isFalse);
    });

    test('投稿管理メインタブは Key と人間向け tooltip を分離している', () {
      expect(source, contains("'post_management_tab_candidates'"));
      expect(source, contains("'post_management_tab_posted'"));
      expect(source, contains("tooltip: 'コレ候補'"));
      expect(source, contains("tooltip: 'コレ済み'"));
      expect(
        source,
        isNot(
          contains(
            "label: idx == 0\n                              ? 'post_management_tab_candidates'",
          ),
        ),
      );
    });
  });
}
