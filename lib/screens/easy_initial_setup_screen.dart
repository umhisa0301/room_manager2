import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop_discovery_summary.dart';
import '../models/user_profile.dart';
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
import '../widgets/shop_discovery_card.dart';

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
  bool _shopRecommendationStarted = false;
  bool _isLoadingShopRecommendations = false;
  String? _shopRecommendationFailedReason;
  List<ShopDiscoverySummary> _shopRecommendations = const [];

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
    setState(() {
      _shopRecommendationStarted = false;
      _shopRecommendationFailedReason = null;
      _shopRecommendations = const [];
    });
  }

  void _logShopRecommend({
    required bool recommendationStarted,
    required int recommendationCount,
    required int savedShopCount,
    required bool shopSaved,
    String failedReason = '',
  }) {
    final selectedGenres = context
        .read<UserProfileProvider>()
        .profile
        .favoriteGenreIdList
        .join(',');
    debugPrint(
      '[ONBOARDING_SHOP_RECOMMEND] '
      'step=3 '
      'selectedGenres=$selectedGenres '
      'recommendationStarted=$recommendationStarted '
      'recommendationCount=$recommendationCount '
      'savedShopCount=$savedShopCount '
      'shopSaved=$shopSaved '
      'failedReason=$failedReason',
    );
  }

  Future<void> _loadShopRecommendations(BuildContext context) async {
    if (_isLoadingShopRecommendations) return;
    setState(() {
      _shopRecommendationStarted = true;
      _isLoadingShopRecommendations = true;
      _shopRecommendationFailedReason = null;
    });
    _logShopRecommend(
      recommendationStarted: true,
      recommendationCount: 0,
      savedShopCount: context.read<SavedShopProvider>().shops.length,
      shopSaved: false,
    );
    final profileProvider = context.read<UserProfileProvider>();
    final savedShopProvider = context.read<SavedShopProvider>();
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    final profile = profileProvider.profile;
    final recs = _suggestedShopSummaries(profile.favoriteGenreIdList);
    setState(() {
      _isLoadingShopRecommendations = false;
      _shopRecommendations = recs;
      _shopRecommendationFailedReason = recs.isEmpty ? 'empty' : null;
    });
    _logShopRecommend(
      recommendationStarted: true,
      recommendationCount: recs.length,
      savedShopCount: savedShopProvider.shops.length,
      shopSaved: false,
      failedReason: recs.isEmpty ? 'empty' : '',
    );
  }

  Future<void> _saveRecommendedShop(
    BuildContext context,
    ShopDiscoverySummary summary,
  ) async {
    final saved = context.read<SavedShopProvider>();
    if (saved.isSaved(summary.shopKey)) return;
    final messenger = ScaffoldMessenger.of(context);
    await saved.upsertShop(
      shopId: summary.shopKey,
      shopName: summary.shopName,
      shopUrl: summary.shopUrl,
    );
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('保存ショップに追加しました')));
    _logShopRecommend(
      recommendationStarted: _shopRecommendationStarted,
      recommendationCount: _shopRecommendations.length,
      savedShopCount: saved.shops.length,
      shopSaved: true,
    );
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
        label: _shopRecommendationStarted ? 'はじめる' : 'おすすめショップを見る',
        height: 48,
        icon: _shopRecommendationStarted
            ? null
            : const Icon(Icons.auto_awesome_rounded),
        isLoading: _isLoadingShopRecommendations,
        onPressed: _isLoadingShopRecommendations
            ? null
            : _shopRecommendationStarted
            ? () => _persistDismissAndLeave(context, markCompleted: true)
            : () => _loadShopRecommendations(context),
      ),
      if (_shopRecommendationStarted) ...[
        const SizedBox(height: 6),
        Text(
          '保存ショップはあとから追加できます',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textTertiary,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
                      isLoading: _isLoadingShopRecommendations,
                      recommendations: _shopRecommendations,
                      failedReason: _shopRecommendationFailedReason,
                      recommendationStarted: _shopRecommendationStarted,
                      onSaveShop: (summary) =>
                          _saveRecommendedShop(context, summary),
                      onSkip: () =>
                          _persistDismissAndLeave(context, markSkipped: true),
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
    required this.isLoading,
    required this.recommendations,
    required this.failedReason,
    required this.recommendationStarted,
    required this.onSaveShop,
    required this.onSkip,
  });

  final bool isLoading;
  final List<ShopDiscoverySummary> recommendations;
  final String? failedReason;
  final bool recommendationStarted;
  final ValueChanged<ShopDiscoverySummary> onSaveShop;
  final VoidCallback onSkip;

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
              'おすすめショップ',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '選んだジャンルから、よく使えそうなショップを提案します。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '気になるショップを保存すると、あとから店内検索に使えます。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '保存ショップ：$n件',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (!recommendationStarted)
              _InlineShopIntroCard(
                candidateCount: _suggestedShopSummaries(
                  context
                      .watch<UserProfileProvider>()
                      .profile
                      .favoriteGenreIdList,
                ).length,
              )
            else if (isLoading)
              const _InlineShopLoadingCard()
            else if (failedReason != null || recommendations.isEmpty)
              _InlineShopEmptyCard(onSkip: onSkip)
            else
              ...recommendations.indexed.map((entry) {
                final index = entry.$1;
                final summary = entry.$2;
                final isSaved = context.watch<SavedShopProvider>().isSaved(
                  summary.shopKey,
                );
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == recommendations.length - 1 ? 0 : 10,
                  ),
                  child: ShopDiscoveryCard(
                    summary: summary,
                    rank: index + 1,
                    isSaved: isSaved,
                    showOpenShopAction: false,
                    disableSavedAction: true,
                    reasonText: _recommendReasonFor(index),
                    onOpenShop: () {},
                    onSave: () => onSaveShop(summary),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _InlineShopIntroCard extends StatelessWidget {
  const _InlineShopIntroCard({required this.candidateCount});

  final int candidateCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        'あなた向けおすすめショップを$candidateCount件ほど提案できます。',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlineShopLoadingCard extends StatelessWidget {
  const _InlineShopLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(height: 12),
          Text('おすすめショップを探しています'),
        ],
      ),
    );
  }
}

