import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/theme/app_motion.dart';
import 'package:room_manager2/utils/home_post_milestone.dart';
import 'package:room_manager2/widgets/home_goal_milestone_progress.dart';

void main() {
  Future<void> pumpProgress(
    WidgetTester tester,
    int postCount, {
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: HomeGoalMilestoneProgress(postCount: postCount),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('HomeGoalMilestoneProgress', () {
    testWidgets('postedCount=0 で1件マーカーに星やチェックが付かない', (tester) async {
      await pumpProgress(tester, 0);

      final marker = tester.widget<Container>(
        find.byKey(const Key('home_goal_marker_1')),
      );
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      final decoration = marker.decoration! as BoxDecoration;
      expect(decoration.color, Colors.white);
    });

    testWidgets('postedCount=0 で挑戦中バッジは件数ラベルの下に配置される', (tester) async {
      await pumpProgress(tester, 0);

      expect(
        find.byKey(const Key('home_goal_in_progress_badge_1')),
        findsOneWidget,
      );
      expect(find.text('挑戦中'), findsOneWidget);

      final labelFinder = find.byKey(const Key('home_goal_milestone_label_1'));
      final badgeFinder = find.byKey(
        const Key('home_goal_in_progress_badge_1'),
      );
      expect(
        tester.getTopLeft(badgeFinder).dy,
        greaterThan(tester.getBottomLeft(labelFinder).dy),
      );
    });

    testWidgets('1件/5件/10件/20件ラベルが各マーカーと同じカラム中央に揃う', (tester) async {
      await pumpProgress(tester, 0);

      for (final milestone in [1, 5, 10, 20]) {
        final markerFinder = find.byKey(Key('home_goal_marker_$milestone'));
        final labelFinder = find.byKey(
          Key('home_goal_milestone_label_$milestone'),
        );
        final markerCenter = tester.getCenter(markerFinder);
        final labelCenter = tester.getCenter(labelFinder);
        expect(
          (markerCenter.dx - labelCenter.dx).abs(),
          lessThan(1.0),
          reason: '$milestone件ラベルがマーカーとX座標でずれている',
        );
        expect(
          labelCenter.dy,
          greaterThan(markerCenter.dy),
          reason: '$milestone件ラベルはマーカーの下にあるべき',
        );
      }
    });

    testWidgets('各マイルストーンは Expanded カラム内にマーカーとラベルを持つ', (tester) async {
      await pumpProgress(tester, 3);

      for (final milestone in [1, 5, 10, 20]) {
        final columnFinder = find.byKey(
          Key('home_goal_milestone_column_$milestone'),
        );
        expect(columnFinder, findsOneWidget);
        expect(
          find.descendant(
            of: columnFinder,
            matching: find.byKey(Key('home_goal_marker_$milestone')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: columnFinder,
            matching: find.byKey(Key('home_goal_milestone_label_$milestone')),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('postedCount=1 で1件はチェック、5件は挑戦中', (tester) async {
      await pumpProgress(tester, 1);

      expect(find.byKey(const Key('home_goal_marker_1')), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        find.byKey(const Key('home_goal_in_progress_badge_5')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_goal_in_progress_badge_1')),
        findsNothing,
      );
    });

    testWidgets('初回は現在 progress を即表示する', (tester) async {
      await pumpProgress(tester, 10);
      expect(
        HomePostMilestoneSnapshot.overallProgress(10),
        closeTo(0.5, 0.001),
      );
      expect(find.byType(HomeGoalMilestoneProgress), findsOneWidget);
    });

    testWidgets('progress 更新後に最終値へ到達し clamp される', (tester) async {
      await pumpProgress(tester, 0);
      await pumpProgress(tester, 25);
      await tester.pump();
      await tester.pump(AppMotion.emphasized);
      expect(HomePostMilestoneSnapshot.overallProgress(25), 1.0);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(4));
    });

    testWidgets('同値更新でも壊れない', (tester) async {
      await pumpProgress(tester, 5);
      await pumpProgress(tester, 5);
      await tester.pump();
      expect(
        find.byKey(const Key('home_goal_in_progress_badge_10')),
        findsOneWidget,
      );
    });

    testWidgets('reduce motion では即時更新する', (tester) async {
      await pumpProgress(tester, 0, reduceMotion: true);
      await pumpProgress(tester, 5, reduceMotion: true);
      await tester.pump();
      // 5件達成時は 1件・5件の2マーカーがチェックになる。
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(
        find.byKey(const Key('home_goal_in_progress_badge_10')),
        findsOneWidget,
      );
    });

    testWidgets('Semantics は全体20件基準で視覚バーと一致する', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpProgress(tester, 3);
        expect(
          HomeGoalMilestoneProgress.semanticsLabelFor(3),
          '今日の投稿目標 20件中3件',
        );
        expect(
          tester.getSemantics(find.byType(HomeGoalMilestoneProgress)),
          matchesSemantics(label: '今日の投稿目標 20件中3件', value: '3'),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Semantics は20件達成時に達成文言になる', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpProgress(tester, 20);
        expect(
          HomeGoalMilestoneProgress.semanticsLabelFor(20),
          '今日の投稿数 20件。今日の投稿目標を達成しました',
        );
        expect(
          tester.getSemantics(find.byType(HomeGoalMilestoneProgress)),
          matchesSemantics(label: '今日の投稿数 20件。今日の投稿目標を達成しました', value: '20'),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Semantics は20件超でも件数を正確に伝える', (tester) async {
      expect(
        HomeGoalMilestoneProgress.semanticsLabelFor(25),
        '今日の投稿数 25件。今日の投稿目標を達成しました',
      );
      expect(HomeGoalMilestoneProgress.semanticsLabelFor(-3), '今日の投稿目標 20件中0件');
    });
  });

  group('overallProgress 境界値', () {
    test('0〜20および不正値で 0〜1 に clamp される', () {
      expect(HomePostMilestoneSnapshot.overallProgress(0), 0.0);
      expect(HomePostMilestoneSnapshot.overallProgress(1), closeTo(0.05, 1e-9));
      expect(HomePostMilestoneSnapshot.overallProgress(4), closeTo(0.2, 1e-9));
      expect(HomePostMilestoneSnapshot.overallProgress(5), closeTo(0.25, 1e-9));
      expect(HomePostMilestoneSnapshot.overallProgress(9), closeTo(0.45, 1e-9));
      expect(HomePostMilestoneSnapshot.overallProgress(10), closeTo(0.5, 1e-9));
      expect(
        HomePostMilestoneSnapshot.overallProgress(19),
        closeTo(0.95, 1e-9),
      );
      expect(HomePostMilestoneSnapshot.overallProgress(20), 1.0);
      expect(HomePostMilestoneSnapshot.overallProgress(21), 1.0);
      expect(HomePostMilestoneSnapshot.overallProgress(100), 1.0);
      expect(HomePostMilestoneSnapshot.overallProgress(-1), 0.0);
      expect(HomePostMilestoneSnapshot.overallProgress(-100), 0.0);
    });

    test('NaN / infinity にならない', () {
      for (final count in [0, 1, 4, 5, 9, 10, 19, 20, 25, -3]) {
        final p = HomePostMilestoneSnapshot.overallProgress(count);
        expect(p.isNaN, isFalse, reason: 'count=$count');
        expect(p.isInfinite, isFalse, reason: 'count=$count');
        expect(p, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
