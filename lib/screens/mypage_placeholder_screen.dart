import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/legal_urls.dart';
import '../models/user_profile.dart';
import '../services/app_action_service.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';

/// ユーザー情報の登録・編集（将来の AI コメント生成向け。項目はすべて任意）。
class MypagePlaceholderScreen extends StatefulWidget {
  const MypagePlaceholderScreen({super.key});

  @override
  State<MypagePlaceholderScreen> createState() =>
      _MypagePlaceholderScreenState();
}

class _MypagePlaceholderScreenState extends State<MypagePlaceholderScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _occupationController;
  late final TextEditingController _genresController;
  String? _genderKey;
  bool _bound = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bound) return;
    _bound = true;
    final p = context.read<UserProfileProvider>().profile;
    _nameController = TextEditingController(text: p.displayName);
    _ageController = TextEditingController(
      text: p.age != null ? '${p.age}' : '',
    );
    _occupationController = TextEditingController(text: p.occupation);
    _genresController = TextEditingController(text: p.favoriteGenres);
    _genderKey = p.genderKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    _genresController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final ageText = _ageController.text.trim();
    int? age;
    if (ageText.isNotEmpty) {
      age = int.tryParse(ageText);
      if (age == null || age < 0 || age > 150) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('年齢は 0〜150 の数値で入力するか、空にしてください')),
          );
        }
        return;
      }
    }

    final next = UserProfile(
      displayName: _nameController.text.trim(),
      age: age,
      genderKey: _genderKey,
      occupation: _occupationController.text.trim(),
      favoriteGenres: _genresController.text.trim(),
    );

    await context.read<UserProfileProvider>().saveProfile(next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('マイページ'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenPaddingH,
            AppDimensions.spacingMd,
            AppDimensions.screenPaddingH,
            100,
          ),
          children: [
            Text(
              'ユーザー情報',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'すべて任意です。将来、AI によるコメント案の生成などに利用できるよう準備するための項目です。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'ユーザー名（任意）',
                      hintText: 'ニックネームなど',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '年齢（任意）',
                      hintText: '例: 30',
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '性別（任意）',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _genderKey,
                        isExpanded: true,
                        hint: const Text('選択しない'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('選択しない'),
                          ),
                          DropdownMenuItem(
                            value: UserProfile.genderMale,
                            child: Text(UserProfile.genderLabelJa(
                                  UserProfile.genderMale,
                                ) ??
                                ''),
                          ),
                          DropdownMenuItem(
                            value: UserProfile.genderFemale,
                            child: Text(UserProfile.genderLabelJa(
                                  UserProfile.genderFemale,
                                ) ??
                                ''),
                          ),
                          DropdownMenuItem(
                            value: UserProfile.genderOther,
                            child: Text(UserProfile.genderLabelJa(
                                  UserProfile.genderOther,
                                ) ??
                                ''),
                          ),
                          DropdownMenuItem(
                            value: UserProfile.genderPreferNot,
                            child: Text(UserProfile.genderLabelJa(
                                  UserProfile.genderPreferNot,
                                ) ??
                                ''),
                          ),
                        ],
                        onChanged: (v) => setState(() => _genderKey = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _occupationController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '職業（任意）',
                      hintText: '例: 会社員',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _genresController,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '好きなジャンル（任意）',
                      hintText: '例: 美容、インテリア、グルメ（複数はカンマ区切りでも可）',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('保存'),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            OutlinedButton.icon(
              onPressed: () => AppActionService.openUrl(
                context,
                url: LegalUrls.privacyPolicy,
              ),
              icon: const Icon(Icons.policy_outlined, size: 20),
              label: const Text('プライバシーポリシー'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.divider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
