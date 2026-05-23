import 'package:flutter/foundation.dart';

import '../config/debug_log_flags.dart';
import '../models/rakuten_managed_product.dart';
import '../services/room_import_metadata_enrichment.dart';
import 'app_debug_log.dart';
import 'room_import_pending_user_copy.dart';
import 'room_reaction_status_display.dart';
import 'shop_display_resolve.dart';

/// ROOMコレ「未確認」商品カード向けの補足ラベル。
abstract final class RoomUnconfirmedDisplayCopy {
  static bool shouldShowPendingHint(RakutenManagedProduct product) {
    if (product.coredActivitySource != RakutenCoredActivitySource.roomImport) {
      return false;
    }
    if (product.roomImportMetadataEnriching) return true;
    if (RoomReactionStatusDisplay.chipLabelForProduct(product) == '未確認') {
      return true;
    }
    return RoomImportMetadataEnrichmentService.needFlagsForProduct(product)
        .willEnrich;
  }

  static String? chipLabelFor(RakutenManagedProduct product) {
    if (!shouldShowPendingHint(product)) return null;
    final info = _classify(product);
    if (info.chipLabel == null) return null;
    if (kDebugMode && DebugLogFlags.kVerboseItemLogsEnabled) {
      final reason = RoomImportPendingUserCopy.classify(product);
      verboseItemLog(
        '[ROOM_UNCONFIRMED_REASON_RENDER] productId=${product.productId.trim()} '
        'pendingReason=${RoomImportPendingUserCopy.logReasonLabel(reason)} '
        'price=${product.itemPrice} label=${info.chipLabel} shown=true',
      );
      _logClassify(product, info);
    }
    return info.chipLabel;
  }

  static String? priceSublineFor(RakutenManagedProduct product) {
    if (!shouldShowPendingHint(product)) return null;
    final info = _classify(product);
    if (info.priceSubline == null) return null;
    if (kDebugMode && DebugLogFlags.kVerboseItemLogsEnabled) {
      _logClassify(product, info);
    }
    return info.priceSubline;
  }

