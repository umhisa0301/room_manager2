import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/room_rakuten_url_normalize.dart';
import '../utils/room_sync_log.dart';
import 'rakuten_item_url_parser.dart';
import 'room_room_page_reaction_parse.dart';

/// ROOM 商品ページから楽天市場の商品URLを推定する。
///
/// **Step 1（本実装）**: HTTP で HTML を取得し [RakutenItemUrlParser] で `item.rakuten.co.jp` を検索。
///
/// **Step 2**: `hb.afl.rakuten.co.jp` リンクの `pc` クエリ（URLエンコードされた item URL）をデコードして採用。
///
/// **WebView フォールバック**: ROOM 側が JS 必須でリンクが HTML に現れない場合、
/// 既存の [RoomUrlExtractionCoordinator] 経由でページを描画し DOM から href を拾う
/// 拡張が可能（本クラスは [resolveRakutenItemUrlFromRoomPage] の戻りで失敗理由を区別できる）。
class RoomUrlResolver {
  RoomUrlResolver({
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 18),
  }) : _client = httpClient ?? http.Client(),
       _timeout = timeout;

  final http.Client _client;
  final Duration _timeout;

  static final RegExp _aflUrlPattern = RegExp(
    r'https?://hb\.afl\.rakuten\.co\.jp/[^\s"<>]+',
    caseSensitive: false,
  );

  /// HTTP のみ。将来的に `useWebViewFallback: true` で Coordinator に委譲可能な拡張点。
  ///
  /// [traceRoomSync] が true のとき、[ROOM_SYNC] プレフィックス付きで詳細ログを出す（kDebugMode のみ）。
  Future<RoomUrlResolveOutcome> resolveRakutenItemUrlFromRoomPage(
    String roomPageUrl, {
    bool useWebViewFallback = false,
    bool traceRoomSync = false,
  }) async {
    final trimmed = roomPageUrl.trim();
    if (trimmed.isEmpty) {
      if (traceRoomSync) {
        roomSyncWarn('ROOM商品ページURLが空（invalidInput）');
      }
      return const RoomUrlResolveFailure(
        RoomUrlResolveFailureKind.invalidInput,
      );
    }
    if (!RoomRakutenUrlNormalize.isLikelyRoomProductPageUrl(trimmed)) {
      if (traceRoomSync) {
        roomSyncWarn('ROOM商品ページURLとして不正（notRoomUrl）: $trimmed');
      }
      return const RoomUrlResolveFailure(RoomUrlResolveFailureKind.notRoomUrl);
    }
    if (useWebViewFallback) {
      if (kDebugMode) {
        debugPrint(
          '[RoomUrlResolver] WebView フォールバックは未実装です（ATS/非同期WebView制約のため HTTP を使用）。',
        );
      }
    }

    late http.Response res;
    final pageFetchSw = Stopwatch()..start();
    try {
      if (traceRoomSync) {
        roomSyncLog('ROOM商品ページへ接続: $trimmed');
        roomSyncLog(
          'User-Agent: Mozilla/5.0 (compatible; RoomManagerApp/1.0; +https://example.invalid)',
        );
      }
      res = await _client
          .get(
            Uri.parse(trimmed),
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (compatible; RoomManagerApp/1.0; +https://example.invalid)',
              'Accept': 'text/html,application/xhtml+xml',
            },
          )
          .timeout(_timeout);
    } on TimeoutException catch (e, st) {
      if (traceRoomSync) {
        roomSyncError('ROOM商品ページ取得失敗: timeout', e, st);
      }
      RoomImportDebugLogBuffer.incRoomPage();
      return const RoomUrlResolveFailure(RoomUrlResolveFailureKind.timeout);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RoomUrlResolver] HTTP 失敗: $e\n$st');
      }
      if (traceRoomSync) {
        roomSyncError('ROOM商品ページ取得失敗: exception', e, st);
      }
      RoomImportDebugLogBuffer.incRoomPage();
      return const RoomUrlResolveFailure(
        RoomUrlResolveFailureKind.networkError,
      );
    }
    pageFetchSw.stop();
    RoomImportDebugLogBuffer.incRoomPage();
    roomImportApiLog(
      'type=roomPage status=${res.statusCode} durationMs=${pageFetchSw.elapsedMilliseconds}',
    );
    roomImportApiLog('rateLimitDetected=${res.statusCode == 429}');

    if (traceRoomSync) {
      roomSyncLog('HTTP status: ${res.statusCode}');
      roomSyncPreview('ROOM商品ページ response body', res.body, maxLength: 500);
    }

    if (res.statusCode < 200 || res.statusCode >= 400) {
      if (traceRoomSync) {
        roomSyncError('ROOM商品ページ取得失敗 status=${res.statusCode}');
        roomSyncPreview('ROOM商品ページ error body', res.body, maxLength: 500);
      }
      return RoomUrlResolveFailure(
        RoomUrlResolveFailureKind.httpError,
        debugDetail: 'status=${res.statusCode}',
      );
    }

    final body = res.body;
    if (body.isEmpty) {
      if (traceRoomSync) {
        roomSyncWarn('ROOM商品ページ response body が空（emptyBody）');
      }
      return const RoomUrlResolveFailure(RoomUrlResolveFailureKind.emptyBody);
    }

    return parseFetchedRoomPageHtml(body, traceRoomSync: traceRoomSync);
  }

  /// ROOM 商品ページの HTML 本文から楽天URL・OG・反応数を解決する（HTTP 層は呼び出し側）。
  ///
  /// [RoomSyncService] の一覧HTML高速パスでも同じロジックを使う。
  static RoomUrlResolveOutcome parseFetchedRoomPageHtml(
    String body, {
    bool traceRoomSync = false,
  }) {
    final decoded = _unescapeBasicXmlEntities(body);
    final aflUrlsOrdered = _collectAflUrlsUniqueOrdered(decoded, body);

    if (traceRoomSync) {
      roomSyncLog('楽天で見るURL抽出開始（① item.rakuten 直接 → ② afl pc デコード）');
      final decList = RakutenItemUrlParser.findAllMatchesInText(decoded);
      final rawList = RakutenItemUrlParser.findAllMatchesInText(body);
      final merged = <String>[];
      final seenItem = <String>{};
      void addAll(List<RakutenItemUrlParseResult> list) {
        for (final r in list) {
          final u = r.rakutenUrl.trim();
          if (u.isEmpty || seenItem.contains(u)) continue;
          seenItem.add(u);
          merged.add(u);
        }
      }

      addAll(decList);
      addAll(rawList);
      roomSyncLog('楽天URL候補数（item.rakuten ユニーク）: ${merged.length}');
      for (var i = 0; i < merged.length; i++) {
        roomSyncLog('楽天URL候補[${i + 1}] (item): ${merged[i]}');
      }
      roomSyncLog('楽天アフィリエイトURL候補数: ${aflUrlsOrdered.length}');
      for (var i = 0; i < aflUrlsOrdered.length; i++) {
        roomSyncLog('楽天URL候補[${i + 1}] (afl): ${aflUrlsOrdered[i]}');
      }
    }

    String? roomPageAffiliateUrl;
    RakutenItemUrlParseResult? parsed = RakutenItemUrlParser.findFirstInText(
      decoded,
    );
    parsed ??= RakutenItemUrlParser.findFirstInText(body);
    if (parsed == null) {
      final pair = _tryParseItemFromFirstAflPc(aflUrlsOrdered, traceRoomSync);
      if (pair != null) {
        parsed = pair.item;
        final raw = pair.aflSourceUrl.trim();
        roomPageAffiliateUrl = raw.isEmpty ? null : raw;
      }
    } else if (aflUrlsOrdered.isNotEmpty) {
      final raw = aflUrlsOrdered.first.trim();
      roomPageAffiliateUrl = raw.isEmpty ? null : raw;
    }

    if (parsed == null) {
      if (traceRoomSync) {
        roomSyncWarn('楽天URLを取得できませんでした（item 直接・afl pc いずれも不一致）');
        final sample = decoded.isNotEmpty ? decoded : body;
        final lower = sample.toLowerCase();
        roomSyncWarn(
          'HTML内に item.rakuten.co.jp を含むか: ${lower.contains('item.rakuten.co.jp')}',
        );
        roomSyncWarn(
          'HTML内に hb.afl.rakuten.co.jp を含むか: ${lower.contains('hb.afl.rakuten.co.jp')}',
        );
        roomSyncWarn('HTML内に 「楽天市場で見る」を含むか: ${sample.contains('楽天市場で見る')}');
        roomSyncWarn('HTML内に 「楽天で見る」を含むか: ${sample.contains('楽天で見る')}');
      }
      return const RoomUrlResolveFailure(
        RoomUrlResolveFailureKind.rakutenLinkNotFound,
      );
    }

    if (traceRoomSync) {
      roomSyncLog('採用楽天URL: ${parsed.rakutenUrl}');
    }

    final meta = _readOpenGraphTitleAndImage(
      decoded.isNotEmpty ? decoded : body,
    );
    final reaction = RoomRoomPageReactionParse.tryParse(body);
    final priceHint = _extractListingHintPriceYenFromText(
      decoded.isNotEmpty ? decoded : body,
    );
    return RoomUrlResolveSuccess(
      rakutenItem: parsed,
      roomPageAffiliateUrl: roomPageAffiliateUrl,
      roomPageTitle: meta.$1,
      roomPageImageUrl: meta.$2,
      roomLikeCount: reaction.roomLikeCount,
      roomCommentCount: reaction.roomCommentCount,
      listingHintPriceYen: priceHint,
    );
  }

  /// 一覧高速パス由来の解決結果に、後から取得した ROOM 商品ページ HTML のメタをマージする。
  ///
  /// 楽天API失敗時のフォールバックで、タイトル・画像・参考価格をフルページ側で補う。
  static RoomUrlResolveSuccess mergeRoomResolveSuccessPreferFetched({
    required RoomUrlResolveSuccess listingOrFast,
    required RoomUrlResolveSuccess fetchedFullPage,
  }) {
    String pickTitle(String? a, String? b) {
      final tb = b?.trim() ?? '';
      if (tb.isNotEmpty) return tb;
      return a?.trim() ?? '';
    }

    String pickImg(String? a, String? b) {
      final tb = b?.trim() ?? '';
      if (tb.isNotEmpty) return tb;
      return a?.trim() ?? '';
    }

    int? pickHint(int? a, int? b) {
      if (b != null && b > 0) return b;
      if (a != null && a > 0) return a;
      return b ?? a;
    }

    final affFetched = fetchedFullPage.roomPageAffiliateUrl?.trim() ?? '';
    return RoomUrlResolveSuccess(
      rakutenItem: listingOrFast.rakutenItem,
      roomPageAffiliateUrl:
          affFetched.isNotEmpty ? fetchedFullPage.roomPageAffiliateUrl : listingOrFast.roomPageAffiliateUrl,
      roomPageTitle: pickTitle(
        listingOrFast.roomPageTitle,
        fetchedFullPage.roomPageTitle,
      ),
      roomPageImageUrl: pickImg(
        listingOrFast.roomPageImageUrl,
        fetchedFullPage.roomPageImageUrl,
      ),
      roomLikeCount: fetchedFullPage.roomLikeCount ?? listingOrFast.roomLikeCount,
      roomCommentCount:
          fetchedFullPage.roomCommentCount ?? listingOrFast.roomCommentCount,
      listingHintPriceYen: pickHint(
        listingOrFast.listingHintPriceYen,
        fetchedFullPage.listingHintPriceYen,
      ),
    );
  }

  /// 一覧カード断片・商品ページ HTML から税込らしき金額を拾う（楽天APIが無いときの補助）。
  static int? _extractListingHintPriceYenFromText(String text) {
    if (text.isEmpty) return null;
    final yen = RegExp(r'[¥￥]\s*([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{2,})');
    final m = yen.firstMatch(text);
    if (m != null && m.groupCount >= 1) {
      final digits = (m.group(1) ?? '').replaceAll(',', '');
      final v = int.tryParse(digits);
      if (v != null && v > 0 && v < 100000000) return v;
    }
    final jsonPrice = RegExp(
      r'"(?:itemPrice|price|minPrice|item_price)"\s*:\s*([0-9]+)',
      caseSensitive: false,
    );
    final jm = jsonPrice.firstMatch(text);
    if (jm != null) {
      final v = int.tryParse(jm.group(1) ?? '');
      if (v != null && v > 0 && v < 100000000) return v;
    }
    return null;
  }

  /// 一覧HTMLの断片から [parseFetchedRoomPageHtml] と同等の解決を試みる。失敗時は null。
  static RoomUrlResolveSuccess? tryParseRoomPageFromHtmlSnippet(
    String htmlFragment, {
    bool traceRoomSync = false,
  }) {
    if (htmlFragment.trim().isEmpty) return null;
    final o = parseFetchedRoomPageHtml(htmlFragment, traceRoomSync: traceRoomSync);
    return o is RoomUrlResolveSuccess ? o : null;
  }

  /// `/items` 等の一覧HTMLから、各投稿キーごとの解決候補を [sink] にマージする。
  static void mergeListingFastPathHintsFromHtml(
    String html,
    String roomUserSegment,
    Map<String, RoomUrlResolveSuccess> sink,
  ) {
    final seg = roomUserSegment.trim();
    if (html.isEmpty || seg.isEmpty) return;
    final re = RegExp(
      r'https?://(?:www\.)?room\.rakuten\.co\.jp/' + RegExp.escape(seg) + r'/(\d{8,})\b',
      caseSensitive: false,
    );
    final seenPost = <String>{};
    for (final m in re.allMatches(html)) {
      final postId = m.group(1) ?? '';
      if (postId.isEmpty || !seenPost.add(postId)) continue;
      final fullUrl = 'https://room.rakuten.co.jp/$seg/$postId';
      final key = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(fullUrl);
      if (key.isEmpty) continue;
      final start = m.start;
      const before = 6000;
      const after = 9000;
      final lo = start > before ? start - before : 0;
      final end = start + after;
      final hi = end > html.length ? html.length : end;
      final snippet = html.substring(lo, hi);
      var ok = tryParseRoomPageFromHtmlSnippet(snippet, traceRoomSync: false);
      final hint = _extractListingHintPriceYenFromText(snippet);
      if (ok != null && hint != null) {
        ok = RoomUrlResolveSuccess(
          rakutenItem: ok.rakutenItem,
          roomPageAffiliateUrl: ok.roomPageAffiliateUrl,
          roomPageTitle: ok.roomPageTitle,
          roomPageImageUrl: ok.roomPageImageUrl,
          roomLikeCount: ok.roomLikeCount,
          roomCommentCount: ok.roomCommentCount,
          listingHintPriceYen: hint,
        );
      }
      if (ok != null) {
        _mergeListingFastPathEntry(sink, key, ok);
      }
    }
  }

  /// collects API の1行から高速パス用の解決候補を [sink] にマージする。
  static void mergeListingFastPathFromCollectsRow(
    Map<String, dynamic> row,
    String roomUserSegment,
    Map<String, RoomUrlResolveSuccess> sink,
  ) {
    final seg = roomUserSegment.trim();
    if (seg.isEmpty) return;
    final id = row['id'];
    if (id is! String || !RegExp(r'^\d{8,}$').hasMatch(id)) return;
    final built = 'https://room.rakuten.co.jp/$seg/$id';
    final key = RoomRakutenUrlNormalize.normalizeRoomProductPageKey(built);
    if (key.isEmpty) return;

    final aflAcc = <String>[];
    RakutenItemUrlParseResult? parsed;
    void onItem(RakutenItemUrlParseResult p) {
      parsed ??= p;
    }

    _scanJsonForRakutenInCollects(row, aflAcc, onItem);

    String? aflAff;
    if (parsed == null && aflAcc.isNotEmpty) {
      final uniq = aflAcc.toSet().toList();
      final pair = _tryParseItemFromFirstAflPc(uniq, false);
      if (pair != null) {
        parsed = pair.item;
        final raw = pair.aflSourceUrl.trim();
        aflAff = raw.isEmpty ? null : raw;
      }
    } else if (parsed != null && aflAcc.isNotEmpty) {
      final raw = aflAcc.first.trim();
      aflAff = raw.isEmpty ? null : raw;
    }

    if (parsed == null) return;
    final RakutenItemUrlParseResult item = parsed!;

    String? pageTitle;
    for (final k in const [
      'title',
      'item_name',
      'itemName',
      'name',
      'item_title',
      'itemTitle',
    ]) {
      final v = row[k];
      if (v is String && v.trim().isNotEmpty) {
        pageTitle = v.trim();
        break;
      }
    }
    String? pageImg;
    for (final k in const [
      'image_url',
      'imageUrl',
      'thumbnail_url',
      'thumbnailUrl',
      'image',
      'item_image_url',
      'itemImageUrl',
    ]) {
      final v = row[k];
      if (v is String && v.trim().startsWith('http')) {
        pageImg = v.trim();
        break;
      }
    }

    final collectPrice = _readOptionalIntFromMap(row, const [
      'price',
      'item_price',
      'itemPrice',
      'min_price',
      'minPrice',
      'search_price',
      'searchPrice',
    ]);
    final success = RoomUrlResolveSuccess(
      rakutenItem: item,
      roomPageAffiliateUrl: aflAff,
      roomPageTitle: pageTitle,
      roomPageImageUrl: pageImg,
      roomLikeCount: _readOptionalIntFromMap(row, const [
        'like_count',
        'likeCount',
        'likes',
      ]),
      roomCommentCount: _readOptionalIntFromMap(row, const [
        'comment_count',
        'commentCount',
        'comments',
      ]),
      listingHintPriceYen:
          collectPrice != null && collectPrice > 0 ? collectPrice : null,
    );
    _mergeListingFastPathEntry(sink, key, success);
  }

  static void _mergeListingFastPathEntry(
    Map<String, RoomUrlResolveSuccess> sink,
    String key,
    RoomUrlResolveSuccess next,
  ) {
    final prev = sink[key];
    if (prev == null) {
      sink[key] = next;
      return;
    }
    int score(RoomUrlResolveSuccess s) {
      final t = (s.roomPageTitle ?? '').trim().length;
      final i = (s.roomPageImageUrl ?? '').trim().length;
      final l = s.roomLikeCount != null ? 1 : 0;
      final c = s.roomCommentCount != null ? 1 : 0;
      final p = (s.listingHintPriceYen != null && s.listingHintPriceYen! > 0)
          ? 4
          : 0;
      return t * 2 + i + l * 3 + c * 3 + p;
    }

    if (score(next) >= score(prev)) {
      sink[key] = next;
    }
  }

  static int? _readOptionalIntFromMap(
    Map<String, dynamic> row,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = row[k];
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is String) return int.tryParse(v.trim());
    }
    return null;
  }

  static void _scanJsonForRakutenInCollects(
    dynamic v,
    List<String> aflAcc,
    void Function(RakutenItemUrlParseResult) onItem,
  ) {
    if (v is String) {
      final s = v;
      if (s.contains('item.rakuten.co.jp')) {
        final p =
            RakutenItemUrlParser.findFirstInText(s) ?? RakutenItemUrlParser.tryParse(s);
        if (p != null) onItem(p);
      }
      if (s.contains('hb.afl.rakuten')) {
        for (final m in _aflUrlPattern.allMatches(s)) {
          final u = m.group(0)?.trim();
          if (u != null && u.isNotEmpty) aflAcc.add(u);
        }
      }
    } else if (v is Map) {
      v.forEach((dynamic k, dynamic val) {
        _scanJsonForRakutenInCollects(val, aflAcc, onItem);
      });
    } else if (v is List) {
      for (final e in v) {
        _scanJsonForRakutenInCollects(e, aflAcc, onItem);
      }
    }
  }

  /// `decodedHtml` → `rawHtml` の順で走査し、重複を除いた afl URL 一覧（先着順）。
  static List<String> _collectAflUrlsUniqueOrdered(
    String decodedHtml,
    String rawHtml,
  ) {
    final seen = <String>{};
    final out = <String>[];
    void scan(String s) {
      for (final m in _aflUrlPattern.allMatches(s)) {
        final u = m.group(0)?.trim();
        if (u == null || u.isEmpty || seen.contains(u)) continue;
        seen.add(u);
        out.add(u);
      }
    }

    scan(decodedHtml);
    scan(rawHtml);
    return out;
  }

  /// 最初に [RakutenItemUrlParser.tryParse] 成功した afl の `pc` デコード結果と、その元 afl URL を返す。
  static ({RakutenItemUrlParseResult item, String aflSourceUrl})?
  _tryParseItemFromFirstAflPc(List<String> aflUrls, bool traceRoomSync) {
    for (final raw in aflUrls) {
      final aflUrl = raw.trim();
      if (aflUrl.isEmpty) continue;

      if (traceRoomSync) {
        roomSyncLog('aflURL: $aflUrl');
      }

      final uri = Uri.tryParse(aflUrl);
      if (uri == null) {
        if (traceRoomSync) {
          roomSyncWarn('aflURL の Uri 解析に失敗');
        }
        continue;
      }

      final pc = uri.queryParameters['pc'];
      if (pc == null || pc.trim().isEmpty) {
        if (traceRoomSync) {
          roomSyncLog('pc param: (なしまたは空)');
        }
        continue;
      }

      if (traceRoomSync) {
        roomSyncLog('pc param: $pc');
      }

      final String decodedPc;
      try {
        decodedPc = Uri.decodeFull(pc.trim());
      } catch (e, st) {
        if (traceRoomSync) {
          roomSyncError('pc の Uri.decodeFull に失敗', e, st);
        }
        continue;
      }

      final decTrim = decodedPc.trim();
      if (decTrim.isEmpty) {
        if (traceRoomSync) {
          roomSyncWarn('decoded URL: (空)');
        }
        continue;
      }

      if (traceRoomSync) {
        roomSyncLog('decoded URL: $decTrim');
      }

      if (!decTrim.toLowerCase().contains('item.rakuten.co.jp')) {
        if (traceRoomSync) {
          roomSyncWarn('decode後に item.rakuten.co.jp を含みません');
        }
        continue;
      }

      final parsed = RakutenItemUrlParser.tryParse(decTrim);
      if (parsed != null) {
        return (item: parsed, aflSourceUrl: aflUrl);
      }

      if (traceRoomSync) {
        roomSyncWarn('RakutenItemUrlParser.tryParse が decode URL で失敗');
      }
    }

    return null;
  }

  /// `&amp;` 等を最低限戻し、href 内の item.rakuten を拾いやすくする。
  static String _unescapeBasicXmlEntities(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'");
  }

  /// ROOM ページ向け og:title / og:image（取得できた場合のみ）。
  static (String?, String?) _readOpenGraphTitleAndImage(String html) {
    String? title;
    final titleRe = RegExp(
      r'property="og:title"[^>]*content="([^"]+)"',
      caseSensitive: false,
    );
    final titleRe2 = RegExp(
      r'content="([^"]+)"[^>]*property="og:title"',
      caseSensitive: false,
    );
    final tm = titleRe.firstMatch(html) ?? titleRe2.firstMatch(html);
    if (tm != null) {
      title = tm.group(1)?.trim();
      if (title != null && title.isEmpty) title = null;
    }

    String? image;
    final imgRe = RegExp(
      r'property="og:image"[^>]*content="([^"]+)"',
      caseSensitive: false,
    );
    final imgRe2 = RegExp(
      r'content="([^"]+)"[^>]*property="og:image"',
      caseSensitive: false,
    );
    final im = imgRe.firstMatch(html) ?? imgRe2.firstMatch(html);
    if (im != null) {
      image = im.group(1)?.trim();
      if (image != null && image.isEmpty) image = null;
    }
    return (title, image);
  }
}

