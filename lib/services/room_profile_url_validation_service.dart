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
  const RoomProfileExistsResult({
    required this.exists,
    required this.canSave,
    required this.logValue,
    required this.message,
  });

  final bool exists;
  final bool canSave;
  final String logValue;
  final String message;
}

class RoomProfileUrlParseResult {
  const RoomProfileUrlParseResult({
    required this.isValid,
    required this.logValue,
    this.roomId = '',
    this.errorMessage,
  });

  final bool isValid;
  final String logValue;
  final String roomId;
  final String? errorMessage;
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

  static const String formatErrorMessage = 'ROOMプロフィールURLの形式ではありません';
  static const String notFoundMessage = 'ROOMプロフィールが見つかりませんでした';
  static const String pendingMessage = 'URL形式は正しいですが、通信環境により確認できませんでした';
  static const String networkPendingMessage =
      '通信環境により確認できませんでした。URL形式は正しいため保存できます';
  static const String successMessage = 'ROOMプロフィールURLを確認しました';
  static const String genericErrorMessage = formatErrorMessage;

  static RoomProfileUrlParseResult parse(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return const RoomProfileUrlParseResult(isValid: true, logValue: 'empty');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      return const RoomProfileUrlParseResult(
        isValid: false,
        logValue: 'invalidFormat',
        errorMessage: formatErrorMessage,
      );
    }
    if (uri.scheme.toLowerCase() != 'https') {
      return const RoomProfileUrlParseResult(
        isValid: false,
        logValue: 'invalidScheme',
        errorMessage: formatErrorMessage,
      );
    }
    if (uri.host.toLowerCase() != 'room.rakuten.co.jp') {
      return const RoomProfileUrlParseResult(
        isValid: false,
        logValue: 'invalidHost',
        errorMessage: formatErrorMessage,
      );
    }
    if (uri.hasQuery || uri.hasFragment) {
      return const RoomProfileUrlParseResult(
        isValid: false,
        logValue: 'invalidDecoration',
        errorMessage: formatErrorMessage,
      );
    }

    final segments = uri.pathSegments
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return const RoomProfileUrlParseResult(
        isValid: false,
        logValue: 'topOnly',
        errorMessage: formatErrorMessage,
      );
    }
    if (segments.length > 2) {
      return const RoomProfileUrlParseResult(
        isValid: false,
        logValue: 'roomProductUrl',
        errorMessage: formatErrorMessage,
      );
    }
    if (segments.length == 2) {
      final suffix = segments[1];
      if (RegExp(r'^\d{8,}$').hasMatch(suffix)) {
        return const RoomProfileUrlParseResult(
          isValid: false,
          logValue: 'roomProductUrl',
          errorMessage: formatErrorMessage,
        );
      }
      if (suffix != 'items' && suffix != 'collections' && suffix != 'likes') {
        return const RoomProfileUrlParseResult(
          isValid: false,
          logValue: 'unsupportedProfilePath',
          errorMessage: formatErrorMessage,
        );
      }
    }

    final roomId = segments.first;
    if (roomId == 'api' ||
        roomId == 'items' ||
        roomId == 'collections' ||
        roomId == 'likes' ||
        RegExp(r'^\d{8,}$').hasMatch(roomId) ||
        !RegExp(r'^[A-Za-z0-9_.~-]+$').hasMatch(roomId)) {
      return const RoomProfileUrlParseResult(
        isValid: false,
        logValue: 'notProfileUrl',
        errorMessage: formatErrorMessage,
      );
    }

    return RoomProfileUrlParseResult(
      isValid: true,
      logValue: 'valid',
      roomId: roomId,
    );
  }

  static String normalize(RoomProfileUrlParseResult parsed) {
    if (!parsed.isValid || parsed.roomId.trim().isEmpty) return '';
    return Uri.https('room.rakuten.co.jp', '/${parsed.roomId}').toString();
  }

  static String extractRoomId(String input) {
    final parsed = parse(input);
    return parsed.isValid ? parsed.roomId.trim() : '';
  }

  static String normalizeProfileUrl(String input) {
    final parsed = parse(input);
    return normalize(parsed);
  }

  static String buildItemsUrl(String profileUrl) {
    final normalized = normalizeProfileUrl(profileUrl);
    if (normalized.isEmpty) return '';
    final roomId = extractRoomId(normalized);
    if (roomId.isEmpty) return '';
    return Uri.https('room.rakuten.co.jp', '/$roomId/items').toString();
  }

  static RoomProfileUrlFormatResult validateFormat(String rawUrl) {
    final parsed = parse(rawUrl);
    if (!parsed.isValid) {
      return RoomProfileUrlFormatResult(
        isValid: false,
        logValue: parsed.logValue,
        errorMessage: parsed.errorMessage,
      );
    }
    if (parsed.logValue == 'empty') {
      return const RoomProfileUrlFormatResult(isValid: true, logValue: 'empty');
    }

    final normalized = normalize(parsed);
    if (normalized.isEmpty) {
      return const RoomProfileUrlFormatResult(
        isValid: false,
        logValue: 'invalidFormat',
        errorMessage: formatErrorMessage,
      );
    }

    return RoomProfileUrlFormatResult(
      isValid: true,
      logValue: 'valid',
      normalizedUrl: normalized,
    );
  }

  Future<RoomProfileExistsResult> verifyExists(String normalizedUrl) async {
    final format = validateFormat(normalizedUrl);
    if (format.isEmpty) {
      return const RoomProfileExistsResult(
        exists: true,
        canSave: true,
        logValue: 'skipped',
        message: '',
      );
    }
    if (!format.isValid || format.normalizedUrl.isEmpty) {
      return const RoomProfileExistsResult(
        exists: false,
        canSave: false,
        logValue: 'invalidFormat',
        message: formatErrorMessage,
      );
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
      if (res.statusCode == 404) {
        return const RoomProfileExistsResult(
          exists: false,
          canSave: false,
          logValue: 'notFound',
          message: notFoundMessage,
        );
      }
      if (res.statusCode == 403 || res.statusCode == 429) {
        return const RoomProfileExistsResult(
          exists: false,
          canSave: true,
          logValue: 'pendingBlocked',
          message: pendingMessage,
        );
      }
      if (res.statusCode < 200 || res.statusCode >= 400) {
        return const RoomProfileExistsResult(
          exists: false,
          canSave: true,
          logValue: 'pendingHttp',
          message: pendingMessage,
        );
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
        canSave: true,
        logValue: ok ? 'true' : 'pendingUnverified',
        message: ok ? successMessage : pendingMessage,
      );
    } on TimeoutException {
      return const RoomProfileExistsResult(
        exists: false,
        canSave: true,
        logValue: 'pendingTimeout',
        message: networkPendingMessage,
      );
    } catch (_) {
      return const RoomProfileExistsResult(
        exists: false,
        canSave: true,
        logValue: 'pendingNetwork',
        message: networkPendingMessage,
      );
    } finally {
      if (_ownsClient) {
        _client.close();
      }
    }
  }
}
