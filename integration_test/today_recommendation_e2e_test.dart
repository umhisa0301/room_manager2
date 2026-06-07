import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:room_manager2/main.dart' as app;

const _appBootTimeout = Duration(seconds: 45);
const _recommendResultTimeout = Duration(minutes: 5);
const _entryReadyTimeout = Duration(minutes: 3);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('today_recommendation_e2e', (tester) async {
    debugPrint('[E2E_RECOMMEND_TEST_START]');

    app.main();
    await tester.pump();
    await _dismissOnboardingIfNeeded(tester);

    await _openHomeTab(tester);
    final result = await _runTodayRecommendationFlow(tester);

    _assertNoRedScreen(tester);
    debugPrint(
      '[E2E_RECOMMEND_TEST_RESULT] success=true result=$result',
    );
  });
}

Future<void> _openHomeTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('app_shell_nav_home')));
  await _pumpUiSettle(tester);

  final success =
      find.text('ROOMコレ管理').evaluate().isNotEmpty ||
      find.text('ROOMデータ更新').evaluate().isNotEmpty;
  debugPrint('[E2E_RECOMMEND_STEP] step=openHomeTab success=$success');
  expect(success, isTrue, reason: 'ホーム（ROOMコレ管理）画面の表示確認');
}

Future<String> _runTodayRecommendationFlow(WidgetTester tester) async {
  await _waitForRecommendationEntryReady(tester);

  final entry = find.byKey(const Key('today_recommendation_entry_button'));
  expect(entry, findsOneWidget, reason: 'おすすめ生成入口ボタンが表示されること');

  try {
    await tester.scrollUntilVisible(
      entry,
      120,
      scrollable: find.byType(Scrollable).first,
    );
  } catch (_) {}
  await _pumpUiSettle(tester);

  await tester.tap(entry);
  await _pumpUiSettle(tester);
  debugPrint('[E2E_RECOMMEND_STEP] step=openRecommendationEntry success=true');

  await waitUntil(
    tester,
    () => find.text('今日のおすすめコレ候補').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 20),
    label: 'recommendationScreen',
  );

  final generateButton = find.byKey(
    const Key('today_recommendation_generate_button'),
  );
  if (generateButton.evaluate().isNotEmpty) {
    await tester.tap(generateButton);
    await tester.pump();
    debugPrint('[E2E_RECOMMEND_STEP] step=startRecommendation success=true');
  } else {
    debugPrint(
      '[E2E_RECOMMEND_STEP] step=startRecommendation success=true '
      'mode=skippedExistingOrLoaded',
    );
  }

  await waitUntil(
    tester,
    () =>
        find
            .byKey(const Key('today_recommendation_status_area'))
            .evaluate()
            .isNotEmpty ||
        _detectRecommendOutcome(tester) != null,
    timeout: const Duration(seconds: 45),
    label: 'recommendStartedOrFinished',
  );

  final sawLoading = find
      .byKey(const Key('today_recommendation_status_area'))
      .evaluate()
      .isNotEmpty;
  if (sawLoading) {
    debugPrint(
      '[E2E_RECOMMEND_STEP] step=recommendRunning success=true '
      'statusAreaVisible=true',
    );
  }

  final result = await _waitForRecommendOutcome(tester);
  debugPrint(
    '[E2E_RECOMMEND_STEP] step=waitResult success=true result=$result',
  );
  return result;
}

Future<void> _waitForRecommendationEntryReady(WidgetTester tester) async {
  await waitUntil(
    tester,
    () {
      final entry = find.byKey(const Key('today_recommendation_entry_button'));
      if (entry.evaluate().isEmpty) {
        return false;
      }
      try {
        final button = tester.widget<FilledButton>(entry);
        return button.onPressed != null;
      } catch (_) {
        return false;
      }
    },
    timeout: _entryReadyTimeout,
    label: 'recommendationEntryReady',
  );
}

Future<String> _waitForRecommendOutcome(WidgetTester tester) async {
  String? detected;
  final deadline = DateTime.now().add(_recommendResultTimeout);

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 300));
    _assertNoRedScreen(tester);

    detected = _detectRecommendOutcome(tester);
    if (detected != null) {
      final stillLoading = find
          .byKey(const Key('today_recommendation_status_area'))
          .evaluate()
          .isNotEmpty;
      if (!stillLoading) {
        await tester.pump(const Duration(milliseconds: 200));
        return detected;
      }
    }
  }

  fail(
    'waitUntil timed out: recommendOutcome (${_recommendResultTimeout.inSeconds}s)',
  );
}

String? _detectRecommendOutcome(WidgetTester tester) {
  if (find
      .byKey(const Key('today_recommendation_error_message'))
      .evaluate()
      .isNotEmpty) {
    return 'userVisibleError';
  }

  if (find
      .byKey(const Key('today_recommendation_empty_message'))
      .evaluate()
      .isNotEmpty) {
    if (find
        .textContaining('ジャンルを設定')
        .evaluate()
        .isNotEmpty) {
      return 'insufficientData';
    }
    return 'empty';
  }

  if (find
      .byKey(const Key('today_recommendation_result_area'))
      .evaluate()
      .isNotEmpty) {
    return 'success';
  }

  if (find
      .byKey(const Key('today_recommendation_skip_message'))
      .evaluate()
      .isNotEmpty) {
    return 'sameDaySkip';
  }

  if (find.textContaining('再生成できます').evaluate().isNotEmpty ||
      find.textContaining('まもなく再生成').evaluate().isNotEmpty) {
    return 'sameDaySkip';
  }

  return null;
}

void _assertNoRedScreen(WidgetTester tester) {
  expect(find.byType(ErrorWidget).evaluate().isEmpty, isTrue);
  expect(tester.takeException(), isNull);
}

Future<void> _dismissOnboardingIfNeeded(WidgetTester tester) async {
  for (var attempt = 0; attempt < 24; attempt++) {
    if (find.byKey(const Key('app_shell_nav_home')).evaluate().isNotEmpty) {
      return;
    }

    final legalTitle = find.text('はじめる前に');
    if (legalTitle.evaluate().isNotEmpty) {
      final checkbox = find.byType(CheckboxListTile);
      if (checkbox.evaluate().isNotEmpty) {
        await tester.tap(checkbox.first);
        await _pumpUiSettle(tester);
      }
      final agree = find.text('同意してはじめる');
      if (agree.evaluate().isNotEmpty) {
        await tester.tap(agree);
        await _pumpUiSettle(tester);
      }
      continue;
    }

    final skipWizard = find.text('スキップして次へ');
    if (skipWizard.evaluate().isNotEmpty) {
      await tester.tap(skipWizard.first);
      await _pumpUiSettle(tester);
      continue;
    }

    final skipLater = find.text('あとで設定する');
    if (skipLater.evaluate().isNotEmpty) {
      await tester.tap(skipLater.first);
      await _pumpUiSettle(tester);
      continue;
    }

    await tester.pump(const Duration(milliseconds: 400));
  }

  await waitUntil(
    tester,
    () => find.byKey(const Key('app_shell_nav_home')).evaluate().isNotEmpty,
    timeout: _appBootTimeout,
    label: 'appShellReady',
  );
}

Future<void> _pumpUiSettle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
  Duration step = const Duration(milliseconds: 250),
  required String label,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (condition()) {
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }
  }
  fail('waitUntil timed out: $label (${timeout.inSeconds}s)');
}
