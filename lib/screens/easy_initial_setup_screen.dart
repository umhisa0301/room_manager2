import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_product_search_condition.dart';
import '../models/shop_discovery_summary.dart';
import '../models/user_profile.dart';
import '../repository/easy_initial_setup_repository.dart';
import '../repository/product_catalog_repository.dart';
import '../repository/rakuten_search_repository.dart';
import '../services/room_profile_url_validation_service.dart';
import '../services/rakuten_genre_master_service.dart';
import '../services/shop_discovery_aggregator.dart';
import '../state/saved_shop_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../theme/mypage_screen_tokens.dart';
import '../utils/app_input_limits.dart';
import '../utils/favorite_genre_pref.dart';
import '../utils/favorite_genre_selection_policy.dart';
import '../utils/genre_pref_log.dart';
import '../utils/onboarding_ui_log.dart';
import '../utils/product_safety_filter.dart';
import '../utils/shop_pool_audit.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/genre_drilldown_picker_sheet.dart';
import '../widgets/mypage/mypage_widgets.dart';
import '../widgets/post_style_picker_sheet.dart';
import '../widgets/shop_discovery_card.dart';

/// 規約同意後の「かんたん初期設定」（スキップ可能）。
class EasyInitialSetupScreen extends StatefulWidget {
  const EasyInitialSetupScreen({
    super.key,
    this.embeddedInEntryHost = true,
    this.initialPageIndex,
  });

  /// true のときルートの [AppShell] の代わりに配置される。
  final bool embeddedInEntryHost;

  /// 指定時はこのページから開始する（マイページからの手動起動向け）。
  final int? initialPageIndex;

  @override
  State<EasyInitialSetupScreen> createState() => _EasyInitialSetupScreenState();
}

class _EasyInitialSetupScreenState extends State<EasyInitialSetupScreen> {
  PageController? _pageController;
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _roomUrlController = TextEditingController();
  Set<String> _postStyleKeys = <String>{};
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
  String? _lastPickedGenreIdInSession;

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  int _firstIncompletePage(UserProfile profile, int savedShopCount) {
    if (!profile.hasRoomUrl) return 1;
    if (profile.favoriteGenreIdList.isEmpty) return 2;
    if (savedShopCount <= 0) return 3;
    return 3;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageControllerAttached) return;
    _pageControllerAttached = true;
    final profile = context.read<UserProfileProvider>().profile;
    _nicknameController.text = profile.displayName;
    _postStyleKeys = profile.postStyleList.toSet();
    _roomUrlController.text = profile.roomUrl;
    final saved = context.read<SavedShopProvider>().shops.length;
    final start = widget.initialPageIndex ??
        (widget.embeddedInEntryHost
            ? 0
            : _firstIncompletePage(profile, saved));
    _pageIndex = start;
    _pageController = PageController(initialPage: start);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _nicknameController.dispose();
    _roomUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileStep(BuildContext context) async {
    final base = context.read<UserProfileProvider>().profile;
    final next = UserProfile(
      displayName: _nicknameController.text.trim(),
      age: base.age,
      genderKey: base.genderKey,
      occupation: base.occupation,
      favoriteGenres: base.favoriteGenres,
      favoriteGenreIds: base.favoriteGenreIds,
      postStyles: _postStyleKeys.take(1).join('、'),
      roomUrl: base.roomUrl,
    );
    await context.read<UserProfileProvider>().saveProfile(next);
  }

