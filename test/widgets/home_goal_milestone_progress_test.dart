import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/widgets/home_goal_milestone_progress.dart';

void main() {
  Future<void> pumpProgress(WidgetTester tester, int postCount) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: HomeGoalMilestoneProgress(postCount: postCount),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HomeGoalMilestoneProgress', () {
    testWidgets('postedCount=0 で1件マーカーに星やチェックが付かない', (
      tester,
    ) async {
      await pumpProgress(tester, 0);

      final marker = tester.widget<Container>(
        find.byKey(const Key('home_goal_marker_1')),
      );
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      final decoration = marker.decoration! as BoxDecoration;
      expect(decoration.color, Colors.white);
    });

    testWidgets('postedCount=0 で挑戦中バッジは件数ラベルの下に配置される', (
      tester,
    ) async {
      await pumpProgress(tester, 0);

      expect(
        find.byKey(const Key('home_goal_in_progress_badge_1')),
        findsOneWidget,
      );
      expect(find.text('挑戦中'), findsOneWidget);

      final labelFinder = find.byKey(const Key('home_goal_milestone_label_1'));
      final badgeFinder = find.byKey(const Key('home_goal_in_progress_badge_1'));
      expect(
        tester.getTopLeft(badgeFinder).dy,
        greaterThan(tester.getBottomLeft(labelFinder).dy),
      );
    });

    testWidgets('1件/5件/10件/20件ラベルが各マーカーと同じカラム中央に揃う', (
      tester,
    ) async {
      await pumpProgress(tester, 0);

      for (final milestone in [1, 5, 10, 20]) {
        final markerFinder = find.byKey(Key('home_goal_marker_$milestone'));
        final labelFinder = find.byKey(Key('home_goal_milestone_label_$milestone'));
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

    testWidgets('各マイルストーンは Expanded カラム内にマーカーとラベルを持つ', (
      tester,
    ) async {
      await pumpProgress(tester, 3);

      for (final milestone in [1, 5, 10, 20]) {
        final columnFinder =
            find.byKey(Key('home_goal_milestone_column_$milestone'));
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
  });
}
