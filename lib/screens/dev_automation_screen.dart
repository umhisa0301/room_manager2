import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';

import '../config/dev_automation_config.dart';
import '../services/dev_automation_runner.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

/// 開発者向け自動検証モードの入口画面（検証ビルド専用）。
class DevAutomationScreen extends StatefulWidget {
  const DevAutomationScreen({super.key});

  static const String title = '開発者向け自動検証';

  @override
  State<DevAutomationScreen> createState() => _DevAutomationScreenState();
}

class _DevAutomationScreenState extends State<DevAutomationScreen> {
  static const String _scenarioTitle = '主要タブ巡回 + 主要操作検証';
  static const String _scenarioDescription =
      '1反復あたり: 主要タブ巡回 → 「水筒」検索 → 検索結果からコレ候補追加 → '
      'おすすめコレ表示 → おすすめからコレ候補追加 → ROOM投稿済商品取り込み → 反応確認。'
      '実行回数はこの一連の流れの反復回数です。';
  static const List<int> _iterationPresets = <int>[1, 3, 5, 10];

  static bool _screenOpenLogged = false;

  final TextEditingController _iterationController = TextEditingController(
    text: '${DevAutomationRunner.defaultIterations}',
  );
  String? _iterationError;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _iterationController.dispose();
    super.dispose();
  }

  int? _parseIterations() {
    final raw = int.tryParse(_iterationController.text.trim());
    final validation = DevAutomationRunner.validateIterations(raw);
    setState(() => _iterationError = validation.errorMessage);
    return validation.value;
  }

  void _startScenario() {
    if (!DevAutomationFlags.isEnabled) return;

    final iterations = _parseIterations();
    if (iterations == null) return;

    if (kDebugMode) {
      debugPrint(
        '[DEV_AUTOMATION_VISIBLE_RUN_REQUEST] '
        'scenario=${DevAutomationScenario.tabTourProductSearch} '
        'source=devAutomationScreen',
      );
    }
    Navigator.of(context).pop(iterations);
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
                  const SizedBox(height: 8),
                  Text(
                    _scenarioDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _iterationController,
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
                          onPressed: () => _setPresetIterations(preset),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _startScenario,
                          child: const Text('開始'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: null,
                          child: const Text('停止'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '開始後は本画面を閉じ、AppShell 上でタブ遷移を可視実行します。'
                    '実行中は画面が閉じるため停止ボタンは利用できません。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                    'ログ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '実行ログは debugPrint / logcat で確認してください。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
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
