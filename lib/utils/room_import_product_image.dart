import 'package:flutter/foundation.dart';

/// ROOM 取り込み時の商品画像候補判定・優先順位。
abstract final class RoomImportProductImage {
  static const _rejectPathFragments = [
    'avatar',
    'profile',
    'user_icon',
    'usericon',
    'user-image',
    'user_image',
    '/user/',
    'room_user',
    'room-user',
    'roomuser',
    'member',
    'noimage',
    'no-image',
    'placeholder',
    'default_icon',
    'icon_user',
    'snsimg',
    'collector',
    'owner_icon',
    'profile_icon',
    'room_icon',
    'roomicon',
  ];

  static const _userLikeKeyFragments = [
    'avatar',
    'profile',
    'user',
    'member',
    'icon',
    'roomuser',
    'room_user',
    'collector',
    'owner',
    'sns',
  ];

  static const _productImageKeys = [
    'image_url',
    'imageUrl',
    'thumbnail_url',
    'thumbnailUrl',
    'thumbnail',
    'item_image_url',
    'itemImageUrl',
    'mediumImageUrl',
    'medium_image_url',
    'smallImageUrl',
    'small_image_url',
    'mainImageUrl',
    'main_image_url',
    'img_url',
    'imgUrl',
    'product_image',
    'productImage',
    'item_image',
    'itemImage',
  ];

  static bool isUserLikeImageKey(String key) {
    final k = key.trim().toLowerCase();
    if (k.isEmpty) return false;
    for (final frag in _userLikeKeyFragments) {
      if (k == frag || k.contains(frag)) {
        if (k.contains('item') && k.contains('image')) continue;
        if (k == 'image' || k == 'imageurl' || k == 'image_url') continue;
        return true;
      }
    }
    return false;
  }

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

  static bool _looksLikeImageAssetUrl(String url) {
    final u = url.trim().toLowerCase();
    if (RegExp(r'\.(jpg|jpeg|png|gif|webp|bmp)(\?|#|$)', caseSensitive: false)
        .hasMatch(u)) {
      return true;
    }
    return u.contains('thumbnail.image.rakuten') ||
        u.contains('r10s.jp') ||
        u.contains('/cabinet/') ||
        u.contains('/img/');
  }

  static bool isLikelyProductImageUrl(String url) {
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return false;
    if (isRejectedProductImageUrl(u)) return false;
    if (!_looksLikeImageAssetUrl(u)) return false;
    return u.contains('thumbnail.image.rakuten') ||
        u.contains('r10s.jp') ||
        u.contains('rakuten.co.jp');
  }

