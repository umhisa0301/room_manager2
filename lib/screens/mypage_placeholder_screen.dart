
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/demo_mode.dart';
import '../config/dev_automation_config.dart';
import '../services/dev_automation_visible_run.dart';
import '../models/user_profile.dart';
import '../models/operation_tutorial_id.dart';
import '../repository/easy_initial_setup_repository.dart';
import '../repository/operation_tutorial_repository.dart';
import '../services/room_profile_url_validation_service.dart';
import '../services/app_action_service.dart';
import '../utils/app_input_limits.dart';
import '../utils/favorite_genre_pref.dart';
import '../utils/favorite_genre_selection_policy.dart';
import '../utils/genre_pref_log.dart';
import '../state/saved_shop_provider.dart';
import '../state/user_profile_provider.dart';
import '../state/room_recommendation_profile_provider.dart';
import '../state/operation_tutorial_controller.dart';
import '../services/room_diagnosis_service.dart';
import '../data/room_type_definitions.dart';
import '../widgets/room_type_diagnosis_widgets.dart';
import 'room_type_diagnosis_screen.dart';
import '../theme/app_theme.dart';
import '../theme/mypage_screen_tokens.dart';
import '../utils/user_profile_genre_migration.dart';
import '../utils/onboarding_ui_log.dart';
import '../widgets/genre_drilldown_picker_sheet.dart';
import '../widgets/post_style_picker_sheet.dart';
import '../widgets/app_text_field.dart';
import '../widgets/mypage/mypage_widgets.dart';
import 'closed_test_demo_screen.dart';
import 'dev_automation_screen.dart';
import 'easy_initial_setup_screen.dart';
import 'monetization_plan_screen.dart';
import 'saved_shops_screen.dart';

export '../widgets/mypage/mypage_widgets.dart' show MyPageSettingsSection;

/// マイページ：設定・プラン・サポートのハブ。
class MypagePlaceholderScreen extends StatefulWidget {
  const MypagePlaceholderScreen({super.key});

  @override
  State<MypagePlaceholderScreen> createState() => _MypagePlaceholderScreenState();
}

class _MypagePlaceholderScreenState extends State<MypagePlaceholderScreen> {
  bool _setupPromptDismissed = false;

