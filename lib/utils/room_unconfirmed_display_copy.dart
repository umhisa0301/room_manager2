import 'package:flutter/foundation.dart';

import '../models/rakuten_managed_product.dart';
import '../services/room_import_metadata_enrichment.dart';
import 'room_import_pending_user_copy.dart';
import 'room_reaction_status_display.dart';

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
    final label = _resolveLabel(product);
    if (kDebugMode && label != null) {
      final reason = RoomImportPendingUserCopy.classify(product);
      debugPrint(
        '[ROOM_UNCONFIRMED_REASON_RENDER] productId=${product.productId.trim()} '
        'pendingReason=${RoomImportPendingUserCopy.logReasonLabel(reason)} '
        'price=${product.itemPrice} label=$label shown=true',
      );
    }
    return label;
  }

  static String? priceSublineFor(RakutenManagedProduct product) {
    if (!shouldShowPendingHint(product)) return null;
    if (product.itemPrice > 0) return null;
    final label = _resolveLabel(product);
    if (label == '商品情報を確認中') return null;
    return label;
  }

  static String? _resolveLabel(RakutenManagedProduct product) {
    if (product.roomImportMetadataEnriching) {
      return '商品情報を確認中';
    }
    final reason = RoomImportPendingUserCopy.classify(product);
    switch (reason) {
      case RoomImportPendingReason.soldOutOrUnavailable:
      case RoomImportPendingReason.noExactMatch:
        return '売り切れ/販売停止の可能性';
      case RoomImportPendingReason.priceMissing:
        if (product.itemPrice <= 0) {
          final imageMissing = product.imageUrl.trim().isEmpty;
          if (imageMissing) return '売り切れ/販売停止の可能性';
          return '商品情報を確認できません';
        }
        return '商品情報を確認中';
      case RoomImportPendingReason.metadataMissing:
        return '商品情報を確認中';
      case RoomImportPendingReason.temporarilyUnavailable:
      case RoomImportPendingReason.unknown:
        if (product.itemPrice <= 0) return '商品情報を確認できません';
        return null;
    }
  }
}
