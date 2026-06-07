import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../config/dev_automation_config.dart';
import '../models/rakuten_product_search_condition.dart';
import '../navigation/app_shell_controller.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/rakuten_search_provider.dart';
import '../state/saved_shop_provider.dart';
import '../utils/dev_automation_log_buffer.dart';

/// 主要タブ巡回 + 通常商品検索シナリオの識別子。
abstract final class DevAutomationScenario {
  static const String tabTourProductSearch = 'tabTourProductSearch';
}

/// シナリオ内の個別ステップ。
enum DevAutomationStep {
  managedTab,
  analyticsTab,
  myPageTab,
  returnToHome,
  productSearch,
}

/// ランナーが利用する外部依存（テスト時に差し替え可能）。
class DevAutomationDependencies {
  const DevAutomationDependencies({
    required this.appShell,
    required this.searchProvider,
    required this.managedProductProvider,
    required this.savedShopProvider,
    this.delay = _defaultDelay,
    this.waitForFrame = _defaultWaitForFrame,
  });

  final AppShellController appShell;
  final RakutenSearchProvider searchProvider;
  final RakutenManagedProductProvider managedProductProvider;
  final SavedShopProvider savedShopProvider;
  final Future<void> Function(Duration duration) delay;
  final Future<void> Function() waitForFrame;

  static Future<void> _defaultDelay(Duration duration) =>
      Future<void>.delayed(duration);

  static Future<void> _defaultWaitForFrame() async {
    await SchedulerBinding.instance.endOfFrame;
  }

  factory DevAutomationDependencies.fromContext(BuildContext context) {
    return DevAutomationDependencies(
      appShell: context.read<AppShellController>(),
      searchProvider: context.read<RakutenSearchProvider>(),
      managedProductProvider: context.read<RakutenManagedProductProvider>(),
      savedShopProvider: context.read<SavedShopProvider>(),
    );
  }
}

/// 実行回数の検証結果。
class DevAutomationIterationValidation {
  const DevAutomationIterationValidation.valid(this.value)
      : errorMessage = null;

  const DevAutomationIterationValidation.invalid(this.errorMessage)
      : value = null;

  final int? value;
  final String? errorMessage;

  bool get isValid => value != null;
}

/// 開発者向け自動検証の実行エンジン。
class DevAutomationRunner extends ChangeNotifier {
  DevAutomationRunner({
    required DevAutomationDependencies dependencies,
    DevAutomationLogBuffer? logBuffer,
  }) : _deps = dependencies,
       _logBuffer = logBuffer ?? DevAutomationLogBuffer();

  static const int defaultIterations = 3;
  static const int minIterations = 1;
  static const int maxIterations = 20;
  static const String defaultProductSearchKeyword = '水筒';

  static const Duration _stepPostFrameWait = Duration(milliseconds: 200);
  static const Duration _betweenIterationsWait = Duration(milliseconds: 400);

  final DevAutomationDependencies _deps;
  final DevAutomationLogBuffer _logBuffer;

  bool _isRunning = false;
  bool _stopRequested = false;
  int _successCount = 0;
  int _failureCount = 0;

  DevAutomationLogBuffer get logBuffer => _logBuffer;
  bool get isRunning => _isRunning;
  bool get stopRequested => _stopRequested;
  int get successCount => _successCount;
  int get failureCount => _failureCount;

  /// 実行回数を検証する（UI・テスト共用）。
  static DevAutomationIterationValidation validateIterations(int? raw) {
    if (raw == null) {
      return const DevAutomationIterationValidation.invalid('実行回数を入力してください');
    }
    if (raw < minIterations || raw > maxIterations) {
      return DevAutomationIterationValidation.invalid(
        '実行回数は $minIterations〜$maxIterations の範囲で指定してください',
      );
    }
    return DevAutomationIterationValidation.valid(raw);
  }

  void requestStop() {
    if (!_isRunning || _stopRequested) return;
    _stopRequested = true;
    _log(
      '[DEV_AUTOMATION_RUN_STOP] scenario=${DevAutomationScenario.tabTourProductSearch} '
      'requested=true',
    );
    notifyListeners();
  }

  /// 主要タブ巡回 + 通常商品検索を [iterations] 回反復実行する。
  Future<void> runTabTourProductSearch({
    required int iterations,
    String keyword = defaultProductSearchKeyword,
  }) async {
    ensureDevAutomationAvailable();
    if (_isRunning) return;

    _isRunning = true;
    _stopRequested = false;
    _successCount = 0;
    _failureCount = 0;
    notifyListeners();

    _log(
      '[DEV_AUTOMATION_RUN_START] scenario=${DevAutomationScenario.tabTourProductSearch} '
      'keyword=$keyword iterations=$iterations',
    );

    try {
      for (var i = 1; i <= iterations; i++) {
        if (_stopRequested) break;

        final iterationOk = await _runSingleIteration(
          iteration: i,
          keyword: keyword,
        );
        if (iterationOk) {
          _successCount++;
        } else {
          _failureCount++;
        }
        notifyListeners();

        if (_stopRequested) break;
        if (i < iterations) {
          await _deps.delay(_betweenIterationsWait);
        }
      }
    } finally {
      _isRunning = false;
      _log(
        '[DEV_AUTOMATION_RUN_END] scenario=${DevAutomationScenario.tabTourProductSearch} '
        'successCount=$_successCount failureCount=$_failureCount '
        'stopped=$_stopRequested',
      );
      notifyListeners();
    }
  }