  Future<void> _openPostStylePickerSheet(BuildContext context) async {
    final profile = context.read<UserProfileProvider>().profile;
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PostStylePickerSheet(
        initialSelectedKeys: profile.postStyleList,
      ),
    );
    if (picked == null || !context.mounted) return;
    final base = context.read<UserProfileProvider>().profile;
    final next = UserProfile(
      displayName: base.displayName,
      age: base.age,
      genderKey: base.genderKey,
      occupation: base.occupation,
      favoriteGenres: base.favoriteGenres,
      favoriteGenreIds: base.favoriteGenreIds,
      postStyles: picked.where(UserProfile.postStyleKeys.contains).take(1).join('、'),
      roomUrl: base.roomUrl,
    );
    await context.read<UserProfileProvider>().saveProfile(next);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('探し方を保存しました')),
    );
  }

  Future<void> _openProfileEditSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => const ProfileEditSheet(),
    );
  }

  Future<void> _openRoomUrlEditSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => const RoomUrlEditSheet(),
    );
  }

  Future<void> _openFavoriteGenrePickerSheet(BuildContext context) async {
    final profile = context.read<UserProfileProvider>().profile;
    final initialIds = _profileFavoriteGenreIds(profile);
    if (kDebugMode) {
      debugPrint(
        '[MYPAGE_GENRE_TREE_OPEN] source=mypage initialCount=${initialIds.length}',
      );
    }
    final picked = await GenreDrilldownPickerSheet.showMulti(
      context,
      initialSelectedIds: initialIds,
      maxSelectable: FavoriteGenreSelectionPolicy.maxSelectable,
      source: 'mypage',
    );
    if (picked == null || !context.mounted) return;
    if (kDebugMode) {
      debugPrint(
        '[MYPAGE_GENRE_TREE_SELECT] count=${picked.length} ids=${picked.join(',')}',
      );
    }
    await _saveFavoriteGenres(
      context,
      picked,
      context.read<UserProfileProvider>().profile,
    );
  }

  Future<void> _saveFavoriteGenres(
    BuildContext context,
    List<String> picked,
    UserProfile base,
  ) async {
    final idList = picked
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(5)
        .toList(growable: false);
    final next = FavoriteGenrePref.profileWithFavoriteGenres(
      base: base,
      genreIds: idList,
      source: 'mypage',
    );
    await context.read<UserProfileProvider>().saveProfile(next);
    final savedNames = next.favoriteGenreList;
    if (kDebugMode) {
      debugPrint(
        '[MYPAGE_GENRE_SAVE] count=${idList.length} ids=${idList.join(',')} '
        'names=${savedNames.join(',')}',
      );
    }
    for (var i = 0; i < idList.length; i++) {
      GenrePrefLog.logSave(
        selectedGenreId: idList[i],
        selectedGenreName: i < savedNames.length ? savedNames[i] : '',
        source: 'mypage',
      );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('好きなジャンルを保存しました')));
  }

  void _openClosedTestDemo(BuildContext context) {
    ensureClosedTestDemoAvailable();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ClosedTestDemoScreen()),
    );
  }

  Future<void> _openDevAutomation(BuildContext context) async {
    if (!DevAutomationFlags.isEnabled) return;
    ensureDevAutomationAvailable();
    final iterations = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(builder: (_) => const DevAutomationScreen()),
    );
    if (iterations == null || !context.mounted) return;
    await DevAutomationVisibleRun.startTabTourProductSearch(
      context: context,
      iterations: iterations,
    );
  }

  void _openEasyInitialSetup(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const EasyInitialSetupScreen(
          embeddedInEntryHost: false,
          initialPageIndex: 0,
        ),
      ),
    );
  }

  void _openMonetizationPlan(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MonetizationPlanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad =
        MediaQuery.paddingOf(context).bottom + MyPageScreenUi.navReserve;
    return Scaffold(
      backgroundColor: MyPageScreenUi.canvas,
      appBar: AppBar(
        title: const Text('マイページ'),
        backgroundColor: MyPageScreenUi.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Consumer4<UserProfileProvider, SavedShopProvider,
            EasyInitialSetupRepository, OperationTutorialRepository>(
          builder: (context, profileProvider, saved, setup, tutorial, _) {
            final profile = profileProvider.profile;
            final missingRoomUrl = !profile.hasRoomUrl;
            final showMyPageSetupCard =
                !setup.initialSetupCompleted && missingRoomUrl;
            final roomUrlFormat =
                RoomProfileUrlValidationService.validateFormat(profile.roomUrl);
            logOnboardingUi(
              route: 'myPage',
              termsAccepted: true,
              initialSetupCompleted: setup.initialSetupCompleted,
              initialSetupSkipped: setup.initialSetupSkipped,
              missingRoomUrl: missingRoomUrl,
              missingGenre: false,
              missingSavedShop: false,
              showMyPageSetupCard: showMyPageSetupCard,
              roomUrlValidationResult: roomUrlFormat.logValue,
              roomProfileExists: missingRoomUrl ? 'skipped' : 'unknown',
            );

            void openSavedShops() {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedShopsScreen(),
                ),
              );
            }

            final profileTutorialDismissed =
                tutorial.isDismissed(OperationTutorialId.profile);
            final showSetupPrompt = showMyPageSetupCard &&
                !_setupPromptDismissed &&
                profileTutorialDismissed;

            Widget buildRoomSettingsCard() {
              return MyPageRoomSettingsCard(
                profile: profile,
                onEditNickname: () => _openProfileEditSheet(context),
                onEditRoomUrl: () => _openRoomUrlEditSheet(context),
              );
            }

            final recProfile =
                context.watch<RoomRecommendationProfileProvider>().profile;
            final isDiagnosed = recProfile?.isDiagnosed ?? false;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                MyPageScreenUi.screenPadH,
                MyPageScreenUi.gapSection,
                MyPageScreenUi.screenPadH,
                bottomPad,
              ),
              children: [
                if (showSetupPrompt) ...[
                  MyPageSetupIncompleteCard(
                    profile: profile,
                    savedShopCount: saved.shops.length,
                    onOpenSetup: () => _openEasyInitialSetup(context),
                    onLater: () =>
                        setState(() => _setupPromptDismissed = true),
                  ),
                  const SizedBox(height: MyPageScreenUi.gapSection),
                ],
                if (!showMyPageSetupCard) ...[
                  buildRoomSettingsCard(),
                  const SizedBox(height: MyPageScreenUi.gapSection),
                ],
                MyPageRoomTypeDiagnosisCard(
                  isDiagnosed: isDiagnosed,
                  typeDisplayName: isDiagnosed
                      ? RoomTypeDefinitions.displayNameFor(
                          recProfile!.primaryTypeId,
                        )
                      : '',
                  interestLabel: isDiagnosed
                      ? RoomDiagnosisService.interestCategoriesLabel(
                          recProfile!.interestCategoryIds,
                        )
                      : '',
                  priorityLabel: isDiagnosed
                      ? RoomDiagnosisService.priorityRulesLabel(
                          recProfile!.priorityRuleIds,
                        )
                      : '',
                  commentToneLabel: isDiagnosed
                      ? RoomDiagnosisService.commentToneLabel(
                          recProfile!.commentToneId,
                        )
                      : '',
                  onStartDiagnosis: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RoomTypeDiagnosisScreen(),
                      ),
                    );
                  },
                  onRetakeDiagnosis: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RoomTypeDiagnosisScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: MyPageScreenUi.gapSection),
                MyPageSettingsSection(
                  onOpenPlan: () => _openMonetizationPlan(context),
                  onOpenDemo: kClosedTestDemoAvailable
                      ? () => _openClosedTestDemo(context)
                      : null,
                  onOpenDevAutomation: DevAutomationFlags.isEnabled
                      ? () => _openDevAutomation(context)
                      : null,
                  onOpenInitialSetup: () => _openEasyInitialSetup(context),
                  onOpenSavedShops: openSavedShops,
                  onOpenTutorialReplay: () {
                    context
                        .read<OperationTutorialController>()
                        .startProfileTutorial(forceReplay: true);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ProfileEditSheet extends StatefulWidget {
  const ProfileEditSheet({super.key});

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final p = context.read<UserProfileProvider>().profile;
    _nameController = TextEditingController(text: p.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final base = context.read<UserProfileProvider>().profile;
    final next = UserProfile(
      displayName: _nameController.text.trim(),
      age: base.age,
      genderKey: base.genderKey,
      occupation: base.occupation,
      favoriteGenres: base.favoriteGenres,
      favoriteGenreIds: base.favoriteGenreIds,
      postStyles: base.postStyles,
      roomUrl: base.roomUrl,
    );
    final messenger = ScaffoldMessenger.of(context);
    await context.read<UserProfileProvider>().saveProfile(next);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('プロフィールを保存しました')));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MyPageScreenUi.overlayTheme(Theme.of(context)),
      child: _SheetScaffold(
        title: 'ニックネームを編集',
        body: [
          AppTextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            labelText: 'ニックネーム（任意）',
            hintText: '例: ルーマネ',
            focusedBorderColor: MyPageScreenUi.primary,
          ),
        const SizedBox(height: 8),
        Text(
          'AIのおすすめ文や投稿文に使用します。未設定でもすべての機能を使えます。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
        primaryLabel: '保存',
        onPrimary: _save,
      ),
    );
  }
}

