import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/product_display_title.dart';

void main() {
  group('deriveProductDisplayTitle', () {
    test('returns short title as-is', () {
      expect(
        deriveProductDisplayTitle('北欧風の収納バスケット'),
        '北欧風の収納バスケット',
      );
    });

    test('truncates long SEO title to first four words', () {
      expect(
        deriveProductDisplayTitle(
          'バスケット 収納 収納かご 北欧風収納バスケット 日用品 小物入れ',
        ),
        'バスケット 収納 収納かご 北欧風収納バスケット…',
      );
    });

    test('returns fallback for empty title', () {
      expect(deriveProductDisplayTitle(''), 'この商品');
    });
  });
}
