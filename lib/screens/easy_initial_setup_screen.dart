import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../navigation/rakuten_search_navigator.dart';
import '../repository/easy_initial_setup_repository.dart';
import '../services/room_profile_url_validation_service.dart';
import '../services/rakuten_genre_master_service.dart';
import '../state/saved_shop_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../utils/onboarding_ui_log.dart';
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
  PageController? _pageController;
  final TextEditingController _roomUrlController = TextEditingController();
  int _pageIndex = 0;
  bool _pageControllerAttached = false;
  String? _lastOnboardingUiLogSignature;
  bool _isCheckingRoomProfile = false;
  String? _roomUrlErrorText;
  String _roomUrlValidationResult = 'notChecked';
  String _roomProfileExists = 'unknown';

  int _firstIncompletePage(UserProfile profile, int savedShopCount) {
    if (!profile.hasRoomUrl) return 0;
    if (profile.favoriteGenreIdList.isEmpty) return 1;
    if (savedShopCount <= 0) return 2;
    return 2;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageControllerAttached) return;
    _pageControllerAttached = true;
    final profile = context.read<UserProfileProvider>().profile;
    _roomUrlController.text = profile.roomUrl;
    final saved = context.read<SavedShopProvider>().shops.length;
    final start = _firstIncompletePage(profile, saved);
    _pageIndex = start;
    _pageController = PageController(initialPage: start);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _roomUrlController.dispose();
    super.dispose();
  }

  Future<void> _persistDismissAndLeave(
    BuildContext context, {
    bool markCompleted = false,
    bool markSkipped = false,
  }) async {
    final nav = Navigator.of(context);
    final embedded = widget.embeddedInEntryHost;
    await context.read<EasyInitialSetupRepository>().dismiss(
      markFlowCompleted: markCompleted,
      markFlowSkipped: markSkipped,
    );
    if (!mounted) return;
    if (!embedded) {
      nav.pop();
    }
  }

  Future<bool> _saveRoomUrlStep(BuildContext context) async {
    if (_isCheckingRoomProfile) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final profileProv = context.read<UserProfileProvider>();
    final base = context.read<UserProfileProvider>().profile;
    final rawUrl = _roomUrlController.text.trim();
    final format = RoomProfileUrlValidationService.validateFormat(rawUrl);
    setState(() {
      _roomUrlValidationResult = format.logValue;
      _roomProfileExists = format.isEmpty ? 'skipped' : 'unknown';
      _roomUrlErrorText = format.errorMessage;
    });
    if (!format.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(RoomProfileUrlValidationService.genericErrorMessage),
        ),
      );
      return false;
    }

    var url = '';
    if (!format.isEmpty) {
      setState(() {
        _isCheckingRoomProfile = true;
        _roomUrlErrorText = null;
      });
      final exists = await RoomProfileUrlValidationService().verifyExists(
        format.normalizedUrl,
      );
      if (!mounted) return false;
      setState(() {
        _isCheckingRoomProfile = false;
        _roomProfileExists = exists.logValue;
        _roomUrlErrorText = exists.exists
            ? null
            : RoomProfileUrlValidationService.genericErrorMessage;
      });
      if (!exists.exists) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(RoomProfileUrlValidationService.genericErrorMessage),
          ),
        );
        return false;
      }
      url = format.normalizedUrl;
    }

    final next = UserProfile(
      displayName: base.displayName,
      age: base.age,
      genderKey: base.genderKey,
      occupation: base.occupation,
      favoriteGenres: base.favoriteGenres,
      favoriteGenreIds: base.favoriteGenreIds,
      roomUrl: url,
    );
    await profileProv.saveProfile(next);
    return true;
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
    final idList = picked
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(5)
        .toList();
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
      final saved = await _saveRoomUrlStep(context);
      if (!mounted) return;
      if (!saved) return;
      _pageController!.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_pageIndex == 1) {
      _pageController!.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _persistDismissAndLeave(context, markCompleted: true);
  }

  void _logEasySetupState(
    UserProfile profile,
    int savedShopCount,
    EasyInitialSetupRepository setup,
  ) {
    final missingRoomUrl = !profile.hasRoomUrl;
    final missingGenre = profile.favoriteGenreIdList.isEmpty;
    final missingSavedShop = savedShopCount <= 0;
    final showMyPageSetupCard =
        !setup.initialSetupCompleted &&
        (missingRoomUrl || missingGenre || missingSavedShop);
    final signature = [
      _pageIndex,
      setup.initialSetupCompleted,
      setup.initialSetupSkipped,
      missingRoomUrl,
      missingGenre,
      missingSavedShop,
      showMyPageSetupCard,
      _roomUrlValidationResult,
      _roomProfileExists,
    ].join('|');
    if (_lastOnboardingUiLogSignature == signature) return;
    _lastOnboardingUiLogSignature = signature;
    logOnboardingUi(
      route: 'easySetup',
      termsAccepted: true,
      initialSetupCompleted: setup.initialSetupCompleted,
      initialSetupSkipped: setup.initialSetupSkipped,
      missingRoomUrl: missingRoomUrl,
      missingGenre: missingGenre,
      missingSavedShop: missingSavedShop,
      showMyPageSetupCard: showMyPageSetupCard,
      roomUrlValidationResult: _roomUrlValidationResult,
      roomProfileExists: _roomProfileExists,
    );
  }

  void _skipStep(BuildContext context) async {
    if (_pageIndex >= 2) {
      await _persistDismissAndLeave(context, markSkipped: true);
      return;
    }
    _pageController!.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  List<Widget> _buildSetupBottomActions(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    final savedCount = context.watch<SavedShopProvider>().shops.length;
    if (_pageIndex == 0) {
      return [
        AppPrimaryButton(
          label: '保存して次へ',
          height: 48,
          isLoading: _isCheckingRoomProfile,
          onPressed: _isCheckingRoomProfile ? null : () => _goNext(context),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () =>
                _persistDismissAndLeave(context, markSkipped: true),
            child: const Text('あとで設定する'),
          ),
        ),
      ];
    }
    if (_pageIndex == 1) {
      final hasGenres = profile.favoriteGenreIdList.isNotEmpty;
      return [
        AppPrimaryButton(
          label: hasGenres ? '次へ' : 'ジャンルを選んで次へ',
          height: 48,
          onPressed: hasGenres
              ? () => _goNext(context)
              : () => _openGenrePicker(context),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () => _skipStep(context),
            child: const Text('スキップして次へ'),
          ),
        ),
      ];
    }
    return [
      AppPrimaryButton(
        label: savedCount >= 1 ? 'はじめる' : 'おすすめショップを見る',
        height: 48,
        icon: savedCount >= 1 ? null : const Icon(Icons.auto_awesome_rounded),
        onPressed: savedCount >= 1
            ? () => _persistDismissAndLeave(context, markCompleted: true)
            : () => openRakutenSearchScreen(
                context,
                initialMode: RakutenSearchInitialMode.shopDiscovery,
              ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.center,
        child: TextButton(
          onPressed: () => _persistDismissAndLeave(context, markSkipped: true),
          child: const Text('あとで設定する'),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final controller = _pageController;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final profile = context.watch<UserProfileProvider>().profile;
    final savedShopCount = context.watch<SavedShopProvider>().shops.length;
    final setup = context.watch<EasyInitialSetupRepository>();
    _logEasySetupState(profile, savedShopCount, setup);
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
                  Expanded(
                    child: Divider(
                      color: AppColors.divider.withValues(alpha: 0.7),
                    ),
                  ),
                  _StepDot(active: _pageIndex == 1, label: '2'),
                  Expanded(
                    child: Divider(
                      color: AppColors.divider.withValues(alpha: 0.7),
                    ),
                  ),
                  _StepDot(active: _pageIndex == 2, label: '3'),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: PageView(
                  controller: controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _pageIndex = i),
                  children: [
                    _StepRoomUrl(
                      controller: _roomUrlController,
                      errorText: _roomUrlErrorText,
                      isChecking: _isCheckingRoomProfile,
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
              ..._buildSetupBottomActions(context),
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
      backgroundColor: active
          ? AppColors.accentLight
          : AppColors.surfaceVariant,
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: c),
      ),
    );
  }
}

class _StepRoomUrl extends StatelessWidget {
  const _StepRoomUrl({
    required this.controller,
    required this.errorText,
    required this.isChecking,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool isChecking;
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
              'ROOM投稿取り込み',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'あなたのROOM投稿を自動でコレ済みに追加できます',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'あとから変更できます',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: controller,
              labelText: 'ROOMプロフィールURL（任意）',
              hintText: '例：https://room.rakuten.co.jp/…',
              onChanged: (_) => onChanged(),
            ),
            if (isChecking || errorText != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (isChecking) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '確認中...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        errorText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
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
              'よく使うジャンル',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'おすすめ候補の精度が上がります\nスキップできます',
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
            AppOutlineButton(
              label: 'ジャンルを選ぶ',
              icon: const Icon(Icons.category_outlined, size: 18),
              height: 44,
              onPressed: onPickGenres,
            ),
            if (count > 0) ...[
              const SizedBox(height: 10),
              Text(
                '選択ジャンルからおすすめショップも提案できます',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
    final profile = context.watch<UserProfileProvider>().profile;
    final suggestions = _suggestedShopNames(profile.favoriteGenreIdList);
    return SingleChildScrollView(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'おすすめショップ',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '選んだジャンルから\nあなた向けショップを提案します',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'あとから変更できます',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentLight.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accentPrimary.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'あなた向けおすすめショップ',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${suggestions.length}件を提案できます',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...suggestions.map(
                    (name) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 16,
                            color: AppColors.accentPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (n > 0) ...[
              const SizedBox(height: 10),
              AppOutlineButton(
                label: '保存ショップ一覧',
                height: 44,
                onPressed: onOpenSavedList,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<String> _suggestedShopNames(List<String> genreIds) {
  final joined = genreIds.join(',');
  if (joined.contains('100227') || joined.contains('100371')) {
    return const ['楽天24', 'タマチャンショップ', '澤井珈琲Beans＆Leaf'];
  }
  if (joined.contains('100939')) {
    return const ['LOWYA', 'scope version.R', 'エア・リゾーム'];
  }
  if (joined.contains('565004')) {
    return const ['楽天24', '爽快ドラッグ', 'ケンコーコム'];
  }
  return const ['楽天24', 'タマチャンショップ', '澤井珈琲Beans＆Leaf'];
}