  Future<void> _persistDismissAndLeave(
    BuildContext context, {
    bool markCompleted = false,
    bool markSkipped = false,
  }) async {
    _dismissKeyboard();
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
    _dismissKeyboard();
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
      postStyles: base.postStyles,
      roomUrl: url,
    );
    await profileProv.saveProfile(next);
    return true;
  }

  Future<void> _openGenrePicker(BuildContext context) async {
    _dismissKeyboard();
    final base = context.read<UserProfileProvider>().profile;
    final profileProv = context.read<UserProfileProvider>();
    final initial = base.favoriteGenreIdList;
    GenrePrefLog.logInitialSetupGenreUiUnified(
      oldPickerVisible: false,
      treePickerVisible: true,
      reason: 'avoidDuplicateGenreSelectionArea',
    );
    final picked = await GenreDrilldownPickerSheet.showMulti(
      context,
      initialSelectedIds: initial,
      maxSelectable: FavoriteGenreSelectionPolicy.maxSelectable,
      source: 'initialSetup',
    );
    if (picked == null || !mounted) return;
    final idList = picked
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(5)
        .toList();
    final lastId = idList.isNotEmpty ? idList.last : null;
    final next = FavoriteGenrePref.profileWithFavoriteGenres(
      base: base,
      genreIds: idList,
      source: 'initialSetup',
    );
    await profileProv.saveProfile(next);
    final savedNames = next.favoriteGenreList;
    for (var i = 0; i < idList.length; i++) {
      GenrePrefLog.logSave(
        selectedGenreId: idList[i],
        selectedGenreName: i < savedNames.length ? savedNames[i] : '',
        source: 'initialSetup',
      );
    }
    if (!mounted) return;
    setState(() {
      _lastPickedGenreIdInSession = lastId;
      _shopRecommendationStarted = false;
      _shopRecommendationFailedReason = null;
      _shopRecommendations = const [];
    });
  }

  Future<void> _openPostStylePicker(BuildContext context) async {
    _dismissKeyboard();
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          PostStylePickerSheet(initialSelectedKeys: _postStyleKeys.toList()),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _postStyleKeys = picked
          .where(UserProfile.postStyleKeys.contains)
          .take(1)
          .toSet();
      _shopRecommendationStarted = false;
      _shopRecommendationFailedReason = null;
      _shopRecommendations = const [];
    });
    debugPrint(
      '[SEARCH_STYLE_SAVE] selected=${_postStyleKeys.isEmpty ? 'null' : _postStyleKeys.first}',
    );
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
      'step=4 '
      'selectedGenres=$selectedGenres '
      'postStyles=${context.read<UserProfileProvider>().profile.effectivePostStyleList.join(',')} '
      'recommendationStarted=$recommendationStarted '
      'recommendationCount=$recommendationCount '
      'savedShopCount=$savedShopCount '
      'shopSaved=$shopSaved '
      'failedReason=$failedReason',
    );
  }

  Future<void> _loadShopRecommendations(BuildContext context) async {
    if (_isLoadingShopRecommendations) return;
    _dismissKeyboard();
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
      GenrePrefLog.logLoad(
        favoriteGenreIds: profile.favoriteGenreIdList,
        favoriteGenreNames: profile.favoriteGenres.split(RegExp(r'[、,]+')),
        source: 'shopRecommend',
      );
      final shopGenre = _resolveInitialSetupShopRecommendGenre(
        profile.favoriteGenreIdList,
        lastPickedGenreId: _lastPickedGenreIdInSession,
      );
      GenrePrefLog.logInitialSetupGenreBinding(
        selectedGenreIds: profile.favoriteGenreIdList,
        selectedGenreNames: profile.favoriteGenreList,
        shopRecommendGenreId: shopGenre.genreId,
        shopRecommendGenreName: shopGenre.genreName,
        matched: shopGenre.matched,
        reason: shopGenre.reason,
      );
      final condition = _shopRecommendationCondition(
        shopGenre.genreId,
        profile.effectivePostStyleList,
        fallbackUsed: shopGenre.fallbackUsed,
        fallbackReason: shopGenre.fallbackReason,
      );
      logShopPoolSummaryFromProductCatalog(
        productCatalogRepository: context.read<ProductCatalogRepository>(),
        source: 'initialSetup',
        excludeSavedShopCodes: savedShopProvider.shops
            .map((e) => e.shopId.trim())
            .where((e) => e.isNotEmpty)
            .toSet(),
      );
      final rawItems = await searchRepository.search(condition: condition);
      final items = rawItems.where((item) {
        final blocked = ProductSafetyFilter.isBlockedProduct(
          itemName: item.itemName,
          shopName: item.shopName,
          genreName: item.genreName,
          itemUrl: item.itemUrl,
          affiliateUrl: item.affiliateUrl,
        );
        if (blocked) {
          ProductSafetyFilter.logFilter(
            source: 'shopRecommend',
            itemCode: item.productId,
            title: item.itemName,
            shopName: item.shopName,
            genreName: item.genreName,
            blocked: true,
            reasons: ProductSafetyFilter.blockedReasons(
              itemName: item.itemName,
              shopName: item.shopName,
              genreName: item.genreName,
            ),
          );
        }
        return !blocked;
      }).toList(growable: false);
      if (!mounted) return;
      final recs = _rankShopRecommendations(
        ShopDiscoveryAggregator.aggregate(items, shopLimit: 5, itemsPerShop: 3),
        profile.effectivePostStyleList,
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
          'reason=${imageItems.isEmpty ? 'imageUrlsEmpty' : profile.effectivePostStyleList.join(',')}',
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
    _dismissKeyboard();
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

  void _goNext(BuildContext context) async {
    _dismissKeyboard();
    if (_pageIndex == 0) {
      await _saveProfileStep(context);
      if (!mounted) return;
      _pageController!.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_pageIndex == 1) {
      final saved = await _saveRoomUrlStep(context);
      if (!mounted) return;
      if (!saved) return;
      _pageController!.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_pageIndex == 2) {
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
    _dismissKeyboard();
    if (_pageIndex >= 3) {
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
      final styleCount = _postStyleKeys.length;
      return [
        MyPagePrimaryButton(
          label: styleCount == 0 ? '探し方を選ぶ' : 'この探し方で次へ',
          height: 48,
          onPressed: styleCount == 0
              ? () => _openPostStylePicker(context)
              : () => _goNext(context),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: styleCount == 0
                ? () => _skipStep(context)
                : () => _openPostStylePicker(context),
            child: Text(styleCount == 0 ? 'スキップして次へ' : '変更する'),
          ),
        ),
      ];
    }
    if (_pageIndex == 1) {
      return [
        MyPagePrimaryButton(
          label: '保存して次へ',
          height: 48,
          isLoading: _isCheckingRoomProfile,
          onPressed: _isCheckingRoomProfile ? null : () => _goNext(context),
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
    if (_pageIndex == 2) {
      final hasGenres = profile.favoriteGenreIdList.isNotEmpty;
      return [
        MyPagePrimaryButton(
          label: hasGenres
              ? '${profile.favoriteGenreIdList.length}件で次へ'
              : 'ジャンルを選ぶ',
          height: 48,
          onPressed: hasGenres
              ? () => _goNext(context)
              : () => _openGenrePicker(context),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: hasGenres
                ? () => _openGenrePicker(context)
                : () => _skipStep(context),
            child: Text(hasGenres ? '変更する' : 'スキップして次へ'),
          ),
        ),
      ];
    }
    final savedShopCount = context.watch<SavedShopProvider>().shops.length;
    return [
      MyPagePrimaryButton(
        label: _shopRecommendationStarted
            ? savedShopCount > 0
                  ? '保存したショップで始める'
                  : 'おすすめショップを保存して始める'
            : 'おすすめショップを見る',
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
    Future<bool> handleWillPop() async {
      _dismissKeyboard();
      if (_pageIndex > 0) {
        await _pageController?.previousPage(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        return false;
      }
      return true;
    }

    return Scaffold(
      backgroundColor: MyPageScreenUi.canvas,
      appBar: AppBar(
        title: const Text('プロフィール設定'),
        backgroundColor: MyPageScreenUi.canvas,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !widget.embeddedInEntryHost,
        leading: _pageIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  _dismissKeyboard();
                  _pageController?.previousPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
              )
            : null,
      ),
      body: PopScope(
        canPop: _pageIndex == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          handleWillPop();
        },
        child: SafeArea(
          child: Theme(
            data: MyPageScreenUi.overlayTheme(theme),
            child: _DismissKeyboardOnInteract(
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
                      _StepDot(
                        active: _pageIndex == 0,
                        enabled: true,
                        label: '1',
                        onTap: () => _jumpToStep(0),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.divider.withValues(alpha: 0.7),
                        ),
                      ),
                      _StepDot(
                        active: _pageIndex == 1,
                        enabled: _pageIndex >= 1,
                        label: '2',
                        onTap: () => _jumpToStep(1),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.divider.withValues(alpha: 0.7),
                        ),
                      ),
                      _StepDot(
                        active: _pageIndex == 2,
                        enabled: _pageIndex >= 2,
                        label: '3',
                        onTap: () => _jumpToStep(2),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.divider.withValues(alpha: 0.7),
                        ),
                      ),
                      _StepDot(
                        active: _pageIndex == 3,
                        enabled: _pageIndex >= 3,
                        label: '4',
                        onTap: () => _jumpToStep(3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: PageView(
                      controller: controller,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) {
                        _dismissKeyboard();
                        setState(() => _pageIndex = i);
                      },
                      children: [
                        _StepProfile(
                          controller: _nicknameController,
                          postStyleKeys: _postStyleKeys,
                          onPickPostStyles: () => _openPostStylePicker(context),
                        ),
                        _StepRoomUrl(
                          controller: _roomUrlController,
                          errorText: _roomUrlErrorText,
                          isChecking: _isCheckingRoomProfile,
                          onChanged: () => setState(() {}),
                        ),
                        _StepGenres(
                          onPickGenres: () => _openGenrePicker(context),
                        ),
                        _StepSavedShops(
                          isLoading: _isLoadingShopRecommendations,
                          recommendations: _shopRecommendations,
                          failedReason: _shopRecommendationFailedReason,
                          recommendationStarted: _shopRecommendationStarted,
                          onSaveShop: (summary) =>
                              _saveRecommendedShop(context, summary),
                          onSkip: () => _persistDismissAndLeave(
                            context,
                            markSkipped: true,
                          ),
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
        ),
        ),
      ),
    );
  }

  void _jumpToStep(int index) {
    if (index > _pageIndex) return;
    _dismissKeyboard();
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.active,
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = active ? Colors.white : AppColors.textTertiary;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: enabled ? onTap : null,
      child: CircleAvatar(
        radius: 14,
        backgroundColor: active
            ? MyPageScreenUi.primary
            : AppColors.surfaceVariant,
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: c),
        ),
      ),
    );
  }
}

class _DismissKeyboardOnInteract extends StatelessWidget {
  const _DismissKeyboardOnInteract({required this.child});

  final Widget child;

  bool _isTapInsideFocusedEditableText(TapDownDetails details) {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null) return false;
    final focusedWidget = focusedContext.widget;
    if (focusedWidget is! EditableText) return false;
    final renderObject = focusedContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = topLeft & renderObject.size;
    return rect.contains(details.globalPosition);
  }

  void _dismissOnTapOutsideEditable(TapDownDetails details) {
    if (_isTapInsideFocusedEditableText(details)) return;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _dismissOnTapOutsideEditable,
      child: child,
    );
  }
}

class _StepProfile extends StatelessWidget {
  const _StepProfile({
    required this.controller,
    required this.postStyleKeys,
    required this.onPickPostStyles,
  });

  final TextEditingController controller;
  final Set<String> postStyleKeys;
  final VoidCallback onPickPostStyles;

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
              'プロフィール',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ニックネームは、今後おすすめ文や投稿文の生成に使えます。\n探し方は、おすすめ候補やショップ提案の調整に使います。あとから変更できます。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'すべて後から変更できます。任意項目は未入力でも始められます。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: controller,
              labelText: 'ニックネーム（任意）',
              hintText: '例: ルーマネ',
              textInputAction: TextInputAction.done,
              focusedBorderColor: MyPageScreenUi.primary,
            ),
            const SizedBox(height: 12),
            _PostStyleSummary(
              selectedKeys: postStyleKeys.toList(growable: false),
              onPick: onPickPostStyles,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostStyleSummary extends StatelessWidget {
  const _PostStyleSummary({required this.selectedKeys, required this.onPick});

  final List<String> selectedKeys;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '探し方（1つ選べます）',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (selectedKeys.isEmpty)
          Text(
            '未選択の場合は内部的に「バランス」として扱います。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
              height: 1.35,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in selectedKeys)
                Chip(
                  label: Text(UserProfile.postStyleLabelJa(key)),
                  backgroundColor: MyPageScreenUi.primaryLight,
                  labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: MyPageScreenUi.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 10),
        MyPageOutlineButton(
          label: selectedKeys.isEmpty ? '探し方を選ぶ' : '探し方を変更',
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          height: 44,
          onPressed: onPick,
        ),
      ],
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
              'あなたのROOM投稿を自動で記録します。投稿済み判定や重複防止に使えます。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'すべて後から変更できます。任意項目は未入力でも始められます。',
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
              keyboardType: TextInputType.url,
              maxLength: AppInputLimits.roomUrlMax,
              inputFormatters: AppInputLimits.urlFormatters(
                maxLength: AppInputLimits.roomUrlMax,
              ),
              errorText: errorText,
              focusedBorderColor: MyPageScreenUi.primary,
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MyPageScreenUi.primary,
                      ),
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
            const SizedBox(height: 6),
            Text(
              'すべて後から変更できます。任意項目は未入力でも始められます。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                height: 1.35,
                fontWeight: FontWeight.w700,
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
            MyPageOutlineButton(
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
    final profile = context.watch<UserProfileProvider>().profile;
    final styleLabels = profile.effectivePostStyleList
        .map(UserProfile.postStyleLabelJa)
        .toList(growable: false);
    final genreLabels = _genreLabelsForShopSummary(profile);
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
              'よく使うショップを保存すると、店内検索から候補を探しやすくなります。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'すべて後から変更できます。任意項目は未入力でも始められます。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _ShopConditionSummary(
              styleLabels: styleLabels,
              genreLabels: genreLabels,
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
                    reasonText: _recommendReasonFor(
                      profile.effectivePostStyleList,
                      summary,
                      index,
                    ),
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
        color: MyPageScreenUi.noticeFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MyPageScreenUi.noticeBorder,
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
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: MyPageScreenUi.primary,
            ),
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
          OutlinedButton(
            onPressed: onSkip,
            style: OutlinedButton.styleFrom(
              foregroundColor: MyPageScreenUi.textSecondary,
              minimumSize: const Size(double.infinity, 40),
              side: BorderSide(color: MyPageScreenUi.cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            child: const Text('あとで設定する'),
          ),
        ],
      ),
    );
  }
}

