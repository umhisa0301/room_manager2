import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/post_comment_generation_result.dart';
import 'post_comment_api_response_parser.dart';
import 'post_comment_generation_exception.dart';
import 'post_comment_generation_service.dart';
import 'post_comment_request_builder.dart';

/// stepbyte-api-server `/api/ai/generate` へ HTTP POST して投稿文を生成する。
class RemotePostCommentGenerationService implements PostCommentGenerationService {
  RemotePostCommentGenerationService({
    required Uri baseUri,
    required String apiKey,
    http.Client? client,
    PostCommentRequestBuilder? requestBuilder,
    PostCommentApiResponseParser? responseParser,
    Duration timeout = const Duration(seconds: 25),
  })  : _baseUri = baseUri,
        _apiKey = apiKey,
        _client = client ?? http.Client(),
        _requestBuilder = requestBuilder ?? const PostCommentRequestBuilder(),
        _responseParser = responseParser ?? const PostCommentApiResponseParser(),
        _timeout = timeout;

  final Uri _baseUri;
  final String _apiKey;
  final http.Client _client;
  final PostCommentRequestBuilder _requestBuilder;
  final PostCommentApiResponseParser _responseParser;
  final Duration _timeout;

  Uri get _endpoint => _baseUri.resolve('/api/ai/generate');

  @override
  Future<PostCommentGenerationResult> generate(
    PostCommentGenerationInput input,
  ) async {
    final requestBody = jsonEncode(_requestBuilder.build(input: input));

    try {
      final response = await _client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'x-stepbyte-app-key': _apiKey,
            },
            body: utf8.encode(requestBody),
          )
          .timeout(_timeout);

      final json = _decodeResponseJson(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (json['success'] == true) {
          throw PostCommentGenerationException(
            'HTTP_ERROR',
            'Server returned HTTP ${response.statusCode}.',
            httpStatus: response.statusCode,
          );
        }
      }

      try {
        return _responseParser.parse(json);
      } on PostCommentGenerationException catch (e) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw PostCommentGenerationException(
            e.code,
            e.message,
            httpStatus: response.statusCode,
          );
        }
        rethrow;
      }
    } on PostCommentGenerationException {
      rethrow;
    } on TimeoutException {
      throw const PostCommentGenerationException(
        'TIMEOUT',
        'Request timed out.',
      );
    } on http.ClientException catch (e) {
      throw PostCommentGenerationException('NETWORK_ERROR', e.message);
    } catch (e) {
      if (e is PostCommentGenerationException) rethrow;
      throw PostCommentGenerationException('NETWORK_ERROR', e.toString());
    }
  }

  Map<String, dynamic> _decodeResponseJson(http.Response response) {
    try {
      final bodyText = utf8.decode(response.bodyBytes);
      final decoded = jsonDecode(bodyText);
      if (decoded is! Map) {
        throw const PostCommentGenerationException(
          'INVALID_JSON',
          'Response is not a JSON object.',
        );
      }
      return Map<String, dynamic>.from(decoded);
    } on PostCommentGenerationException {
      rethrow;
    } catch (_) {
      throw const PostCommentGenerationException(
        'INVALID_JSON',
        'Failed to parse response JSON.',
      );
    }
  }
}
