import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/demo_mode.dart';
import '../constants/legal_urls.dart';
import '../models/rakuten_genre_master_entry.dart';
import '../models/user_profile.dart';
import '../services/app_action_service.dart';
import '../services/rakuten_genre_master_service.dart';
import '../state/saved_shop_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../utils/user_profile_genre_migration.dart';
import 'rakuten_search_screen.dart';
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
              ),
            _SectionHeader(
              title: 'プロフィール / ユーザー情報',
              body: 'ホーム表示や将来のおすすめ最適化で使う基本情報です（すべて任意）。',
            ),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
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
                  TextFormField(
                    controller: _occupationController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '職業（任意）',
                      hintText: '例: 会社員',
                    ),
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
                  OutlinedButton.icon(
                    onPressed: _openFavoriteGenresPicker,
                    icon: const Icon(Icons.category_outlined, size: 20),
                    label: Text(
                      _favoriteGenreIds.isEmpty
                          ? 'ジャンルを選ぶ（最大5件）'
                          : 'ジャンルを変更（${_favoriteGenreIds.length}/5）',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.divider),
                    ),
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
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('保存'),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            _SectionHeader(title: 'アプリ設定や補助導線', body: '運用中によく使う管理画面へ移動できます。'),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
                children: [
                  if (kDemoModeEnabled) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ClosedTestDemoScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.rocket_launch_outlined, size: 20),
                      label: const Text('クローズドテスト用デモを見る'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
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
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            _SectionHeader(title: 'プライバシーポリシー', body: '利用前に確認できるよう、いつでも開けます。'),
            const SizedBox(height: 10),
            _SectionCard(
              child: OutlinedButton.icon(
                onPressed: () => AppActionService.openUrl(
                  context,
                  url: LegalUrls.privacyPolicy,
                ),
                icon: const Icon(Icons.policy_outlined, size: 20),
                label: const Text('プライバシーポリシーを開く'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.divider),
                ),
              ),
            ),
          ],
        ),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            final ordered = <String>[];
            for (final e in _entries) {
              final id = e.genreId;
              if (_selected.contains(id)) ordered.add(id);
            }
            Navigator.of(context).pop(ordered);
          },
          child: const Text('決定'),
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
    return Container(
      margin: EdgeInsets.only(bottom: marginBottom ?? 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.divider),
      ),
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