class _ShopConditionSummary extends StatelessWidget {
  const _ShopConditionSummary({
    required this.styleLabels,
    required this.genreLabels,
  });

  final List<String> styleLabels;
  final List<String> genreLabels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '現在の条件',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _ConditionLabelRow(title: '探し方', labels: styleLabels),
          const SizedBox(height: 8),
          _ConditionLabelRow(
            title: 'ジャンル',
            labels: genreLabels.isEmpty ? const ['未設定'] : genreLabels,
          ),
          const SizedBox(height: 10),
          Text(
            'これらをもとに、保存しやすいショップを提案しています。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionLabelRow extends StatelessWidget {
  const _ConditionLabelRow({required this.title, required this.labels});

  final String title;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final label in labels) _ConditionLabelChip(label: label),
          ],
        ),
      ],
    );
  }
}

class _ConditionLabelChip extends StatelessWidget {
  const _ConditionLabelChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.85)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

List<String> _genreLabelsForShopSummary(UserProfile profile) {
  final names = profile.favoriteGenreList;
  if (names.isNotEmpty) return names.take(3).toList(growable: false);

  final service = RakutenGenreMasterService.instance;
  return profile.favoriteGenreIdList
      .map(service.getGenreNameById)
      .where(
        (name) =>
            name.isNotEmpty &&
            name != RakutenGenreMasterService.unknownGenreDisplayLabel,
      )
      .take(3)
      .toList(growable: false);
}

