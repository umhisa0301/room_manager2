import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/theme/app_motion.dart';
import 'package:room_manager2/widgets/home_animated_int_count.dart';

void main() {
  Future<void> pumpCount(
    WidgetTester tester, {
    required int value,
    bool reduceMotion = false,
    Key? hostKey,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Center(
              child: HomeAnimatedIntCount(
                key: hostKey,
                value: value,
                builder: (context, displayValue) => Text(
                  '$displayValue',
                  key: const Key('animated_int_display'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('HomeAnimatedIntCount', () {
    testWidgets('初回は現在値を即表示する', (tester) async {
      await pumpCount(tester, value: 7);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('値増加時に最終値へ到達する', (tester) async {
      await pumpCount(tester, value: 2);
      expect(find.text('2'), findsOneWidget);

      await pumpCount(tester, value: 5);
      await tester.pump();
      await tester.pump(AppMotion.emphasized);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('値減少時も最終値へ到達する', (tester) async {
      await pumpCount(tester, value: 8);
      await pumpCount(tester, value: 3);
      await tester.pump();
      await tester.pump(AppMotion.emphasized);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('同値更新で表示が変わらない', (tester) async {
      await pumpCount(tester, value: 4, hostKey: const Key('count_host'));
      expect(find.text('4'), findsOneWidget);

      await pumpCount(tester, value: 4, hostKey: const Key('count_host'));
      await tester.pump();
      expect(find.text('4'), findsOneWidget);
      await tester.pump(AppMotion.emphasized);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('reduce motion では即時表示する', (tester) async {
      await pumpCount(tester, value: 1, reduceMotion: true);
      await pumpCount(tester, value: 9, reduceMotion: true);
      await tester.pump();
      expect(find.text('9'), findsOneWidget);
    });
  });
}
