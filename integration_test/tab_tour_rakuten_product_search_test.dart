import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:room_manager2/main.dart' as app;
import 'package:room_manager2/widgets/rakuten_search_result_card.dart';

const _keyword = '水筒';
const _appBootTimeout = Duration(seconds: 45);
const _searchResultTimeout = Duration(minutes: 3);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tab_tour_rakuten_product_search_e2e', (tester) async {
    debugPrint('[E2E_TAB_TOUR_SEARCH_TEST_START] keyword=$_keyword');

    app.main();
    await tester.pump();
    await _dismissOnboardingIfNeeded(tester);

    await _tapNavAndVerify(
      tester,
      key: const Key('app_shell_nav_managed'),
      step: 'managedTab',
      verify: () => find.textContaining('コレ候補').evaluate().isNotEmpty,
    );
    await _takeStepScreenshot(binding, '01_managed_tab');

    await _tapNavAndVerify(
      tester,
      key: const Key('app_shell_nav_analytics'),
      step: 'analyticsTab',
      verify: () => find.text('分析').evaluate().isNotEmpty,
    );
    await _takeStepScreenshot(binding, '02_analytics_tab');

    await _tapNavAndVerify(
      tester,
      key: const Key('app_shell_nav_mypage'),
      step: 'myPageTab',
      verify: () => find.text('マイページ').evaluate().isNotEmpty,
    );
    await _takeStepScreenshot(binding, '03_mypage_tab');

    await _tapNavAndVerify(
      tester,
      key: const Key('app_shell_nav_home'),
      step: 'homeTab',
      verify: () => find.text('ROOMコレ管理').evaluate().isNotEmpty,
    );

    await _tapNavAndVerify(
      tester,
      key: const Key('app_shell_nav_search'),
      step: 'searchSheet',
      verify: () =>
          find.byKey(const Key('add_candidate_sheet')).evaluate().isNotEmpty,
    );
    await _takeStepScreenshot(binding, '04_search_sheet');

    await tester.tap(find.byKey(const Key('add_candidate_rakuten_product')));
    await waitUntil(
      tester,
      () =>
          find
              .byKey(const Key('product_search_keyword_entry'))
              .evaluate()
              .isNotEmpty,
      timeout: const Duration(seconds: 15),
      label: 'rakutenSearchScreen',
    );
    debugPrint('[E2E_TAB_TOUR_STEP] step=rakutenProductSearch success=true');
    await _takeStepScreenshot(binding, '05_rakuten_search_screen');

    await tester.tap(find.byKey(const Key('product_search_keyword_entry')));
    await _pumpUiSettle(tester);
    expect(find.byKey(const Key('product_search_keyword_field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('product_search_keyword_field')));
    await tester.enterText(
      find.byKey(const Key('product_search_keyword_field')),
      _keyword,
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('product_search_detail_submit')));
    await tester.pump();

    await _waitForSearchResults(tester);

    final resultList = find.byKey(const Key('product_search_result_list'));
    final resultItem = find.byKey(const Key('product_search_result_item'));
    final resultCards = find.byType(RakutenSearchResultCard);
    final resultCount = resultItem.evaluate().isNotEmpty
        ? resultItem.evaluate().length
        : resultCards.evaluate().length;

    expect(
      resultList.evaluate().isNotEmpty ||
          resultItem.evaluate().isNotEmpty ||
          resultCards.evaluate().isNotEmpty,
      isTrue,
      reason: '検索結果が1件以上表示されること',
    );
    expect(resultCount, greaterThanOrEqualTo(1));

    await _takeStepScreenshot(binding, '06_search_results');
    debugPrint(
      '[E2E_TAB_TOUR_SEARCH_TEST_RESULT] success=true resultCount=$resultCount',
    );
  });
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

Future<void> _tapNavAndVerify(
  WidgetTester tester, {
  required Key key,
  required String step,
  required bool Function() verify,
}) async {
  await tester.tap(find.byKey(key));
  await _pumpUiSettle(tester);
  final success = verify();
  debugPrint('[E2E_TAB_TOUR_STEP] step=$step success=$success');
  expect(success, isTrue, reason: '$step の画面確認に失敗しました');
}

Future<void> _pumpUiSettle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _waitForSearchResults(WidgetTester tester) async {
  await waitUntil(
    tester,
    () {
      final loading = find.text('商品を探しています');
      final hasResults =
          find.byKey(const Key('product_search_result_list')).evaluate().isNotEmpty ||
          find.byKey(const Key('product_search_result_item')).evaluate().isNotEmpty ||
          find.byType(RakutenSearchResultCard).evaluate().isNotEmpty;
      final hasError = find.text('検索結果を表示できませんでした').evaluate().isNotEmpty;
      return hasResults || (loading.evaluate().isEmpty && hasError);
    },
    timeout: _searchResultTimeout,
    label: 'searchResults',
  );

  if (find.text('検索結果を表示できませんでした').evaluate().isNotEmpty) {
    fail('楽天商品検索がエラー画面で終了しました');
  }
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

Future<void> _takeStepScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  try {
    await binding
        .convertFlutterSurfaceToImage()
        .timeout(const Duration(seconds: 5));
    await binding.takeScreenshot(name).timeout(const Duration(seconds: 8));
  } on TimeoutException {
    debugPrint('[E2E_SCREENSHOT_SKIP] name=$name reason=timeout');
  } catch (e) {
    debugPrint('[E2E_SCREENSHOT_SKIP] name=$name error=$e');
  }
}
