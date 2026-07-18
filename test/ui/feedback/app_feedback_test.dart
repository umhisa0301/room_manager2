import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/app_messenger.dart';
import 'package:room_manager2/ui/feedback/app_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppFeedback durations', () {
    test('defines expected default durations', () {
      expect(
        AppFeedback.durationShortSuccess,
        const Duration(milliseconds: 2000),
      );
      expect(AppFeedback.durationInfo, const Duration(milliseconds: 3000));
      expect(AppFeedback.durationError, const Duration(milliseconds: 4000));
    });
  });

  group('AppFeedback local messenger', () {
    testWidgets('success / error / info are visible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    TextButton(
                      onPressed: () =>
                          AppFeedback.success(context, message: '成功メッセージ'),
                      child: const Text('success'),
                    ),
                    TextButton(
                      onPressed: () =>
                          AppFeedback.error(context, message: 'エラーメッセージ'),
                      child: const Text('error'),
                    ),
                    TextButton(
                      onPressed: () =>
                          AppFeedback.info(context, message: '情報メッセージ'),
                      child: const Text('info'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('success'));
      await tester.pump();
      expect(find.text('成功メッセージ'), findsOneWidget);

      await tester.tap(find.text('error'));
      await tester.pump();
      expect(find.text('エラーメッセージ'), findsOneWidget);
      expect(find.text('成功メッセージ'), findsNothing);

      await tester.tap(find.text('info'));
      await tester.pump();
      expect(find.text('情報メッセージ'), findsOneWidget);
      expect(find.text('エラーメッセージ'), findsNothing);
    });

    testWidgets('rapid shows do not leave queued snackbars', (tester) async {
      late ScaffoldMessengerState messenger;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                return TextButton(
                  onPressed: () {
                    AppFeedback.success(context, message: 'first');
                    AppFeedback.success(context, message: 'second');
                    AppFeedback.success(context, message: 'third');
                  },
                  child: const Text('burst'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('burst'));
      await tester.pump();
      // 連続表示では最新のみ。first/second はキューに残らない。
      expect(find.text('third'), findsOneWidget);
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsNothing);

      messenger.clearSnackBars();
      await tester.pump();
      expect(find.text('third'), findsNothing);
    });
  });

  group('AppFeedback root messenger', () {
    testWidgets('successRoot shows on appRootScaffoldMessengerKey', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: appRootScaffoldMessengerKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

      AppFeedback.successRoot(message: 'root成功');
      await tester.pump();
      expect(find.text('root成功'), findsOneWidget);
    });
  });
}
