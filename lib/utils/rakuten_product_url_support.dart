import 'room_rakuten_url_normalize.dart';

/// 楽天市場 item 検索の対象外 URL 判定（BOOKS / ファッション等）。
abstract final class RakutenProductUrlSupport {
  const RakutenProductUrlSupport._();

  static const String messageUnsupportedRakutenServiceUrl =
      'このURL形式は現在の取得対象外です（楽天BOOKS・ファッション等）';

  static const String unsupportedReasonTag = 'unsupportedRakutenService';

  /// 対象外 URL のときのみ非 null。
  static RakutenUnsupportedUrlDetection? detectUnsupported(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final affiliateTarget = RoomRakutenUrlNormalize.decodeAffiliatePcTargetUrl(
      trimmed,
    );
    final probe = (affiliateTarget ?? trimmed).trim();
    if (probe.isEmpty) return null;

    final uri = Uri.tryParse(probe);
    if (uri == null || !uri.hasAuthority) return null;

    final host = uri.host.toLowerCase();
    if (!_isRakutenHost(host)) return null;

    if (_isSupportedItemRakutenHost(host)) return null;

    final serviceTag = _unsupportedServiceTag(host, uri.path);
    if (serviceTag == null) return null;

    return RakutenUnsupportedUrlDetection(
      reason: unsupportedReasonTag,
      host: host,
      serviceTag: serviceTag,
      userMessage: messageUnsupportedRakutenServiceUrl,
    );
  }

  static bool _isRakutenHost(String hostLower) {
    return hostLower == 'rakuten.co.jp' ||
        hostLower.endsWith('.rakuten.co.jp') ||
        hostLower.endsWith('.rakuten.ne.jp');
  }

  static bool _isSupportedItemRakutenHost(String hostLower) {
    return hostLower == 'item.rakuten.co.jp' ||
        hostLower.endsWith('.item.rakuten.co.jp');
  }

  static String? _unsupportedServiceTag(String hostLower, String path) {
    const hostTags = <String, String>{
      'books.rakuten.co.jp': 'books',
      'brandavenue.rakuten.co.jp': 'fashion',
      'fashion.rakuten.co.jp': 'fashion',
      'ticket.rakuten.co.jp': 'ticket',
      'travel.rakuten.co.jp': 'travel',
      'beauty.rakuten.co.jp': 'beauty',
      'kobo.rakuten.co.jp': 'kobo',
    };
    for (final e in hostTags.entries) {
      if (hostLower == e.key || hostLower.endsWith('.${e.key}')) {
        return e.value;
      }
    }
    if (hostLower.contains('brandavenue')) return 'fashion';
    if (hostLower.contains('books.rakuten')) return 'books';

    final pathLower = path.toLowerCase();
    if (hostLower == 'www.rakuten.co.jp' || hostLower == 'rakuten.co.jp') {
      if (pathLower.startsWith('/fashion')) return 'fashion';
      if (pathLower.startsWith('/book')) return 'books';
    }
    return null;
  }
}

/// 対象外 URL 判定結果。
final class RakutenUnsupportedUrlDetection {
  const RakutenUnsupportedUrlDetection({
    required this.reason,
    required this.host,
    required this.serviceTag,
    required this.userMessage,
  });

  final String reason;
  final String host;
  final String serviceTag;
  final String userMessage;
}
