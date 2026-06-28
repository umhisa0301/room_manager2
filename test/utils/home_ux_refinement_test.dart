import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/profile_tutorial_flow.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/models/today_recommendation.dart';
import 'package:room_manager2/utils/recommendation_diversity_utils.dart';
import 'package:room_manager2/utils/today_recommendation_visible_selection.dart';

RakutenSearchItem _item({
  required String id,
  required String name,
  String shopCode = 'shop-a',
  String imageUrl = '',
}) =>
    RakutenSearchItem(
      productId: id,
      itemName: name,
      itemPrice: 1500,
      itemUrl: 'https://example.com/$id',
      affiliateUrl: '',
      imageUrl: imageUrl,
      shopName: 'Shop',
      shopCode: shopCode,
    );

TodayRecommendationEntry _entry({
  required String id,
  String name = '商品',
  String shopCode = 'shop-a',
  TodayRecommendationSection section = TodayRecommendationSection.popular,
}) =>
    TodayRecommendationEntry(
      item: _item(id: id, name: name, shopCode: shopCode),
      section: section,
    );

void main() {
  group('RecommendationDiversityUtils', () {
    test('サイズ違いの同一シリーズ商品名を類似と判定する', () {
      expect(
        RecommendationDiversityUtils.areTitlesSimilar(
          '木製キャビネット 幅90cm ナチュラル',
          '木製キャビネット 幅120cm ナチュラル',
        ),
        isTrue,
      );
    });

    test('異なる商品名は類似と判定しない', () {
      expect(
        RecommendationDiversityUtils.areTitlesSimilar(
          'キッチンタイマー',
          'ペット用自動給水器',
        ),
        isFalse,
      );
    });

    test('同一ショップは2件目を分散ゲートで弾く', () {
      final picked = [_entry(id: '1', shopCode: 'same-shop')];
      expect(
        RecommendationDiversityUtils.passesDiversityGate(
          item: _item(id: '2', name: '別商品', shopCode: 'same-shop'),
          picked: picked,
          allowDuplicateShop: false,
        ),
        isFalse,
      );
    });
  });

  group('TodayRecommendationVisibleSelection', () {
    test('保存ショップ未登録時は sellable を表示件数に含めない', () {
      final entries = [
        _entry(id: '1', section: TodayRecommendationSection.sellable),
        _entry(id: '2', section: TodayRecommendationSection.popular),
        _entry(id: '3', section: TodayRecommendationSection.fresh),
      ];

      expect(
        TodayRecommendationVisibleSelection.visibleCount(entries, 0),
        2,
      );
    });

    test('非表示候補を除外し backfill で表示3件を確保する', () {
      final entries = [
        _entry(id: '1', section: TodayRecommendationSection.sellable),
        _entry(id: '2', section: TodayRecommendationSection.popular),
      ];
      final backfill = [
        _entry(
          id: '3',
          name: '発見候補',
          shopCode: 'shop-b',
          section: TodayRecommendationSection.fresh,
        ),
        _entry(
          id: '4',
          name: '追加候補',
          shopCode: 'shop-c',
          section: TodayRecommendationSection.popular,
        ),
      ];

      final result = TodayRecommendationVisibleSelection.ensureVisibleCap(
        entries: entries,
        savedShopCount: 0,
        backfillPool: backfill,
      );

      expect(result.entries.length, 3);
      expect(
        result.entries.every(
          (e) => e.section != TodayRecommendationSection.sellable,
        ),
        isTrue,
      );
    });

    test('表示可能候補が2件しかない場合は2件のまま', () {
      final entries = [
        _entry(id: '1', section: TodayRecommendationSection.popular),
        _entry(id: '2', section: TodayRecommendationSection.fresh),
      ];

      final result = TodayRecommendationVisibleSelection.ensureVisibleCap(
        entries: entries,
        savedShopCount: 0,
        backfillPool: const [],
      );

      expect(result.entries.length, 2);
      expect(result.fallbackReason, 'insufficientVisibleCandidates');
    });
  });

  group('profileTutorialFlow', () {
    test('ガイドは2ステップで現行UIと一致する', () {
      expect(profileTutorialFlow.steps.length, 2);
      expect(profileTutorialFlow.steps[0].title, 'ROOMプロフィール');
      expect(profileTutorialFlow.steps[1].title, 'ROOMタイプ診断');
    });

    test('ROOMプロフィールの説明が現行UIに合わせている', () {
      expect(
        profileTutorialFlow.steps[0].body,
        contains('ニックネームとROOM URL'),
      );
      expect(
        profileTutorialFlow.steps[0].body,
        contains('投稿済み商品や反応を確認しやすく'),
      );
      expect(profileTutorialFlow.steps[0].body, isNot(contains('個人情報')));
      expect(profileTutorialFlow.steps[0].body, isNot(contains('個人設定')));
    });
  });

  group('homeTodayWorkCard copy', () {
    test('投稿ステップのボタン文言は投稿する', () {
      final source = File(
        'lib/screens/home_placeholder_screen.dart',
      ).readAsStringSync();
      expect(source, contains("buttonLabel: '投稿する'"));
      expect(source, isNot(contains("buttonLabel: '投稿へ'")));
    });

    test('今日やることCTAは共通TextStyleで18px太字', () {
      final source = File(
        'lib/screens/home_placeholder_screen.dart',
      ).readAsStringSync();
      expect(source, contains('_homeTodayWorkCtaTextStyle'));
      expect(source, contains('fontSize: 18'));
      expect(source, contains('fontWeight: FontWeight.w700'));
      expect(source, contains("buttonLabel: '探す'"));
      expect(source, contains('textStyle: _homeTodayWorkCtaTextStyle'));
    });
  });
}
