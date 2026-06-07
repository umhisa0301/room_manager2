import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';

import '../config/dev_automation_config.dart';
import '../services/dev_automation_runner.dart';
import '../theme/app_theme.dart';
import '../utils/dev_automation_log_buffer.dart';
import '../widgets/app_card.dart';

/// 開発者向け自動検証モードの入口画面（検証ビルド専用）。
class DevAutomationScreen extends StatefulWidget {
  const DevAutomationScreen({super.key});

  static const String title = '開発者向け自動検証';

  @override
  State<DevAutomationScreen> createState() => _DevAutomationScreenState();
}

class _DevAutomationScreenState extends State<DevAutomationScreen> {
  static const String _scenarioTitle = '主要タブ巡回 + 水筒検索';
  static const List<int> _iterationPresets = <int>[1, 3, 5, 10];

  static bool _screenOpenLogged = false;

  late final DevAutomationLogBuffer _logBuffer;
  DevAutomationRunner? _runner;
  final TextEditingController _iterationController = TextEditingController(
    text: '${DevAutomationRunner.defaultIterations}',
  );
  String? _iterationError;

  @override
  void initState() {
    super.initState();
    _logBuffer = DevAutomationLogBuffer();
    if (!DevAutomationFlags.isEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).maybePop();
      });
      return;
    }
    if (kDebugMode && !_screenOpenLogged) {
      _screenOpenLogged = true;
      debugPrint('[DEV_AUTOMATION_SCREEN_OPEN] enabled=true');
    }
    _logBuffer.addListener(_onLogChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!DevAutomationFlags.isEnabled || _runner != null) return;
    _runner = DevAutomationRunner(
      dependencies: DevAutomationDependencies.fromContext(context),
      logBuffer: _logBuffer,
    )..addListener(_onRunnerChanged);
  }

  @override
  void dispose() {
    _runner?.removeListener(_onRunnerChanged);
    _logBuffer.removeListener(_onLogChanged);
    _iterationController.dispose();
    super.dispose();
  }

  void _onRunnerChanged() {
    if (mounted) setState(() {});
  }

  void _onLogChanged() {
    if (mounted) setState(() {});
  }

  int? _parseIterations() {
    final raw = int.tryParse(_iterationController.text.trim());
    final validation = DevAutomationRunner.validateIterations(raw);
    setState(() => _iterationError = validation.errorMessage);
    return validation.value;
  }

  Future<void> _startScenario() async {
    if (!DevAutomationFlags.isEnabled) return;
    final runner = _runner;
    if (runner == null || runner.isRunning) return;

    final iterations = _parseIterations();
    if (iterations == null) return;

    await runner.runTabTourProductSearch(iterations: iterations);
  }

  void _requestStop() {
    _runner?.requestStop();
  }

  void _setPresetIterations(int value) {
    _iterationController.text = '$value';
    _parseIterations();
  }

  @override
  Widget build(BuildContext context) {
    if (!DevAutomationFlags.isEnabled) {
      return const SizedBox.shrink();
    }

    final runner = _runner;
    final isRunning = runner?.isRunning ?? false;
    final logs = _logBuffer.entries;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(DevAutomationScreen.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          children: [
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    DevAutomationScreen.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'この機能は検証ビルド専用です',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '有効状態',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DevAutomationFlags.isEnabled ? '有効' : '無効',
                    style: TextStyle(
                      color: DevAutomationFlags.isEnabled
                          ? AppColors.accentPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'シナリオ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _scenarioTitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _iterationController,
                    enabled: !isRunning,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '実行回数',
                      helperText:
                          'デフォルト ${DevAutomationRunner.defaultIterations} 回 '
                          '（${DevAutomationRunner.minIterations}〜'
                          '${DevAutomationRunner.maxIterations}）',
                      errorText: _iterationError,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => _parseIterations(),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final preset in _iterationPresets)
                        ActionChip(
                          label: Text('$preset 回'),
                          onPressed: isRunning
                              ? null
                              : () => _setPresetIterations(preset),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: isRunning ? null : _startScenario,
                          child: const Text('開始'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isRunning ? _requestStop : null,
                          child: const Text('停止'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '実行状態',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRunning
                        ? '実行中${runner?.stopRequested == true ? '（停止待ち）' : ''}'
                        : '待機中',
                    style: TextStyle(
                      color: isRunning
                          ? AppColors.accentPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('成功回数: ${runner?.successCount ?? 0}'),
                  Text('失敗回数: ${runner?.failureCount ?? 0}'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '最新ログ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (logs.isEmpty)
                    Text(
                      'ログはまだありません',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    for (final line in logs.reversed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
