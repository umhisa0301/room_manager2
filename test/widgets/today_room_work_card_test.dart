import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/screens/home_placeholder_screen.dart';
import 'package:room_manager2/theme/app_motion.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required bool isRecommendationReviewComplete,
    required int pendingCandidateCount,
    int todayRoomPostCount = 0,
    bool isRecommendationLoading = false,
    bool isRecommendationOpening = false,
    bool reduceMotion = false,
    VoidCallback? onOpenRecommendations,
    VoidCallback? onOpenPendingCandidates,
    VoidCallback? onOpenSearch,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: SingleChildScrollView(
              child: TodayRoomWorkCard(
                isRecommendationReviewComplete: isRecommendationReviewComplete,
                todayRoomPostCount: todayRoomPostCount,
                pendingCandidateCount: pendingCandidateCount,
                isRecommendationLoading: isRecommendationLoading,
                isRecommendationOpening: isRecommendationOpening,
                onOpenRecommendations: onOpenRecommendations ?? () {},
                onOpenPendingCandidates: onOpenPendingCandidates ?? () {},
                onOpenSearch: onOpenSearch ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  Key? primaryActionKey(WidgetTester tester) {
    final switchers = tester.widgetList<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    for (final switcher in switchers) {
      final child = switcher.child;
      if (child is KeyedSubtree) {
        return child.key;
      }
    }
    return null;
  }

  group('TodayRoomWorkCard primary CTA', () {
    testWidgets('recommendations → post → search の表示切替', (tester) async {
      await pumpCard(
        tester,
        isRecommendationReviewComplete: false,
        pendingCandidateCount: 0,
      );
      expect(find.text('おすすめコレ'), findsOneWidget);
      expect(find.text('今日の候補を確認'), findsOneWidget);

      await pumpCard(
        tester,
        isRecommendationReviewComplete: true,
        pendingCandidateCount: 3,
      );
      await tester.pump();
      await tester.pump(AppMotion.normal);
      expect(find.text('投稿する'), findsOneWidget);
      expect(find.text('候補を投稿'), findsOneWidget);
      expect(find.text('コレ候補3件'), findsOneWidget);

      await pumpCard(
        tester,
        isRecommendationReviewComplete: true,
        pendingCandidateCount: 0,
        todayRoomPostCount: 1,
      );
      await tester.pump();
      await tester.pump(AppMotion.normal);
      expect(find.text('探す'), findsOneWidget);
      expect(find.text('候補を増やす'), findsOneWidget);
    });

    testWidgets('同じアクションで rebuild しても Key が変わらない', (tester) async {
      await pumpCard(
        tester,
        isRecommendationReviewComplete: false,
        pendingCandidateCount: 0,
      );
      final key1 = primaryActionKey(tester);
      expect(key1, isNotNull);

      await pumpCard(
        tester,
        isRecommendationReviewComplete: false,
        pendingCandidateCount: 0,
      );
      final key2 = primaryActionKey(tester);
      expect(key2, key1);
    });

    testWidgets('reduce motion で即時切替する', (tester) async {
      await pumpCard(
        tester,
        isRecommendationReviewComplete: false,
        pendingCandidateCount: 0,
        reduceMotion: true,
      );
      await pumpCard(
        tester,
        isRecommendationReviewComplete: true,
        pendingCandidateCount: 2,
        reduceMotion: true,
      );
      await tester.pump();
      expect(find.text('投稿する'), findsOneWidget);
      expect(find.text('おすすめコレ'), findsNothing);
    });

    testWidgets('主CTAの onPressed が維持される', (tester) async {
      var taps = 0;
      await pumpCard(
        tester,
        isRecommendationReviewComplete: true,
        pendingCandidateCount: 1,
        onOpenPendingCandidates: () => taps++,
      );
      await tester.tap(find.text('投稿する'));
      expect(taps, 1);
    });

    testWidgets('loading / opening 中は主CTAが disabled', (tester) async {
      var taps = 0;
      await pumpCard(
        tester,
        isRecommendationReviewComplete: false,
        pendingCandidateCount: 0,
        isRecommendationLoading: true,
        onOpenRecommendations: () => taps++,
      );
      await tester.tap(find.text('おすすめコレ'));
      expect(taps, 0);

      await pumpCard(
        tester,
        isRecommendationReviewComplete: false,
        pendingCandidateCount: 0,
        isRecommendationOpening: true,
        onOpenRecommendations: () => taps++,
      );
      await tester.tap(find.text('おすすめコレ'));
      expect(taps, 0);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'おすすめコレ'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('生成中のみ LinearProgressIndicator を表示する', (tester) async {
      await pumpCard(
        tester,
        isRecommendationReviewComplete: false,
        pendingCandidateCount: 0,
        isRecommendationLoading: true,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await pumpCard(
        tester,
        isRecommendationReviewComplete: false,
        pendingCandidateCount: 0,
        isRecommendationOpening: true,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('主CTA Semantics が action ごとに日本語化し Key を維持する', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpCard(
        tester,
        isRecommendationReviewComplete: false,
        pendingCandidateCount: 0,
      );
      await tester.pump();

      final rec = tester.getSemantics(
        find.byKey(const Key('home_recommendation_button')),
      );
      expect(rec.label, '今日のおすすめを見る');
      expect(rec.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(rec.hasFlag(SemanticsFlag.isEnabled), isTrue);
      expect(find.bySemanticsLabel('home_recommendation_button'), findsNothing);
      expect(find.bySemanticsLabel('今日のおすすめを見る'), findsOneWidget);
      expect(find.text('おすすめコレ'), findsOneWidget);

      await pumpCard(
        tester,
        isRecommendationReviewComplete: true,
        pendingCandidateCount: 2,
      );
      await tester.pump();
      await tester.pump(AppMotion.normal);

      final post = tester.getSemantics(
        find.byKey(const Key('home_room_post_button')),
      );
      expect(post.label, 'コレ候補の商品を投稿する');
      expect(post.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(post.hasFlag(SemanticsFlag.isEnabled), isTrue);
      expect(find.bySemanticsLabel('home_room_post_button'), findsNothing);
      expect(find.bySemanticsLabel('コレ候補の商品を投稿する'), findsOneWidget);

      await pumpCard(
        tester,
        isRecommendationReviewComplete: true,
        pendingCandidateCount: 0,
      );
      await tester.pump();
      await tester.pump(AppMotion.normal);

      final search = tester.getSemantics(
        find.byKey(const Key('home_search_more_button')),
      );
      expect(search.label, '新しい商品を探す');
      expect(search.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(find.bySemanticsLabel('home_search_more_button'), findsNothing);
      expect(find.bySemanticsLabel('新しい商品を探す'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('busy 中の主CTA Semantics は enabled=false', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;

      await pumpCard(
        tester,
        isRecommendationReviewComplete: false,
        pendingCandidateCount: 0,
        isRecommendationLoading: true,
        onOpenRecommendations: () => taps++,
      );
      await tester.pump();

      final rec = tester.getSemantics(
        find.byKey(const Key('home_recommendation_button')),
      );
      expect(rec.label, '今日のおすすめを見る');
      expect(rec.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(rec.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
      expect(rec.hasFlag(SemanticsFlag.isEnabled), isFalse);

      await tester.tap(find.byKey(const Key('home_recommendation_button')));
      await tester.pump();
      expect(taps, 0);

      handle.dispose();
    });
  });

  group('TodayRoomWorkCard work steps', () {
    testWidgets('completed 時にチェックと完了文言を表示する', (tester) async {
      await pumpCard(
        tester,
        isRecommendationReviewComplete: true,
        pendingCandidateCount: 2,
        todayRoomPostCount: 0,
      );
      expect(find.text('完了'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('次にやる'), findsWidgets);
    });

    testWidgets('他 state の見た目を維持する', (tester) async {
      await pumpCard(
        tester,
        isRecommendationReviewComplete: false,
        pendingCandidateCount: 0,
      );
      expect(find.text('次にやる'), findsWidgets);
      expect(find.text('任意'), findsWidgets);
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsWidgets);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsWidgets);
    });

    testWidgets('同値 rebuild で不整合なし', (tester) async {
      await pumpCard(
        tester,
        isRecommendationReviewComplete: true,
        pendingCandidateCount: 0,
        todayRoomPostCount: 2,
      );
      expect(find.text('完了'), findsWidgets);

      await pumpCard(
        tester,
        isRecommendationReviewComplete: true,
        pendingCandidateCount: 0,
        todayRoomPostCount: 2,
      );
      await tester.pump();
      expect(find.text('完了'), findsWidgets);
      expect(find.text('次にやる'), findsWidgets);
    });
  });
}
