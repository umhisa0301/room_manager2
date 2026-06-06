import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/shop_discovery_pool_supplement.dart';
import 'package:room_manager2/services/shop_discovery_pool_supplement_ui_bridge.dart';
import 'package:room_manager2/services/shop_pool_keyword_relevance.dart';

ShopDiscoveryPoolSupplementResult _supplementResultWithDecisions({
  required String keyword,
  required int recommendedDisplayCount,
  required List<ShopDiscoveryPoolSupplementCandidateDecision> decisions,
  List<ShopDiscoveryPoolSupplementCandidate> selected = const [],
}) {
  return ShopDiscoveryPoolSupplementResult(
    keyword: keyword,
    comparison: ShopDiscoveryPoolSupplementResult.empty.comparison,
    poolQuality: null,
    apiQuality: ShopDiscoveryPoolSupplementResult.empty.apiQuality,
    eligibleSupplementCount: selected.length,
    selectedSupplements: selected,
    zeroReason: '',
    wouldShowSupplementIfEnabled: recommendedDisplayCount > 0,
    apiWeakSignal: false,
    apiWeakReason: '',
    poolCouldCoverApiWeakness: false,
    displayDecision: ShopDiscoveryPoolSupplementDisplayDecision(
      decision: recommendedDisplayCount > 0 ? 'showCandidate' : 'hide',
      reason: 'test',
      recommendedDisplayCount: recommendedDisplayCount,
      maxAllowedDisplayCount: 2,
      confidence: 'medium',
      eligibleAfterStrongEvidence: 0,
      candidateDecisions: decisions,
    ),
  );
}

ShopDiscoveryPoolSupplementCandidate _selectedCandidate({
  required String shopCode,
  int hitItemCount = 10,
  double score = 300,
}) {
  return ShopDiscoveryPoolSupplementCandidate(
    rank: 1,
    shopCode: shopCode,
    shopName: 'Shop $shopCode',
    score: score,
    relevance: ShopPoolKeywordMatchLevel.strong,
    matchedBy: 'itemName',
    hitItemCount: hitItemCount,
    avgReview: 4.5,
    maxReviewCount: 100,
    primaryGenreName: '大人用水筒・マグボトル',
    matchedGenreName: '大人用水筒・マグボトル',
    hasImage: true,
    hasShopUrl: true,
    reason: ShopDiscoveryPoolSupplementReason.strongRelevance,
  );
}

ShopDiscoveryPoolSupplementCandidateDecision _decision({
  required String shopCode,
  required bool showEligible,
  required int displayRank,
  bool strongItemEvidence = false,
  bool genreAligned = true,
}) {
  return ShopDiscoveryPoolSupplementCandidateDecision(
    rank: 1,
    shopCode: shopCode,
    shopName: 'Shop $shopCode',
    showEligible: showEligible,
    reason: showEligible
        ? 'apiMissingStrongPoolCandidate'
        : 'similarToCandidate1OrTooGeneric',
    candidateDecisionReason: showEligible
        ? 'apiMissingStrongPoolCandidate'
        : 'similarToCandidate1OrTooGeneric',
    displayRank: displayRank,
    genericShop: false,
    broadShop: false,
    genreAligned: genreAligned,
    genreAlignmentReason: genreAligned ? 'matchesKeywordGenre' : 'unknown',
    strongItemEvidence: strongItemEvidence,
    matchedBy: 'itemName',
    hitItemCount: 10,
    primaryGenreName: '大人用水筒・マグボトル',
    matchedGenreName: '大人用水筒・マグボトル',
  );
}