class _InlineShopEmptyCard extends StatelessWidget {
  const _InlineShopEmptyCard({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'おすすめショップを取得できませんでした',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'あとから「探す」タブのショップ発掘で追加できます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          AppSecondaryButton(
            label: 'あとで設定する',
            onPressed: onSkip,
            expand: true,
            height: 40,
          ),
        ],
      ),
    );
  }
}

List<ShopDiscoverySummary> _suggestedShopSummaries(List<String> genreIds) {
  final joined = genreIds.join(',');
  if (joined.contains('100227') || joined.contains('100371')) {
    return _foodShopSummaries;
  }
  if (joined.contains('100939')) {
    return _interiorShopSummaries;
  }
  if (joined.contains('565004')) {
    return _dailyShopSummaries;
  }
  return _genericShopSummaries;
}

String _recommendReasonFor(int index) {
  const reasons = [
    '選択ジャンルに近い商品が多いショップです',
    'レビュー数が多い商品を扱っています',
    '候補探しに使いやすいショップです',
    '日常的に使いやすい商品がまとまっています',
    'ROOM投稿の幅を広げやすいショップです',
  ];
  return reasons[index.clamp(0, reasons.length - 1)];
}

final List<ShopDiscoverySummary> _genericShopSummaries = const [
  ShopDiscoverySummary(
    shopKey: 'rakuten24',
    shopName: '楽天24',
    shopUrl: 'https://www.rakuten.co.jp/rakuten24/',
    hitItemCount: 28,
    maxReviewCount: 12400,
    avgReviewAverage: 4.42,
    discoveryScore: 184.2,
    representativeItems: [
      ShopRepresentativeItem(itemName: '日用品', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: '食品', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: 'コスメ', imageUrl: '', itemUrl: ''),
    ],
  ),
  ShopDiscoverySummary(
    shopKey: 'book',
    shopName: '楽天ブックス',
    shopUrl: 'https://www.rakuten.co.jp/book/',
    hitItemCount: 18,
    maxReviewCount: 8200,
    avgReviewAverage: 4.55,
    discoveryScore: 162.8,
    representativeItems: [
      ShopRepresentativeItem(itemName: '本', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: '雑誌', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: 'DVD', imageUrl: '', itemUrl: ''),
    ],
  ),
  ShopDiscoverySummary(
    shopKey: 'tamachanshop',
    shopName: 'タマチャンショップ',
    shopUrl: 'https://www.rakuten.co.jp/kyunan/',
    hitItemCount: 15,
    maxReviewCount: 6800,
    avgReviewAverage: 4.48,
    discoveryScore: 151.3,
    representativeItems: [
      ShopRepresentativeItem(itemName: '食品', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: 'ナッツ', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: '健康食品', imageUrl: '', itemUrl: ''),
    ],
  ),
];

final List<ShopDiscoverySummary> _foodShopSummaries = [
  const ShopDiscoverySummary(
    shopKey: 'sawaicoffee',
    shopName: '澤井珈琲Beans＆Leaf',
    shopUrl: 'https://www.rakuten.co.jp/sawaicoffee-tea/',
    hitItemCount: 22,
    maxReviewCount: 15400,
    avgReviewAverage: 4.61,
    discoveryScore: 196.4,
    representativeItems: [
      ShopRepresentativeItem(itemName: 'コーヒー', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: 'ドリップ', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: '豆', imageUrl: '', itemUrl: ''),
    ],
  ),
  ..._genericShopSummaries,
];

final List<ShopDiscoverySummary> _interiorShopSummaries = [
  const ShopDiscoverySummary(
    shopKey: 'low-ya',
    shopName: 'LOWYA',
    shopUrl: 'https://www.rakuten.co.jp/low-ya/',
    hitItemCount: 19,
    maxReviewCount: 9100,
    avgReviewAverage: 4.36,
    discoveryScore: 169.5,
    representativeItems: [
      ShopRepresentativeItem(itemName: '家具', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: '収納', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: 'インテリア', imageUrl: '', itemUrl: ''),
    ],
  ),
  const ShopDiscoverySummary(
    shopKey: 'air-rhizome',
    shopName: 'エア・リゾーム',
    shopUrl: 'https://www.rakuten.co.jp/air-rhizome/',
    hitItemCount: 14,
    maxReviewCount: 6200,
    avgReviewAverage: 4.32,
    discoveryScore: 143.8,
    representativeItems: [
      ShopRepresentativeItem(itemName: 'ラック', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: 'テーブル', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: 'チェア', imageUrl: '', itemUrl: ''),
    ],
  ),
  _genericShopSummaries[0],
  _genericShopSummaries[1],
];

final List<ShopDiscoverySummary> _dailyShopSummaries = [
  const ShopDiscoverySummary(
    shopKey: 'soukai',
    shopName: '爽快ドラッグ',
    shopUrl: 'https://www.rakuten.co.jp/soukai/',
    hitItemCount: 21,
    maxReviewCount: 11800,
    avgReviewAverage: 4.39,
    discoveryScore: 178.0,
    representativeItems: [
      ShopRepresentativeItem(itemName: '日用品', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: '洗剤', imageUrl: '', itemUrl: ''),
      ShopRepresentativeItem(itemName: '衛生用品', imageUrl: '', itemUrl: ''),
    ],
  ),
  ..._genericShopSummaries,
];
