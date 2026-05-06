import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/legal_urls.dart';
import '../repository/legal_consent_repository.dart';
import '../services/app_action_service.dart';
import '../theme/app_theme.dart';

/// 初回起動時のみ表示する規約・プライバシー同意。
class LegalConsentScreen extends StatefulWidget {
  const LegalConsentScreen({super.key});

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'はじめる前に',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'このアプリでは、楽天ROOM運用を補助するために、'
                        '入力したURLや登録した商品情報をアプリ内で管理します。',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.45,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '利用規約の概要',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '・本アプリは楽天ROOMの運用補助を目的とします\n'
                        '・入力・保存したデータは端末内で管理され、公開しません\n'
                        '・商用APIや外部サービスの利用条件は各提供者に従います\n'
                        '・詳細は利用規約の全文をご確認ください',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => AppActionService.openUrl(
                              context,
                              url: LegalUrls.termsOfService,
                            ),
                            child: const Text('利用規約を開く'),
                          ),
                          TextButton(
                            onPressed: () => AppActionService.openUrl(
                              context,
                              url: LegalUrls.privacyPolicy,
                            ),
                            child: const Text('プライバシーポリシーを開く'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              CheckboxListTile(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  '利用規約とプライバシーポリシーに同意します',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: !_agreed
                    ? null
                    : () async {
                        await context
                            .read<LegalConsentRepository>()
                            .setAccepted();
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text(
                  '同意してはじめる',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
