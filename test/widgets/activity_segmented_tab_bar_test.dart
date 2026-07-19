import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/theme/app_motion.dart';
import 'package:room_manager2/widgets/activity/activity_segmented_tab_bar.dart';

void main() {
  group('ActivitySegmentedTabBar', () {
    testWidgets('人間向け Semantics と selected を持つ', (tester) async {
      final handle = tester.ensureSemantics();
      var selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ActivitySegmentedTabBar(
                  selectedIndex: selected,
                  onChanged: (i) => setState(() => selected = i),
                );
              },
            ),
          ),
        ),
      );

      final achievement = tester.getSemantics(find.bySemanticsLabel('実績'));
      expect(achievement.label, '実績');
      expect(achievement.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(achievement.hasFlag(SemanticsFlag.isSelected), isTrue);

      final analytics = tester.getSemantics(find.bySemanticsLabel('分析'));
      expect(analytics.label, '分析');
      expect(analytics.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(analytics.hasFlag(SemanticsFlag.isSelected), isFalse);

      await tester.tap(find.bySemanticsLabel('分析'));
      await tester.pump();

      final analyticsSelected = tester.getSemantics(
        find.bySemanticsLabel('分析'),
      );
      expect(analyticsSelected.hasFlag(SemanticsFlag.isSelected), isTrue);
      handle.dispose();
    });

    testWidgets('同じタブ再選択では onChanged を呼ばない', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivitySegmentedTabBar(
              selectedIndex: 0,
              onChanged: (_) => calls++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('実績'));
      await tester.pump();
      expect(calls, 0);
    });

    testWidgets('reduce motion 時は AnimatedContainer が即時', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  expect(
                    AppMotion.durationOf(context, AppMotion.normal),
                    Duration.zero,
                  );
                  return ActivitySegmentedTabBar(
                    selectedIndex: 0,
                    onChanged: (_) {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final animated = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      expect(animated.duration, Duration.zero);
    });
  });
}
