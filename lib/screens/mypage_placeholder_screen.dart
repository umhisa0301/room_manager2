import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/legal_urls.dart';
import '../models/user_profile.dart';
import '../services/app_action_service.dart';
import '../state/saved_shop_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import 'rakuten_search_screen.dart';
import 'saved_shops_screen.dart';

/// マイページ：ユーザー情報・ROOM情報・ジャンル・設定などをまとめる画面。
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
  late final TextEditingController _roomUrlController;
  String? _genderKey;
  bool _bound = false;
  bool _showOnboardingHint = false;

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
     _roomUrlController = TextEditingController(text: p.roomUrl);
    _genderKey = p.genderKey;
    final hasCoreProfile = p.displayName.trim().isNotEmpty ||
        p.roomUrl.trim().isNotEmpty ||
        p.favoriteGenres.trim().isNotEmpty;
    _showOnboardingHint = !hasCoreProfile;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    _genresController.dispose();
    _roomUrlController.dispose();
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
      roomUrl: _roomUrlController.text.trim(),
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
            if (_showOnboardingHint)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 22,
                          color: AppColors.accentPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'はじめにマイページを整えておきましょう',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ROOMのURLや好きなジャンルを登録しておくと、今後のおすすめ機能や検索補助に活かせます。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showOnboardingHint = false;
                            });
                          },
                          child: const Text('後で'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            // ROOM情報セクション
            Text(
              'ROOM情報',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'あなたの楽天ROOMのURLを登録しておくと、すぐにROOMページを開けます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _roomUrlController,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '楽天ROOMのURL（任意）',
                hintText: '例: https://room.rakuten.co.jp/xxxx',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _roomUrlController.text.trim().isEmpty
                    ? null
                    : () => AppActionService.openUrl(
                          context,
                          url: _roomUrlController.text.trim(),
                        ),
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                label: const Text('ROOMを開く'),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            // 好きなジャンルセクション
            Text(
              '好きなジャンル',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '複数のジャンルをカンマや読点で区切って入力できます。あとでおすすめや検索条件に活用します。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
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
                hintText: '例: 美容、インテリア、グルメ',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _GenresChipsPreview(rawText: _genresController.text),
            const SizedBox(height: AppDimensions.spacingLg),
            // プロフィール / ユーザー情報セクション
            Text(
              'プロフィール',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '将来のコメント生成やおすすめ表示の参考として使う予定の、基本的なユーザー情報です（すべて任意）。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
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
                      child: Text(
                            UserProfile.genderLabelJa(
                              UserProfile.genderMale,
                            ) ??
                            '',
                          ),
                    ),
                    DropdownMenuItem(
                      value: UserProfile.genderFemale,
                      child: Text(
                            UserProfile.genderLabelJa(
                              UserProfile.genderFemale,
                            ) ??
                            '',
                          ),
                    ),
                    DropdownMenuItem(
                      value: UserProfile.genderOther,
                      child: Text(
                            UserProfile.genderLabelJa(
                              UserProfile.genderOther,
                            ) ??
                            '',
                          ),
                    ),
                    DropdownMenuItem(
                      value: UserProfile.genderPreferNot,
                      child: Text(
                            UserProfile.genderLabelJa(
                              UserProfile.genderPreferNot,
                            ) ??
                            '',
                          ),
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
            const SizedBox(height: AppDimensions.spacingLg),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('保存'),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              'その他',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SavedShopsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.bookmarks_outlined, size: 20),
              label: Consumer<SavedShopProvider>(
                builder: (context, saved, _) {
                  return Text('保存ショップを管理する（${saved.shops.length}件）');
                },
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.divider),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RakutenSearchScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.travel_explore_rounded, size: 20),
              label: const Text('ショップ発掘を開く'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.divider),
              ),
            ),
            const SizedBox(height: 8),
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

/// 好きなジャンル入力欄の下に表示する、簡易プレビュー用のチップ一覧。
class _GenresChipsPreview extends StatelessWidget {
  const _GenresChipsPreview({required this.rawText});

  final String rawText;

  @override
  Widget build(BuildContext context) {
    final genres = _parseGenres(rawText);
    if (genres.isEmpty) {
      return Text(
        '入力したジャンルはここにタグとして表示されます。',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
            ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final g in genres)
          Chip(
            label: Text(
              g,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            backgroundColor: AppColors.surfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
            ),
          ),
      ],
    );
  }

  List<String> _parseGenres(String text) {
    final tokens = text.split(RegExp(r'[、,\n]'));
    return tokens
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
}
