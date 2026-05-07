import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_product_search_condition.dart';
import '../models/shop_discovery_summary.dart';
import '../models/user_profile.dart';
import '../repository/easy_initial_setup_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../services/room_profile_url_validation_service.dart';
import '../services/rakuten_genre_master_service.dart';
import '../services/shop_discovery_aggregator.dart';
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
  _ShopRecommendationMode _shopRecommendationMode =
      _ShopRecommendationMode.balance;

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
          content: Text(RoomProfileUrlValidationService.formatErrorMessage),
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
        _roomUrlErrorText = exists.canSave ? null : exists.message;
      });
      messenger.showSnackBar(SnackBar(content: Text(exists.message)));
      if (!exists.canSave) {
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
    final searchRepository = context.read<RakutenSearchRepository>();
    try {
      final profile = profileProvider.profile;
      final condition = _shopRecommendationCondition(
        profile.favoriteGenreIdList,
        _shopRecommendationMode,
      );
      final items = await searchRepository.search(condition: condition);
      if (!mounted) return;
      final recs = _rankShopRecommendations(
        ShopDiscoveryAggregator.aggregate(items, shopLimit: 5, itemsPerShop: 3),
        _shopRecommendationMode,
      );
      setState(() {
        _isLoadingShopRecommendations = false;
        _shopRecommendations = recs;
        _shopRecommendationFailedReason = recs.isEmpty ? 'empty' : null;
      });
      for (final summary in recs) {
        final imageItems = summary.representativeItems
            .where((e) => e.imageUrl.trim().isNotEmpty)
            .toList(growable: false);
        debugPrint(
          '[ONBOARDING_SHOP_RECOMMEND] '
          'shopName=${summary.shopName} '
          'imageCount=${imageItems.length} '
          'firstImageUrl=${imageItems.isEmpty ? '' : imageItems.first.imageUrl} '
          'reason=${imageItems.isEmpty ? 'imageUrlsEmpty' : _shopRecommendationMode.logValue}',
        );
      }
      _logShopRecommend(
        recommendationStarted: true,
        recommendationCount: recs.length,
        savedShopCount: savedShopProvider.shops.length,
        shopSaved: false,
        failedReason: recs.isEmpty ? 'empty' : '',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingShopRecommendations = false;
        _shopRecommendations = const [];
        _shopRecommendationFailedReason = 'searchFailed';
      });
      _logShopRecommend(
        recommendationStarted: true,
        recommendationCount: 0,
        savedShopCount: savedShopProvider.shops.length,
        shopSaved: false,
        failedReason: 'searchFailed',
      );
    }
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
    messenger.showSnackBar(const SnackBar(content: Text('保存しました')));
    _logShopRecommend(
      recommendationStarted: _shopRecommendationStarted,
      recommendationCount: _shopRecommendations.length,
      savedShopCount: saved.shops.length,
      shopSaved: true,
    );
    setState(() {});
  }

  void _setShopRecommendationMode(_ShopRecommendationMode mode) {
    if (_shopRecommendationMode == mode) return;
    setState(() {
      _shopRecommendationMode = mode;
      _shopRecommendationStarted = false;
      _shopRecommendationFailedReason = null;
      _shopRecommendations = const [];
    });
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
                      mode: _shopRecommendationMode,
                      onModeChanged: _setShopRecommendationMode,
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
    required this.mode,
    required this.onModeChanged,
    required this.onSaveShop,
    required this.onSkip,
  });

  final bool isLoading;
  final List<ShopDiscoverySummary> recommendations;
  final String? failedReason;
  final bool recommendationStarted;
  final _ShopRecommendationMode mode;
  final ValueChanged<_ShopRecommendationMode> onModeChanged;
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
              '選んだジャンルと探し方から、保存しやすいショップを提案します。',
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
            _ShopRecommendationModePicker(
              selected: mode,
              onChanged: onModeChanged,
            ),
            const SizedBox(height: 8),
            Text(
              '探し方：${mode.label}\n${mode.description}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
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
              const _InlineShopIntroCard(candidateCount: 3)
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
                    reasonText: _recommendReasonFor(mode, summary, index),
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

class _ShopRecommendationModePicker extends StatelessWidget {
  const _ShopRecommendationModePicker({
    required this.selected,
    required this.onChanged,
  });

  final _ShopRecommendationMode selected;
  final ValueChanged<_ShopRecommendationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mode in _ShopRecommendationMode.values)
          ChoiceChip(
            label: Text(mode.label),
            selected: selected == mode,
            showCheckmark: false,
            selectedColor: AppColors.accentLight,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected == mode
                  ? AppColors.accentPrimary.withValues(alpha: 0.45)
                  : AppColors.divider.withValues(alpha: 0.9),
            ),
            labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected == mode
                  ? AppColors.accentPrimary
                  : AppColors.textSecondary,
              fontWeight: selected == mode ? FontWeight.w800 : FontWeight.w600,
            ),
            visualDensity: VisualDensity.compact,
            onSelected: (_) => onChanged(mode),
          ),
      ],
    );
  }
}

