import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/demo_mode.dart';
import '../constants/legal_urls.dart';
import '../models/rakuten_managed_product.dart';
import '../models/user_profile.dart';
import '../navigation/app_shell_controller.dart';
import '../repository/easy_initial_setup_repository.dart';
import '../services/room_profile_url_validation_service.dart';
import '../services/app_action_service.dart';
import '../services/room_import_collects_policy.dart';
import '../services/room_import_limit_policy.dart';
import '../widgets/room_import_enrichment_pending_hint.dart';
import '../utils/room_sync_button_visibility.dart';
import '../utils/room_sync_card_copy.dart';
import '../widgets/room_post_import_flow.dart';
import '../widgets/room_sync_last_reaction_summary.dart';
import '../services/rakuten_genre_master_service.dart';
import '../services/room_collect_post_limit.dart';
import '../state/activity_log_provider.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/room_activity_event_provider.dart';
import '../state/saved_shop_provider.dart';
import '../state/user_profile_provider.dart';
import '../state/bulk_operation_state_controller.dart';
import '../state/room_import_controller.dart';
import '../theme/app_theme.dart';
import '../utils/user_profile_genre_migration.dart';
import '../utils/onboarding_ui_log.dart';
import '../widgets/favorite_genre_picker_sheet.dart';
import '../widgets/post_style_picker_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import 'activity_placeholder_screen.dart';
import 'closed_test_demo_screen.dart';
import 'easy_initial_setup_screen.dart';
import 'saved_shops_screen.dart';

/// マイページ：設定・状態確認のハブ（ホームの行動・おすすめ導線はここでは持たない）。
class MypagePlaceholderScreen extends StatelessWidget {
  const MypagePlaceholderScreen({super.key});

  static const double _screenPadH = AppDimensions.screenPaddingH;
  static const double _gap = AppDimensions.spacingMd;
  static const double _navReserve = 64;

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