({String genreId, String genreName, bool matched, String reason, bool fallbackUsed, String fallbackReason})
    _resolveInitialSetupShopRecommendGenre(
  List<String> genreIds, {
  String? lastPickedGenreId,
}) {
  final svc = RakutenGenreMasterService.instance;
  final cleaned = genreIds
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
  if (cleaned.isEmpty) {
    GenrePrefLog.logInitialSetupShopRecommendGenre(
      genreId: '',
      genreName: '',
      fallbackUsed: true,
      fallbackReason: 'noGenreSelected',
    );
    return (
      genreId: '',
      genreName: '',
      matched: true,
      reason: 'noGenreSelected',
      fallbackUsed: true,
      fallbackReason: 'noGenreSelected',
    );
  }
  final preferred = lastPickedGenreId?.trim() ?? '';
  final chosen = preferred.isNotEmpty && cleaned.contains(preferred)
      ? preferred
      : cleaned.last;
  final name = svc.getGenreNameById(chosen);
  final displayName = name.isNotEmpty &&
          name != RakutenGenreMasterService.unknownGenreDisplayLabel
      ? name
      : chosen;
  GenrePrefLog.logInitialSetupShopRecommendGenre(
    genreId: chosen,
    genreName: displayName,
    fallbackUsed: false,
    fallbackReason: preferred.isNotEmpty ? 'lastPickedInSession' : 'lastInSavedList',
  );
  return (
    genreId: chosen,
    genreName: displayName,
    matched: true,
    reason: preferred.isNotEmpty ? 'lastPickedInSession' : 'lastInSavedList',
    fallbackUsed: false,
    fallbackReason: '',
  );
}

