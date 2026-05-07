import 'dart:async';

import 'package:http/http.dart' as http;

import 'room_user_posted_listing_fetcher.dart';

class RoomProfileUrlFormatResult {
  const RoomProfileUrlFormatResult({
    required this.isValid,
    required this.logValue,
    this.normalizedUrl = '',
    this.errorMessage,
  });

  final bool isValid;
  final String logValue;
  final String normalizedUrl;
  final String? errorMessage;

  bool get isEmpty => logValue == 'empty';
}

class RoomProfileExistsResult {
  const RoomProfileExistsResult({required this.exists, required this.logValue});

  final bool exists;
  final String logValue;
}

class RoomProfileUrlValidationService {
  RoomProfileUrlValidationService({
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 12),
  }) : _client = httpClient ?? http.Client(),
       _ownsClient = httpClient == null,
       _timeout = timeout;

  final http.Client _client;
  final bool _ownsClient;
  final Duration _timeout;

  static const String genericErrorMessage = 'ROOMプロフィールを確認できませんでした';

  static RoomProfileUrlFormatResult validateFormat(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return const RoomProfileUrlFormatResult(isValid: true, logValue: 'empty');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      return const RoomProfileUrlFormatResult(
        isValid: false,
        logValue: 'invalidFormat',
        errorMessage: genericErrorMessage,
      );
    }
    if (uri.scheme.toLowerCase() != 'https') {
      return const RoomProfileUrlFormatResult(
        isValid: false,
        logValue: 'invalidScheme',
        errorMessage: genericErrorMessage,
      );
    }
    if (uri.host.toLowerCase() != 'room.rakuten.co.jp') {
      return const RoomProfileUrlFormatResult(
        isValid: false,
        logValue: 'invalidHost',
        errorMessage: genericErrorMessage,
      );
    }
    if (uri.hasQuery || uri.hasFragment) {
      return const RoomProfileUrlFormatResult(
        isValid: false,
        logValue: 'invalidDecoration',
        errorMessage: genericErrorMessage,
      );
    }

    final segments = uri.pathSegments
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return const RoomProfileUrlFormatResult(
        isValid: false,
        logValue: 'topOnly',
        errorMessage: genericErrorMessage,
      );
    }
    if (segments.length != 1) {
      return const RoomProfileUrlFormatResult(
        isValid: false,
        logValue: 'roomProductUrl',
        errorMessage: genericErrorMessage,
      );
    }

    final userSegment = segments.single;
    if (userSegment == 'api' ||
        userSegment == 'items' ||
        RegExp(r'^\d{8,}$').hasMatch(userSegment)) {
      return const RoomProfileUrlFormatResult(
        isValid: false,
        logValue: 'notProfileUrl',
        errorMessage: genericErrorMessage,
      );
    }

    return RoomProfileUrlFormatResult(
      isValid: true,
      logValue: 'valid',
      normalizedUrl: Uri.https(
        'room.rakuten.co.jp',
        '/$userSegment',
      ).toString(),
    );
  }

  Future<RoomProfileExistsResult> verifyExists(String normalizedUrl) async {
    final format = validateFormat(normalizedUrl);
    if (format.isEmpty) {
      return const RoomProfileExistsResult(exists: true, logValue: 'skipped');
    }
    if (!format.isValid || format.normalizedUrl.isEmpty) {
      return const RoomProfileExistsResult(exists: false, logValue: 'false');
    }

    final uri = Uri.parse(format.normalizedUrl);
    try {
      final res = await _client
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (compatible; RoomManagerApp/1.0; +https://example.invalid)',
              'Accept': 'text/html,application/xhtml+xml',
            },
          )
          .timeout(_timeout);
      if (res.statusCode == 404 ||
          res.statusCode < 200 ||
          res.statusCode >= 400 ||
          res.body.trim().isEmpty) {
        return const RoomProfileExistsResult(exists: false, logValue: 'false');
      }
      final html = res.body;
      final hasInitialUserId =
          RoomUserPostedListingFetcher.tryParseNumericUserIdFromInitialState(
            html,
          ) !=
          null;
      final looksLikeRoomProfile =
          html.contains('room.rakuten.co.jp') &&
          (html.contains('userData') ||
              html.contains('__INITIAL_STATE__') ||
              html.contains('ROOM'));
      final ok = hasInitialUserId || looksLikeRoomProfile;
      return RoomProfileExistsResult(
        exists: ok,
        logValue: ok ? 'true' : 'false',
      );
    } on TimeoutException {
      return const RoomProfileExistsResult(exists: false, logValue: 'timeout');
    } catch (_) {
      return const RoomProfileExistsResult(exists: false, logValue: 'false');
    } finally {
      if (_ownsClient) {
        _client.close();
      }
    }
  }
}
