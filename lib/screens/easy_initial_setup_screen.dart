import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../navigation/rakuten_search_navigator.dart';
import '../repository/easy_initial_setup_repository.dart';
import '../services/rakuten_genre_master_service.dart';
import '../state/saved_shop_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/favorite_genre_picker_sheet.dart';
import 'saved_shops_screen.dart';

/// 規約同意後の「かんたん初期設定」（スキップ可能）。
class EasyInitialSetupScreen extends StatefulWidget {
  const EasyInitialSetupScreen({super.key, this.embeddedInEntryHost = true});

  /// true のときルートの [AppShell] の代わりに配置される。
  final bool embeddedInEntryHost;

  @override
  State<EasyInitialSetupScreen> createState() => _EasyInitialSetupScreenState();
}

class _EasyInitialSetupScreenState extends State<EasyInitialSetupScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _roomUrlController = TextEditingController();
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final profile = context.read<UserProfileProvider>().profile;
      _roomUrlController.text = profile.roomUrl;
      final saved = context.read<SavedShopProvider>().shops.length;
      final repo = context.read<EasyInitialSetupRepository>();
      if (profile.hasRoomUrl &&
          profile.favoriteGenreIdList.isNotEmpty &&
          saved > 0) {
        await repo.dismiss();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _roomUrlController.dispose();
    super.dispose();
  }

  Future<void> _persistDismissAndLeave(BuildContext context) async {
    final nav = Navigator.of(context);
    final embedded = widget.embeddedInEntryHost;
    await context.read<EasyInitialSetupRepository>().dismiss();
    if (!mounted) return;
    if (!embedded) {
      nav.pop();
    }
  }

  Future<void> _saveRoomUrlStep(BuildContext context) async {
    final base = context.read<UserProfileProvider>().profile;
    final url = _roomUrlController.text.trim();
    final next = UserProfile(
      displayName: base.displayName,
      age: base.age,
      genderKey: base.genderKey,
      occupation: base.occupation,
      favoriteGenres: base.favoriteGenres,
      favoriteGenreIds: base.favoriteGenreIds,
      roomUrl: url,
    );
    await context.read<UserProfileProvider>().saveProfile(next);
  }

  Future<void> _openGenrePicker(BuildContext context) async {
    final base = context.read<UserProfileProvider>().profile;
    final profileProv = context.read<UserProfileProvider>();
    final initial = base.favoriteGenreIdList;
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FavoriteGenrePickerSheet(initialSelectedIds: initial),
    );
    if (picked == null || !mounted) return;
    final svc = RakutenGenreMasterService.instance;
    final idList = picked.map((e) => e.trim()).where((e) => e.isNotEmpty).take(5).toList();
    final names = <String>[];
    for (final id in idList) {
      final n = svc.getGenreNameById(id);
      if (n.isNotEmpty &&
          n != RakutenGenreMasterService.unknownGenreDisplayLabel) {
        names.add(n);
      }
    }
    final next = UserProfile(
      displayName: base.displayName,
      age: base.age,
      genderKey: base.genderKey,
      occupation: base.occupation,
      favoriteGenres: names.join('、'),
      favoriteGenreIds: idList.join('、'),
      roomUrl: base.roomUrl,
    );
    await profileProv.saveProfile(next);
    if (!mounted) return;
    setState(() {});
  }

  void _goNext(BuildContext context) async {
    if (_pageIndex == 0) {
      await _saveRoomUrlStep(context);
      if (!mounted) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_pageIndex == 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _persistDismissAndLeave(context);
  }

  void _skipStep(BuildContext context) {
    if (_pageIndex >= 2) {
      _persistDismissAndLeave(context);
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('かんたん初期設定'),
        automaticallyImplyLeading: !widget.embeddedInEntryHost,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'あとからマイページで変更できます。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _StepDot(active: _pageIndex == 0, label: '1'),
                  Expanded(child: Divider(color: AppColors.divider.withValues(alpha: 0.7))),
                  _StepDot(active: _pageIndex == 1, label: '2'),
                  Expanded(child: Divider(color: AppColors.divider.withValues(alpha: 0.7))),
                  _StepDot(active: _pageIndex == 2, label: '3'),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _pageIndex = i),
                  children: [
                    _StepRoomUrl(
                      controller: _roomUrlController,
                      onChanged: () => setState(() {}),
                    ),
                    _StepGenres(onPickGenres: () => _openGenrePicker(context)),
                    _StepSavedShops(
                      onOpenDiscovery: () {
                        openRakutenSearchScreen(
                          context,
                          initialMode: RakutenSearchInitialMode.shopDiscovery,
                        );
                      },
                      onOpenSavedList: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const SavedShopsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppPrimaryButton(
                label: _pageIndex >= 2 ? 'はじめる' : '次へ',
                height: 48,
                onPressed: () => _goNext(context),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _skipStep(context),
                      child: const Text('スキップ'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: () => _persistDismissAndLeave(context),
                      child: const Text('あとで設定する'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = active ? AppColors.accentPrimary : AppColors.textTertiary;
    return CircleAvatar(
      radius: 14,
      backgroundColor: active ? AppColors.accentLight : AppColors.surfaceVariant,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: c,
        ),
      ),
    );
  }
}

class _StepRoomUrl extends StatelessWidget {
  const _StepRoomUrl({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step 1：ROOMプロフィールURL',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ROOM投稿取り込みに使います。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: controller,
              labelText: 'ROOMプロフィールURL（任意）',
              hintText: '例：https://room.rakuten.co.jp/…',
              onChanged: (_) => onChanged(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepGenres extends StatelessWidget {
  const _StepGenres({required this.onPickGenres});

  final VoidCallback onPickGenres;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<UserProfileProvider>().profile;
    final count = profile.favoriteGenreIdList.length;
    return SingleChildScrollView(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step 2：よく使うジャンル',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'おすすめ候補の精度が上がります。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              count > 0 ? '選択中：$count 件' : 'まだ選択されていません（スキップできます）',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onPickGenres,
              icon: const Icon(Icons.category_outlined),
              label: const Text('ジャンルを選ぶ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepSavedShops extends StatelessWidget {
  const _StepSavedShops({
    required this.onOpenDiscovery,
    required this.onOpenSavedList,
  });

  final VoidCallback onOpenDiscovery;
  final VoidCallback onOpenSavedList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = context.watch<SavedShopProvider>().shops.length;
    return SingleChildScrollView(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step 3：保存ショップ',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'よく使うショップ内で商品を探しやすくなります。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '現在の保存数：$n 件',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            AppPrimaryButton(
              label: 'ショップ発掘を開く',
              icon: const Icon(Icons.travel_explore_rounded),
              height: 44,
              onPressed: onOpenDiscovery,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onOpenSavedList,
              child: const Text('保存ショップ一覧'),
            ),
          ],
        ),
      ),
    );
  }
}
