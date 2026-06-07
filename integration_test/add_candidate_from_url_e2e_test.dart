import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:room_manager2/main.dart' as app;
import 'package:room_manager2/services/rakuten_item_page_url_item_code_service.dart';
import 'package:room_manager2/utils/rakuten_product_url_support.dart';

/// 単体テスト・実機確認で安定している URL（商品削除時はログで原因特定可能）。
const _normalItemUrl =
    'https://item.rakuten.co.jp/soukaidrink/4901085161999/?scid=wi_ich_ichibaapp_weburl_share';
const _slugItemUrl = 'https://item.rakuten.co.jp/oiwaizen/sanrio-001-s/';
final _affiliateItemUrl =
    'https://hb.afl.rakuten.co.jp/hgc/test/?pc=${Uri.encodeComponent('https://item.rakuten.co.jp/soukaidrink/4901085161999/?scid=share')}&link_type=pcpath';
const _unsupportedBooksUrl = 'https://books.rakuten.co.jp/rb/1234567890/';
const _unsupportedFashionUrl =
    'https://brandavenue.rakuten.co.jp/item/foo/';

const _appBootTimeout = Duration(seconds: 45);
const _urlJudgeTimeout = Duration(minutes: 3);
const _unsupportedJudgeTimeout = Duration(seconds: 15);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add_candidate_from_url_e2e', (tester) async {
    debugPrint('[E2E_URL_ADD_TEST_START]');

    app.main();
    await tester.pump();
    await _dismissOnboardingIfNeeded(tester);
    await _openUrlAddSheet(tester);

    await _runResolvableUrlScenario(
      tester,
      step: 'normalUrl',
      url: _normalItemUrl,
      expectedItemCode: 'soukaidrink:4901085161999',
    );

    await _runResolvableUrlScenario(
      tester,
      step: 'slugUrl',
      url: _slugItemUrl,
      expectedItemCode: 'oiwaizen:sanrio-001-s',
    );

    await _runResolvableUrlScenario(
      tester,
      step: 'affiliateUrl',
      url: _affiliateItemUrl,
      expectedItemCode: 'soukaidrink:4901085161999',
    );

    await _runUnsupportedUrlScenario(
      tester,
      step: 'unsupportedBooks',
      url: _unsupportedBooksUrl,
    );

    await _runUnsupportedUrlScenario(
      tester,
      step: 'unsupportedFashion',
      url: _unsupportedFashionUrl,
    );

    _assertNoRedScreen(tester);
    debugPrint('[E2E_URL_ADD_TEST_RESULT] success=true');
  });
}

Future<void> _openUrlAddSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('app_shell_nav_search')));
  await _pumpUiSettle(tester);

  await waitUntil(
    tester,
    () => find.byKey(const Key('add_candidate_sheet')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 15),
    label: 'addCandidateSheet',
  );

  await tester.tap(find.byKey(const Key('add_candidate_from_url')));
  await _pumpUiSettle(tester);

  await waitUntil(
    tester,
    () =>
        find.byKey(const Key('add_candidate_url_field')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 20),
    label: 'urlAddBottomSheet',
  );
}

Future<void> _runResolvableUrlScenario(
  WidgetTester tester, {
  required String step,
  required String url,
  required String expectedItemCode,
}) async {
  try {
    await _enterUrlAndJudge(tester, url: url, timeout: _urlJudgeTimeout);
    _assertNoRedScreen(tester);

    final couldNotConfirm = find.text(
      RakutenItemPageUrlItemCodeService.messageCouldNotConfirmProductUrl,
    );
    expect(
      couldNotConfirm.evaluate().isEmpty,
      isTrue,
      reason: '$step: 商品URLを確認できませんでした が表示されないこと url=$url',
    );

    await waitUntil(
      tester,
      () => find.byKey(const Key('add_candidate_url_result_area')).evaluate().isNotEmpty,
      timeout: _urlJudgeTimeout,
      label: '$step resultArea',
    );

    expect(
      find.textContaining(expectedItemCode).evaluate().isNotEmpty,
      isTrue,
      reason: '$step: itemCode=$expectedItemCode が表示されること url=$url',
    );

    final hasOutcome = _hasResolvableOutcome(tester);
    expect(
      hasOutcome,
      isTrue,
      reason: '$step: 判定結果または登録/候補状態が表示されること url=$url',
    );

    debugPrint('[E2E_URL_ADD_STEP] step=$step success=true url=$url');
  } catch (e, st) {
    debugPrint('[E2E_URL_ADD_STEP] step=$step success=false url=$url error=$e');
    debugPrint('[E2E_URL_ADD_STEP] step=$step stack=$st');
    rethrow;
  }
}

Future<void> _runUnsupportedUrlScenario(
  WidgetTester tester, {
  required String step,
  required String url,
}) async {
  try {
    await _enterUrlAndJudge(
      tester,
      url: url,
      timeout: _unsupportedJudgeTimeout,
    );
    _assertNoRedScreen(tester);

    await waitUntil(
      tester,
      () =>
          find
              .byKey(const Key('add_candidate_url_unsupported_message'))
              .evaluate()
              .isNotEmpty ||
          find
              .textContaining(
                RakutenProductUrlSupport.messageUnsupportedRakutenServiceUrl,
              )
              .evaluate()
              .isNotEmpty,
      timeout: _unsupportedJudgeTimeout,
      label: '$step unsupportedMessage',
    );

    expect(
      find.byKey(const Key('add_candidate_url_result_area')).evaluate().isEmpty,
      isTrue,
      reason: '$step: 対象外URLで判定結果カードが出ないこと url=$url',
    );

    debugPrint('[E2E_URL_ADD_STEP] step=$step success=true url=$url');
  } catch (e, st) {
    debugPrint('[E2E_URL_ADD_STEP] step=$step success=false url=$url error=$e');
    debugPrint('[E2E_URL_ADD_STEP] step=$step stack=$st');
    rethrow;
  }
}

Future<void> _enterUrlAndJudge(
  WidgetTester tester, {
  required String url,
  required Duration timeout,
}) async {
  final field = find.byKey(const Key('add_candidate_url_field'));
  expect(field, findsOneWidget);

  await tester.tap(field);
  await tester.enterText(field, url);
  await tester.pump();

  await tester.tap(find.byKey(const Key('add_candidate_url_judge_button')));
  await tester.pump();

  await waitUntil(
    tester,
    () {
      final hasResult =
          find.byKey(const Key('add_candidate_url_result_area')).evaluate().isNotEmpty;
      final hasUnsupported =
          find
              .byKey(const Key('add_candidate_url_unsupported_message'))
              .evaluate()
              .isNotEmpty;
      final hasCouldNotConfirm = find
          .text(RakutenItemPageUrlItemCodeService.messageCouldNotConfirmProductUrl)
          .evaluate()
          .isNotEmpty;
      return hasResult || hasUnsupported || hasCouldNotConfirm;
    },
    timeout: timeout,
    label: 'urlJudge url=$url',
  );
}

bool _hasResolvableOutcome(WidgetTester tester) {
  final stateLabels = ['コレ済み', 'コレ候補', '未登録'];
  final actionLabels = ['コレ候補に追加', '候補を見る', 'コレ済一覧で見る'];

  final hasStateChip = stateLabels.any(
    (label) => find.text(label).evaluate().isNotEmpty,
  );
  final hasAction = actionLabels.any(
    (label) => find.text(label).evaluate().isNotEmpty,
  );
  final hasRegisterKey =
      find.byKey(const Key('add_candidate_url_register_button')).evaluate().isNotEmpty;

  return hasStateChip || hasAction || hasRegisterKey;
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