RakutenProductSearchCondition _shopRecommendationCondition(
  String genreId,
  List<String> postStyleKeys, {
  required bool fallbackUsed,
  required String fallbackReason,
}) {
  final gid = genreId.trim();
  final styles = postStyleKeys.isEmpty
      ? const [UserProfile.postStyleBalance]
      : postStyleKeys;
  final keyword = gid.isEmpty ? _fallbackKeywordForStyles(styles) : '';
  if (gid.isEmpty) {
    GenrePrefLog.logInitialSetupShopRecommendGenre(
      genreId: '',
      genreName: '',
      fallbackUsed: true,
      fallbackReason: fallbackReason.isNotEmpty ? fallbackReason : 'keywordFallback',
    );
  }
  return RakutenProductSearchCondition(
    keyword: keyword,
    genreId: gid.isNotEmpty ? gid : null,
    maxPrice: styles.contains(UserProfile.postStyleAffordable) ? 3500 : null,
    minPrice: styles.contains(UserProfile.postStylePremium) ? 5000 : null,
    minReviewCount:
        styles.contains(UserProfile.postStyleHighlyRated) ||
            styles.contains(UserProfile.postStyleReviewRich)
        ? 20
        : null,
    minReviewAverage: styles.contains(UserProfile.postStyleHighlyRated)
        ? 4.2
        : null,
    sort: _sortForPostStyles(styles),
  ).normalized();
}