  Future<void> _openPostStylePickerSheet(BuildContext context) async {
    final profile = context.read<UserProfileProvider>().profile;
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) =>
          PostStylePickerSheet(initialSelectedKeys: profile.postStyleList),
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
      postStyles: picked
          .where(UserProfile.postStyleKeys.contains)
          .take(1)
          .join('、'),
      roomUrl: base.roomUrl,
    );
    debugPrint(
      '[SEARCH_STYLE_SAVE] selected=${picked.where(UserProfile.postStyleKeys.contains).take(1).join()}',
    );
    await context.read<UserProfileProvider>().saveProfile(next);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('探し方を保存しました')));
  }

  Future<void> _openFavoriteGenrePickerSheet(BuildContext context) async {
    final profile = context.read<UserProfileProvider>().profile;
    final initialIds = _profileFavoriteGenreIds(profile);
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final h = MediaQuery.sizeOf(sheetContext).height * 0.88;
        return SizedBox(
          height: h,
          child: FavoriteGenrePickerSheet(initialSelectedIds: initialIds),
        );
      },
    );
    if (picked == null || !context.mounted) return;
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
    final svc = RakutenGenreMasterService.instance;
    final ids = picked.map((e) => e.trim()).where((e) => e.isNotEmpty).take(5);
    final idList = ids.toList(growable: false);
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
      postStyles: base.postStyles,
      roomUrl: base.roomUrl,
    );
    await context.read<UserProfileProvider>().saveProfile(next);
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

  void _openEasyInitialSetup(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            const EasyInitialSetupScreen(embeddedInEntryHost: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom + _navReserve;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('マイページ')),
      body: SafeArea(
        top: false,
        child:
            Consumer6<
              UserProfileProvider,
              SavedShopProvider,
              RakutenManagedProductProvider,
              RoomActivityEventProvider,
              ActivityLogProvider,
              EasyInitialSetupRepository
            >(
              builder:
                  (
                    context,
                    profileProvider,
                    saved,
                    managed,
                    activityEvents,
                    activityLog,
                    setup,
                    _,
                  ) {
                    final profile = profileProvider.profile;
                    final missingRoomUrl = !profile.hasRoomUrl;
                    final missingGenre = profile.favoriteGenreIdList.isEmpty;
                    final missingSavedShop = saved.shops.isEmpty;
                    final showMyPageSetupCard =
                        !setup.initialSetupCompleted &&
                        (missingRoomUrl || missingGenre || missingSavedShop);
                    final roomUrlFormat =
                        RoomProfileUrlValidationService.validateFormat(
                          profile.roomUrl,
                        );
                    logOnboardingUi(
                      route: 'myPage',
                      termsAccepted: true,
                      initialSetupCompleted: setup.initialSetupCompleted,
                      initialSetupSkipped: setup.initialSetupSkipped,
                      missingRoomUrl: missingRoomUrl,
                      missingGenre: missingGenre,
                      missingSavedShop: missingSavedShop,
                      showMyPageSetupCard: showMyPageSetupCard,
                      roomUrlValidationResult: roomUrlFormat.logValue,
                      roomProfileExists: missingRoomUrl ? 'skipped' : 'unknown',
                    );
                    final candidateCount = managed.items
                        .where(
                          (e) =>
                              e.status == RakutenManagedProductStatus.candidate,
                        )
                        .length;
                    final doneCount = managed.items
                        .where(
                          (e) => e.status == RakutenManagedProductStatus.done,
                        )
                        .length;
                    final now = DateTime.now();
                    final todayPostCount = RoomCollectPostLimitSnapshot.compute(
                      items: managed.items,
                      events: activityEvents.events,
                      now: now,
                    ).todayCount;
                    final todayCommentCount =
                        activityLog.getTodayLog()?.commentCount ?? 0;

                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        _screenPadH,
                        AppDimensions.spacingMd,
                        _screenPadH,
                        bottomPad,
                      ),
                      children: [
                        if (showMyPageSetupCard) ...[
                          MyPageHeader(
                            profile: profile,
                            savedShopCount: saved.shops.length,
                            onOpenSetup: () => _openEasyInitialSetup(context),
                            onStepGenre: () =>
                                _openFavoriteGenrePickerSheet(context),
                            onStepRoom: () => _openRoomUrlEditSheet(context),
                            onStepProfile: () => _openProfileEditSheet(context),
                            onStepSavedShops: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SavedShopsScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: _gap),
                        ],
                        MyPageRegisteredContentCard(
                          profile: profile,
                          savedShopCount: saved.shops.length,
                          onEditNickname: () => _openProfileEditSheet(context),
                          onEditPostStyles: () =>
                              _openPostStylePickerSheet(context),
                          onEditRoomUrl: () => _openRoomUrlEditSheet(context),
                          onEditGenres: () =>
                              _openFavoriteGenrePickerSheet(context),
                          onOpenSavedShops: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SavedShopsScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: _gap),
                        MyPageQuickSummaryCard(
                          candidateCount: candidateCount,
                          doneCount: doneCount,
                          savedShopCount: saved.shops.length,
                          todayCommentCount: todayCommentCount,
                          todayPostCount: todayPostCount,
                          onTapCandidates: () => context
                              .read<AppShellController>()
                              .openRoomCollect(initialTabIndex: 0),
                          onTapDone: () => context
                              .read<AppShellController>()
                              .openRoomCollect(initialTabIndex: 1),
                          onTapSavedShops: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SavedShopsScreen(),
                              ),
                            );
                          },
                          onTapTodayActivity: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const ActivityPlaceholderScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: _gap),
                        MyPageRoomSyncSection(
                          onEditRoomUrl: () => _openRoomUrlEditSheet(context),
                        ),
                        const SizedBox(height: _gap),
                        MyPageSettingsSection(
                          onOpenDemo: kClosedTestDemoAvailable
                              ? () => _openClosedTestDemo(context)
                              : null,
                          onOpenInitialSetup: () =>
                              _openEasyInitialSetup(context),
                        ),
                      ],
                    );
                  },
            ),
      ),
    );
  }
}

class MyPageHeader extends StatefulWidget {
  const MyPageHeader({
    super.key,
    required this.profile,
    required this.savedShopCount,
    required this.onOpenSetup,
    required this.onStepGenre,
    required this.onStepRoom,
    required this.onStepProfile,
    required this.onStepSavedShops,
  });

