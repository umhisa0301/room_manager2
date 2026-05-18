import 'package:flutter/foundation.dart';

/// ROOM 取り込み時の商品画像候補判定・優先順位。
abstract final class RoomImportProductImage {
  static const _rejectPathFragments = [
    'avatar',
    'profile',
    'user_icon',
    'usericon',
    '/user/',
    'room_user',
    'member',
    'noimage',
    'no-image',
    'placeholder',
    'default_icon',
    'icon_user',
  ];

  static bool isRejectedProductImageUrl(
    String url, {
    String alt = '',
    String className = '',
    int? width,
    int? height,
    bool nearProductLink = false,
  }) {
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return true;
    for (final frag in _rejectPathFragments) {
      if (u.contains(frag)) return true;
    }
    final altL = alt.toLowerCase();
    final classL = className.toLowerCase();
    if (altL.contains('avatar') ||
        altL.contains('プロフィール') ||
        altL.contains('profile') ||
        classL.contains('avatar') ||
        classL.contains('profile') ||
        classL.contains('user-icon')) {
      return true;
    }
    if (width != null && height != null && width > 0 && height > 0) {
      final maxSide = width > height ? width : height;
      final minSide = width < height ? width : height;
      if (maxSide <= 96 && minSide <= 96) return true;
      if (width == height && maxSide <= 120) return true;
    }
    if (!nearProductLink &&
        !u.contains('item.rakuten') &&
        !u.contains('thumbnail.image.rakuten') &&
        !u.contains('r10s.jp') &&
        !u.contains('rakuten.co.jp')) {
      if (maxSideIfKnown(width, height) <= 80) return true;
    }
    return false;
  }

  static int maxSideIfKnown(int? width, int? height) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 9999;
    }
    return width > height ? width : height;
  }

  static bool isLikelyProductImageUrl(String url) {
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return false;
    if (isRejectedProductImageUrl(u)) return false;
    return u.contains('item.rakuten') ||
        u.contains('thumbnail.image.rakuten') ||
        u.contains('r10s.jp') ||
        u.contains('rakuten.co.jp') ||
        u.contains('/item/') ||
        u.contains('product');
  }

  /// 保存用画像 URL（API > 確定できる ROOM 商品画像 > 既存 > なし）。
  static String pickPersistImageUrl({
    required String productId,
    required String roomPageImageUrl,
    String apiImageUrl = '',
    String existingImageUrl = '',
    bool preserveExistingOnly = false,
  }) {
    if (preserveExistingOnly) {
      final ex = existingImageUrl.trim();
      if (_isHttp(ex)) {
        _logExtract(
          productId: productId,
          selected: 'existing',
          url: ex,
          room: roomPageImageUrl,
          api: apiImageUrl,
        );
        return ex;
      }
    }
    final api = apiImageUrl.trim();
    if (_isHttp(api) && !isRejectedProductImageUrl(api)) {
      _logExtract(
        productId: productId,
        selected: 'api',
        url: api,
        room: roomPageImageUrl,
        api: api,
      );
      return api;
    }
    final room = roomPageImageUrl.trim();
    if (_isHttp(room) &&
        !isRejectedProductImageUrl(room) &&
        (isLikelyProductImageUrl(room) || !isRejectedProductImageUrl(room))) {
      if (!isRejectedProductImageUrl(room)) {
        _logExtract(
          productId: productId,
          selected: 'roomProduct',
          url: room,
          room: room,
          api: api,
        );
        return room;
      }
    }
    final ex = existingImageUrl.trim();
    if (_isHttp(ex) && !isRejectedProductImageUrl(ex)) {
      _logExtract(
        productId: productId,
        selected: 'existing',
        url: ex,
        room: room,
        api: api,
      );
      return ex;
    }
    _logExtract(
      productId: productId,
      selected: 'none',
      url: '',
      room: room,
      api: api,
      rejected: _rejectReasons(room),
    );
    return '';
  }

  static void logImageCandidate({
    required String productId,
    required String url,
    int? width,
    int? height,
    String alt = '',
    String className = '',
    bool nearProductLink = false,
  }) {
    if (!kDebugMode) return;
    final rejected = isRejectedProductImageUrl(
      url,
      alt: alt,
      className: className,
      width: width,
      height: height,
      nearProductLink: nearProductLink,
    );
    final reason = rejected ? _rejectReason(url) : 'selected';
    debugPrint(
      '[ROOM_IMPORT_IMAGE_CANDIDATE] productId=$productId url=$url '
      'width=${width ?? '-'} height=${height ?? '-'} alt=$alt className=$className '
      'nearProductLink=$nearProductLink rejected=$rejected reason=$reason',
    );
  }

  static String _rejectReason(String url) {
    if (isRejectedProductImageUrl(url)) {
      final u = url.toLowerCase();
      if (u.contains('avatar') || u.contains('profile')) return 'avatar|profile';
      if (u.contains('noimage')) return 'noImage';
      if (maxSideIfKnown(null, null) < 100) return 'tooSmall';
      return 'notProduct';
    }
    return 'selected';
  }

  static String _rejectReasons(String roomUrl) {
    if (roomUrl.trim().isEmpty) return 'none';
    return _rejectReason(roomUrl);
  }

  static bool _isHttp(String url) {
    final u = url.trim();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  static void _logExtract({
    required String productId,
    required String selected,
    required String url,
    required String room,
    required String api,
    String rejected = '',
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ROOM_IMPORT_PRODUCT_EXTRACT] productId=$productId '
      'imageCandidates=room,api,existing selectedImageSource=$selected '
      'rejectedImages=${rejected.isEmpty ? '-' : rejected} reason=persistPick',
    );
  }
}
