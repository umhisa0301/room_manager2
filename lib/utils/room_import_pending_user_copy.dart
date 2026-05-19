import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';

/// ROOM取り込み結果の未確認理由（ユーザー向け短文 + ログ用）。
enum RoomImportPendingReason {
  soldOutOrUnavailable,
  priceMissing,
  metadataMissing,
  noExactMatch,
  temporarilyUnavailable,
  unknown,
}

abstract final class RoomImportPendingUserCopy {
  static RoomImportPendingReason classify(RakutenManagedProduct product) {
    final price = product.itemPrice;
    final hasUrl = product.itemUrl.trim().isNotEmpty ||
        (product.affiliateUrl?.trim().isNotEmpty ?? false);
    final shopMissing = product.shopName.trim().isEmpty;
    final genreMissing = _isGenreUnset(product.genreName);
    final imageMissing = product.imageUrl.trim().isEmpty;

    if (!hasUrl) return RoomImportPendingReason.noExactMatch;
    if (price <= 0 && imageMissing) {
      return RoomImportPendingReason.soldOutOrUnavailable;
    }
    if (price <= 0) return RoomImportPendingReason.priceMissing;
    if (shopMissing || genreMissing) {
      return RoomImportPendingReason.metadataMissing;
    }
    return RoomImportPendingReason.unknown;
  }

  static bool _isGenreUnset(String genreName) {
    final g = genreName.trim();
    return g.isEmpty || g == 'ジャンル未設定' || g == '未分類';
  }

  static String userMessageFor(RoomImportPendingReason reason) {
    return switch (reason) {
      RoomImportPendingReason.soldOutOrUnavailable =>
        '売り切れ・販売停止の可能性がある商品があります',
      RoomImportPendingReason.priceMissing =>
        '一部の商品は価格を確認できませんでした',
      RoomImportPendingReason.metadataMissing =>
        '一部の商品はショップ名・ジャンルを確認中です',
      RoomImportPendingReason.noExactMatch =>
        '一部の商品は商品情報を照合できませんでした',
      RoomImportPendingReason.temporarilyUnavailable =>
        '一部の商品はあとで再確認できます',
      RoomImportPendingReason.unknown =>
        '一部の商品はあとで再確認できます',
    };
  }

  static String logReasonLabel(RoomImportPendingReason reason) {
    return switch (reason) {
      RoomImportPendingReason.soldOutOrUnavailable => 'soldOutOrUnavailable',
      RoomImportPendingReason.priceMissing => 'priceMissing',
      RoomImportPendingReason.metadataMissing => 'metadataMissing',
      RoomImportPendingReason.noExactMatch => 'noExactMatch',
      RoomImportPendingReason.temporarilyUnavailable => 'temporarilyUnavailable',
      RoomImportPendingReason.unknown => 'unknown',
    };
  }

  static void logPendingProduct({
    required RakutenManagedProduct product,
    required RoomImportPendingReason reason,
    Iterable<String> pendingFields = const [],
    bool apiMatched = false,
    String apiStatus = '',
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ROOM_IMPORT_PRODUCT_INFO_PENDING_REASON] productId=${product.productId} '
      'title=${product.itemName.trim()} shopCode=${product.shopCode.trim()} '
      'pendingFields=${pendingFields.join(',')} '
      'reason=${logReasonLabel(reason)} userMessage=${userMessageFor(reason)}',
    );
    logUnconfirmedCause(
      product: product,
      reason: reason,
      apiMatched: apiMatched,
      apiStatus: apiStatus,
    );
  }

  static void logUnconfirmedCause({
    required RakutenManagedProduct product,
    required RoomImportPendingReason reason,
    bool apiMatched = false,
    String apiStatus = '',
  }) {
    if (!kDebugMode) return;
    final cause = switch (reason) {
      RoomImportPendingReason.soldOutOrUnavailable => 'soldOutOrUnavailable',
      RoomImportPendingReason.priceMissing => 'priceOnlyMissing',
      RoomImportPendingReason.metadataMissing => 'metadataOnlyMissing',
      RoomImportPendingReason.noExactMatch => 'apiNoMatch',
      RoomImportPendingReason.temporarilyUnavailable => 'unknown',
      RoomImportPendingReason.unknown => 'unknown',
    };
    debugPrint(
      '[ROOM_IMPORT_UNCONFIRMED_CAUSE] productId=${product.productId} '
      'hasRoomTitle=${product.itemName.trim().isNotEmpty} '
      'hasRoomImage=${product.imageUrl.trim().isNotEmpty} '
      'hasRoomItemUrl=${product.itemUrl.trim().isNotEmpty} '
      'hasItemCode=${product.roomApiCompositeItemCode.trim().isNotEmpty} '
      'hasShopCode=${product.shopCode.trim().isNotEmpty} '
      'hasPrice=${product.itemPrice > 0} '
      'hasShopName=${product.shopName.trim().isNotEmpty} '
      'hasGenreName=${product.genreName.trim().isNotEmpty} '
      'apiMatched=$apiMatched apiStatus=${apiStatus.isEmpty ? '-' : apiStatus} '
      'cause=$cause',
    );
  }

  /// 取り込み結果シート向けの要約文。
  static String buildResultSummary({
    required int added,
    required int confirmed,
    required List<RakutenManagedProduct> pendingProducts,
  }) {
    if (added <= 0) return '';
    final pending = pendingProducts.length;
    if (pending <= 0) {
      return '商品情報：$confirmed件確認済み';
    }
    final reasons = <RoomImportPendingReason>{};
    for (final p in pendingProducts) {
      reasons.add(classify(p));
    }
    final lines = <String>[
      '商品情報：$confirmed件確認済み / $pending件は未確認です',
    ];
    if (reasons.contains(RoomImportPendingReason.soldOutOrUnavailable)) {
      lines.add(userMessageFor(RoomImportPendingReason.soldOutOrUnavailable));
    } else if (reasons.contains(RoomImportPendingReason.priceMissing)) {
      lines.add(userMessageFor(RoomImportPendingReason.priceMissing));
    } else if (reasons.contains(RoomImportPendingReason.metadataMissing)) {
      lines.add(userMessageFor(RoomImportPendingReason.metadataMissing));
    } else {
      lines.add('未確認の商品は、あとで再確認できます');
    }
    logResultCopy(
      added: added,
      confirmed: confirmed,
      soldOutOrUnavailable: pendingProducts
          .where((p) => classify(p) == RoomImportPendingReason.soldOutOrUnavailable)
          .length,
      metadataPending: pendingProducts
          .where((p) => classify(p) == RoomImportPendingReason.metadataMissing)
          .length,
      message: lines.join(' / '),
    );
    return lines.join('\n');
  }

  static void logResultCopy({
    required int added,
    required int confirmed,
    required int soldOutOrUnavailable,
    required int metadataPending,
    required String message,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ROOM_IMPORT_RESULT_USER_COPY] added=$added confirmed=$confirmed '
      'soldOutOrUnavailable=$soldOutOrUnavailable metadataPending=$metadataPending '
      'message=$message',
    );
  }
}