  final UserProfile profile;
  final int savedShopCount;
  final VoidCallback onOpenSetup;
  final VoidCallback onStepGenre;
  final VoidCallback onStepRoom;
  final VoidCallback onStepProfile;
  final VoidCallback onStepSavedShops;

  @override
  State<MyPageHeader> createState() => _MyPageHeaderState();
}

class _MyPageHeaderState extends State<MyPageHeader> {
  bool _isExpanded = false;

  static const Duration _expandDuration = Duration(milliseconds: 200);
  static const Curve _expandCurve = Curves.easeOutCubic;

  String _accuracySummaryLine(int remaining) {
    if (remaining <= 0) return '高';
    if (remaining == 1) return '中（あと1ステップ）';
    if (remaining == 2) return '中（あと2ステップ）';
    return '低（あと$remainingステップ）';
  }

  String _nextStepShortTitle(int firstIncomplete) {
    switch (firstIncomplete) {
      case 0:
        return 'ROOMプロフィールURL';
      case 1:
        return 'よく使うジャンル';
      case 2:
        return '保存ショップ';
      default:
        return '';
    }
  }

  String _collapsedNextStepLine(int firstIncomplete) {
    final t = _nextStepShortTitle(firstIncomplete);
    if (t.isEmpty) return '次：設定を進める';
    return '次：$t';
  }

  String _stepProgressDots(List<bool> stepDoneFlags) {
    final b = StringBuffer();
    for (final done in stepDoneFlags) {
      b.write(done ? '●' : '○');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final genreCount = widget.profile.favoriteGenreIdList.length;
    final hasGenres = genreCount > 0;
    final hasRoomUrl = widget.profile.hasRoomUrl;
    final savedDone = widget.savedShopCount > 0;

    final stepRoomDone = hasRoomUrl;
    final stepGenreDone = hasGenres;
    final stepSavedDone = savedDone;

    final stepDoneFlags = <bool>[stepRoomDone, stepGenreDone, stepSavedDone];
    final completedCount = stepDoneFlags.where((e) => e).length;
    final firstIncomplete = stepDoneFlags.indexWhere((e) => !e);
    final remaining = 3 - completedCount;
    final allDone = remaining == 0;

    if (allDone) {
      return AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'おすすめ精度：高',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '🎉 準備完了！おすすめ精度が最大になりました',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.success.withValues(alpha: 0.94),
                fontWeight: FontWeight.w800,
                height: 1.38,
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'おすすめ精度：${_accuracySummaryLine(remaining)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _collapsedNextStepLine(firstIncomplete),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.textSecondary,
                      size: 26,
                    ),
                  ],
                ),
              ),
            ),
          ),
          RepaintBoundary(
            child: ClipRect(
              child: AnimatedSize(
                duration: _expandDuration,
                curve: _expandCurve,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                child: _isExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 14),
                          Text(
                            '進捗：$completedCount / 3 完了',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _stepProgressDots(stepDoneFlags),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.88,
                                  ),
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 10),
                          _MyPageStepRow(
                            stepLabel: 'STEP1',
                            title: 'ROOMプロフィールURL',
                            description: 'ROOM投稿取り込みに使います。あとから変更できます。',
                            isDone: stepRoomDone,
                            isNextStep: firstIncomplete == 0,
                            onTap: widget.onStepRoom,
                          ),
                          const SizedBox(height: 8),
                          _MyPageStepRow(
                            stepLabel: 'STEP2',
                            title: 'よく使うジャンル',
                            description: 'おすすめ候補の精度が上がります。スキップできます。',
                            isDone: stepGenreDone,
                            isNextStep: firstIncomplete == 1,
                            onTap: widget.onStepGenre,
                          ),
                          const SizedBox(height: 8),
                          _MyPageStepRow(
                            stepLabel: 'STEP3',
                            title: '保存ショップ',
                            description: 'よく使うショップ内で商品を探しやすくなります。',
                            isDone: stepSavedDone,
                            isNextStep: firstIncomplete == 2,
                            onTap: widget.onStepSavedShops,
                          ),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppPrimaryButton(
            label: 'かんたん初期設定を再開',
            height: 46,
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: widget.onOpenSetup,
          ),
        ],
      ),
    );
  }
}