void main() {
  group('ShopDiscoveryPoolSupplementUiBridge', () {
    test('showEligible + displayRank<=recommended の候補だけ抽出する', () {
      final result = _supplementResultWithDecisions(
        keyword: '水筒',
        recommendedDisplayCount: 1,
        selected: [_selectedCandidate(shopCode: 'soukaidrink', hitItemCount: 22)],
        decisions: [
          _decision(
            shopCode: 'soukaidrink',
            showEligible: true,
            displayRank: 1,
            strongItemEvidence: true,
            genreAligned: false,
          ),
          _decision(
            shopCode: 'rakuten24',
            showEligible: false,
            displayRank: 0,
          ),
        ],
      );

      final bridge =
          ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(result);

      expect(bridge.displayCandidateCount, 1);
      expect(bridge.recommendedDisplayCount, 1);
      expect(bridge.displayCandidates.single.shopCode, 'soukaidrink');
      expect(bridge.displayCandidates.single.displayRank, 1);
      expect(bridge.displayCandidates.single.strongItemEvidence, isTrue);
      expect(bridge.buildUiBridgeLogLine(),
          contains('[SHOP_DISCOVERY_POOL_SUPPLEMENT_UI_BRIDGE]'));
      expect(bridge.buildUiBridgeLogLine(), contains('displayCandidates=1'));
      expect(bridge.buildUiBridgeLogLine(), contains('shopCodes=soukaidrink'));
      expect(bridge.buildUiBridgeLogLine(), contains('willUsePoolForUi=false'));
      expect(bridge.buildUiBridgeLogLine(), contains('willSkipApi=false'));
      expect(bridge.buildUiCardLogLine(),
          contains('[SHOP_DISCOVERY_POOL_SUPPLEMENT_UI_CARD]'));
      expect(bridge.buildUiCardLogLine(), contains('visibleCards=1'));
      expect(bridge.buildUiCardLogLine(), contains('shopCodes=soukaidrink'));
    });

    test('buildCardTapLogLine のログ形式', () {
      final bridge = ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(
        _supplementResultWithDecisions(
          keyword: '水筒',
          recommendedDisplayCount: 1,
          selected: [_selectedCandidate(shopCode: 'soukaidrink', hitItemCount: 22)],
          decisions: [
            _decision(
              shopCode: 'soukaidrink',
              showEligible: true,
              displayRank: 1,
              strongItemEvidence: true,
            ),
          ],
        ),
      );
      final line = ShopDiscoveryPoolSupplementUiBridge.buildCardTapLogLine(
        keyword: '水筒',
        candidate: bridge.displayCandidates.single,
        action: 'shopSearch',
      );
      expect(line, contains('[SHOP_DISCOVERY_POOL_SUPPLEMENT_CARD_TAP]'));
      expect(line, contains('keyword=水筒'));
      expect(line, contains('shopCode=soukaidrink'));
      expect(line, contains('action=shopSearch'));
    });

    test('recommendedDisplayCount=0 なら displayCandidates=0（コーヒー相当）', () {
      final result = _supplementResultWithDecisions(
        keyword: 'コーヒー',
        recommendedDisplayCount: 0,
        decisions: [
          _decision(
            shopCode: 'atlas-online',
            showEligible: false,
            displayRank: 0,
          ),
        ],
      );

      final bridge =
          ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(result);

      expect(bridge.displayCandidateCount, 0);
      expect(bridge.buildUiBridgeLogLine(), contains('displayCandidates=0'));
      expect(bridge.buildUiCardLogLine(), contains('visibleCards=0'));
      expect(bridge.buildUiBridgeLogLine(), contains('shopCodes=-'));
    });

    test('ベビー相当で recommendedDisplayCount=0 なら displayCandidates=0', () {
      final result = _supplementResultWithDecisions(
        keyword: 'ベビー',
        recommendedDisplayCount: 0,
        decisions: [
          _decision(
            shopCode: 'tiger-online',
            showEligible: false,
            displayRank: 0,
            genreAligned: false,
          ),
        ],
      );

      final bridge =
          ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(result);

      expect(bridge.displayCandidateCount, 0);
      expect(bridge.keyword, 'ベビー');
      expect(bridge.buildUiBridgeLogLine(), contains('displayCandidates=0'));
    });

    test('showEligible=false は displayRank があっても除外される', () {
      final result = _supplementResultWithDecisions(
        keyword: '水筒',
        recommendedDisplayCount: 1,
        decisions: [
          _decision(shopCode: 'rakuten24', showEligible: false, displayRank: 0),
        ],
      );

      final bridge =
          ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(result);

      expect(bridge.displayCandidateCount, 0);
    });

    test('displayRank>recommended は除外される', () {
      final result = _supplementResultWithDecisions(
        keyword: '水筒',
        recommendedDisplayCount: 1,
        decisions: [
          _decision(shopCode: 'shop-a', showEligible: true, displayRank: 2),
        ],
      );

      final bridge =
          ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(result);

      expect(bridge.displayCandidateCount, 0);
    });

    test('contentEquals は表示候補の差分を検出する', () {
      final left = ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(
        _supplementResultWithDecisions(
          keyword: '水筒',
          recommendedDisplayCount: 1,
          decisions: [
            _decision(
              shopCode: 'soukaidrink',
              showEligible: true,
              displayRank: 1,
            ),
          ],
        ),
      );
      final same = ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(
        _supplementResultWithDecisions(
          keyword: '水筒',
          recommendedDisplayCount: 1,
          decisions: [
            _decision(
              shopCode: 'soukaidrink',
              showEligible: true,
              displayRank: 1,
            ),
          ],
        ),
      );
      final different =
          ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(
        _supplementResultWithDecisions(
          keyword: 'コーヒー',
          recommendedDisplayCount: 0,
          decisions: const [],
        ),
      );

      expect(left.contentEquals(same), isTrue);
      expect(left.contentEquals(different), isFalse);
      expect(
        ShopDiscoveryPoolSupplementUiBridgeResult.empty.contentEquals(left),
        isFalse,
      );
    });

    test('candidate1 不適格でも candidate2 が displayRank=1 なら抽出する', () {
      final result = _supplementResultWithDecisions(
        keyword: '水筒',
        recommendedDisplayCount: 1,
        selected: [
          _selectedCandidate(shopCode: 'the-charme'),
        ],
        decisions: [
          _decision(shopCode: 'rakuten24', showEligible: false, displayRank: 0),
          _decision(
            shopCode: 'the-charme',
            showEligible: true,
            displayRank: 1,
          ),
        ],
      );

      final bridge =
          ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(result);

      expect(bridge.displayCandidateCount, 1);
      expect(bridge.displayCandidates.single.shopCode, 'the-charme');
      expect(bridge.displayCandidates.single.displayRank, 1);
    });

    test('保存済みショップは displayCandidates から除外される', () {
      final result = _supplementResultWithDecisions(
        keyword: '水筒',
        recommendedDisplayCount: 1,
        selected: [_selectedCandidate(shopCode: 'ra-beans', hitItemCount: 7)],
        decisions: [
          _decision(
            shopCode: 'ra-beans',
            showEligible: true,
            displayRank: 1,
            strongItemEvidence: true,
          ),
        ],
      );

      final extracted =
          ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(result);
      expect(extracted.displayCandidateCount, 1);
      expect(extracted.displayCandidates.single.shopCode, 'ra-beans');

      final excluded =
          ShopDiscoveryPoolSupplementUiBridge.excludeSavedFromDisplayCandidates(
        extracted,
        savedShopCodes: {'ra-beans'},
      );

      expect(excluded.before, 1);
      expect(excluded.after, 0);
      expect(excluded.savedExcluded, 1);
      expect(excluded.excludedShopCodes, ['ra-beans']);
      expect(excluded.bridge.displayCandidateCount, 0);
      expect(excluded.bridge.recommendedDisplayCount, 1);
      expect(excluded.buildLogLine(),
          contains('[SHOP_DISCOVERY_POOL_SUPPLEMENT_SAVED_EXCLUDE]'));
      expect(excluded.buildLogLine(), contains('keyword=水筒'));
      expect(excluded.buildLogLine(), contains('before=1'));
      expect(excluded.buildLogLine(), contains('after=0'));
      expect(excluded.buildLogLine(), contains('savedExcluded=1'));
      expect(excluded.buildLogLine(), contains('shopCodes=ra-beans'));
      expect(excluded.bridge.buildUiCardLogLine(), contains('visibleCards=0'));
      expect(excluded.bridge.buildUiCardLogLine(), contains('shopCodes=-'));
    });

    test('保存済みでないショップは従来通り displayCandidates に残る', () {
      final result = _supplementResultWithDecisions(
        keyword: '水筒',
        recommendedDisplayCount: 1,
        selected: [_selectedCandidate(shopCode: 'the-charme')],
        decisions: [
          _decision(
            shopCode: 'the-charme',
            showEligible: true,
            displayRank: 1,
          ),
        ],
      );

      final extracted =
          ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(result);
      final excluded =
          ShopDiscoveryPoolSupplementUiBridge.excludeSavedFromDisplayCandidates(
        extracted,
        savedShopCodes: {'ra-beans'},
      );

      expect(excluded.savedExcluded, 0);
      expect(excluded.bridge.displayCandidateCount, 1);
      expect(excluded.bridge.displayCandidates.single.shopCode, 'the-charme');
    });

    test('extractDisplayCandidates 単体では保存済み判定を行わない', () {
      final result = _supplementResultWithDecisions(
        keyword: '水筒',
        recommendedDisplayCount: 1,
        selected: [_selectedCandidate(shopCode: 'ra-beans')],
        decisions: [
          _decision(
            shopCode: 'ra-beans',
            showEligible: true,
            displayRank: 1,
          ),
        ],
      );

      final bridge =
          ShopDiscoveryPoolSupplementUiBridge.extractDisplayCandidates(result);

      expect(bridge.displayCandidateCount, 1);
      expect(bridge.displayCandidates.single.shopCode, 'ra-beans');
    });
  });
}