String _fallbackKeywordForStyles(List<String> styles) {
  if (styles.contains(UserProfile.postStyleSocial)) return '雑貨 インテリア';
  if (styles.contains(UserProfile.postStylePractical)) {
    return '日用品 キッチン 食品';
  }
  if (styles.contains(UserProfile.postStyleAffordable)) return '日用品 お得';
  if (styles.contains(UserProfile.postStylePremium)) return '家電 美容 高級';
  if (styles.contains(UserProfile.postStyleHighlyRated)) return '食品 高評価';
  if (styles.contains(UserProfile.postStyleTrend)) return '季節 新着 トレンド';
  return '日用品 キッチン ベビー 食品';
}

String? _sortForPostStyles(List<String> styles) {
  if (styles.contains(UserProfile.postStyleAffordable)) return '+itemPrice';
  if (styles.contains(UserProfile.postStylePremium)) return '-itemPrice';
  if (styles.contains(UserProfile.postStyleHighlyRated)) {
    return '-reviewAverage';
  }
  if (styles.contains(UserProfile.postStyleReviewRich)) return '-reviewCount';
  if (styles.contains(UserProfile.postStyleTrend)) return '-updateTimestamp';
  return null;
}

List<ShopDiscoverySummary> _rankShopRecommendations(
  List<ShopDiscoverySummary> source,
  List<String> postStyleKeys,
) {
  final out = [...source];
  final styles = postStyleKeys.isEmpty
      ? const [UserProfile.postStyleBalance]
      : postStyleKeys;
  if (styles.contains(UserProfile.postStyleSocial)) {
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
  } else if (styles.contains(UserProfile.postStyleHighlyRated) ||
      styles.contains(UserProfile.postStyleReviewRich)) {
    out.sort((a, b) {
      final avg = b.avgReviewAverage.compareTo(a.avgReviewAverage);
      if (avg != 0) return avg;
      return b.maxReviewCount.compareTo(a.maxReviewCount);
    });
  } else if (styles.contains(UserProfile.postStyleAffordable)) {
    out.sort((a, b) => b.hitItemCount.compareTo(a.hitItemCount));
  } else {
    out.sort((a, b) => b.discoveryScore.compareTo(a.discoveryScore));
  }
  return out.take(5).toList(growable: false);
}

