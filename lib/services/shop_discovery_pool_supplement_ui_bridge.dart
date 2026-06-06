import '../services/shop_discovery_pool_supplement.dart';
import '../utils/app_debug_log.dart';

/// 補助枠 UI へ渡す1件分（API 結果とは別枠・表示専用）。
class ShopDiscoveryPoolSupplementUiDisplayCandidate {
  const ShopDiscoveryPoolSupplementUiDisplayCandidate({
    required this.shopCode,
    required this.shopName,
    required this.displayRank,
    required this.reason,
    required this.strongItemEvidence,
    required this.genreAligned,
    required this.hitItemCount,
    required this.score,
  });

  final String shopCode;
  final String shopName;
  final int displayRank;
  final String reason;
  final bool strongItemEvidence;
  final bool genreAligned;
  final int hitItemCount;
  final double score;
}

/// ShopDiscoveryPoolSupplement 判定から UI 表示対象を抽出した結果。
class ShopDiscoveryPoolSupplementUiBridgeResult {
  const ShopDiscoveryPoolSupplementUiBridgeResult({
    required this.keyword,
    required this.recommendedDisplayCount,
    required this.displayCandidates,
  });

  final String keyword;
  final int recommendedDisplayCount;
  final List<ShopDiscoveryPoolSupplementUiDisplayCandidate> displayCandidates;

  static const empty = ShopDiscoveryPoolSupplementUiBridgeResult(
    keyword: '',
    recommendedDisplayCount: 0,
    displayCandidates: <ShopDiscoveryPoolSupplementUiDisplayCandidate>[],
  );

  int get displayCandidateCount => displayCandidates.length;

  bool contentEquals(ShopDiscoveryPoolSupplementUiBridgeResult other) {
    if (keyword != other.keyword) return false;
    if (recommendedDisplayCount != other.recommendedDisplayCount) return false;
    if (displayCandidates.length != other.displayCandidates.length) {
      return false;
    }
    for (var i = 0; i < displayCandidates.length; i++) {
      final left = displayCandidates[i];
      final right = other.displayCandidates[i];
      if (left.shopCode != right.shopCode ||
          left.displayRank != right.displayRank ||
          left.shopName != right.shopName) {
        return false;
      }
    }
    return true;
  }

  String buildUiBridgeLogLine() {
    final keywordForLog = keyword.isEmpty ? '-' : keyword;
    final codes = displayCandidates.map((e) => e.shopCode).toList();
    return '[SHOP_DISCOVERY_POOL_SUPPLEMENT_UI_BRIDGE] '
        'keyword=$keywordForLog '
        'displayCandidates=$displayCandidateCount '
        'recommendedDisplayCount=$recommendedDisplayCount '
        'shopCodes=${codes.isEmpty ? '-' : codes.join(',')} '
        'willUsePoolForUi=false willSkipApi=false';
  }

  String buildUiCardLogLine() {
    final keywordForLog = keyword.isEmpty ? '-' : keyword;
    final codes = displayCandidates.map((e) => e.shopCode).toList();
    return '[SHOP_DISCOVERY_POOL_SUPPLEMENT_UI_CARD] '
        'keyword=$keywordForLog '
        'visibleCards=$displayCandidateCount '
        'shopCodes=${codes.isEmpty ? '-' : codes.join(',')}';
  }
}

/// 補助枠 displayCandidates から保存済みショップを除外した結果（ログ用メタ付き）。
class ShopDiscoveryPoolSupplementSavedExcludeResult {
  const ShopDiscoveryPoolSupplementSavedExcludeResult({
    required this.bridge,
    required this.before,
    required this.after,
    required this.savedExcluded,
    required this.excludedShopCodes,
  });

  final ShopDiscoveryPoolSupplementUiBridgeResult bridge;
  final int before;
  final int after;
  final int savedExcluded;
  final List<String> excludedShopCodes;

  String buildLogLine() {
    final keywordForLog =
        bridge.keyword.isEmpty ? '-' : bridge.keyword;
    final codes = excludedShopCodes;
    return '[SHOP_DISCOVERY_POOL_SUPPLEMENT_SAVED_EXCLUDE] '
        'keyword=$keywordForLog '
        'before=$before '
        'after=$after '
        'savedExcluded=$savedExcluded '
        'shopCodes=${codes.isEmpty ? '-' : codes.join(',')}';
  }
}

/// supplement 判定 → UI 表示候補の橋渡し（ログ・将来の補助枠 UI 用）。
abstract final class ShopDiscoveryPoolSupplementUiBridge {
  ShopDiscoveryPoolSupplementUiBridge._();

  static bool _isSavedShopCode(String shopCode, Set<String> savedShopCodes) {
    final code = shopCode.trim();
    if (code.isEmpty) return false;
    return savedShopCodes.contains(code);
  }

