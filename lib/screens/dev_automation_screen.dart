import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';

import '../config/dev_automation_config.dart';
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
  static const List<String> _plannedVerificationItems = <String>[
    '主要タブ巡回',
    '水筒検索反復',
    'URLから追加',
    'ROOM取り込み',
    'おすすめ生成',
  ];

  static bool _screenOpenLogged = false;

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
                    '今後追加予定の検証項目',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  for (final item in _plannedVerificationItems) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('・'),
                        Expanded(child: Text(item)),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Text(
                'まだ実行機能はありません',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
