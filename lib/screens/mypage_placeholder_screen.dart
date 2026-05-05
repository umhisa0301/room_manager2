import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/demo_mode.dart';
import '../constants/legal_urls.dart';
import '../models/rakuten_genre_master_entry.dart';
import '../models/rakuten_managed_product.dart';
import '../models/user_profile.dart';
import '../navigation/app_shell_controller.dart';
import '../services/app_action_service.dart';
import '../services/room_import_limit_policy.dart';
import '../widgets/room_post_import_flow.dart';
import '../services/rakuten_genre_master_service.dart';
import '../services/room_collect_post_limit.dart';
import '../state/activity_log_provider.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/room_activity_event_provider.dart';
import '../state/saved_shop_provider.dart';
import '../state/user_profile_provider.dart';
import '../state/room_import_controller.dart';
import '../theme/app_theme.dart';
import '../utils/user_profile_genre_migration.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import 'activity_placeholder_screen.dart';
import 'closed_test_demo_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom + _navReserve;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('マイページ')),
      body: SafeArea(
        top: false,
        child:
            Consumer5<
              UserProfileProvider,
              SavedShopProvider,
              RakutenManagedProductProvider,
              RoomActivityEventProvider,
              ActivityLogProvider
            >(
              builder:
                  (
                    context,
                    profileProvider,
                    saved,
                    managed,
                    activityEvents,
                    activityLog,
                    _,
                  ) {
                    final profile = profileProvider.profile;
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
                        MyPageHeader(
                          profile: profile,
                          savedShopCount: saved.shops.length,
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
    required this.onStepGenre,
    required this.onStepRoom,
    required this.onStepProfile,
    required this.onStepSavedShops,
  });

  final UserProfile profile;
  final int savedShopCount;
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
        return 'ジャンル設定';
      case 1:
        return 'ROOM連携';
      case 2:
        return 'プロフィール入力';
      case 3:
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
    final profileConfigured =
        widget.profile.displayName.trim().isNotEmpty ||
        widget.profile.age != null ||
        widget.profile.genderKey != null ||
        widget.profile.occupation.trim().isNotEmpty;
    final hasGenres = genreCount > 0;
    final hasRoomUrl = widget.profile.hasRoomUrl;
    final savedDone = widget.savedShopCount > 0;

    final stepGenreDone = hasGenres;
    final stepRoomDone = hasRoomUrl;
    final stepProfileDone = profileConfigured;
    final stepSavedDone = savedDone;

    final stepDoneFlags = <bool>[
      stepGenreDone,
      stepRoomDone,
      stepProfileDone,
      stepSavedDone,
    ];
    final completedCount = stepDoneFlags.where((e) => e).length;
    final firstIncomplete = stepDoneFlags.indexWhere((e) => !e);
    final remaining = 4 - completedCount;
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
                            '進捗：$completedCount / 4 完了',
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
                            title: 'ジャンル設定',
                            description: '興味のあるジャンルを選ぶと、あなた向けの候補が出やすくなります。',
                            isDone: stepGenreDone,
                            isNextStep: firstIncomplete == 0,
                            onTap: widget.onStepGenre,
                          ),
                          const SizedBox(height: 8),
                          _MyPageStepRow(
                            stepLabel: 'STEP2',
                            title: 'ROOM連携',
                            description:
                                'ROOMのURLを登録すると、投稿スタイルに近い商品を優先しやすくなります。',
                            isDone: stepRoomDone,
                            isNextStep: firstIncomplete == 1,
                            onTap: widget.onStepRoom,
                          ),
                          const SizedBox(height: 8),
                          _MyPageStepRow(
                            stepLabel: 'STEP3',
                            title: 'プロフィール入力',
                            description: '年代や属性を入れると、提案のブレが減ります。',
                            isDone: stepProfileDone,
                            isNextStep: firstIncomplete == 2,
                            onTap: widget.onStepProfile,
                          ),
                          const SizedBox(height: 8),
                          _MyPageStepRow(
                            stepLabel: 'STEP4',
                            title: '保存ショップ',
                            description: '保存したショップが多いほど精度が上がります。',
                            isDone: stepSavedDone,
                            isNextStep: firstIncomplete == 3,
                            onTap: widget.onStepSavedShops,
                          ),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
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

class MyPageRoomSyncSection extends StatelessWidget {
  const MyPageRoomSyncSection({super.key, required this.onEditRoomUrl});

  final VoidCallback onEditRoomUrl;

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
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    final roomUrl = profile.roomUrl.trim();
    final hasUrl = roomUrl.isNotEmpty;

    return Consumer<RoomImportController>(
      builder: (context, ctl, _) {
        final busy = ctl.isRunning;
        final completed = ctl.checkedCount;
        final total = ctl.targetCount;

        return AppCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionHeader(
                title: 'ROOM投稿取り込み',
                subtitle: '楽天ROOMの最新投稿を確認して、まだ取り込んでいない商品を追加します。',
                icon: Icons.downloading_rounded,
              ),
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
                  onPressed: onEditRoomUrl,
                  child: const Text('ROOM URLを登録'),
                ),
              ] else ...[
                if (busy) ...[
                  Text(
                    'ROOM投稿を確認中',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (total > 0)
                    Text(
                      '$completed / $total件',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: total > 0 && completed >= 0
                        ? (completed / total).clamp(0.0, 1.0)
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: busy ? null : () => _handleImport(context),
                  child: Text(
                    '投稿済みを${RoomImportLimitPolicy.freeBatchLimit}件取り込む',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '無料版は${RoomImportLimitPolicy.freeBatchLimit}件ずつ取り込めます',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                // TODO(RewardedAd|Subscription): 広告／Pro による追加バッチ導線をここに復帰。
              ],
            ],
          ),
        );
      },
    );
  }
}

