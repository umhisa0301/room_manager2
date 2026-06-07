import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:room_manager2/main.dart' as app;

const _appBootTimeout = Duration(seconds: 45);
const _importResultTimeout = Duration(minutes: 5);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('room_import_e2e', (tester) async {
    debugPrint('[E2E_ROOM_IMPORT_TEST_START]');

    app.main();
    await tester.pump();
    await _dismissOnboardingIfNeeded(tester);

    await _openHomeTab(tester);
    final result = await _runRoomImportFlow(tester);

    _assertNoRedScreen(tester);
    debugPrint(
      '[E2E_ROOM_IMPORT_TEST_RESULT] success=true result=$result',
    );
  });
}

Future<void> _openHomeTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('app_shell_nav_home')));
  await _pumpUiSettle(tester);

  final success =
      find.text('ROOMコレ管理').evaluate().isNotEmpty ||
      find.text('ROOMデータ更新').evaluate().isNotEmpty;
  debugPrint('[E2E_ROOM_IMPORT_STEP] step=openHomeTab success=$success');
  expect(success, isTrue, reason: 'ホーム（ROOMコレ管理）画面の表示確認');
}

Future<String> _runRoomImportFlow(WidgetTester tester) async {
  final notConfigured = find.byKey(
    const Key('room_import_not_configured_message'),
  );
  if (notConfigured.evaluate().isNotEmpty) {
    debugPrint(
      '[E2E_ROOM_IMPORT_STEP] step=openImportEntry success=true '
      'mode=notConfigured',
    );
    debugPrint(
      '[E2E_ROOM_IMPORT_STEP] step=waitResult success=true '
      'result=notConfigured',
    );
    return 'notConfigured';
  }

  final entry = find.byKey(const Key('room_import_entry_button'));
  expect(
    entry,
    findsOneWidget,
    reason: 'ROOM取り込み入口ボタンが表示されること',
  );
  debugPrint('[E2E_ROOM_IMPORT_STEP] step=openImportEntry success=true');

  await tester.tap(entry);
  await _pumpUiSettle(tester);

  await waitUntil(
    tester,
    () => find.byKey(const Key('room_import_confirm_dialog')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 15),
    label: 'importConfirmDialog',
  );

  final startButton = find.byKey(const Key('room_import_start_button'));
  expect(startButton, findsOneWidget);
  await tester.tap(startButton);
  await tester.pump();
  debugPrint('[E2E_ROOM_IMPORT_STEP] step=startImport success=true');

  await waitUntil(
    tester,
    () =>
        find.byKey(const Key('room_import_status_area')).evaluate().isNotEmpty ||
        _detectImportOutcome(tester) != null,
    timeout: const Duration(seconds: 45),
    label: 'importStartedOrFinished',
  );

  final sawBusy =
      find.byKey(const Key('room_import_status_area')).evaluate().isNotEmpty;
  if (sawBusy) {
    debugPrint(
      '[E2E_ROOM_IMPORT_STEP] step=importRunning success=true '
      'statusAreaVisible=true',
    );
  }

  final result = await _waitForImportOutcome(tester);
  debugPrint(
    '[E2E_ROOM_IMPORT_STEP] step=waitResult success=true result=$result',
  );

  await _dismissResultUiIfPresent(tester);
  return result;
}

Future<String> _waitForImportOutcome(WidgetTester tester) async {
  String? detected;
  final deadline = DateTime.now().add(_importResultTimeout);

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 300));
    _assertNoRedScreen(tester);

    detected = _detectImportOutcome(tester);
    if (detected != null) {
      await tester.pump(const Duration(milliseconds: 200));
      return detected;
    }
  }

  fail(
    'waitUntil timed out: importOutcome (${_importResultTimeout.inSeconds}s)',
  );
}

String? _detectImportOutcome(WidgetTester tester) {
  if (find.byKey(const Key('room_import_error_message')).evaluate().isNotEmpty) {
    return 'userVisibleError';
  }

  if (find.byKey(const Key('room_import_result_area')).evaluate().isNotEmpty) {
    if (find.textContaining('件追加しました').evaluate().isNotEmpty ||
        find.textContaining('件を取り込みました').evaluate().isNotEmpty) {
      return 'success';
    }
    if (find.text('新しい投稿は見つかりませんでした').evaluate().isNotEmpty ||
        find.text('追加はありませんでした').evaluate().isNotEmpty) {
      return 'empty';
    }
    if (find.text('追加できませんでした').evaluate().isNotEmpty) {
      return 'userVisibleError';
    }
    return 'skip';
  }

  final snackbarTexts = [
    '件を取り込みました',
    'ROOM投稿の確認が終わりました（追加なし）',
    'ROOMページを',
    '紐付けました',
    '古い投稿に未取り込みが残っている可能性',
  ];
  for (final fragment in snackbarTexts) {
    if (find.textContaining(fragment).evaluate().isNotEmpty) {
      if (fragment.contains('追加なし')) {
        return 'empty';
      }
      return 'success';
    }
  }

  if (find.text('ROOM同期').evaluate().isNotEmpty &&
      find.byKey(const Key('room_import_error_message')).evaluate().isEmpty) {
    final dialogBody = find.byType(AlertDialog);
    if (dialogBody.evaluate().isNotEmpty) {
      return 'userVisibleError';
    }
  }

  return null;
}

Future<void> _dismissResultUiIfPresent(WidgetTester tester) async {
  final closeButtons = find.text('閉じる');
  if (closeButtons.evaluate().isNotEmpty) {
    await tester.tap(closeButtons.first);
    await _pumpUiSettle(tester);
  }

  if (find.byKey(const Key('room_import_result_area')).evaluate().isNotEmpty) {
    await tester.pageBack();
    await _pumpUiSettle(tester);
  }
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
