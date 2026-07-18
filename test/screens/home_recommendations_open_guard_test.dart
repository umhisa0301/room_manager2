import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ホーム `_openTodayRecommendations` と同じ再入ガード契約を検証するハーネス。
class _RecommendationsOpenGuardHarness extends StatefulWidget {
  const _RecommendationsOpenGuardHarness({
    required this.onEnsureToday,
    required this.pushRouteBuilder,
  });

  final Future<void> Function() onEnsureToday;
  final WidgetBuilder pushRouteBuilder;

  @override
  State<_RecommendationsOpenGuardHarness> createState() =>
      _RecommendationsOpenGuardHarnessState();
}

class _RecommendationsOpenGuardHarnessState
    extends State<_RecommendationsOpenGuardHarness> {
  bool _isOpening = false;
  int ensureTodayCalls = 0;
  int pushCalls = 0;

  bool get isOpening => _isOpening;

  Future<void> open() async {
    if (_isOpening) return;
    _isOpening = true;
    if (mounted) setState(() {});
    try {
      ensureTodayCalls++;
      await widget.onEnsureToday();
      if (!mounted) return;
      pushCalls++;
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute<void>(builder: widget.pushRouteBuilder));
    } catch (_) {
      // finally で解除されることを検証するため、テスト用に握りつぶす。
    } finally {
      _isOpening = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton(
          key: const Key('primary_cta'),
          onPressed: _isOpening ? null : open,
          child: const Text('おすすめコレ'),
        ),
        TextButton(
          key: const Key('flow_chip'),
          onPressed: _isOpening ? null : open,
          child: const Text('おすすめ確認'),
        ),
      ],
    );
  }
}

void main() {
  group('home recommendations open guard (source)', () {
    test('ホーム実装に再入ガードがある', () {
      final source = File(
        'lib/screens/home_placeholder_screen.dart',
      ).readAsStringSync();
      expect(source, contains('bool _isOpeningTodayRecommendations = false'));
      expect(source, contains('if (_isOpeningTodayRecommendations) return'));
      expect(source, contains('_isOpeningTodayRecommendations = true'));
      expect(source, contains('} finally {'));
      expect(source, contains('_isOpeningTodayRecommendations = false'));
      expect(source, contains('if (mounted) setState(() {})'));
      expect(source, contains('isRecommendationOpening:'));
    });
  });

  group('recommendations open reentry guard', () {
    testWidgets('主CTA連打で ensureToday / push が1回', (tester) async {
      final ensureGate = Completer<void>();
      late _RecommendationsOpenGuardHarnessState state;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return _RecommendationsOpenGuardHarness(
                  onEnsureToday: () => ensureGate.future,
                  pushRouteBuilder: (_) =>
                      const Scaffold(body: Text('recommendations')),
                );
              },
            ),
          ),
        ),
      );
      state =
          tester.state(find.byType(_RecommendationsOpenGuardHarness))
              as _RecommendationsOpenGuardHarnessState;

      await tester.tap(find.byKey(const Key('primary_cta')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('primary_cta')));
      await tester.pump();

      expect(state.ensureTodayCalls, 1);
      expect(state.pushCalls, 0);

      ensureGate.complete();
      await tester.pumpAndSettle();
      expect(state.pushCalls, 1);
      expect(find.text('recommendations'), findsOneWidget);
    });

    testWidgets('フローchipとの交互連打でも1回', (tester) async {
      final ensureGate = Completer<void>();
      late _RecommendationsOpenGuardHarnessState state;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RecommendationsOpenGuardHarness(
              onEnsureToday: () => ensureGate.future,
              pushRouteBuilder: (_) =>
                  const Scaffold(body: Text('recommendations')),
            ),
          ),
        ),
      );
      state =
          tester.state(find.byType(_RecommendationsOpenGuardHarness))
              as _RecommendationsOpenGuardHarnessState;

      await tester.tap(find.byKey(const Key('primary_cta')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('flow_chip')));
      await tester.pump();

      expect(state.ensureTodayCalls, 1);

      ensureGate.complete();
      await tester.pumpAndSettle();
      expect(state.pushCalls, 1);
    });

    testWidgets('失敗後に再試行可能', (tester) async {
      var shouldFail = true;
      late _RecommendationsOpenGuardHarnessState state;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RecommendationsOpenGuardHarness(
              onEnsureToday: () async {
                if (shouldFail) {
                  shouldFail = false;
                  throw StateError('ensure failed');
                }
              },
              pushRouteBuilder: (_) =>
                  const Scaffold(body: Text('recommendations')),
            ),
          ),
        ),
      );
      state =
          tester.state(find.byType(_RecommendationsOpenGuardHarness))
              as _RecommendationsOpenGuardHarnessState;

      await tester.tap(find.byKey(const Key('primary_cta')));
      await tester.pump();
      expect(state.ensureTodayCalls, 1);
      expect(state.isOpening, isFalse);

      await tester.tap(find.byKey(const Key('primary_cta')));
      await tester.pumpAndSettle();
      expect(state.ensureTodayCalls, 2);
      expect(state.pushCalls, 1);
    });

    testWidgets('戻った後に再度利用可能', (tester) async {
      late _RecommendationsOpenGuardHarnessState state;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RecommendationsOpenGuardHarness(
              onEnsureToday: () async {},
              pushRouteBuilder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('recommendations-page'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      state =
          tester.state(find.byType(_RecommendationsOpenGuardHarness))
              as _RecommendationsOpenGuardHarnessState;

      await tester.tap(find.byKey(const Key('primary_cta')));
      await tester.pumpAndSettle();
      expect(state.pushCalls, 1);

      await tester.tap(find.text('recommendations-page'));
      await tester.pumpAndSettle();
      expect(state.isOpening, isFalse);

      await tester.tap(find.byKey(const Key('primary_cta')));
      await tester.pumpAndSettle();
      expect(state.ensureTodayCalls, 2);
      expect(state.pushCalls, 2);
    });

    testWidgets('Widget破棄中に例外なし', (tester) async {
      final ensureGate = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RecommendationsOpenGuardHarness(
              onEnsureToday: () => ensureGate.future,
              pushRouteBuilder: (_) =>
                  const Scaffold(body: Text('recommendations')),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('primary_cta')));
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      ensureGate.complete();
      await tester.pump();
      // 破棄後の setState 例外がなければ成功。
    });
  });
}