class MyPageSettingsSection extends StatelessWidget {
  const MyPageSettingsSection({super.key, this.onOpenDemo});

  final VoidCallback? onOpenDemo;

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
          AppSecondaryButton(
            label: 'プライバシーポリシーを開く',
            onPressed: () =>
                AppActionService.openUrl(context, url: LegalUrls.privacyPolicy),
            icon: const Icon(Icons.policy_outlined),
            expand: true,
            height: 42,
          ),
        ],
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
  late final TextEditingController _ageController;
  late final TextEditingController _occupationController;
  String? _genderKey;

  @override
  void initState() {
    super.initState();
    final p = context.read<UserProfileProvider>().profile;
    _nameController = TextEditingController(text: p.displayName);
    _ageController = TextEditingController(
      text: p.age != null ? '${p.age}' : '',
    );
    _occupationController = TextEditingController(text: p.occupation);
    _genderKey = p.genderKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final base = context.read<UserProfileProvider>().profile;
    final ageText = _ageController.text.trim();
    int? age;
    if (ageText.isNotEmpty) {
      age = int.tryParse(ageText);
      if (age == null || age < 0 || age > 150) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('年齢は 0〜150 の数値で入力するか、空にしてください')),
        );
        return;
      }
    }
    final next = UserProfile(
      displayName: _nameController.text.trim(),
      age: age,
      genderKey: _genderKey,
      occupation: _occupationController.text.trim(),
      favoriteGenres: base.favoriteGenres,
      favoriteGenreIds: base.favoriteGenreIds,
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
      title: 'プロフィールを編集',
      body: [
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
        _GenderChipField(
          value: _genderKey,
          onChanged: (v) => setState(() => _genderKey = v),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _occupationController,
          textInputAction: TextInputAction.done,
          labelText: '職業（任意）',
          hintText: '例: 会社員',
        ),
      ],
      primaryLabel: '保存',
      onPrimary: _save,
    );
  }
}

class RoomUrlEditSheet extends StatefulWidget {
  const RoomUrlEditSheet({super.key});

  @override
  State<RoomUrlEditSheet> createState() => _RoomUrlEditSheetState();
}