  /// 補助枠表示候補から保存済みショップを除外する（通常 API 結果には影響しない）。
  static ShopDiscoveryPoolSupplementSavedExcludeResult excludeSavedFromDisplayCandidates(
    ShopDiscoveryPoolSupplementUiBridgeResult bridge, {
    Set<String> savedShopCodes = const {},
  }) {
    if (savedShopCodes.isEmpty || bridge.displayCandidates.isEmpty) {
      return ShopDiscoveryPoolSupplementSavedExcludeResult(
        bridge: bridge,
        before: bridge.displayCandidateCount,
        after: bridge.displayCandidateCount,
        savedExcluded: 0,
        excludedShopCodes: const [],
      );
    }

    final before = bridge.displayCandidateCount;
    final excludedShopCodes = <String>[];
    final filtered = <ShopDiscoveryPoolSupplementUiDisplayCandidate>[];
    for (final candidate in bridge.displayCandidates) {
      if (_isSavedShopCode(candidate.shopCode, savedShopCodes)) {
        excludedShopCodes.add(candidate.shopCode.trim());
        continue;
      }
      filtered.add(candidate);
    }

    final afterBridge = ShopDiscoveryPoolSupplementUiBridgeResult(
      keyword: bridge.keyword,
      recommendedDisplayCount: bridge.recommendedDisplayCount,
      displayCandidates: filtered,
    );
    return ShopDiscoveryPoolSupplementSavedExcludeResult(
      bridge: afterBridge,
      before: before,
      after: filtered.length,
      savedExcluded: excludedShopCodes.length,
      excludedShopCodes: excludedShopCodes,
    );
  }

  static ShopDiscoveryPoolSupplementUiBridgeResult extractDisplayCandidates(
    ShopDiscoveryPoolSupplementResult supplement,
  ) {
    final displayDecision = supplement.displayDecision;
    final recommended = displayDecision.recommendedDisplayCount;
    if (recommended <= 0 || displayDecision.candidateDecisions.isEmpty) {
      return ShopDiscoveryPoolSupplementUiBridgeResult(
        keyword: supplement.keyword,
        recommendedDisplayCount: recommended,
        displayCandidates: const <ShopDiscoveryPoolSupplementUiDisplayCandidate>[],
      );
    }

    final supplementByCode = <String, ShopDiscoveryPoolSupplementCandidate>{
      for (final c in supplement.selectedSupplements) c.shopCode: c,
    };

    final extracted = <ShopDiscoveryPoolSupplementUiDisplayCandidate>[];
    for (final decision in displayDecision.candidateDecisions) {
      if (!decision.showEligible) continue;
      if (decision.displayRank <= 0) continue;
      if (decision.displayRank > recommended) continue;

      final matched = supplementByCode[decision.shopCode];
      extracted.add(
        ShopDiscoveryPoolSupplementUiDisplayCandidate(
          shopCode: decision.shopCode,
          shopName: decision.shopName,
          displayRank: decision.displayRank,
          reason: decision.reason,
          strongItemEvidence: decision.strongItemEvidence,
          genreAligned: decision.genreAligned,
          hitItemCount: matched?.hitItemCount ?? decision.hitItemCount,
          score: matched?.score ?? 0,
        ),
      );
    }

    extracted.sort((a, b) => a.displayRank.compareTo(b.displayRank));
    return ShopDiscoveryPoolSupplementUiBridgeResult(
      keyword: supplement.keyword,
      recommendedDisplayCount: recommended,
      displayCandidates: extracted,
    );
  }

  /// 補助枠判定の詳細監査ログ（`CATALOG_AUDIT_LOGS=true` のときのみ）。
  static void logBridgeResult(ShopDiscoveryPoolSupplementUiBridgeResult result) {
    catalogAuditLog(result.buildUiBridgeLogLine());
  }

  /// 補助枠カード表示の詳細監査ログ（`CATALOG_AUDIT_LOGS=true` のときのみ）。
  static void logCardResult(ShopDiscoveryPoolSupplementUiBridgeResult result) {
    catalogAuditLog(result.buildUiCardLogLine());
  }

  /// 補助枠 displayCandidates からの保存済み除外を監査ログへ出力する。
  static void logSavedExclude(
    ShopDiscoveryPoolSupplementSavedExcludeResult result,
  ) {
    if (result.savedExcluded <= 0) {
      return;
    }
    catalogAuditLog(result.buildLogLine());
  }

  static String buildCardTapLogLine({
    required String keyword,
    required ShopDiscoveryPoolSupplementUiDisplayCandidate candidate,
    required String action,
  }) {
    final keywordForLog = keyword.isEmpty ? '-' : keyword;
    return '[SHOP_DISCOVERY_POOL_SUPPLEMENT_CARD_TAP] '
        'keyword=$keywordForLog '
        'shopCode=${candidate.shopCode} '
        'shopName=${candidate.shopName} '
        'action=$action';
  }

  /// 補助枠カードタップを debug ビルド向けユーザー操作ログへ出力する。
  static void logCardTap({
    required String keyword,
    required ShopDiscoveryPoolSupplementUiDisplayCandidate candidate,
    required String action,
  }) {
    shopDiscoveryUserActionLog(
      buildCardTapLogLine(
        keyword: keyword,
        candidate: candidate,
        action: action,
      ),
    );
  }
}
