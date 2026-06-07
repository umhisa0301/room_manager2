import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/dev_automation_config.dart';
import 'dev_automation_runner.dart';

/// AppShell 上で開発者向け自動検証を可視実行する。
abstract final class DevAutomationVisibleRun {
  static DevAutomationRunner? _activeRunner;

  /// 実行中ランナー（テスト・将来の停止 UI 用）。
  static DevAutomationRunner? get activeRunner => _activeRunner;

  /// DevAutomationScreen を閉じた後、AppShell 配下の [context] から呼び出す。
  static Future<void> startTabTourProductSearch({
    required BuildContext context,
    required int iterations,
    String keyword = DevAutomationRunner.defaultProductSearchKeyword,
  }) async {
    if (!DevAutomationFlags.isEnabled) return;
    ensureDevAutomationAvailable();
    if (_activeRunner?.isRunning == true) return;

    const scenario = DevAutomationScenario.tabTourProductSearch;
    if (kDebugMode) {
      debugPrint('[DEV_AUTOMATION_VISIBLE_RUN_STARTED] scenario=$scenario');
    }

    final runner = DevAutomationRunner(
      dependencies: DevAutomationDependencies.fromContext(context),
    );
    _activeRunner = runner;

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('自動検証を実行中…'),
        duration: Duration(days: 1),
      ),
    );

    try {
      await runner.runTabTourProductSearch(
        iterations: iterations,
        keyword: keyword,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[DEV_AUTOMATION_VISIBLE_RUN_ERROR] scenario=$scenario error=$e\n$st',
        );
      }
    } finally {
      if (kDebugMode) {
        debugPrint(
          '[DEV_AUTOMATION_VISIBLE_RUN_FINISHED] scenario=$scenario '
          'successCount=${runner.successCount} failureCount=${runner.failureCount}',
        );
      }
      _activeRunner = null;
      if (context.mounted && messenger != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '自動検証が完了しました: 成功${runner.successCount} / 失敗${runner.failureCount}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
