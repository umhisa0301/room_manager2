import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/demo_mode.dart';
import '../constants/legal_urls.dart';
import '../navigation/app_shell_controller.dart';
import '../navigation/rakuten_search_navigator.dart';
import '../models/rakuten_genre_master_entry.dart';
import '../models/user_profile.dart';
import '../services/app_action_service.dart';
import '../services/rakuten_genre_master_service.dart';
import '../state/saved_shop_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../utils/user_profile_genre_migration.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import 'saved_shops_screen.dart';
import 'closed_test_demo_screen.dart';

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
  late final TextEditingController _roomUrlController;
  String? _genderKey;
  bool _bound = false;
  bool _showOnboardingHint = false;

  /// マイページで選んだ `genreId`（最大5件）。保存時に [UserProfile.favoriteGenreIds] へ反映。
  final List<String> _favoriteGenreIds = [];

  /// [favoriteGenreIdList] が空で、マスタへ移行できなかった従来のフリーテキストを一時保持。
  String _preservedFreeformFavoriteGenres = '';

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
    _roomUrlController = TextEditingController(text: p.roomUrl);
    _genderKey = p.genderKey;
    _showOnboardingHint = !p.hasCoreProfile;

    _favoriteGenreIds.clear();
    _favoriteGenreIds.addAll(p.favoriteGenreIdList);
    if (_favoriteGenreIds.isEmpty && p.favoriteGenres.trim().isNotEmpty) {
      _favoriteGenreIds.addAll(
        UserProfileGenreMigration.idsFromLegacyFavoriteGenresText(
          p.favoriteGenres,
        ),
      );
    }
    if (_favoriteGenreIds.isEmpty && p.favoriteGenres.trim().isNotEmpty) {
      _preservedFreeformFavoriteGenres = p.favoriteGenres.trim();
    } else {
      _preservedFreeformFavoriteGenres = '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    _roomUrlController.dispose();
    super.dispose();
  }

  Future<void> _openFavoriteGenresPicker() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _FavoriteGenresPickerDialog(
        initialSelectedIds: List<String>.from(_favoriteGenreIds),
        onLimitReached: () {
          messenger.showSnackBar(
            const SnackBar(content: Text('ジャンルは最大5件まで選択できます')),
          );
        },
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _favoriteGenreIds
        ..clear()
        ..addAll(picked.take(5));
      if (_favoriteGenreIds.isNotEmpty) {
        _preservedFreeformFavoriteGenres = '';
      }
    });
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

    final svc = RakutenGenreMasterService.instance;
    final ids = _favoriteGenreIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(5)
        .toList();

    String favoriteGenresStr;
    String favoriteGenreIdsStr;
    if (ids.isNotEmpty) {
      favoriteGenreIdsStr = ids.join('、');
      final names = <String>[];
      for (final id in ids) {
        final n = svc.getGenreNameById(id);
        if (n.isNotEmpty &&
            n != RakutenGenreMasterService.unknownGenreDisplayLabel) {
          names.add(n);
        }
      }
      favoriteGenresStr = names.join('、');
    } else {
      favoriteGenreIdsStr = '';
      favoriteGenresStr = _preservedFreeformFavoriteGenres.trim();
    }

    final next = UserProfile(
      displayName: _nameController.text.trim(),
      age: age,
      genderKey: _genderKey,
      occupation: _occupationController.text.trim(),
      favoriteGenres: favoriteGenresStr,
      favoriteGenreIds: favoriteGenreIdsStr,
      roomUrl: _roomUrlController.text.trim(),
    );

    await context.read<UserProfileProvider>().saveProfile(next);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存しました')));
    }
  }

  void _openClosedTestDemo() {
    ensureClosedTestDemoAvailable();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ClosedTestDemoScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('マイページ')),
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
              _SectionCard(
                marginBottom: AppDimensions.spacingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.flag_circle_outlined,
                          size: 22,
                          color: AppColors.accentPrimary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '最初に3つだけ設定しておくと運用しやすくなります',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ユーザー名・ROOM URL・好きなジャンルを登録すると、'
                      'ホーム表示やおすすめ候補の精度向上に活かせます。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppSecondaryButton(
                      label: '後で',
                      onPressed: () {
                        setState(() {
                          _showOnboardingHint = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            _SectionHeader(
              title: 'プロフィール / ユーザー情報',
              body: 'ホーム表示や将来のおすすめ最適化で使う基本情報です（すべて任意）。',
            ),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
                children: [
                  AppTextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    labelText: 'ユーザー名（任意）',
                    hintText: 'ニックネームなど',
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    textInputAction: TextInputAction.next,
                    labelText: '年齢（任意）',
                    hintText: '例: 30',
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: '性別（任意）'),
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
                  AppTextField(
                    controller: _occupationController,
                    textInputAction: TextInputAction.next,
                    labelText: '職業（任意）',
                    hintText: '例: 会社員',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            _SectionHeader(
              title: 'ROOM情報',
              body:
                  '楽天ROOMのURLを保存しておくと、このアプリからすぐに開けます。'
                  'プロフィールとあわせて、おすすめ候補の参考にも使います。',
            ),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
                children: [
                  AppTextField(
                    controller: _roomUrlController,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.url,
                    labelText: '楽天ROOMのURL（任意）',
                    hintText: '例: https://room.rakuten.co.jp/xxxx',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _roomUrlController.text.trim().isEmpty
                          ? 'URLを登録すると「ROOMを開く」が使えます。'
                          : '登録したURLをすぐに開けます。',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppSecondaryButton(
                    label: 'ROOMを開く',
                    icon: const Icon(Icons.open_in_new_rounded),
                    expand: true,
                    height: 44,
                    onPressed: _roomUrlController.text.trim().isEmpty
                        ? null
                        : () => AppActionService.openUrl(
                            context,
                            url: _roomUrlController.text.trim(),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            _SectionHeader(
              title: '好きなジャンル',
              body: 'アプリ内のジャンルマスタから最大5件まで選べます（おすすめ候補の参考に使います）。',
            ),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSecondaryButton(
                    label: _favoriteGenreIds.isEmpty
                        ? 'ジャンルを選ぶ（最大5件）'
                        : 'ジャンルを変更（${_favoriteGenreIds.length}/5）',
                    onPressed: _openFavoriteGenresPicker,
                    icon: const Icon(Icons.category_outlined),
                    expand: true,
                    height: 44,
                  ),
                  const SizedBox(height: 8),
                  _GenresChipsPreview(
                    genreIds: List<String>.from(_favoriteGenreIds),
                    legacyFreeformText: _preservedFreeformFavoriteGenres,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            AppPrimaryButton(label: '保存', onPressed: _save),
            const SizedBox(height: AppDimensions.spacingMd),
            _SectionHeader(
              title: '運用メニュー',
              body:
                  'ROOMの投稿やコレ運用で、すぐ戻りたい画面をまとめています。'
                  '下の2つから開けます。',
            ),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OperationMenuNavTile(
                    icon: Icons.add_comment_outlined,
                    title: 'コメントを見る',
                    subtitle: '投稿用テンプレの作成・コピーや、直近のコピー履歴を確認できます。',
                    onPressed: () {
                      context.read<AppShellController>().selectTab(2);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.divider.withValues(alpha: 0.85),
                    ),
                  ),
                  _OperationMenuNavTile(
                    icon: Icons.insights_outlined,
                    title: '活動を見る',
                    subtitle: '今日の整理やコレ状況など、ROOM運用ダッシュボードで確認できます。',
                    onPressed: () {
                      context.read<AppShellController>().openActivityTab();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            _SectionHeader(title: 'アプリ設定や補助導線', body: '運用中によく使う管理画面へ移動できます。'),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
                children: [
                  if (kClosedTestDemoAvailable) ...[
                    AppSecondaryButton(
                      label: 'クローズドテスト用デモを見る',
                      onPressed: _openClosedTestDemo,
                      icon: const Icon(Icons.rocket_launch_outlined),
                      expand: true,
                      height: 44,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Consumer<SavedShopProvider>(
                    builder: (context, saved, _) => AppSecondaryButton(
                      label: '保存ショップを管理する（${saved.shops.length}件）',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SavedShopsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bookmarks_outlined),
                      expand: true,
                      height: 44,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppSecondaryButton(
                    label: 'ショップ発掘を開く',
                    onPressed: () {
                      openRakutenSearchScreen(
                        context,
                        initialMode: RakutenSearchInitialMode.shopDiscovery,
                      );
                    },
                    icon: const Icon(Icons.travel_explore_rounded),
                    expand: true,
                    height: 44,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            _SectionHeader(title: 'プライバシーポリシー', body: '利用前に確認できるよう、いつでも開けます。'),
            const SizedBox(height: 10),
            _SectionCard(
              child: AppSecondaryButton(
                label: 'プライバシーポリシーを開く',
                onPressed: () => AppActionService.openUrl(
                  context,
                  url: LegalUrls.privacyPolicy,
                ),
                icon: const Icon(Icons.policy_outlined),
                expand: true,
                height: 44,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 運用メニュー内の導線1行（タイトル＋短い補足）。
class _OperationMenuNavTile extends StatelessWidget {
  const _OperationMenuNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onPressed,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 22, color: AppColors.accentPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteGenresPickerDialog extends StatefulWidget {
  const _FavoriteGenresPickerDialog({
    required this.initialSelectedIds,
    required this.onLimitReached,
  });

  final List<String> initialSelectedIds;
  final VoidCallback onLimitReached;

  @override
  State<_FavoriteGenresPickerDialog> createState() =>
      _FavoriteGenresPickerDialogState();
}

class _FavoriteGenresPickerDialogState
    extends State<_FavoriteGenresPickerDialog> {
  late final Set<String> _selected;
  late final List<RakutenGenreMasterEntry> _entries;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(
      widget.initialSelectedIds.map((e) => e.trim()).where((e) => e.isNotEmpty),
    );
    _entries = RakutenGenreMasterService.instance.getAllGenres();
  }

  void _onToggle(String genreId, bool? checked) {
    final id = genreId.trim();
    if (id.isEmpty) return;
    if (checked == true) {
      if (_selected.length >= 5) {
        widget.onLimitReached();
        return;
      }
      setState(() => _selected.add(id));
    } else {
      setState(() => _selected.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('好きなジャンルを選ぶ'),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'チェックを付けたジャンルが保存されます（${_selected.length}/5）。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final e = _entries[index];
                  final id = e.genreId;
                  final name = e.genreName;
                  return CheckboxListTile(
                    value: _selected.contains(id),
                    onChanged: (v) => _onToggle(id, v),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppSecondaryButton(
          label: 'キャンセル',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppPrimaryButton(
          label: '決定',
          height: 40,
          expand: false,
          onPressed: () {
            final ordered = <String>[];
            for (final e in _entries) {
              final id = e.genreId;
              if (_selected.contains(id)) ordered.add(id);
            }
            Navigator.of(context).pop(ordered);
          },
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.marginBottom});

  final Widget child;
  final double? marginBottom;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.only(bottom: marginBottom ?? 0),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

/// 選んだジャンル（マスタ名称）と、移行前のフリーテキストのプレビュー。
class _GenresChipsPreview extends StatelessWidget {
  const _GenresChipsPreview({
    required this.genreIds,
    required this.legacyFreeformText,
  });

  final List<String> genreIds;
  final String legacyFreeformText;

  @override
  Widget build(BuildContext context) {
    final svc = RakutenGenreMasterService.instance;
    if (genreIds.isEmpty && legacyFreeformText.trim().isEmpty) {
      return Text(
        '「ジャンルを選ぶ」から登録すると、ここに表示されます。',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
      );
    }

    final chips = <Widget>[];

    for (final id in genreIds) {
      final label = svc.getGenreNameById(id);
      if (label.isEmpty) continue;
      chips.add(
        Chip(
          label: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          ),
        ),
      );
    }

    if (genreIds.isEmpty && legacyFreeformText.trim().isNotEmpty) {
      final legacy = UserProfile(
        favoriteGenres: legacyFreeformText,
      ).favoriteGenreList;
      chips.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '従来の入力（マスタへ未対応の語は保存時までこのまま保持されます）',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ),
      );
      for (final g in legacy) {
        chips.add(
          Chip(
            label: Text(
              g,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.65),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
            ),
          ),
        );
      }
    }

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}