enum _ShopRecommendationMode {
  balance('バランス', '商品数・評価・レビュー数をもとに選んでいます', 'balance'),
  affordable('お手頃価格', '低〜中価格帯の商品が多いショップを優先します', 'affordable'),
  highlyRated('高評価', '平均評価とレビュー件数を優先します', 'highlyRated'),
  social('SNS映え', '画像つき商品や雑貨・インテリア寄りの商品を優先します', 'social'),
  practical('実用的', '日用品・食品など継続投稿しやすい商品を優先します', 'practical');

  const _ShopRecommendationMode(this.label, this.description, this.logValue);

  final String label;
  final String description;
  final String logValue;
}

RakutenProductSearchCondition _shopRecommendationCondition(
  List<String> genreIds,
  _ShopRecommendationMode mode,
) {
  final genreId = genreIds.isNotEmpty ? genreIds.first.trim() : '';
  final keyword = genreId.isEmpty ? _fallbackKeywordForMode(mode) : '';
  return RakutenProductSearchCondition(
    keyword: keyword,
    genreId: genreId.isNotEmpty ? genreId : null,
    maxPrice: mode == _ShopRecommendationMode.affordable ? 3500 : null,
    minReviewCount: mode == _ShopRecommendationMode.highlyRated ? 20 : null,
    minReviewAverage: mode == _ShopRecommendationMode.highlyRated ? 4.2 : null,
  ).normalized();
}

String _fallbackKeywordForMode(_ShopRecommendationMode mode) {
  switch (mode) {
    case _ShopRecommendationMode.affordable:
      return '日用品 お得';
    case _ShopRecommendationMode.highlyRated:
      return '食品 高評価';
    case _ShopRecommendationMode.social:
      return '雑貨 インテリア';
    case _ShopRecommendationMode.practical:
      return '日用品 キッチン 食品';
    case _ShopRecommendationMode.balance:
      return '日用品 キッチン ベビー 食品';
  }
}

List<ShopDiscoverySummary> _rankShopRecommendations(
  List<ShopDiscoverySummary> source,
  _ShopRecommendationMode mode,
) {
  final out = [...source];
  switch (mode) {
    case _ShopRecommendationMode.affordable:
      out.sort((a, b) => b.hitItemCount.compareTo(a.hitItemCount));
      break;
    case _ShopRecommendationMode.highlyRated:
      out.sort((a, b) {
        final avg = b.avgReviewAverage.compareTo(a.avgReviewAverage);
        if (avg != 0) return avg;
        return b.maxReviewCount.compareTo(a.maxReviewCount);
      });
      break;
    case _ShopRecommendationMode.social:
      out.sort((a, b) {
        final bi = b.representativeItems
            .where((e) => e.imageUrl.trim().isNotEmpty)
            .length;
        final ai = a.representativeItems
            .where((e) => e.imageUrl.trim().isNotEmpty)
            .length;
        final byImage = bi.compareTo(ai);
        if (byImage != 0) return byImage;
        return b.discoveryScore.compareTo(a.discoveryScore);
      });
      break;
    case _ShopRecommendationMode.practical:
    case _ShopRecommendationMode.balance:
      out.sort((a, b) => b.discoveryScore.compareTo(a.discoveryScore));
      break;
  }
  return out.take(5).toList(growable: false);
}

String _recommendReasonFor(
  _ShopRecommendationMode mode,
  ShopDiscoverySummary summary,
  int index,
) {
  switch (mode) {
    case _ShopRecommendationMode.affordable:
      return 'お手頃価格の商品が多いショップです';
    case _ShopRecommendationMode.highlyRated:
      return 'レビュー数が多く、候補探しに使いやすいショップです';
    case _ShopRecommendationMode.social:
      return summary.representativeItems.any(
            (e) => e.imageUrl.trim().isNotEmpty,
          )
          ? '画像つきの商品が多く、SNS投稿に向いています'
          : '雑貨・インテリア寄りの商品を探しやすいショップです';
    case _ShopRecommendationMode.practical:
      return '継続投稿しやすい実用ジャンルの商品が多いショップです';
    case _ShopRecommendationMode.balance:
      return index == 0 ? '選択ジャンルに近い商品が多いショップです' : '商品数・評価・レビュー数のバランスが良いショップです';
  }
}