  /// 商品画像として保存・表示してよい URL か（厳しめ）。
  static bool isSafeProductImageUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return false;
    if (isRejectedProductImageUrl(u)) return false;
    return isLikelyProductImageUrl(u);
  }

  static bool isSuspiciousStoredProductImage(
    String url, {
    String shopCode = '',
    String itemCode = '',
  }) {
    final u = url.trim();
    if (u.isEmpty) return false;
    if (isRejectedProductImageUrl(u)) return true;
    if (!isLikelyProductImageUrl(u)) return true;
    final shop = shopCode.trim();
    final item = itemCode.trim();
    if (shop.isNotEmpty &&
        item.isNotEmpty &&
        !u.contains('r10s.jp') &&
        !u.contains('thumbnail.image.rakuten') &&
        !u.contains('item.rakuten')) {
      return true;
    }
    return false;
  }

  /// collects 行から商品画像 URL のみ抽出（ユーザー画像キーは除外）。
  static CollectsImagePickResult pickProductImageFromCollectsRow(
    Map<String, dynamic> row, {
    String productId = '',
  }) {
    final keys = <String>[];
    final rejectedKeys = <String>[];
    String? selectedKey;
    String? selectedUrl;

    void consider(String key, String? url) {
      if (url == null) return;
      final u = url.trim();
      if (!u.startsWith('http')) return;
      keys.add(key);
      if (isUserLikeImageKey(key)) {
        rejectedKeys.add(key);
        return;
      }
      if (!isSafeProductImageUrl(u)) {
        rejectedKeys.add(key);
        return;
      }
      selectedKey ??= key;
      selectedUrl ??= u;
    }

    for (final k in _productImageKeys) {
      final v = row[k];
      if (v is String && _looksLikeImageAssetUrl(v)) consider(k, v);
    }
    _scanCollectsJsonForProductImages(row, consider);

    logCollectsImageKeys(
      productId: productId,
      keys: keys,
      selectedKey: selectedKey,
      rejectedKeys: rejectedKeys,
    );

    return CollectsImagePickResult(
      url: selectedUrl,
      selectedKey: selectedKey,
      rejectedKeys: rejectedKeys,
    );
  }

  static void _scanCollectsJsonForProductImages(
    dynamic value,
    void Function(String key, String? url) consider, [
    String keyPrefix = '',
  ]) {
    if (value is Map) {
      for (final entry in value.entries) {
        final k = entry.key.toString();
        final fullKey = keyPrefix.isEmpty ? k : '$keyPrefix.$k';
        if (entry.value is String) {
          final s = (entry.value as String).trim();
          if (s.startsWith('http://') || s.startsWith('https://')) {
            consider(fullKey, s);
          }
        } else {
          _scanCollectsJsonForProductImages(entry.value, consider, fullKey);
        }
      }
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        _scanCollectsJsonForProductImages(
          value[i],
          consider,
          keyPrefix.isEmpty ? '[$i]' : '$keyPrefix[$i]',
        );
      }
    }
  }

  /// 保存用画像 URL（楽天API > ROOM HTML商品画像 > collects商品画像 > 既存 > なし）。
  static String pickPersistImageUrl({
    required String productId,
    String roomPageImageUrl = '',
    String roomHtmlImageUrl = '',
    String collectsImageUrl = '',
    String apiImageUrl = '',
    String existingImageUrl = '',
    bool preserveExistingOnly = false,
  }) {
    final oldUrl = existingImageUrl.trim();
    if (preserveExistingOnly) {
      if (_isHttp(oldUrl) && isSafeProductImageUrl(oldUrl)) {
        _logDecision(
          productId: productId,
          selectedSource: 'existing',
          selectedUrl: oldUrl,
          oldUrl: oldUrl,
          apiAvailable: false,
          roomHtmlAvailable: false,
          collectsAvailable: false,
          reason: 'preserveExistingOnly',
        );
        return oldUrl;
      }
      _logDecision(
        productId: productId,
        selectedSource: 'none',
        selectedUrl: '',
        oldUrl: oldUrl,
        apiAvailable: false,
        roomHtmlAvailable: false,
        collectsAvailable: false,
        reason: 'preserveExistingOnlyUnsafe',
      );
      return '';
    }

    final api = apiImageUrl.trim();
    final html = roomHtmlImageUrl.trim().isNotEmpty
        ? roomHtmlImageUrl.trim()
        : roomPageImageUrl.trim();
    final collects = collectsImageUrl.trim();
    final apiOk = _isHttp(api) && isSafeProductImageUrl(api);
    final htmlOk = _isHttp(html) && isSafeProductImageUrl(html);
    final collectsOk = _isHttp(collects) && isSafeProductImageUrl(collects);
    final existingOk = _isHttp(oldUrl) && isSafeProductImageUrl(oldUrl);

    String selectedSource = 'none';
    String selectedUrl = '';
    String reason = 'noSafeImage';

    if (apiOk) {
      selectedSource = 'rakutenApi';
      selectedUrl = api;
      reason = 'preferApi';
    } else if (htmlOk) {
      selectedSource = 'roomHtmlProduct';
      selectedUrl = html;
      reason = 'roomHtmlSafe';
    } else if (collectsOk) {
      selectedSource = 'collectsProduct';
      selectedUrl = collects;
      reason = 'collectsSafe';
    } else if (existingOk) {
      selectedSource = 'existing';
      selectedUrl = oldUrl;
      reason = 'existingSafe';
    } else if (_isHttp(html) || _isHttp(collects) || _isHttp(api)) {
      reason = 'unsafeRoomImageRejected';
    }

    _logDecision(
      productId: productId,
      selectedSource: selectedSource,
      selectedUrl: selectedUrl,
      oldUrl: oldUrl,
      apiAvailable: apiOk,
      roomHtmlAvailable: htmlOk,
      collectsAvailable: collectsOk,
      reason: reason,
    );

    logImageSourceAudit(
      productId: productId,
      source: selectedSource,
      url: selectedUrl,
      isSafe: selectedUrl.isNotEmpty,
      rejectedReason: reason == 'unsafeRoomImageRejected'
          ? 'unsafeCandidate'
          : (selectedUrl.isEmpty ? 'none' : ''),
    );

    return selectedUrl;
  }

  static void logImageSourceAudit({
    required String productId,
    required String source,
    required String url,
    required bool isSafe,
    String rejectedReason = '',
    String title = '',
    String shopCode = '',
    String itemCode = '',
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ROOM_IMAGE_SOURCE_AUDIT] productId=$productId '
      'title=${title.isEmpty ? '-' : title} shopCode=${shopCode.isEmpty ? '-' : shopCode} '
      'itemCode=${itemCode.isEmpty ? '-' : itemCode} source=$source '
      'url=${url.isEmpty ? '-' : url} isSafeProductImage=$isSafe '
      'rejectedReason=${rejectedReason.isEmpty ? '-' : rejectedReason}',
    );
  }

  static void logCollectsImageKeys({
    required String productId,
    required List<String> keys,
    String? selectedKey,
    required List<String> rejectedKeys,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ROOM_IMPORT_COLLECTS_IMAGE_KEYS] productId=${productId.isEmpty ? '-' : productId} '
      'keys=${keys.isEmpty ? '-' : keys.join(',')} '
      'selectedKey=${selectedKey ?? '-'} '
      'rejectedKeys=${rejectedKeys.isEmpty ? '-' : rejectedKeys.join(',')}',
    );
  }

  static void logImageRecovery({
    required int checked,
    required int suspicious,
    required int recovered,
    required int cleared,
    required int failed,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ROOM_IMPORT_IMAGE_RECOVERY] checked=$checked suspicious=$suspicious '
      'recovered=$recovered cleared=$cleared failed=$failed',
    );
  }

  static void logCollectsResponseShape(Map<String, dynamic> row) {
    if (!kDebugMode) return;
    final productLike = <String>[];
    final userLike = <String>[];
    final imageLike = <String>[];
    var hasProductImage = false;
    var hasUserIcon = false;

    void walk(dynamic value, String prefix) {
      if (value is Map) {
        for (final e in value.entries) {
          final k = e.key.toString();
          final full = prefix.isEmpty ? k : '$prefix.$k';
          final kl = k.toLowerCase();
          if (kl.contains('image') ||
              kl.contains('thumbnail') ||
              kl.contains('img')) {
            imageLike.add(full);
            if (e.value is String &&
                (e.value as String).trim().startsWith('http')) {
              if (isUserLikeImageKey(k)) {
                hasUserIcon = true;
                userLike.add(full);
              } else if (isSafeProductImageUrl((e.value as String).trim())) {
                hasProductImage = true;
                productLike.add(full);
              }
            }
          }
          if (isUserLikeImageKey(k)) userLike.add(full);
          walk(e.value, full);
        }
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          walk(value[i], '$prefix[$i]');
        }
      }
    }

    walk(row, '');
    debugPrint(
      '[ROOM_COLLECTS_RESPONSE_SHAPE] itemKeys=${row.keys.take(24).join(',')} '
      'productLikeKeys=${productLike.isEmpty ? '-' : productLike.take(8).join(',')} '
      'userLikeKeys=${userLike.isEmpty ? '-' : userLike.take(8).join(',')} '
      'imageLikeKeys=${imageLike.isEmpty ? '-' : imageLike.take(12).join(',')} '
      'hasProductImage=$hasProductImage hasUserIcon=$hasUserIcon',
    );
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
      return 'notProduct';
    }
    return 'selected';
  }

  static bool _isHttp(String url) {
    final u = url.trim();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  static void _logDecision({
    required String productId,
    required String selectedSource,
    required String selectedUrl,
    required String oldUrl,
    required bool apiAvailable,
    required bool roomHtmlAvailable,
    required bool collectsAvailable,
    required String reason,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ROOM_IMPORT_IMAGE_DECISION] productId=$productId '
      'apiImageAvailable=$apiAvailable roomHtmlImageAvailable=$roomHtmlAvailable '
      'collectsImageAvailable=$collectsAvailable selectedSource=$selectedSource '
      'selectedUrl=${selectedUrl.isEmpty ? '-' : selectedUrl} '
      'oldUrl=${oldUrl.isEmpty ? '-' : oldUrl} '
      'changed=${selectedUrl.trim() != oldUrl.trim()} reason=$reason',
    );
    debugPrint(
      '[ROOM_IMPORT_PRODUCT_EXTRACT] productId=$productId '
      'imageCandidates=api,roomHtml,collects,existing '
      'selectedImageSource=$selectedSource '
      'rejectedImages=${reason == 'unsafeRoomImageRejected' ? 'unsafeCandidates' : (selectedUrl.isEmpty && !apiAvailable && !roomHtmlAvailable && !collectsAvailable ? 'allUnsafe' : '-')} '
      'reason=$reason',
    );
  }
}

final class CollectsImagePickResult {
  const CollectsImagePickResult({
    this.url,
    this.selectedKey,
    this.rejectedKeys = const [],
  });

  final String? url;
  final String? selectedKey;
  final List<String> rejectedKeys;
}
