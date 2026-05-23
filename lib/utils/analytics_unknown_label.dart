import '../services/rakuten_genre_master_service.dart';
import 'app_debug_log.dart';
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

  /// 傾向分析用の表示ジャンル名（genreName 空でもマスタ解決を試す）。
  static String? resolveAnalyticsGenreLabel({
    required String genreName,
    String? genreId,
  }) {
    final gn = genreName.trim();
    if (gn.isNotEmpty && !isUnknownGenreLabel(gn)) {
      return gn;
    }
    final gid = (genreId ?? '').trim();
    if (gid.isEmpty) return null;
    final resolved = RakutenGenreMasterService.instance.genreNameIfKnown(gid);
    if (resolved == null || resolved.isEmpty) return null;
    if (isUnknownGenreLabel(resolved)) return null;
    return resolved;
  }

  static bool isAnalyticsEligibleGenre(String genreName, {String? genreId}) {
    final resolved = resolveAnalyticsGenreLabel(
      genreName: genreName,
      genreId: genreId,
    );
    if (resolved != null) return true;
    final gn = genreName.trim();
    if (gn.isNotEmpty && isUnknownGenreLabel(gn)) {
      _logExclude(field: 'genre', rawLabel: gn, reason: 'unknownLabel');
      return false;
    }
    final gid = (genreId ?? '').trim();
    if (gid.isNotEmpty) {
      _logExclude(field: 'genre', rawLabel: gid, reason: 'unresolvedId');
      return false;
    }
    _logExclude(field: 'genre', rawLabel: gn.isEmpty ? '(empty)' : gn, reason: 'empty');
    return false;
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
    analyticsAuditLog(
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
    analyticsAuditLog(
      '[ROOM_NEXT_ACTION_UNKNOWN_GUARD] candidateAction=$candidateAction '
      'removed=$removed reason=$reason',
    );
  }

  static void _logExclude({
    required String field,
    required String rawLabel,
    required String reason,
  }) {
    analyticsAuditLog(
      '[ANALYTICS_UNKNOWN_EXCLUDE] field=$field rawLabel=$rawLabel '
      'excluded=true reason=$reason',
    );
  }
}
