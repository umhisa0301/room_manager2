import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/shop_discovery_pool_supplement_ui_bridge.dart';
import 'package:room_manager2/widgets/shop_discovery_pool_supplement_cards.dart';

ShopDiscoveryPoolSupplementUiDisplayCandidate _candidate({
  required String shopCode,
  required String shopName,
  int displayRank = 1,
  bool strongItemEvidence = false,
  bool genreAligned = false,
}) {
  return ShopDiscoveryPoolSupplementUiDisplayCandidate(
    shopCode: shopCode,
    shopName: shopName,
    displayRank: displayRank,
    reason: 'apiMissingStrongPoolCandidate',
    strongItemEvidence: strongItemEvidence,
    genreAligned: genreAligned,
    hitItemCount: 10,
    score: 300,
  );
}

void main() {
  group('ShopDiscoveryPoolSupplementCardCopy', () {
    test('strongItemEvidence=true かつ genreAligned=false は商品名理由文', () {
      final text = ShopDiscoveryPoolSupplementCardCopy.reasonText(
        _candidate(
          shopCode: 'soukaidrink',
          shopName: '爽快ドリンク',
          strongItemEvidence: true,
          genreAligned: false,
        ),
      );
      expect(text, '商品名に検索キーワードを含む商品が多く見つかりました');
    });

    test('genreAligned=true はジャンル理由文', () {
      final text = ShopDiscoveryPoolSupplementCardCopy.reasonText(
        _candidate(
          shopCode: 'shop-a',
          shopName: 'Shop A',
          genreAligned: true,
        ),
      );
      expect(text, '検索キーワードと関連するジャンルの商品が見つかりました');
    });
  });

  group('ShopDiscoveryPoolSupplementCardsSection', () {
    testWidgets('displayCandidates が空なら補助枠を表示しない', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShopDiscoveryPoolSupplementCardsSection(candidates: []),
          ),
        ),
      );

      expect(find.text('追加で見つかったショップ候補'), findsNothing);
    });

    testWidgets('displayCandidates が1件なら補助枠カードを表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopDiscoveryPoolSupplementCardsSection(
              candidates: [
                _candidate(
                  shopCode: 'soukaidrink',
                  shopName: '爽快ドリンク専門店',
                  strongItemEvidence: true,
                  genreAligned: false,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('追加で見つかったショップ候補'), findsOneWidget);
      expect(find.text('爽快ドリンク専門店'), findsOneWidget);
      expect(find.text('アプリ内データより'), findsOneWidget);
      expect(
        find.text('商品名に検索キーワードを含む商品が多く見つかりました'),
        findsOneWidget,
      );
    });

    testWidgets('複数候補は displayRank 昇順の並びで表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopDiscoveryPoolSupplementCardsSection(
              candidates: [
                _candidate(
                  shopCode: 'shop-a',
                  shopName: 'Shop Alpha',
                  displayRank: 1,
                  genreAligned: true,
                ),
                _candidate(
                  shopCode: 'shop-b',
                  shopName: 'Shop Beta',
                  displayRank: 2,
                  genreAligned: true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Shop Alpha'), findsOneWidget);
      expect(find.text('Shop Beta'), findsOneWidget);

      final alphaOffset = tester.getTopLeft(find.text('Shop Alpha'));
      final betaOffset = tester.getTopLeft(find.text('Shop Beta'));
      expect(alphaOffset.dy, lessThan(betaOffset.dy));
    });

    testWidgets('onCandidateTap が渡されていればタップで callback が呼ばれる', (
      tester,
    ) async {
      ShopDiscoveryPoolSupplementUiDisplayCandidate? tapped;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopDiscoveryPoolSupplementCardsSection(
              candidates: [
                _candidate(
                  shopCode: 'soukaidrink',
                  shopName: '楽天24 ドリンク館',
                  strongItemEvidence: true,
                ),
              ],
              onCandidateTap: (candidate) => tapped = candidate,
            ),
          ),
        ),
      );

      await tester.tap(find.text('楽天24 ドリンク館'));
      await tester.pump();

      expect(tapped, isNotNull);
      expect(tapped!.shopCode, 'soukaidrink');
      expect(tapped!.shopName, '楽天24 ドリンク館');
    });
  });
}
