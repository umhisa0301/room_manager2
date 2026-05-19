import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/room_import_safe_merge.dart';

void main() {
  group('RoomImportSafeMerge', () {
    test('既存 price=3980 に incoming price=-1 が来ても 3980 を維持', () {
      expect(
        RoomImportSafeMerge.mergePrice(
          field: 'price',
          existing: 3980,
          incoming: -1,
          log: false,
        ),
        3980,
      );
    });

    test('既存 imageUrl 有効、incoming 空なら既存維持', () {
      expect(
        RoomImportSafeMerge.mergeString(
          field: 'imageUrl',
          existing: 'https://example.com/a.jpg',
          incoming: '',
          log: false,
        ),
        'https://example.com/a.jpg',
      );
    });

    test('既存 shopCode 有効、incoming 空なら既存維持', () {
      expect(
        RoomImportSafeMerge.mergeString(
          field: 'shopCode',
          existing: 'soukaidrink',
          incoming: '',
          log: false,
        ),
        'soukaidrink',
      );
    });

    test('既存 genreName 有効、incoming 空なら既存維持', () {
      expect(
        RoomImportSafeMerge.mergeString(
          field: 'genreName',
          existing: 'コーヒー飲料',
          incoming: '',
          log: false,
        ),
        'コーヒー飲料',
      );
    });

    test('incoming api値が有効な場合だけ上書き', () {
      expect(
        RoomImportSafeMerge.mergePrice(
          field: 'price',
          existing: 100,
          incoming: 3980,
          log: false,
        ),
        3980,
      );
      expect(
        RoomImportSafeMerge.mergeString(
          field: 'shopName',
          existing: '旧ショップ',
          incoming: '爽快ドリンク専門店',
          log: false,
        ),
        '爽快ドリンク専門店',
      );
    });
  });
}
