import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/room_import_enrich_keyword_normalize.dart';

void main() {
  group('RoomImportEnrichKeywordNormalize', () {
    test('strips bracket promos and shortens', () {
      const raw =
          '【57％OFF】スーツ レディース ビジネス フォーマル 大きいサイズ セットアップ パンツスーツ 送料無料';
      final n = RoomImportEnrichKeywordNormalize.normalize(raw);
      expect(n.contains('【'), isFalse);
      expect(n.contains('57'), isFalse);
      expect(n.contains('送料無料'), isFalse);
      expect(
        n.length,
        lessThanOrEqualTo(RoomImportEnrichKeywordNormalize.maxKeywordChars),
      );
      expect(n, contains('スーツ'));
      expect(n, contains('セットアップ'));
    });

    test('collapses whitespace', () {
      const raw = '  aa　　bb \n cc\t ';
      expect(RoomImportEnrichKeywordNormalize.normalize(raw), 'aa bb cc');
    });
  });
}