class _MyPageStepRow extends StatelessWidget {
  const _MyPageStepRow({
    required this.stepLabel,
    required this.title,
    required this.description,
    required this.isDone,
    required this.isNextStep,
    required this.onTap,
  });

  final String stepLabel;
  final String title;
  final String description;
  final bool isDone;
  final bool isNextStep;
  final VoidCallback onTap;

  static const Color _orange = Color(0xFFE65100);
  static const Color _orangeSurface = Color(0xFFFFF7E8);

  @override
  Widget build(BuildContext context) {
    final borderColor = isNextStep
        ? _orange
        : isDone
        ? AppColors.divider.withValues(alpha: 0.35)
        : AppColors.divider.withValues(alpha: 0.28);
    final borderW = isNextStep ? 2.0 : 1.0;
    final bg = isNextStep
        ? _orangeSurface
        : isDone
        ? AppColors.surfaceVariant.withValues(alpha: 0.22)
        : AppColors.surfaceVariant.withValues(alpha: 0.12);

    final stepStyleColor = isNextStep
        ? _orange
        : isDone
        ? AppColors.textSecondary.withValues(alpha: 0.5)
        : AppColors.textSecondary.withValues(alpha: 0.42);
    final titleStyleColor = isNextStep
        ? AppColors.textPrimary
        : isDone
        ? AppColors.textSecondary.withValues(alpha: 0.72)
        : AppColors.textSecondary.withValues(alpha: 0.48);
    final descStyleColor = isNextStep
        ? AppColors.textSecondary
        : AppColors.textSecondary.withValues(alpha: 0.45);

    final leadingIcon = isDone
        ? Icon(
            Icons.check_circle_rounded,
            color: AppColors.success.withValues(alpha: 0.72),
            size: 22,
          )
        : Icon(
            Icons.circle_outlined,
            color: isNextStep
                ? _orange
                : AppColors.textSecondary.withValues(alpha: 0.45),
            size: 22,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            border: Border.all(color: borderColor, width: borderW),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: leadingIcon,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stepLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: stepStyleColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: titleStyleColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: descStyleColor, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: isNextStep
                          ? _orange
                          : AppColors.textSecondary.withValues(alpha: 0.45),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyPageQuickSummaryCard extends StatelessWidget {
  const MyPageQuickSummaryCard({
    super.key,
    required this.savedShopCount,
    required this.candidateCount,
    required this.doneCount,
    required this.todayCommentCount,
    required this.todayPostCount,
    required this.onTapCandidates,
    required this.onTapDone,
    required this.onTapSavedShops,
    required this.onTapTodayActivity,
  });

  final int savedShopCount;
  final int candidateCount;
  final int doneCount;
  final int todayCommentCount;
  final int todayPostCount;
  final VoidCallback onTapCandidates;
  final VoidCallback onTapDone;
  final VoidCallback onTapSavedShops;
  final VoidCallback onTapTodayActivity;

  @override
  Widget build(BuildContext context) {
    final activityLine =
        '直近24時間のROOM投稿 $todayPostCount件 / コメントコピー $todayCommentCount回';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 10),
            blurRadius: 22,
          ),
        ],
      ),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(
              title: '状態サマリー',
              subtitle: 'タップで資産の詳細または活動ダッシュボードへ',
              icon: Icons.list_alt_outlined,
            ),
            const SizedBox(height: 10),
            _MyPageSummarySectionTitle(title: '資産（ストック）', dense: true),
            const SizedBox(height: 6),
            _SummaryListTile(
              icon: Icons.bookmark_add_outlined,
              label: 'コレ候補',
              value: '$candidateCount件',
              onTap: onTapCandidates,
            ),
            Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
            _SummaryListTile(
              icon: Icons.collections_bookmark_outlined,
              label: 'コレ済',
              value: '$doneCount件',
              onTap: onTapDone,
            ),
            Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
            _SummaryListTile(
              icon: Icons.bookmarks_outlined,
              label: '保存ショップ',
              value: '$savedShopCount件',
              onTap: onTapSavedShops,
            ),
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: AppColors.divider.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            _MyPageSummarySectionTitle(title: '今日の活動', dense: true),
            const SizedBox(height: 6),
            _MyPageTodayActivityListTile(
              title: '',
              detailLine: activityLine,
              subtitle: '活動タブで詳しく見られます',
              onTap: onTapTodayActivity,
            ),
          ],
        ),
      ),
    );
  }
}

