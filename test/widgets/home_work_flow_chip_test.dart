import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/screens/home_placeholder_screen.dart';

void main() {
  group('TodayRoomWorkCard flow chips', () {
    testWidgets('Semantics label / enabled / 最小タップ領域', (tester) async {
      final handle = tester.ensureSemantics();
      var recommendationsTaps = 0;
      var postTaps = 0;
      var searchTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodayRoomWorkCard(
              isRecommendationReviewComplete: false,
              todayRoomPostCount: 0,
              pendingCandidateCount: 2,
              isRecommendationLoading: false,
              onOpenRecommendations: () => recommendationsTaps++,
              onOpenPendingCandidates: () => postTaps++,
              onOpenSearch: () => searchTaps++,
            ),
          ),
        ),
      );
      await tester.pump();

      final rec = tester.getSemantics(
        find.bySemanticsLabel('今日のおすすめを確認する、次にやる'),
      );
      expect(rec.label, '今日のおすすめを確認する、次にやる');
      expect(rec.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(rec.hasFlag(SemanticsFlag.isEnabled), isTrue);

      final post = tester.getSemantics(
        find.bySemanticsLabel('コレ候補の商品を投稿する、任意'),
      );
      expect(post.label, 'コレ候補の商品を投稿する、任意');
      expect(post.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(post.hasFlag(SemanticsFlag.isEnabled), isTrue);

      final search = tester.getSemantics(find.bySemanticsLabel('新しい商品を探す、任意'));
      expect(search.label, '新しい商品を探す、任意');
      expect(search.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(search.hasFlag(SemanticsFlag.isEnabled), isTrue);

      final chipRect = tester.getRect(
        find.bySemanticsLabel('今日のおすすめを確認する、次にやる'),
      );
      expect(chipRect.height, greaterThanOrEqualTo(44));

      await tester.tap(find.text('投稿'));
      await tester.tap(find.text('商品探し'));
      await tester.pump();
      expect(postTaps, 1);
      expect(searchTaps, 1);
      expect(recommendationsTaps, 0);

      handle.dispose();
    });

    testWidgets('busy 時はおすすめ確認が disabled', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodayRoomWorkCard(
              isRecommendationReviewComplete: false,
              todayRoomPostCount: 0,
              pendingCandidateCount: 0,
              isRecommendationLoading: true,
              onOpenRecommendations: () => taps++,
              onOpenPendingCandidates: () {},
              onOpenSearch: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final rec = tester.getSemantics(
        find.bySemanticsLabel('今日のおすすめを確認する、次にやる'),
      );
      expect(rec.label, '今日のおすすめを確認する、次にやる');
      expect(rec.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(rec.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
      expect(rec.hasFlag(SemanticsFlag.isEnabled), isFalse);

      await tester.tap(find.text('おすすめ確認'));
      await tester.pump();
      expect(taps, 0);
      handle.dispose();
    });

    testWidgets('小画面幅でも overflow しない', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: TodayRoomWorkCard(
                isRecommendationReviewComplete: true,
                todayRoomPostCount: 1,
                pendingCandidateCount: 0,
                isRecommendationLoading: false,
                onOpenRecommendations: () {},
                onOpenPendingCandidates: () {},
                onOpenSearch: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('おすすめ確認'), findsOneWidget);
      expect(find.text('投稿'), findsOneWidget);
      expect(find.text('商品探し'), findsOneWidget);
    });
  });
}
