import 'package:flutter/foundation.dart';

import 'shop_display_resolve.dart';

/// 反応分析・次にやることから除外する「未分類／未確認」ラベル判定。
abstract final class AnalyticsUnknownLabel {
  static const Set<String> unknownGenreLabels = {
    '',
    '-',
    '未分類',
    'ジャンル未確認',
    'ジャンル未設定',
    '不明',
    'unknown',
  };

  static const Set<String> unknownShopLabels = {
    '',
    '-',
    'ショップ未確認',
    'ショップ未設定',
    'ショップ名不明',
    '不明',
  };

  static bool isUnknownGenreLabel(String? raw) {
    final t = (raw ?? '').trim();
    if (unknownGenreLabels.contains(t)) return true;
    if (RegExp(r'^\d+$').hasMatch(t)) return true;
    return false;
  }

  static bool isUnknownShopLabel(String? raw, {String? shopCode}) {
    final t = (raw ?? '').trim();
    if (unknownShopLabels.contains(t)) return true;
    if (t.isNotEmpty && ShopDisplayResolve.looksLikeShopCode(t)) {
      return true;
    }
    if (t.isEmpty && (shopCode ?? '').trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  static bool isAnalyticsEligibleGenre(String genreName, {String? genreId}) {
    if (isUnknownGenreLabel(genreName)) {
      _logExclude(field: 'genre', rawLabel: genreName, reason: 'unknownLabel');
      return false;
    }
    final gid = (genreId ?? '').trim();
    if (gid.isNotEmpty && isUnknownGenreLabel(gid)) {
      _logExclude(field: 'genre', rawLabel: gid, reason: 'codeOnly');
      return false;
    }
    return true;
  }

  static bool isAnalyticsEligibleShop({
    required String shopName,
    required String shopCode,
  }) {
    if (isUnknownShopLabel(shopName, shopCode: shopCode)) {
      final raw = shopName.trim().isNotEmpty ? shopName : shopCode;
      _logExclude(
        field: 'shop',
        rawLabel: raw,
        reason: shopName.trim().isEmpty ? 'codeOnly' : 'unknownLabel',
      );
      return false;
    }
    return true;
  }

  static void logExistingDataGuard({
    required String productId,
    required String genreName,
    required String genreId,
    required bool excludedFromTrend,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[UNKNOWN_GENRE_EXISTING_DATA_GUARD] productId=$productId '
      'genreName=${genreName.isEmpty ? '-' : genreName} genreId=${genreId.isEmpty ? '-' : genreId} '
      'excludedFromTrend=$excludedFromTrend keptInStorage=true',
    );
  }

  static void logNextActionGuard({
    required String candidateAction,
    required bool removed,
    required String reason,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ROOM_NEXT_ACTION_UNKNOWN_GUARD] candidateAction=$candidateAction '
      'removed=$removed reason=$reason',
    );
  }

  static void _logExclude({
    required String field,
    required String rawLabel,
    required String reason,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ANALYTICS_UNKNOWN_EXCLUDE] field=$field rawLabel=$rawLabel '
      'excluded=true reason=$reason',
    );
  }
}