  static _RoomUnconfirmedDisplayInfo _classify(RakutenManagedProduct product) {
    if (product.roomImportMetadataEnriching) {
      return const _RoomUnconfirmedDisplayInfo(
        chipLabel: '商品情報を確認中',
        severity: 'info',
      );
    }

    final hasTitle = product.itemName.trim().isNotEmpty;
    final hasImage = product.imageUrl.trim().isNotEmpty;
    final hasItemUrl = product.itemUrl.trim().isNotEmpty ||
        (product.affiliateUrl?.trim().isNotEmpty ?? false);
    final hasShopCode = product.shopCode.trim().isNotEmpty;
    final shopName = product.shopName.trim();
    final hasShopName = shopName.isNotEmpty &&
        shopName != 'ショップ未設定' &&
        shopName != 'ショップ名不明' &&
        shopName != product.shopCode.trim();
    final genreName = product.genreName.trim();
    final hasGenreName = genreName.isNotEmpty &&
        genreName != 'ジャンル未設定' &&
        genreName != '未分類';
    final hasPrice = product.itemPrice > 0;
    final roomCorePresent =
        hasTitle && hasImage && hasItemUrl && (hasShopCode || hasShopName);

    if (!hasItemUrl && !hasShopCode) {
      return const _RoomUnconfirmedDisplayInfo(
        chipLabel: '楽天市場の商品情報と照合できません',
        priceSubline: '販売終了・URL変更の可能性があります',
        severity: 'warning',
      );
    }

    if (!hasPrice && !hasImage && !hasTitle) {
      return const _RoomUnconfirmedDisplayInfo(
        chipLabel: '売り切れ・販売停止の可能性',
        priceSubline: '楽天市場側で商品情報を確認できませんでした',
        severity: 'error',
      );
    }

    if (!hasPrice && !hasImage) {
      return const _RoomUnconfirmedDisplayInfo(
        chipLabel: '売り切れ・販売停止の可能性',
        priceSubline: '楽天市場側で商品情報を確認できませんでした',
        severity: 'error',
      );
    }

    if (!hasPrice && roomCorePresent) {
      return const _RoomUnconfirmedDisplayInfo(
        priceSubline: '価格を確認できません',
        detail: '販売状況が変わった可能性があります',
        severity: 'info',
      );
    }

    if (!hasPrice) {
      return const _RoomUnconfirmedDisplayInfo(
        priceSubline: '価格を確認できません',
        detail: '販売状況が変わった可能性があります',
        severity: 'info',
      );
    }

    if (hasShopCode && !hasShopName) {
      return const _RoomUnconfirmedDisplayInfo(
        chipLabel: 'ショップ名を確認中',
        priceSubline: 'ショップ名はあとで表示されます',
        severity: 'info',
      );
    }

    if (!hasGenreName && hasTitle && hasPrice) {
      return const _RoomUnconfirmedDisplayInfo(
        chipLabel: 'ジャンル未確認',
        priceSubline: '商品情報は取得済みです',
        severity: 'info',
      );
    }

    if (roomCorePresent && (!hasPrice || !hasShopName || !hasGenreName)) {
      return const _RoomUnconfirmedDisplayInfo(
        chipLabel: 'ROOM投稿情報のみ取得済み',
        priceSubline: '価格・ショップ名はあとで再確認できます',
        severity: 'info',
      );
    }

    final reason = RoomImportPendingUserCopy.classify(product);
    switch (reason) {
      case RoomImportPendingReason.soldOutOrUnavailable:
        return const _RoomUnconfirmedDisplayInfo(
          chipLabel: '売り切れ・販売停止の可能性',
          priceSubline: '楽天市場側で商品情報を確認できませんでした',
          severity: 'error',
        );
      case RoomImportPendingReason.noExactMatch:
        return const _RoomUnconfirmedDisplayInfo(
          chipLabel: '楽天市場の商品情報と照合できません',
          priceSubline: '販売終了・URL変更の可能性があります',
          severity: 'warning',
        );
      case RoomImportPendingReason.metadataMissing:
        return const _RoomUnconfirmedDisplayInfo(
          chipLabel: '商品情報を確認中',
          severity: 'info',
        );
      case RoomImportPendingReason.priceMissing:
        return const _RoomUnconfirmedDisplayInfo(
          priceSubline: '価格を確認できません',
          detail: '販売状況が変わった可能性があります',
          severity: 'info',
        );
      case RoomImportPendingReason.temporarilyUnavailable:
      case RoomImportPendingReason.unknown:
        if (!hasTitle && !hasImage && !hasItemUrl && !hasShopCode) {
          return const _RoomUnconfirmedDisplayInfo(
            chipLabel: '商品情報を確認できません',
            severity: 'warning',
          );
        }
        return const _RoomUnconfirmedDisplayInfo();
    }
  }

  static void _logClassify(
    RakutenManagedProduct product,
    _RoomUnconfirmedDisplayInfo info,
  ) {
    final shopName = product.shopName.trim();
    verboseItemLog(
      '[ROOM_UNCONFIRMED_DISPLAY_CLASSIFY] productId=${product.productId.trim()} '
      'hasTitle=${product.itemName.trim().isNotEmpty} '
      'hasImage=${product.imageUrl.trim().isNotEmpty} '
      'hasItemUrl=${product.itemUrl.trim().isNotEmpty} '
      'hasShopCode=${product.shopCode.trim().isNotEmpty} '
      'hasShopName=${shopName.isNotEmpty && shopName != ShopDisplayResolve.unknownShopLabel} '
      'hasGenreName=${product.genreName.trim().isNotEmpty} '
      'hasPrice=${product.itemPrice > 0} '
      'label=${info.chipLabel ?? info.priceSubline ?? '-'} '
      'detail=${info.detail ?? '-'} severity=${info.severity}',
    );
  }
}

class _RoomUnconfirmedDisplayInfo {
  const _RoomUnconfirmedDisplayInfo({
    this.chipLabel,
    this.priceSubline,
    this.detail,
    this.severity = 'info',
  });

  final String? chipLabel;
  final String? priceSubline;
  final String? detail;
  final String severity;
}
