import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

    test('/items 付きROOMプロフィールURLを許可して正規化する', () {
      final result = RoomProfileUrlValidationService.validateFormat(
        'https://room.rakuten.co.jp/room_def277c8b5/items',
      );

      expect(result.isValid, isTrue);
      expect(result.logValue, 'valid');
      expect(
        result.normalizedUrl,
        'https://room.rakuten.co.jp/room_def277c8b5',
      );
    });

    test('/collections と /likes もプロフィール導線として許可する', () {
      final collections = RoomProfileUrlValidationService.validateFormat(
        'https://room.rakuten.co.jp/room_def277c8b5/collections',
      );
      final likes = RoomProfileUrlValidationService.validateFormat(
        'https://room.rakuten.co.jp/room_def277c8b5/likes',
      );

      expect(collections.isValid, isTrue);
      expect(likes.isValid, isTrue);
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

    test('roomIdなしの /items は拒否する', () {
      final result = RoomProfileUrlValidationService.validateFormat(
        'https://room.rakuten.co.jp/items',
      );

      expect(result.isValid, isFalse);
      expect(result.logValue, 'notProfileUrl');
    });

    test('短縮URLは拒否する', () {
      final result = RoomProfileUrlValidationService.validateFormat(
        'https://bit.ly/room-sample',
      );

      expect(result.isValid, isFalse);
      expect(result.logValue, 'invalidHost');
    });
  });

  group('RoomProfileUrlValidationService.verifyExists', () {
    test('200系は保存可能な確認成功にする', () async {
      final service = RoomProfileUrlValidationService(
        httpClient: MockClient(
          (_) async => http.Response(
            'window.__INITIAL_STATE__ = {"userData":{"id":"12345"}}',
            200,
          ),
        ),
      );

      final result = await service.verifyExists(
        'https://room.rakuten.co.jp/room_def277c8b5',
      );

      expect(result.exists, isTrue);
      expect(result.canSave, isTrue);
      expect(result.message, RoomProfileUrlValidationService.successMessage);
    });

    test('404は保存不可にする', () async {
      final service = RoomProfileUrlValidationService(
        httpClient: MockClient((_) async => http.Response('not found', 404)),
      );

      final result = await service.verifyExists(
        'https://room.rakuten.co.jp/room_def277c8b5',
      );

      expect(result.exists, isFalse);
      expect(result.canSave, isFalse);
      expect(result.message, RoomProfileUrlValidationService.notFoundMessage);
    });

    test('403/429は形式OKなら確認保留で保存可能にする', () async {
      final blocked = RoomProfileUrlValidationService(
        httpClient: MockClient((_) async => http.Response('forbidden', 403)),
      );
      final limited = RoomProfileUrlValidationService(
        httpClient: MockClient((_) async => http.Response('limited', 429)),
      );

      final blockedResult = await blocked.verifyExists(
        'https://room.rakuten.co.jp/room_def277c8b5',
      );
      final limitedResult = await limited.verifyExists(
        'https://room.rakuten.co.jp/room_def277c8b5',
      );

      expect(blockedResult.canSave, isTrue);
      expect(limitedResult.canSave, isTrue);
      expect(
        blockedResult.message,
        RoomProfileUrlValidationService.pendingMessage,
      );
    });

    test('通信失敗は形式OKなら確認保留で保存可能にする', () async {
      final service = RoomProfileUrlValidationService(
        httpClient: MockClient((_) async => throw Exception('offline')),
      );

      final result = await service.verifyExists(
        'https://room.rakuten.co.jp/room_def277c8b5',
      );

      expect(result.exists, isFalse);
      expect(result.canSave, isTrue);
      expect(
        result.message,
        RoomProfileUrlValidationService.networkPendingMessage,
      );
    });
  });
}
