import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../config/dev_automation_config.dart';
import '../models/rakuten_managed_product.dart';
import '../models/rakuten_product_search_condition.dart';
import '../models/room_reaction_sync_batch_result.dart';
import '../models/room_sync_result.dart';
import '../models/today_recommendation.dart';
import '../navigation/app_shell_controller.dart';
import '../services/room_profile_url_validation_service.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/rakuten_search_provider.dart';
import '../state/room_import_controller.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../state/user_profile_provider.dart';
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
  addCandidateFromSearch,
  openRecommendation,
  addCandidateFromRecommendation,
  roomImport,
  reactionCheck,
}

/// コレ候補追加ステップの outcome ラベル（ログ・テスト用）。
abstract final class DevAutomationCandidateAddResult {
  static const String added = 'added';
  static const String alreadyCandidate = 'alreadyCandidate';
  static const String alreadyManaged = 'alreadyManaged';
  static const String skippedDuplicate = 'skippedDuplicate';
  static const String userVisibleError = 'userVisibleError';
}

/// ランナーが利用する外部依存（テスト時に差し替え可能）。
class DevAutomationDependencies {
  const DevAutomationDependencies({
    required this.appShell,
    required this.searchProvider,
    required this.managedProductProvider,
    required this.savedShopProvider,
    this.todayRecommendationProvider,
    this.userProfileProvider,
    this.roomImportController,
    this.context,
    this.delay = _defaultDelay,
    this.waitForFrame = _defaultWaitForFrame,
  });

  final AppShellController appShell;
  final RakutenSearchProvider searchProvider;
  final RakutenManagedProductProvider managedProductProvider;
  final SavedShopProvider savedShopProvider;
  final TodayRecommendationProvider? todayRecommendationProvider;
  final UserProfileProvider? userProfileProvider;
  final RoomImportController? roomImportController;
  final BuildContext? context;
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
      todayRecommendationProvider: context.read<TodayRecommendationProvider>(),
      userProfileProvider: context.read<UserProfileProvider>(),
      roomImportController: context.read<RoomImportController>(),
      context: context,
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

  /// コレ候補追加の outcome を分類する（UI 経路と同じ判定基準）。
  static String classifyCandidateAddOutcome({
    required RakutenManagedProductStatus before,
    required RakutenManagedProductStatus after,
    required String? error,
  }) {
    if (error != null && error.trim().isNotEmpty) {
      return DevAutomationCandidateAddResult.userVisibleError;
    }
    if (before == RakutenManagedProductStatus.done) {
      return DevAutomationCandidateAddResult.alreadyManaged;
    }
    if (before == RakutenManagedProductStatus.candidate) {
      return DevAutomationCandidateAddResult.alreadyCandidate;
    }
    if (after == RakutenManagedProductStatus.candidate) {
      return DevAutomationCandidateAddResult.added;
    }
    return DevAutomationCandidateAddResult.skippedDuplicate;
  }

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
      DevAutomationStep.addCandidateFromSearch,
      DevAutomationStep.openRecommendation,
      DevAutomationStep.addCandidateFromRecommendation,
      DevAutomationStep.roomImport,
      DevAutomationStep.reactionCheck,
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
        result: result.result,
        added: result.added,
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
        case DevAutomationStep.addCandidateFromSearch:
          return _executeAddCandidateFromSearch();
        case DevAutomationStep.openRecommendation:
          return _executeOpenRecommendation();
        case DevAutomationStep.addCandidateFromRecommendation:
          return _executeAddCandidateFromRecommendation();
        case DevAutomationStep.roomImport:
          return _executeRoomImport();
        case DevAutomationStep.reactionCheck:
          return _executeReactionCheck();
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

