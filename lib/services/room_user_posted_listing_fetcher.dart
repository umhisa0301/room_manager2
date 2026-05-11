import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/room_rakuten_url_normalize.dart';
import '../utils/room_sync_log.dart';

/// ユーザーの ROOM プロフィールURL起点で、投稿済み ROOM **商品ページ** URL を HTML から収集する。
///
/// - HTTP のみ（WebView なし）。ROOM 側のマークアップ変更に弱い拡張点として正規表現・パス判定を局所化。
/// - スクロール相当の追加件数は [fetchCollectsApiPage]（公開 collects JSON API）で取得。
class RoomUserPostedListingFetcher {
  RoomUserPostedListingFetcher({
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 22),
  }) : _client = httpClient ?? http.Client(),
       _timeout = timeout;

  final http.Client _client;
  final Duration _timeout;

  /// ログ用: 絶対URL抽出に使う正規表現（[RegExp.pattern] と同一文字列）。
  static const String listingAbsoluteUrlPatternSource =
      r'https?://(?:www\.)?room\.rakuten\.co\.jp/[^\s"<>]+';

  /// ログ用: href 抽出に使う正規表現。
  static const String listingHrefPatternSource =
      r'''href\s*=\s*["']([^"']+)["']''';

  /// ログ用: 投稿IDフォールバック（1700始まり13桁以上想定）。
  static const String postIdFallbackPatternSource = r'\b(1700\d{9,})\b';

  static final RegExp _postIdFallbackPattern = RegExp(
    postIdFallbackPatternSource,
  );

  /// ROOM 一覧 HTML（主に `/items`）内の調査ログ（埋め込み JSON / キーワード出現回数）。
  static void logListingHtmlInvestigation(String html) {
    final h = html;
    int count(String needle) {
      if (needle.isEmpty) return 0;
      var c = 0;
      final sub = needle;
      for (var i = h.indexOf(sub); i >= 0; i = h.indexOf(sub, i + sub.length)) {
        c++;
      }
      return c;
    }

    roomSyncLog(
      'LIST調査 __NEXT_DATA__=${count('__NEXT_DATA__')} '
      '__INITIAL_STATE__=${count('__INITIAL_STATE__')} '
      'initialState(部分一致)=${count('initialState')} '
      'api=${count('api')} item=${count('item')} cursor=${count('cursor')} '
      'page=${count('page')} offset=${count('offset')} since=${count('since')} '
      'continuation=${count('continuation')} roomId=${count('roomId')} '
      'userId=${count('userId')}',
    );
    final id = tryParseNumericUserIdFromInitialState(h);
    roomSyncLog('LIST調査 __INITIAL_STATE__ からの userData.id: ${id ?? '(未取得)'}');
  }

  /// `window.__INITIAL_STATE__` 内の `userData.id`（数値ユーザーID）。collects API のパスに使用。
  static String? tryParseNumericUserIdFromInitialState(String html) {
    const prefix = 'window.__INITIAL_STATE__ = ';
    final startIdx = html.indexOf(prefix);
    if (startIdx < 0) return null;
    var j = startIdx + prefix.length;
    while (j < html.length &&
        (html[j] == ' ' || html[j] == '\n' || html[j] == '\r')) {
      j++;
    }
    if (j >= html.length || html[j] != '{') return null;
    final jsonStart = j;
    var depth = 0;
    var inString = false;
    var stringQuote = 0;
    var escape = false;
    for (; j < html.length; j++) {
      final ch = html[j];
      if (escape) {
        escape = false;
        continue;
      }
      if (inString) {
        if (ch == r'\') {
          escape = true;
          continue;
        }
        if (ch.codeUnitAt(0) == stringQuote) {
          inString = false;
          stringQuote = 0;
        }
        continue;
      }
      switch (ch) {
        case '"':
        case "'":
          inString = true;
          stringQuote = ch.codeUnitAt(0);
          continue;
        case '{':
          depth++;
          continue;
        case '}':
          depth--;
          if (depth == 0) {
            final raw = html.substring(jsonStart, j + 1);
            return _readUserDataIdFromInitialStateJson(raw);
          }
          continue;
        default:
          continue;
      }
    }
    return null;
  }

  static String? _readUserDataIdFromInitialStateJson(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final userData = decoded['userData'];
      if (userData is! Map<String, dynamic>) return null;
      final id = userData['id'];
      if (id is String && RegExp(r'^\d+$').hasMatch(id)) return id;
      if (id is int) return id.toString();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 一覧ページの HTML 本文のみ取得（プロフィールが `/items` 以外でもホスト妥当なら GET）。
  Future<String?> fetchListingHtmlBody(String userRoomProfileUrl) async {
    final trimmed = userRoomProfileUrl.trim();
    if (trimmed.isEmpty) return null;
    late Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      return null;
    }
    if (!uri.hasScheme || !_isRoomHost(uri.host)) return null;
    final res = await _getRoomListingPage(uri);
    RoomImportDebugLogBuffer.incRoomList();
    if (res == null ||
        res.statusCode < 200 ||
        res.statusCode >= 400 ||
        res.body.isEmpty) {
      return null;
    }
    return res.body;
  }

  /// 楽天ROOM公開API `GET /api/{numericUserId}/collects` の1ページ分を解析する。
  Future<RoomCollectsApiPage?> fetchCollectsApiPage({
    required String numericUserId,
    required String roomUserSegment,
    String? afterId,
    int limit = 20,
  }) async {
    final apiSw = Stopwatch()..start();
    var statusCode = -1;
    if (!RegExp(r'^\d+$').hasMatch(numericUserId)) {
      roomSyncWarn('collects API: numericUserId が不正のため中断');
      roomImportApiLog(
        'type=roomList status=invalidInput durationMs=${apiSw.elapsedMilliseconds}',
      );
      return null;
    }
    final q = <String, String>{
      'api_version': '1',
      'limit': limit.clamp(1, 50).toString(),
    };
    if (afterId != null && afterId.isNotEmpty) {
      q['after_id'] = afterId;
    }
    final uri = Uri.https(
      'room.rakuten.co.jp',
      '/api/$numericUserId/collects',
      q,
    );
    roomSyncLog('collects API GET: $uri');
    late http.Response res;
    try {
      res = await _client
          .get(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (compatible; RoomManagerApp/1.0; +https://example.invalid)',
              'Accept': 'application/json',
              'Referer': 'https://room.rakuten.co.jp/$roomUserSegment/items',
            },
          )
          .timeout(_timeout);
      statusCode = res.statusCode;
    } on TimeoutException catch (e, st) {
      roomSyncError('collects API タイムアウト', e, st);
      RoomImportDebugLogBuffer.incRoomList();
      return null;
    } catch (e, st) {
      roomSyncError('collects API 例外', e, st);
      RoomImportDebugLogBuffer.incRoomList();
      return null;
    }

    RoomImportDebugLogBuffer.incRoomList();
    roomSyncLog('collects API HTTP status: ${res.statusCode}');
    if (res.statusCode < 200 || res.statusCode >= 400 || res.body.isEmpty) {
      roomSyncWarn('collects API 応答不正（未取得扱い）');
      return null;
    }

    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      final status = decoded['status'];
      final code = decoded['code'];
      if (status != 'success' || code != 200) {
        roomSyncWarn(
          'collects API JSON status 非 success: status=$status code=$code',
        );
        return null;
      }
      final data = decoded['data'];
      if (data is! List<dynamic>) return null;
      final meta = decoded['meta'];
      String? nextAfter;
      if (meta is Map<String, dynamic>) {
        final a = meta['after_id'];
        if (a is String && a.isNotEmpty) nextAfter = a;
      }

      final out = <String>[];
      for (final row in data) {
        if (row is! Map<String, dynamic>) continue;
        final id = row['id'];
        if (id is! String || id.isEmpty) continue;
        if (!RegExp(r'^\d{8,}$').hasMatch(id)) continue;
        final built = 'https://room.rakuten.co.jp/$roomUserSegment/$id';
        final key = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(built);
        if (key.isNotEmpty) out.add(key);
      }

      return RoomCollectsApiPage(
        roomPageKeysOrdered: out,
        nextAfterId: nextAfter,
        rawItemCount: data.length,
      );
    } catch (e, st) {
      roomSyncError('collects API JSON 解析失敗', e, st);
      return null;
    } finally {
      roomImportApiLog(
        'type=roomList status=$statusCode durationMs=${apiSw.elapsedMilliseconds}',
      );
      roomImportApiLog('rateLimitDetected=${statusCode == 429}');
    }
  }

  /// 投稿の古い→新しいなど **一覧上の出現順** を可能な限り保持した URL リスト（重複キーは除外）。
  Future<List<String>> fetchPostedRoomProductPageUrls(
    String userRoomProfileUrl, {
    void Function(String html)? onListingHtml,
  }) async {
    final fetchSw = Stopwatch()..start();
    final trimmed = userRoomProfileUrl.trim();
    roomSyncLog('ROOM一覧取得処理: fetchPostedRoomProductPageUrls 開始');
    roomSyncLog('入力ROOM URL: ${trimmed.isEmpty ? '(空)' : trimmed}');

    if (trimmed.isEmpty) {
      roomSyncWarn('入力ROOM URL が空のため中断');
      roomImportPerfLog(
        'fetchRoomListEnd status=invalidInput htmlBytes=0 durationMs=${fetchSw.elapsedMilliseconds}',
      );
      return [];
    }
    Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (e, st) {
      roomSyncError('ROOM URL の Uri 解析に失敗', e, st);
      roomImportPerfLog(
        'fetchRoomListEnd status=invalidUrl htmlBytes=0 durationMs=${fetchSw.elapsedMilliseconds}',
      );
      return [];
    }

    roomSyncLog('正規化後ROOM URL（HTTP GET に使用）: ${uri.toString()}');
    roomSyncLog('補足: 現行実装では /items 等のパスは自動付与しません（入力の Uri をそのまま GET します）。');
    roomSyncLog('参考 /items を付けた場合の例URL: ${_exampleItemsUrl(uri)}');

    if (!uri.hasScheme || !_isRoomHost(uri.host)) {
      roomSyncWarn(
        'スキームまたはホスト不正のため中断 hasScheme=${uri.hasScheme} host=${uri.host}',
      );
      roomImportPerfLog(
        'fetchRoomListEnd status=invalidHost htmlBytes=0 durationMs=${fetchSw.elapsedMilliseconds}',
      );
      return [];
    }

    final userSeg = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    roomSyncLog('ROOM ユーザーセグメント（先頭パス）: ${userSeg.isEmpty ? '(なし)' : userSeg}');

    roomSyncLog('楽天ROOM一覧へ接続: ${uri.toString()}');
    roomSyncLog(
      'User-Agent: Mozilla/5.0 (compatible; RoomManagerApp/1.0; +https://example.invalid)',
    );

    final res = await _getRoomListingPage(uri);
    RoomImportDebugLogBuffer.incRoomList();
    if (res == null) {
      roomImportPerfLog(
        'fetchRoomListEnd status=fetchFailed htmlBytes=0 durationMs=${fetchSw.elapsedMilliseconds}',
      );
      return [];
    }

    roomSyncLog('HTTP status: ${res.statusCode}');
    roomSyncPreview('ROOM一覧 response body', res.body, maxLength: 500);

    if (res.statusCode < 200 || res.statusCode >= 400 || res.body.isEmpty) {
      roomSyncError(
        'ROOM一覧ページ取得失敗 status=${res.statusCode} bodyEmpty=${res.body.isEmpty}',
      );
      roomSyncPreview('ROOM一覧 error body preview', res.body, maxLength: 500);
      roomImportPerfLog(
        'fetchRoomListEnd status=${res.statusCode} htmlBytes=${res.body.length} durationMs=${fetchSw.elapsedMilliseconds}',
      );
      roomImportApiLog(
        'type=roomList status=${res.statusCode} durationMs=${fetchSw.elapsedMilliseconds}',
      );
      roomImportApiLog('rateLimitDetected=${res.statusCode == 429}');
      return [];
    }
    roomImportPerfLog(
      'fetchRoomListEnd status=${res.statusCode} htmlBytes=${res.body.length} durationMs=${fetchSw.elapsedMilliseconds}',
    );
    roomImportApiLog(
      'type=roomList status=${res.statusCode} durationMs=${fetchSw.elapsedMilliseconds}',
    );
    roomImportApiLog('rateLimitDetected=${res.statusCode == 429}');

    final html = res.body;
    logListingHtmlInvestigation(html);
    onListingHtml?.call(html);
    final decoded = RoomUrlResolverStyleUnescape.unescapeBasicXmlEntities(html);
    final candidates = _collectFromHtml(
      html: html,
      decodedHtml: decoded,
      baseUri: uri,
    );
    roomSyncLog('ROOM商品URL抽出開始（生候補・重複あり）');
    roomSyncLog('抽出候補数（フィルタ前 href/絶対URL 総数）: ${candidates.length}');

    final seen = <String>{};
    final out = <String>[];

    for (final raw in candidates) {
      final abs = raw.startsWith('http') ? raw : uri.resolve(raw).toString();
      if (!RoomRakutenUrlNormalize.isLikelyRoomProductPageUrl(abs)) continue;
      final u = Uri.tryParse(abs);
      if (u == null || !_isRoomHost(u.host)) continue;
      if (userSeg.isNotEmpty && !_belongsToRoomUser(u, userSeg)) continue;
      if (!_isLikelyRoomPostPath(u)) continue;
      final key = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(abs);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(key);
    }

    roomSyncLog('ROOM商品URL抽出結果（ユーザー・投稿IDパス妥当性でフィルタ後）');
    roomSyncLog('抽出件数: ${out.length}');
    for (var i = 0; i < out.length; i++) {
      roomSyncLog('ROOM商品URL[${i + 1}]: ${out[i]}');
    }

    if (out.isEmpty) {
      roomSyncWarn('ROOM商品URLを1件も抽出できませんでした（href/絶対URL経路）');
      roomSyncWarn('使用した正規表現（絶対URL）: $listingAbsoluteUrlPatternSource');
      roomSyncWarn('使用した正規表現（href）: $listingHrefPatternSource');
      roomSyncWarn(
        'HTML内に room.rakuten.co.jp を含むか: ${html.toLowerCase().contains('room.rakuten.co.jp')}',
      );
      roomSyncWarn(
        'HTML内に 1700 形式の商品IDらしき文字列(13桁以上の連続数字)を含むか: ${_htmlHasLongDigitId(html)}',
      );

      if (userSeg.isEmpty) {
        roomSyncWarn('ROOM ユーザーセグメントが空のため投稿IDフォールバックをスキップ');
      } else {
        roomSyncLog('href/絶対URLからの抽出が0件のため、投稿ID fallback抽出を開始');
        roomSyncLog('使用した正規表現（投稿ID）: $postIdFallbackPatternSource');
        final postIds = _extractPostIdCandidates(html, decoded);
        roomSyncLog('投稿ID候補数: ${postIds.length}');
        for (var i = 0; i < postIds.length; i++) {
          roomSyncLog('投稿ID[${i + 1}]: ${postIds[i]}');
        }
        const fallbackRoomUrlMax = 10;
        var addedFromFallback = 0;
        for (final postId in postIds) {
          if (addedFromFallback >= fallbackRoomUrlMax) break;
          final built = 'https://room.rakuten.co.jp/$userSeg/$postId';
          final key = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(
            built,
          );
          if (key.isEmpty || seen.contains(key)) continue;
          seen.add(key);
          out.add(key);
          addedFromFallback++;
          roomSyncLog('fallback生成ROOM URL[$addedFromFallback]: $key');
        }
        roomSyncLog('fallback後ROOM商品URL件数: ${out.length}');
      }
    }

    return out;
  }

  Future<http.Response?> _getRoomListingPage(Uri uri) async {
    try {
      return await _client
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (compatible; RoomManagerApp/1.0; +https://example.invalid)',
              'Accept': 'text/html,application/xhtml+xml',
            },
          )
          .timeout(_timeout);
    } on TimeoutException catch (e, st) {
      roomSyncError('ROOM一覧ページ取得失敗: タイムアウト', e, st);
      return null;
    } catch (e, st) {
      roomSyncError('ROOM一覧ページ取得失敗: 例外', e, st);
      return null;
    }
  }

  static String _exampleItemsUrl(Uri u) {
    final p = u.path.endsWith('/') ? '${u.path}items' : '${u.path}/items';
    return u.replace(path: p).toString();
  }

  static bool _htmlHasLongDigitId(String html) {
    return RegExp(r'\d{13,}').hasMatch(html);
  }

  /// HTML / エスケープ解除HTML の両方から、出現順でユニークな投稿ID候補を列挙。
  static List<String> _extractPostIdCandidates(
    String html,
    String decodedHtml,
  ) {
    final ordered = <String>[];
    final seenIds = <String>{};
    void scan(String source) {
      for (final m in _postIdFallbackPattern.allMatches(source)) {
        final id = (m.group(1) ?? '').trim();
        if (id.isEmpty || seenIds.contains(id)) continue;
        seenIds.add(id);
        ordered.add(id);
      }
    }

    scan(html);
    scan(decodedHtml);
    return ordered;
  }

  static bool _isRoomHost(String host) {
    final h = host.toLowerCase();
    return h == 'room.rakuten.co.jp' || h.endsWith('.room.rakuten.co.jp');
  }

  static bool _belongsToRoomUser(Uri productUri, String userSegment) {
    final segs = productUri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.isEmpty) return false;
    return segs.first == userSegment;
  }

  /// パスが `{user}/{投稿ID}` 形式かどうかの軽量判定（投稿IDは数字想定・将来の形式差はここで調整）。
  static bool _isLikelyRoomPostPath(Uri u) {
    final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length < 2) return false;
    final last = segs.last;
    return RegExp(r'^\d{8,}$').hasMatch(last);
  }

  static List<String> _collectFromHtml({
    required String html,
    required String decodedHtml,
    required Uri baseUri,
  }) {
    final out = <String>[];
    final reAbs = RegExp(listingAbsoluteUrlPatternSource, caseSensitive: false);
    for (final m in reAbs.allMatches(html)) {
      final s = m.group(0);
      if (s != null) out.add(s);
    }
    for (final m in reAbs.allMatches(decodedHtml)) {
      final s = m.group(0);
      if (s != null) out.add(s);
    }

    final reHref = RegExp(listingHrefPatternSource, caseSensitive: false);
    for (final m in reHref.allMatches(html)) {
      final ref = (m.group(1) ?? '').trim();
      if (ref.isEmpty || ref.startsWith('#')) continue;
      out.add(ref);
    }
    for (final m in reHref.allMatches(decodedHtml)) {
      final ref = (m.group(1) ?? '').trim();
      if (ref.isEmpty || ref.startsWith('#')) continue;
      out.add(ref);
    }
    return out;
  }
}

/// [RoomUrlResolver] と同等の最低限エスケープ解除（クラス共有せず局所で保持し、既存ファイル名を増やさない）。
/// [/api/{id}/collects] 相当の1ページぶん（正規化済み ROOM 商品ページキー列）。
class RoomCollectsApiPage {
  const RoomCollectsApiPage({
    required this.roomPageKeysOrdered,
    this.nextAfterId,
    required this.rawItemCount,
  });

  final List<String> roomPageKeysOrdered;
  final String? nextAfterId;
  final int rawItemCount;
}

abstract final class RoomUrlResolverStyleUnescape {
  static String unescapeBasicXmlEntities(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'");
  }
}