sealed class RoomUrlResolveOutcome {
  const RoomUrlResolveOutcome();
}

final class RoomUrlResolveSuccess extends RoomUrlResolveOutcome {
  const RoomUrlResolveSuccess({
    required this.rakutenItem,
    this.roomPageAffiliateUrl,
    this.roomPageTitle,
    this.roomPageImageUrl,
    this.roomLikeCount,
    this.roomCommentCount,
    this.listingHintPriceYen,
  });

  final RakutenItemUrlParseResult rakutenItem;

  /// ROOM商品ページHTML上の `hb.afl.rakuten.co.jp` リンク（先着／pc デコードに使ったもの）。
  final String? roomPageAffiliateUrl;
  final String? roomPageTitle;
  final String? roomPageImageUrl;

  /// ROOM HTML から推定したいいね数（未取得は null）。
  final int? roomLikeCount;

  /// ROOM HTML から推定したコメント数（未取得は null）。
  final int? roomCommentCount;

  /// 一覧HTML／collects から拾った参考価格（円）。楽天APIが無い・失敗時の補助。
  final int? listingHintPriceYen;
}

final class RoomUrlResolveFailure extends RoomUrlResolveOutcome {
  const RoomUrlResolveFailure(this.kind, {this.debugDetail});

  final RoomUrlResolveFailureKind kind;
  final String? debugDetail;
}

enum RoomUrlResolveFailureKind {
  invalidInput,
  notRoomUrl,
  timeout,
  networkError,
  httpError,
  emptyBody,
  rakutenLinkNotFound,
}