class _RoomUrlEditSheetState extends State<RoomUrlEditSheet> {
  late final TextEditingController _roomUrlController;

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
    FocusManager.instance.primaryFocus?.unfocus();
    final base = context.read<UserProfileProvider>().profile;
    final next = UserProfile(
      displayName: base.displayName,
      age: base.age,
      genderKey: base.genderKey,
      occupation: base.occupation,
      favoriteGenres: base.favoriteGenres,
      favoriteGenreIds: base.favoriteGenreIds,
      roomUrl: _roomUrlController.text.trim(),
    );
    final messenger = ScaffoldMessenger.of(context);
    await context.read<UserProfileProvider>().saveProfile(next);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('ROOM URLを保存しました')));
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = _roomUrlController.text.trim().isNotEmpty;
    return _SheetScaffold(
      title: 'ROOM URLを編集',
      body: [
        AppTextField(
          controller: _roomUrlController,
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.url,
          labelText: '楽天ROOMのURL（任意）',
          hintText: '例: https://room.rakuten.co.jp/xxxx',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(
          '未入力でも保存できます。登録するとマイページからROOMをすぐ開けます。',
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
    );
  }
}

class FavoriteGenrePickerSheet extends StatefulWidget {
  const FavoriteGenrePickerSheet({super.key, required this.initialSelectedIds});

  final List<String> initialSelectedIds;

  @override
  State<FavoriteGenrePickerSheet> createState() =>
      _FavoriteGenrePickerSheetState();
}

class _FavoriteGenrePickerSheetState extends State<FavoriteGenrePickerSheet> {
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

  void _toggle(String genreId, bool? checked) {
    final id = genreId.trim();
    if (id.isEmpty) return;
    if (checked == true) {
      if (_selected.length >= 5) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ジャンルは最大5件まで選択できます')));
        return;
      }
      setState(() => _selected.add(id));
    } else {
      setState(() => _selected.remove(id));
    }
  }

  void _apply() {
    final ordered = <String>[];
    for (final e in _entries) {
      final id = e.genreId;
      if (_selected.contains(id)) ordered.add(id);
    }
    Navigator.of(context).pop(ordered);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final limitReached = _selected.length >= 5;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '好きなジャンルを選ぶ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.divider.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.numbers_rounded,
                          size: 22,
                          color: AppColors.accentPrimary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '最大5件まで選べます（現在 ${_selected.length} / 5）',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'タップでON/OFF。上限に達している項目はこれ以上追加できません。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final id in _selected)
                          InputChip(
                            label: Text(_genreNameForId(id)),
                            onDeleted: () =>
                                setState(() => _selected.remove(id)),
                            backgroundColor: AppColors.surfaceVariant
                                .withValues(alpha: 0.7),
                            side: BorderSide(
                              color: AppColors.divider.withValues(alpha: 0.9),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 112,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final e = _entries[index];
                  final id = e.genreId;
                  final selected = _selected.contains(id);
                  final disabledByLimit = limitReached && !selected;
                  return _GenreGridCell(
                    label: e.genreName,
                    icon: _iconForGenrePicker(e.genreName, e.genreId),
                    selected: selected,
                    disabled: disabledByLimit,
                    onTap: () {
                      if (disabledByLimit) return;
                      _toggle(id, !selected);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      label: 'キャンセル',
                      onPressed: () => Navigator.of(context).pop(),
                      expand: true,
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppPrimaryButton(
                      label: '決定',
                      onPressed: _apply,
                      height: 48,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _genreNameForId(String id) {
    for (final entry in _entries) {
      if (entry.genreId == id) return entry.genreName;
    }
    return id;
  }
}

class _GenreGridCell extends StatelessWidget {
  const _GenreGridCell({
    required this.label,
    required this.icon,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentPrimary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent
                  : AppColors.divider.withValues(alpha: 0.85),
              width: selected ? 2 : 1,
            ),
            color: selected
                ? AppColors.accentLight.withValues(alpha: 0.38)
                : AppColors.surface,
          ),
          child: Opacity(
            opacity: disabled ? 0.42 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 28,
                    color: selected ? accent : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(height: 4),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderChipField extends StatelessWidget {
  const _GenderChipField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String? value})>[
      (label: '選択しない', value: null),
      (label: '男性', value: UserProfile.genderMale),
      (label: '女性', value: UserProfile.genderFemale),
      (label: 'その他', value: UserProfile.genderOther),
      (label: '回答しない', value: UserProfile.genderPreferNot),
    ];
    return InputDecorator(
      decoration: const InputDecoration(labelText: '性別（任意）'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            ChoiceChip(
              label: Text(item.label),
              selected: value == item.value,
              showCheckmark: false,
              onSelected: (_) => onChanged(item.value),
              selectedColor: AppColors.accentLight,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: value == item.value
                    ? AppColors.accentPrimary.withValues(alpha: 0.45)
                    : AppColors.divider.withValues(alpha: 0.9),
              ),
              labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: value == item.value
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
                fontWeight: value == item.value
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
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
  });

  final String title;
  final List<Widget> body;
  final String primaryLabel;
  final VoidCallback onPrimary;

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
              AppPrimaryButton(label: primaryLabel, onPressed: onPrimary),
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

IconData _iconForGenrePicker(String genreName, String genreId) {
  final n = genreName;
  if (n.contains('食品') ||
      n.contains('スイーツ') ||
      n.contains('お菓子') ||
      n.contains('米')) {
    return Icons.restaurant_outlined;
  }
  if (n.contains('ファッション') ||
      n.contains('服') ||
      n.contains('靴') ||
      n.contains('バッグ')) {
    return Icons.checkroom_outlined;
  }
  if (n.contains('本') || n.contains('電子') || n.contains('書籍')) {
    return Icons.menu_book_outlined;
  }
  if (n.contains('家電') ||
      n.contains('PC') ||
      n.contains('スマホ') ||
      n.contains('カメラ')) {
    return Icons.devices_outlined;
  }
  if (n.contains('美容') || n.contains('コスメ') || n.contains('香水')) {
    return Icons.brush_outlined;
  }
  if (n.contains('スポーツ') || n.contains('アウトドア') || n.contains('ゴルフ')) {
    return Icons.hiking_outlined;
  }
  if (n.contains('花') || n.contains('ガーデン') || n.contains('園芸')) {
    return Icons.local_florist_outlined;
  }
  if (n.contains('おもちゃ') || n.contains('ホビー') || n.contains('ゲーム')) {
    return Icons.toys_outlined;
  }
  if (n.contains('車') || n.contains('バイク') || n.contains('自転車')) {
    return Icons.pedal_bike_outlined;
  }
  if (n.contains('インテリア') || n.contains('家具') || n.contains('寝具')) {
    return Icons.chair_outlined;
  }
  if (n.contains('ペット') || n.contains('動物')) {
    return Icons.pets_outlined;
  }
  if (n.contains('雑貨') || n.contains('日用品')) {
    return Icons.shopping_basket_outlined;
  }
  const fallbacks = <IconData>[
    Icons.category_outlined,
    Icons.shopping_bag_outlined,
    Icons.storefront_outlined,
    Icons.widgets_outlined,
    Icons.inventory_2_outlined,
    Icons.auto_awesome_outlined,
  ];
  return fallbacks[genreId.hashCode.abs() % fallbacks.length];
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
