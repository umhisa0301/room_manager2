import 'dart:async';

import 'package:http/http.dart' as http;

import '../utils/room_rakuten_url_normalize.dart';
import '../utils/room_sync_log.dart';

/// ユーザーの ROOM プロフィールURL起点で、投稿済み ROOM **商品ページ** URL を HTML から収集する。
///
/// - HTTP のみ（WebView なし）。ROOM 側のマークアップ変更に弱い拡張点として正規表現・パス判定を局所化。
/// - 将来: ページング・同期オフセット引数を足せる構造。
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

  /// 投稿の古い→新しいなど **一覧上の出現順** を可能な限り保持した URL リスト（重複キーは除外）。
  Future<List<String>> fetchPostedRoomProductPageUrls(String userRoomProfileUrl) async {
    final trimmed = userRoomProfileUrl.trim();
    roomSyncLog('ROOM一覧取得処理: fetchPostedRoomProductPageUrls 開始');
    roomSyncLog('入力ROOM URL: ${trimmed.isEmpty ? '(空)' : trimmed}');

    if (trimmed.isEmpty) {
      roomSyncWarn('入力ROOM URL が空のため中断');
      return [];
    }
    Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (e, st) {
      roomSyncError('ROOM URL の Uri 解析に失敗', e, st);
      return [];
    }

    roomSyncLog('正規化後ROOM URL（HTTP GET に使用）: ${uri.toString()}');
    roomSyncLog(
      '補足: 現行実装では /items 等のパスは自動付与しません（入力の Uri をそのまま GET します）。',
    );
    roomSyncLog('参考 /items を付けた場合の例URL: ${_exampleItemsUrl(uri)}');

    if (!uri.hasScheme || !_isRoomHost(uri.host)) {
      roomSyncWarn(
        'スキームまたはホスト不正のため中断 hasScheme=${uri.hasScheme} host=${uri.host}',
      );
      return [];
    }

    final userSeg = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    roomSyncLog('ROOM ユーザーセグメント（先頭パス）: ${userSeg.isEmpty ? '(なし)' : userSeg}');

    roomSyncLog('楽天ROOM一覧へ接続: ${uri.toString()}');
    roomSyncLog(
      'User-Agent: Mozilla/5.0 (compatible; RoomManagerApp/1.0; +https://example.invalid)',
    );

    late http.Response res;
    try {
      res = await _client
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
      return [];
    } catch (e, st) {
      roomSyncError('ROOM一覧ページ取得失敗: 例外', e, st);
      return [];
    }

    roomSyncLog('HTTP status: ${res.statusCode}');
    roomSyncPreview('ROOM一覧 response body', res.body, maxLength: 500);

    if (res.statusCode < 200 || res.statusCode >= 400 || res.body.isEmpty) {
      roomSyncError(
        'ROOM一覧ページ取得失敗 status=${res.statusCode} bodyEmpty=${res.body.isEmpty}',
      );
      roomSyncPreview('ROOM一覧 error body preview', res.body, maxLength: 500);
      return [];
    }

    final html = res.body;
    final decoded = RoomUrlResolverStyleUnescape.unescapeBasicXmlEntities(html);
    final candidates = _collectFromHtml(html: html, decodedHtml: decoded, baseUri: uri);
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
      roomSyncWarn('ROOM商品URLを1件も抽出できませんでした');
      roomSyncWarn('使用した正規表現（絶対URL）: $listingAbsoluteUrlPatternSource');
      roomSyncWarn('使用した正規表現（href）: $listingHrefPatternSource');
      roomSyncWarn(
        'HTML内に room.rakuten.co.jp を含むか: ${html.toLowerCase().contains('room.rakuten.co.jp')}',
      );
      roomSyncWarn(
        'HTML内に 1700 形式の商品IDらしき文字列(13桁以上の連続数字)を含むか: ${_htmlHasLongDigitId(html)}',
      );
    }

    return out;
  }

  static String _exampleItemsUrl(Uri u) {
    final p = u.path.endsWith('/') ? '${u.path}items' : '${u.path}/items';
    return u.replace(path: p).toString();
  }

  static bool _htmlHasLongDigitId(String html) {
    return RegExp(r'\d{13,}').hasMatch(html);
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
    final reAbs = RegExp(
      listingAbsoluteUrlPatternSource,
      caseSensitive: false,
    );
    for (final m in reAbs.allMatches(html)) {
      final s = m.group(0);
      if (s != null) out.add(s);
    }
    for (final m in reAbs.allMatches(decodedHtml)) {
      final s = m.group(0);
      if (s != null) out.add(s);
    }

    final reHref = RegExp(
      listingHrefPatternSource,
      caseSensitive: false,
    );
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