String _recommendReasonFor(
  List<String> postStyleKeys,
  ShopDiscoverySummary summary,
  int index,
) {
  final styles = postStyleKeys.isEmpty
      ? const [UserProfile.postStyleBalance]
      : postStyleKeys;
  if (styles.contains(UserProfile.postStyleAffordable)) {
    return '買いやすい価格の商品が多いショップです';
  }
  if (styles.contains(UserProfile.postStylePremium)) {
    return '高単価の商品を探しやすいショップです';
  }
  if (styles.contains(UserProfile.postStyleHighlyRated)) {
    return '高評価の商品が多いショップです';
  }
  if (styles.contains(UserProfile.postStyleReviewRich)) {
    return 'レビュー件数が多く、紹介しやすい商品が多いショップです';
  }
  if (styles.contains(UserProfile.postStyleSocial)) {
    return summary.representativeItems.any((e) => e.imageUrl.trim().isNotEmpty)
        ? '見た目で選びやすい画像の商品が多いショップです'
        : '雑貨・インテリア寄りの商品を探しやすいショップです';
  }
  if (styles.contains(UserProfile.postStylePractical)) {
    return '継続投稿しやすい実用ジャンルの商品が多いショップです';
  }
  if (styles.contains(UserProfile.postStyleTrend)) {
    return '新しさや季節感を意識して候補を探しやすいショップです';
  }
  return index == 0 ? '選択ジャンルに近い商品が多いショップです' : '商品数・評価・レビュー数のバランスが良いショップです';
}