  Future<bool> _runSingleIteration({
    required int iteration,
    required String keyword,
  }) async {
    final steps = <DevAutomationStep>[
      DevAutomationStep.managedTab,
      DevAutomationStep.analyticsTab,
      DevAutomationStep.myPageTab,
      DevAutomationStep.returnToHome,
      DevAutomationStep.productSearch,
    ];

    for (final step in steps) {
      if (_stopRequested) return false;

      _log(
        '[DEV_AUTOMATION_STEP_START] '
        'scenario=${DevAutomationScenario.tabTourProductSearch} '
        'iteration=$iteration step=${step.name}',
      );

      final result = await _runStep(
        step: step,
        iteration: iteration,
        keyword: keyword,
      );

      _logStepResult(
        iteration: iteration,
        step: step,
        success: result.success,
        displayCount: result.displayCount,
        durationMs: result.durationMs,
        error: result.error,
      );

      if (!result.success) return false;
    }
    return true;
  }

  Future<_StepResult> _runStep({
    required DevAutomationStep step,
    required int iteration,
    required String keyword,
  }) async {
    try {
      switch (step) {
        case DevAutomationStep.managedTab:
          _deps.appShell.selectTab(1);
          await _waitAfterTabSwitch(expectedIndex: 1);
          return const _StepResult(success: true);
        case DevAutomationStep.analyticsTab:
          _deps.appShell.selectTab(3);
          await _waitAfterTabSwitch(expectedIndex: 3);
          return const _StepResult(success: true);
        case DevAutomationStep.myPageTab:
          _deps.appShell.selectTab(4);
          await _waitAfterTabSwitch(expectedIndex: 4);
          return const _StepResult(success: true);
        case DevAutomationStep.returnToHome:
          _deps.appShell.selectTab(0);
          await _waitAfterTabSwitch(expectedIndex: 0);
          return const _StepResult(success: true);
        case DevAutomationStep.productSearch:
          return _executeProductSearch(keyword);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[DEV_AUTOMATION_STEP_ERROR] scenario=${DevAutomationScenario.tabTourProductSearch} '
          'iteration=$iteration step=${step.name} error=$e\n$st',
        );
      }
      return _StepResult(success: false, error: e);
    }
  }

  Future<void> _waitAfterTabSwitch({required int expectedIndex}) async {
    await _deps.waitForFrame();
    await _deps.delay(_stepPostFrameWait);
    if (_deps.appShell.currentIndex != expectedIndex) {
      throw StateError(
        'Tab index mismatch: expected=$expectedIndex actual=${_deps.appShell.currentIndex}',
      );
    }
  }

  /// [RakutenSearchScreen._runSearch] の通常商品検索経路に合わせる。
  Future<_StepResult> _executeProductSearch(String keyword) async {
    final stopwatch = Stopwatch()..start();
    final condition = RakutenProductSearchCondition(
      keyword: keyword,
    ).normalized();
    if (condition.keyword.isEmpty) {
      return _StepResult(
        success: false,
        durationMs: stopwatch.elapsedMilliseconds,
        error: StateError('keyword is empty after normalization'),
      );
    }

    final managedProv = _deps.managedProductProvider;
    final excludeIds = managedProv.productIdsExcludedFromKeywordSearch();
    final excludeCandidateIds = managedProv
        .candidateProductIdsExcludedFromKeywordSearch();
    final excludeDoneIds = managedProv
        .doneProductIdsExcludedFromKeywordSearch();
    final savedShopCodes = _deps.savedShopProvider.shops
        .map((e) => e.shopId.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    const modeTag = 'product';
    final searchProv = _deps.searchProvider;
    final sessionId = searchProv.beginSearchSession(modeTag: modeTag);
    searchProv.clearErrorForNewSearch(modeTag: modeTag, requestId: sessionId);

    await searchProv.searchWithCondition(
      condition,
      excludeRegisteredProductIds: excludeIds,
      excludeCandidateProductIds: excludeCandidateIds,
      excludeDoneProductIds: excludeDoneIds,
      excludeSavedShopCodes: savedShopCodes,
      sessionId: sessionId,
      modeTag: modeTag,
    );

    final displayCount = _resolveDisplayCount(searchProv);
    final success =
        searchProv.status == RakutenSearchStatus.success && displayCount > 0;

    return _StepResult(
      success: success,
      displayCount: displayCount,
      durationMs: stopwatch.elapsedMilliseconds,
      error: success
          ? null
          : StateError(
              'search failed: status=${searchProv.status.name} '
              'displayCount=$displayCount message=${searchProv.errorMessage}',
            ),
    );
  }

  int _resolveDisplayCount(RakutenSearchProvider searchProv) {
    final summary = searchProv.keywordManagedFetchSummary;
    if (summary != null && summary.displayCount > 0) {
      return summary.displayCount;
    }
    return searchProv.results.length;
  }

  void _logStepResult({
    required int iteration,
    required DevAutomationStep step,
    required bool success,
    int? displayCount,
    int? durationMs,
    Object? error,
  }) {
    final buffer = StringBuffer()
      ..write(
        '[DEV_AUTOMATION_STEP_RESULT] '
        'scenario=${DevAutomationScenario.tabTourProductSearch} ',
      )
      ..write('iteration=$iteration step=${step.name} success=$success');
    if (displayCount != null) {
      buffer.write(' displayCount=$displayCount');
    }
    if (durationMs != null) {
      buffer.write(' durationMs=$durationMs');
    }
    if (error != null) {
      buffer.write(' error=$error');
    }
    _log(buffer.toString());
  }

  void _log(String message) {
    _logBuffer.add(message);
  }
}

class _StepResult {
  const _StepResult({
    required this.success,
    this.displayCount,
    this.durationMs,
    this.error,
  });

  final bool success;
  final int? displayCount;
  final int? durationMs;
  final Object? error;
}
