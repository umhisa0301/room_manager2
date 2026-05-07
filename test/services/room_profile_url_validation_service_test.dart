import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/room_profile_url_validation_service.dart';

void main() {
  group('RoomProfileUrlValidationService.validateFormat', () {
    test('ROOMプロフィールURLを許可して正規化する', () {
      final result = RoomProfileUrlValidationService.validateFormat(
        'https://room.rakuten.co.jp/sample_user/',
      );

      expect(result.isValid, isTrue);
      expect(result.logValue, 'valid');
      expect(result.normalizedUrl, 'https://room.rakuten.co.jp/sample_user');
    });

    test('空は任意入力として許可する', () {
      final result = RoomProfileUrlValidationService.validateFormat('');

      expect(result.isValid, isTrue);
      expect(result.isEmpty, isTrue);
      expect(result.logValue, 'empty');
    });

    test('httpは拒否する', () {
      final result = RoomProfileUrlValidationService.validateFormat(
        'http://room.rakuten.co.jp/sample_user',
      );

      expect(result.isValid, isFalse);
      expect(result.logValue, 'invalidScheme');
    });

    test('楽天市場URLは拒否する', () {
      final result = RoomProfileUrlValidationService.validateFormat(
        'https://item.rakuten.co.jp/shop/item/',
      );

      expect(result.isValid, isFalse);
      expect(result.logValue, 'invalidHost');
    });

    test('ROOMトップURLのみは拒否する', () {
      final result = RoomProfileUrlValidationService.validateFormat(
        'https://room.rakuten.co.jp/',
      );

      expect(result.isValid, isFalse);
      expect(result.logValue, 'topOnly');
    });

    test('ROOM商品URL相当の複数パスは拒否する', () {
      final result = RoomProfileUrlValidationService.validateFormat(
        'https://room.rakuten.co.jp/sample_user/1700123456789012',
      );

      expect(result.isValid, isFalse);
      expect(result.logValue, 'roomProductUrl');
    });

    test('短縮URLは拒否する', () {
      final result = RoomProfileUrlValidationService.validateFormat(
        'https://bit.ly/room-sample',
      );

      expect(result.isValid, isFalse);
      expect(result.logValue, 'invalidHost');
    });
  });
}