class _MyPageSummarySectionTitle extends StatelessWidget {
  const _MyPageSummarySectionTitle({required this.title, this.dense = false});

  final String title;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w800,
      letterSpacing: dense ? 0.2 : 0.4,
    );
    return Text(title, style: style);
  }
}

class _MyPageTodayActivityListTile extends StatelessWidget {
  const _MyPageTodayActivityListTile({
    required this.title,
    required this.detailLine,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String detailLine;
  final String subtitle;
  final VoidCallback onTap;

  static const Color _boltColor = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentPrimary;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.bolt_rounded, size: 22, color: _boltColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty) ...[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    detailLine,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: AppColors.surfaceVariant.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        splashFactory: InkRipple.splashFactory,
        splashColor: accent.withValues(alpha: 0.34),
        highlightColor: accent.withValues(alpha: 0.14),
        child: content,
      ),
    );
  }
}

class _SummaryListTile extends StatelessWidget {
  const _SummaryListTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyPageRoomLinkCard extends StatelessWidget {
  const MyPageRoomLinkCard({
    super.key,
    required this.profile,
    required this.onEditRoomUrl,
  });

  final UserProfile profile;
  final VoidCallback onEditRoomUrl;

  @override
  Widget build(BuildContext context) {
    final url = profile.roomUrl.trim();
    final hasUrl = url.isNotEmpty;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: hasUrl ? 'ROOM連携済み' : 'ROOM URL未登録',
            subtitle: hasUrl ? '投稿先をすぐ開けます' : '登録すると投稿先をすぐ開けます',
            icon: Icons.link_rounded,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: hasUrl ? 'ROOMを開く' : 'ROOM URLを登録',
                  onPressed: hasUrl
                      ? () => AppActionService.openUrl(context, url: url)
                      : onEditRoomUrl,
                  icon: Icon(
                    hasUrl ? Icons.open_in_new_rounded : Icons.add_link_rounded,
                  ),
                  height: 40,
                  expand: true,
                ),
              ),
              if (hasUrl) ...[
                const SizedBox(width: 8),
                AppSecondaryButton(
                  label: '編集',
                  onPressed: onEditRoomUrl,
                  icon: const Icon(Icons.edit_outlined),
                  height: 40,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class MyPageRoomSyncSection extends StatefulWidget {
  const MyPageRoomSyncSection({super.key, required this.onEditRoomUrl});

  final VoidCallback onEditRoomUrl;

  @override
  State<MyPageRoomSyncSection> createState() => _MyPageRoomSyncSectionState();
}

class _MyPageRoomSyncSectionState extends State<MyPageRoomSyncSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context
            .read<RoomImportController>()
            .tickSlowRoomMetadataEnrichmentIfNeeded(context),
      );
    });
  }

  Future<void> _handleImport(BuildContext context) async {
    final roomUrl = context.read<UserProfileProvider>().profile.roomUrl.trim();
    if (roomUrl.isEmpty) return;
    final ctl = context.read<RoomImportController>();
    final result = await ctl.runImport(context);
    if (!context.mounted) return;
    if (result == null) return;
    await RoomPostImportFlow.presentPostImportUi(
      context,
      result,
      startBatch: () => ctl.runImport(context),
      startDeepCollectsBatch: () => ctl.runImport(context, deepCollectsExplore: true),
    );
  }

  Future<void> _handleDeepRoomImport(BuildContext context) async {
    final roomUrl = context.read<UserProfileProvider>().profile.roomUrl.trim();
    if (roomUrl.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('さらに古い投稿を探す'),
        content: Text(
          '通常取り込みで見つからない古いROOM投稿を探します。'
          'ROOMの collects API を最大${RoomImportCollectsPolicy.deepMaxCollectPages}ページまで取得し、'
          '数分〜10分以上かかる場合があります。実行しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('実行'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final ctl = context.read<RoomImportController>();
    final result = await ctl.runImport(context, deepCollectsExplore: true);
    if (!context.mounted) return;
    if (result == null) return;
    await RoomPostImportFlow.presentPostImportUi(
      context,
      result,
      startBatch: () => ctl.runImport(context),
      startDeepCollectsBatch: () => ctl.runImport(context, deepCollectsExplore: true),
    );
  }

  Future<void> _handleReactionSync(BuildContext context) async {
    final roomUrl = context.read<UserProfileProvider>().profile.roomUrl.trim();
    if (roomUrl.isEmpty) return;
    final ctl = context.read<RoomImportController>();
    final r = await ctl.runReactionSync(context);
    if (!context.mounted || r == null) return;
    if (r.hasFatalError) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('反応を確認する'),
          content: Text(r.fatalErrorMessage!.trim()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }
    final text = r.uiSummaryMessage.trim().isNotEmpty
        ? r.uiSummaryMessage
        : '反応を確認しました：確認${r.itemsChecked}件 / 変更なし';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _handleEnrichRoomMetadata(BuildContext context) async {
    await RoomPostImportFlow.runManualPendingRoomImportMetadataEnrich(context);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    final roomUrl = profile.roomUrl.trim();
    final hasUrl = roomUrl.isNotEmpty;
    final importedDoneCount = context
        .watch<RakutenManagedProductProvider>()
        .items
        .where(
          (e) =>
              e.status == RakutenManagedProductStatus.done &&
              e.roomUrl.trim().isNotEmpty,
        )
        .length;

    return Consumer2<RoomImportController, BulkOperationStateController>(
      builder: (context, ctl, bulk, _) {
        final syncBusy = ctl.isRunning ||
            bulk.isMetadataEnriching ||
            bulk.isRoomReactionSyncRunning;
        final enrichingOnly = !ctl.isRunning &&
            !bulk.isRoomReactionSyncRunning &&
            bulk.isMetadataEnriching;
        final reactionOnly = !ctl.isRunning &&
            !bulk.isMetadataEnriching &&
            bulk.isRoomReactionSyncRunning;
        final syncJob = RoomSyncButtonVisibility.jobLabel(
          importing: ctl.isRunning,
          syncingReactions: reactionOnly,
          enrichingMetadata: enrichingOnly,
        );
        if (syncBusy) {
          for (final b in const [
            'import',
            'reaction',
            'maintenance',
            'deepSearch',
            'metadataRetry',
          ]) {
            RoomSyncButtonVisibility.logHiddenWhileBusy(
              screen: 'myPage',
              job: syncJob,
              button: b,
            );
            RoomSyncButtonVisibility.logRenderDecision(
              screen: 'myPage',
              button: b,
              canRun: false,
              visible: false,
              reason: 'busy',
            );
          }
        }
        final completed = ctl.checkedCount;
        final total = ctl.targetCount;
        final actionLocked = bulk.isAnyBlockingOperationRunning;

        final busyTitle = ctl.isRunning
            ? (total > 0
                  ? '現在投稿済み商品を取り込み中です（$completed / $total件）'
                  : (ctl.importProcessingHint.isNotEmpty
                        ? ctl.importProcessingHint
                        : '現在投稿済み商品を取り込み中です'))
            : (reactionOnly
                  ? '現在反応を確認中です'
                  : (enrichingOnly
                        ? '現在ショップ名・ジャンルを確認中です'
                        : ''));

        final canRunPrimary = hasUrl && !actionLocked;
        final showPrimaryButtons = canRunPrimary && !syncBusy;
        if (!syncBusy) {
          final reason =
              !hasUrl ? 'missingRoomUrl' : (actionLocked ? 'guarded' : 'ready');
          final v = showPrimaryButtons;
          final c = canRunPrimary;
          for (final b in const [
            'import',
            'reaction',
            'maintenance',
            'deepSearch',
            'metadataRetry',
          ]) {
            RoomSyncButtonVisibility.logRenderDecision(
              screen: 'myPage',
              button: b,
              canRun: c,
              visible: v,
              reason: reason,
            );
          }
        }

        return AppCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionHeader(
                title: RoomSyncCardCopy.title,
                subtitle: RoomSyncCardCopy.subtitle,
                icon: Icons.downloading_rounded,
              ),
              if (hasUrl) ...[
                const SizedBox(height: 10),
                Text(
                  importedDoneCount <= 0
                      ? 'まだROOM投稿を取り込んでいません'
                      : '取り込み済み：$importedDoneCount件',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              if (!hasUrl) ...[
                Text(
                  'ROOMのプロフィールURLを登録してください',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onEditRoomUrl,
                  child: const Text('ROOM URLを登録'),
                ),
              ] else ...[
                if (syncBusy && busyTitle.isNotEmpty) ...[
                  Text(
                    busyTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (ctl.isRunning && total > 0)
                    Text(
                      '$completed / $total件',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: ctl.isRunning && total > 0 && completed >= 0
                        ? (completed / total).clamp(0.0, 1.0)
                        : null,
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  if (actionLocked && !syncBusy) ...[
                    Text(
                      bulk.blockingRoomTourUserMessage ??
                          BulkOperationStateController.blockingSnackMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const RoomSyncLastReactionSummaryPanel(),
                  const SizedBox(height: 12),
                  if (showPrimaryButtons) ...[
                    FilledButton(
                      onPressed: () {
                        RoomSyncButtonVisibility.logIdleVisible(
                          screen: 'myPage',
                          button: 'import',
                        );
                        _handleImport(context);
                      },
                      child: const Text('投稿済み商品を取り込む'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () {
                        RoomSyncButtonVisibility.logIdleVisible(
                          screen: 'myPage',
                          button: 'reaction',
                        );
                        _handleReactionSync(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('反応を確認する'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    RoomSyncCardCopy.combinedFooterHint,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 14),
                  ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      RoomSyncCardCopy.maintenanceTileTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      RoomSyncCardCopy.maintenanceTileSubtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    children: [
                      if (showPrimaryButtons) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            RoomSyncButtonVisibility.logIdleVisible(
                              screen: 'myPage',
                              button: 'deepSearch',
                            );
                            _handleDeepRoomImport(context);
                          },
                          icon: const Icon(Icons.manage_search_outlined, size: 18),
                          label: const Text('さらに古い投稿を探す'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '通常取り込みで見つからない古いROOM投稿を探します。時間がかかる場合があります。',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            RoomSyncButtonVisibility.logIdleVisible(
                              screen: 'myPage',
                              button: 'metadataRetry',
                            );
                            _handleEnrichRoomMetadata(context);
                          },
                          icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                          label: const Text('ショップ名・ジャンルを再確認'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '取り込み時に商品情報を取得できなかった商品だけ再試行します（1回あたり最大${RoomImportLimitPolicy.manualEnrichMaxProductsPerRun}件）。',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                        ),
                      ] else if (hasUrl) ...[
                        Text(
                          bulk.blockingRoomTourUserMessage ??
                              BulkOperationStateController.blockingSnackMessage,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ],
                  ),
                  const RoomImportEnrichmentPendingHint(),
                  const SizedBox(height: 6),
                  Text(
                    RoomSyncCardCopy.freeTierLine(
                      limit: RoomImportLimitPolicy.freeBatchLimit,
                    ),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class MyPageSettingsSection extends StatelessWidget {
  const MyPageSettingsSection({
    super.key,
    this.onOpenDemo,
    required this.onOpenInitialSetup,
  });

  final VoidCallback? onOpenDemo;
  final VoidCallback onOpenInitialSetup;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(
            title: '設定・その他',
            subtitle: '低頻度の確認項目',
            icon: Icons.settings_outlined,
          ),
          const SizedBox(height: 10),
          if (onOpenDemo != null) ...[
            AppSecondaryButton(
              label: 'クローズドテスト用デモを見る',
              onPressed: onOpenDemo,
              icon: const Icon(Icons.rocket_launch_outlined),
              expand: true,
              height: 42,
            ),
            const SizedBox(height: 8),
          ],
          AppOutlineButton(
            label: 'かんたん初期設定をやり直す',
            onPressed: onOpenInitialSetup,
            icon: const Icon(Icons.tune_rounded),
            height: 38,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => AppActionService.openUrl(
              context,
              url: LegalUrls.termsOfService,
            ),
            icon: const Icon(Icons.article_outlined),
            label: const Text('利用規約を開く'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                AppActionService.openUrl(context, url: LegalUrls.privacyPolicy),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('プライバシーポリシーを開く'),
          ),
        ],
      ),
    );
  }
}

class MyPageRegisteredContentCard extends StatelessWidget {
  const MyPageRegisteredContentCard({
    super.key,
    required this.profile,
    required this.savedShopCount,
    required this.onEditNickname,
    required this.onEditPostStyles,
    required this.onEditRoomUrl,
    required this.onEditGenres,
    required this.onOpenSavedShops,
  });

  final UserProfile profile;
  final int savedShopCount;
  final VoidCallback onEditNickname;
  final VoidCallback onEditPostStyles;
  final VoidCallback onEditRoomUrl;
  final VoidCallback onEditGenres;
  final VoidCallback onOpenSavedShops;

  @override
  Widget build(BuildContext context) {
    final nickname = profile.displayName.trim().isEmpty ? '未設定' : '登録済み';
    final postStyles = profile.postStyleLabelsText;
    final roomUrl = profile.hasRoomUrl ? '登録済み' : '未設定';
    final genreCount = profile.favoriteGenreIdList.length;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(
            title: '登録内容',
            subtitle: 'ROOM URL・ニックネーム・探し方・ジャンル・保存ショップを確認できます',
            icon: Icons.assignment_ind_outlined,
          ),
          const SizedBox(height: 10),
          _RegisteredContentRow(
            title: 'ニックネーム',
            value: nickname,
            onTap: onEditNickname,
          ),
          _RegisteredContentRow(
            title: '探し方',
            value: postStyles,
            onTap: onEditPostStyles,
          ),
          _RegisteredContentRow(
            title: 'ROOM URL',
            value: roomUrl,
            onTap: onEditRoomUrl,
          ),
          _RegisteredContentRow(
            title: 'よく使うジャンル',
            value: '$genreCount件',
            onTap: onEditGenres,
          ),
          _RegisteredContentRow(
            title: '保存ショップ',
            value: '$savedShopCount件',
            onTap: onOpenSavedShops,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _RegisteredContentRow extends StatelessWidget {
  const _RegisteredContentRow({
    required this.title,
    required this.value,
    required this.onTap,
    this.showDivider = true,
  });

  final String title;
  final String value;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            ],
          ),
          onTap: onTap,
        ),
        if (showDivider) Divider(height: 1, color: AppColors.divider),
      ],
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
    return _SheetScaffold(
      title: 'ニックネームを編集',
      body: [
        AppTextField(
          controller: _nameController,
          textInputAction: TextInputAction.done,
          labelText: 'ニックネーム（任意）',
          hintText: '例: ルーマネ',
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
    return _SheetScaffold(
      title: 'ROOMプロフィールを登録',
      body: [
        AppTextField(
          controller: _roomUrlController,
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.url,
          labelText: 'ROOMプロフィールURL（任意）',
          hintText: '例: https://room.rakuten.co.jp/xxxx',
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
        AppSecondaryButton(
          label: 'ROOMを開く',
          onPressed: hasUrl
              ? () => AppActionService.openUrl(
                  context,
                  url: _roomUrlController.text.trim(),
                )
              : null,
          icon: const Icon(Icons.open_in_new_rounded),
          expand: true,
          height: 42,
        ),
      ],
      primaryLabel: '保存',
      onPrimary: _save,
      primaryEnabled: !_isCheckingRoomProfile,
      isPrimaryLoading: _isCheckingRoomProfile,
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
              AppPrimaryButton(
                label: primaryLabel,
                onPressed: primaryEnabled ? onPrimary : null,
                isLoading: isPrimaryLoading,
              ),
              const SizedBox(height: 8),
              AppSecondaryButton(
                label: '閉じる',
                onPressed: () => Navigator.of(context).pop(),
                expand: true,
                height: 44,
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