  Future<_StepResult> _executeAddCandidateFromSearch() async {
    final stopwatch = Stopwatch()..start();
    final results = _deps.searchProvider.results;
    if (results.isEmpty) {
      return _StepResult(
        success: false,
        durationMs: stopwatch.elapsedMilliseconds,
        error: StateError('no search results to add'),
      );
    }

    final managed = _deps.managedProductProvider;
    var target = results.first;
    for (final item in results) {
      if (managed.statusForProduct(item.productId) ==
          RakutenManagedProductStatus.none) {
        target = item;
        break;
      }
    }

    final before = managed.statusForProduct(target.productId);
    final err = await managed.registerCandidate(target);
    final after = managed.statusForProduct(target.productId);
    final outcome = classifyCandidateAddOutcome(
      before: before,
      after: after,
      error: err,
    );

    return _StepResult(
      success: true,
      result: outcome,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<_StepResult> _executeOpenRecommendation() async {
    final stopwatch = Stopwatch()..start();
    final recommender = _deps.todayRecommendationProvider;
    if (recommender == null) {
      return _StepResult(
        success: true,
        result: 'skippedNotImplemented',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    _deps.appShell.selectTab(0);
    await _waitAfterTabSwitch(expectedIndex: 0);

    final profileProvider = _deps.userProfileProvider;
    if (profileProvider == null) {
      return _StepResult(
        success: true,
        result: 'insufficientData',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    final todayKey = _localDateKey(DateTime.now());
    final beforeBundle = recommender.bundle;
    final sameDayBefore =
        beforeBundle != null && beforeBundle.localDateKey == todayKey;

    await recommender.ensureToday(
      profile: profileProvider.profile,
      managedItems: _deps.managedProductProvider.items,
      savedShops: _deps.savedShopProvider.shops,
      trigger: 'devAutomation',
    );

    if (sameDayBefore) {
      return _StepResult(
        success: true,
        result: 'sameDaySkip',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    final bundle = recommender.bundle;
    if (bundle != null && bundle.entries.isNotEmpty) {
      return _StepResult(
        success: true,
        result: 'success',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    if (recommender.errorMessage != null &&
        recommender.errorMessage!.trim().isNotEmpty) {
      return _StepResult(
        success: true,
        result: 'insufficientData',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    return _StepResult(
      success: true,
      result: 'insufficientData',
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<_StepResult> _executeAddCandidateFromRecommendation() async {
    final stopwatch = Stopwatch()..start();
    final recommender = _deps.todayRecommendationProvider;
    if (recommender == null) {
      return _StepResult(
        success: true,
        result: 'skippedNotImplemented',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    final bundle = recommender.bundle;
    if (bundle == null || bundle.entries.isEmpty) {
      return _StepResult(
        success: true,
        result: 'insufficientData',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    TodayRecommendationEntry? target;
    for (final entry in bundle.entries) {
      if (entry.decision == TodayRecommendationDecision.pending) {
        target = entry;
        break;
      }
    }
    target ??= bundle.entries.first;

    final managed = _deps.managedProductProvider;
    final before = managed.statusForProduct(target.item.productId);
    final err = await recommender.markAddedCandidate(
      managedProvider: managed,
      item: target.item,
    );
    final after = managed.statusForProduct(target.item.productId);
    final outcome = classifyCandidateAddOutcome(
      before: before,
      after: after,
      error: err,
    );

    return _StepResult(
      success: true,
      result: outcome,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<_StepResult> _executeRoomImport() async {
    final stopwatch = Stopwatch()..start();
    final controller = _deps.roomImportController;
    final context = _deps.context;
    if (controller == null || context == null) {
      return _StepResult(
        success: true,
        result: 'skippedNotImplemented',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    _deps.appShell.selectTab(4);
    await _waitAfterTabSwitch(expectedIndex: 4);

    final profileUrl = _normalizedRoomProfileUrl();
    if (profileUrl.isEmpty) {
      return _StepResult(
        success: true,
        result: 'notConfigured',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    if (!context.mounted) {
      return _StepResult(
        success: true,
        result: 'skip',
        added: 0,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    final result = await controller.runImport(context);
    return _classifyRoomImportResult(
      result: result,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<_StepResult> _executeReactionCheck() async {
    final stopwatch = Stopwatch()..start();
    final controller = _deps.roomImportController;
    final context = _deps.context;
    if (controller == null || context == null) {
      return _StepResult(
        success: true,
        result: 'skippedNotImplemented',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    final profileUrl = _normalizedRoomProfileUrl();
    if (profileUrl.isEmpty) {
      return _StepResult(
        success: true,
        result: 'insufficientData',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    final importedDoneCount = _deps.managedProductProvider.items
        .where((e) => e.status == RakutenManagedProductStatus.done)
        .length;
    if (importedDoneCount == 0) {
      return _StepResult(
        success: true,
        result: 'insufficientData',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    if (!context.mounted) {
      return _StepResult(
        success: true,
        result: 'userVisibleError',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    final out = await controller.runReactionSync(context);
    return _classifyReactionCheckResult(
      result: out,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  _StepResult _classifyRoomImportResult({
    required RoomSyncResult? result,
    required int durationMs,
  }) {
    if (result == null) {
      return _StepResult(
        success: true,
        result: 'skip',
        added: 0,
        durationMs: durationMs,
      );
    }
    if (result.hasFatalError) {
      return _StepResult(
        success: true,
        result: 'userVisibleError',
        added: result.newlyCollectedCount,
        durationMs: durationMs,
      );
    }
    if (result.newlyCollectedCount > 0) {
      return _StepResult(
        success: true,
        result: 'added',
        added: result.newlyCollectedCount,
        durationMs: durationMs,
      );
    }
    if (result.skippedCount > 0 && result.processedCount > 0) {
      return _StepResult(
        success: true,
        result: 'skip',
        added: 0,
        durationMs: durationMs,
      );
    }
    return _StepResult(
      success: true,
      result: 'empty',
      added: 0,
      durationMs: durationMs,
    );
  }

  _StepResult _classifyReactionCheckResult({
    required RoomReactionSyncBatchResult? result,
    required int durationMs,
  }) {
    if (result == null) {
      return _StepResult(
        success: true,
        result: 'userVisibleError',
        durationMs: durationMs,
      );
    }
    if (result.hasFatalError) {
      return _StepResult(
        success: true,
        result: 'userVisibleError',
        durationMs: durationMs,
      );
    }
    if (result.updated > 0) {
      return _StepResult(
        success: true,
        result: 'success',
        durationMs: durationMs,
      );
    }
    if (result.itemsChecked > 0) {
      return _StepResult(
        success: true,
        result: 'noNewReaction',
        durationMs: durationMs,
      );
    }
    return _StepResult(
      success: true,
      result: 'alreadyChecked',
      durationMs: durationMs,
    );
  }

  String _normalizedRoomProfileUrl() {
    final profile = _deps.userProfileProvider?.profile.roomUrl ?? '';
    return RoomProfileUrlValidationService.normalizeProfileUrl(profile);
  }

  String _localDateKey(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}';
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
    String? result,
    int? added,
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
    if (result != null) {
      buffer.write(' result=$result');
    }
    if (added != null) {
      buffer.write(' added=$added');
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
    this.result,
    this.added,
    this.durationMs,
    this.error,
  });

  final bool success;
  final int? displayCount;
  final String? result;
  final int? added;
  final int? durationMs;
  final Object? error;
}