class RoomUrlEditSheet extends StatefulWidget {
  const RoomUrlEditSheet({super.key, this.successMessage = 'ROOM URLを保存しました'});

  final String successMessage;

  @override
  State<RoomUrlEditSheet> createState() => _RoomUrlEditSheetState();
}

class _RoomUrlEditSheetState extends State<RoomUrlEditSheet> {
  late final TextEditingController _roomUrlController;
  bool _isCheckingRoomProfile = false;
  String? _roomUrlErrorText;

  @override
  void initState() {
    super.initState();
    _roomUrlController = TextEditingController(
      text: context.read<UserProfileProvider>().profile.roomUrl,
    );
    AppInputLimits.logApplied(
      screen: 'myPage',
      field: 'roomUrl',
      maxLength: AppInputLimits.roomUrlMax,
      keyboardType: 'url',
      formatter: 'url',
    );
  }

  @override
  void dispose() {
    _roomUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isCheckingRoomProfile) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final base = context.read<UserProfileProvider>().profile;
    final rawUrl = _roomUrlController.text.trim();
    final format = RoomProfileUrlValidationService.validateFormat(rawUrl);
    setState(() {
      _roomUrlErrorText = format.errorMessage;
    });
    if (!format.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(RoomProfileUrlValidationService.formatErrorMessage),
        ),
      );
      return;
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
      if (!mounted) return;
      setState(() {
        _isCheckingRoomProfile = false;
        _roomUrlErrorText = exists.canSave ? null : exists.message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(exists.message)));
      if (!exists.canSave) {
        return;
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
    final messenger = ScaffoldMessenger.of(context);
    await context.read<UserProfileProvider>().saveProfile(next);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(widget.successMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final format = RoomProfileUrlValidationService.validateFormat(
      _roomUrlController.text,
    );
    final hasUrl = _roomUrlController.text.trim().isNotEmpty && format.isValid;
    return Theme(
      data: MyPageScreenUi.overlayTheme(Theme.of(context)),
      child: _SheetScaffold(
        title: 'ROOMプロフィールを登録',
        body: [
          AppTextField(
            controller: _roomUrlController,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.url,
            labelText: 'ROOMプロフィールURL（任意）',
            hintText: '例: https://room.rakuten.co.jp/xxxx',
            maxLength: AppInputLimits.roomUrlMax,
            inputFormatters: AppInputLimits.urlFormatters(
              maxLength: AppInputLimits.roomUrlMax,
            ),
            errorText: _roomUrlErrorText,
            focusedBorderColor: MyPageScreenUi.primary,
            onChanged: (_) => setState(() {
              _roomUrlErrorText = null;
            }),
          ),
        if (_isCheckingRoomProfile || _roomUrlErrorText != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (_isCheckingRoomProfile) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  '確認中...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                    _roomUrlErrorText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'あなたのROOM投稿を自動で記録します。投稿済み判定や重複防止に使えます。未入力でも保存できます。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        MyPageOutlineButton(
          label: 'ROOMを開く',
          onPressed: hasUrl
              ? () => AppActionService.openUrl(
                  context,
                  url: _roomUrlController.text.trim(),
                )
              : null,
          icon: const Icon(Icons.open_in_new_rounded),
          height: 42,
        ),
      ],
      primaryLabel: '保存',
      onPrimary: _save,
      primaryEnabled: !_isCheckingRoomProfile,
      isPrimaryLoading: _isCheckingRoomProfile,
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryEnabled = true,
    this.isPrimaryLoading = false,
  });

  final String title;
  final List<Widget> body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryEnabled;
  final bool isPrimaryLoading;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...body,
              const SizedBox(height: 16),
              MyPagePrimaryButton(
                label: primaryLabel,
                onPressed: primaryEnabled ? onPrimary : null,
                isLoading: isPrimaryLoading,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: MyPageScreenUi.outlineButtonStyle(height: 44),
                child: const Text('閉じる'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _profileFavoriteGenreIds(UserProfile profile) {
  final ids = <String>[...profile.favoriteGenreIdList];
  if (ids.isEmpty && profile.favoriteGenres.trim().isNotEmpty) {
    ids.addAll(
      UserProfileGenreMigration.idsFromLegacyFavoriteGenresText(
        profile.favoriteGenres,
      ),
    );
  }
  return ids.take(5).toList(growable: false);
}
