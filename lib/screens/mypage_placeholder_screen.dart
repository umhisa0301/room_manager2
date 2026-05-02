import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/demo_mode.dart';
import '../constants/legal_urls.dart';
import '../models/rakuten_genre_master_entry.dart';
import '../models/rakuten_managed_product.dart';
import '../models/user_profile.dart';
import '../navigation/app_shell_controller.dart';
import '../navigation/rakuten_search_navigator.dart';
import '../services/app_action_service.dart';
import '../services/rakuten_genre_master_service.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/saved_shop_provider.dart';
import '../state/today_recommendation_provider.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../utils/user_profile_genre_migration.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import 'closed_test_demo_screen.dart';
import 'saved_shops_screen.dart';
import 'today_recommendations_screen.dart';

/// マイページ：今日のコレ探しを始めるための設定・運用ハブ。
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
      builder: (sheetContext) =>
          FavoriteGenrePickerSheet(initialSelectedIds: initialIds),
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

  void _openTodayRecommendations(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TodayRecommendationsScreen(),
      ),
    );
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
            Consumer4<
              UserProfileProvider,
              SavedShopProvider,
              RakutenManagedProductProvider,
              TodayRecommendationProvider
            >(
              builder: (context, profileProvider, saved, managed, rec, _) {
                final profile = profileProvider.profile;
                final candidateCount = managed.items
                    .where(
                      (e) => e.status == RakutenManagedProductStatus.candidate,
                    )
                    .length;
                final doneCount = managed.items
                    .where((e) => e.status == RakutenManagedProductStatus.done)
                    .length;

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
                    MyPageTodayRecommendationCard(
                      recommendationProvider: rec,
                      onOpenRecommendations: () =>
                          _openTodayRecommendations(context),
                      onOpenColeCandidateSearch: () => context
                          .read<AppShellController>()
                          .openRoomCollect(initialTabIndex: 0),
                    ),
                    const SizedBox(height: _gap),
                    MyPageQuickSummaryCard(
                      candidateCount: candidateCount,
                      doneCount: doneCount,
                      savedShopCount: saved.shops.length,
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
                    ),
                    const SizedBox(height: _gap),
                    MyPageOperationMenuCard(
                      savedShopCount: saved.shops.length,
                      onOpenComments: () =>
                          context.read<AppShellController>().selectTab(2),
                      onOpenActivity: () =>
                          context.read<AppShellController>().openActivityTab(),
                      onOpenSavedShops: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SavedShopsScreen(),
                          ),
                        );
                      },
                      onOpenShopDiscovery: () {
                        openRakutenSearchScreen(
                          context,
                          initialMode: RakutenSearchInitialMode.shopDiscovery,
                        );
                      },
                      onOpenRoomColle: () =>
                          context.read<AppShellController>().openRoomCollect(),
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

class MyPageHeader extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final genreCount = profile.favoriteGenreIdList.length;
    final profileConfigured =
        profile.displayName.trim().isNotEmpty ||
        profile.age != null ||
        profile.genderKey != null ||
        profile.occupation.trim().isNotEmpty;
    final hasGenres = genreCount > 0;
    final hasRoomUrl = profile.hasRoomUrl;
    final savedDone = savedShopCount > 0;

    final stepGenreDone = hasGenres;
    final stepRoomDone = hasRoomUrl;
    final stepProfileDone = profileConfigured;
    final stepSavedDone = savedDone;

    final accuracyBools = <bool>[
      stepGenreDone,
      stepRoomDone,
      stepProfileDone,
      stepSavedDone,
    ];
    final accuracyScore = accuracyBools.where((e) => e).length;
    final accuracyLabel = accuracyScore >= 3
        ? '高'
        : accuracyScore >= 2
        ? '中'
        : '低';
    final accuracyLine = accuracyScore >= 3
        ? '精度：高（すべてのステップ完了）'
        : '精度：$accuracyLabel（あと${3 - accuracyScore}ステップで高）';

    final stepDoneFlags = <bool>[
      stepGenreDone,
      stepRoomDone,
      stepProfileDone,
      stepSavedDone,
    ];
    final firstIncomplete = stepDoneFlags.indexWhere((e) => !e);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'おすすめ精度を上げる',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          _MyPageStepRow(
            stepLabel: 'STEP1',
            title: 'ジャンル設定',
            isDone: stepGenreDone,
            emphasizeIncomplete: !stepGenreDone,
            extraGenreUnset: !hasGenres,
            isNextFocus: firstIncomplete == 0,
            onTap: onStepGenre,
          ),
          const SizedBox(height: 8),
          _MyPageStepRow(
            stepLabel: 'STEP2',
            title: 'ROOM連携',
            isDone: stepRoomDone,
            emphasizeIncomplete: !stepRoomDone,
            extraGenreUnset: false,
            isNextFocus: firstIncomplete == 1,
            onTap: onStepRoom,
          ),
          const SizedBox(height: 8),
          _MyPageStepRow(
            stepLabel: 'STEP3',
            title: 'プロフィール入力',
            isDone: stepProfileDone,
            emphasizeIncomplete: !stepProfileDone,
            extraGenreUnset: false,
            isNextFocus: firstIncomplete == 2,
            onTap: onStepProfile,
          ),
          const SizedBox(height: 8),
          _MyPageStepRow(
            stepLabel: 'STEP4',
            title: '保存ショップ',
            isDone: stepSavedDone,
            emphasizeIncomplete: !stepSavedDone,
            extraGenreUnset: false,
            isNextFocus: firstIncomplete == 3,
            onTap: onStepSavedShops,
          ),
          const SizedBox(height: 12),
          Text(
            accuracyLine,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
              fontWeight: FontWeight.w600,
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
    required this.isDone,
    required this.emphasizeIncomplete,
    required this.extraGenreUnset,
    required this.isNextFocus,
    required this.onTap,
  });

  final String stepLabel;
  final String title;
  final bool isDone;
  final bool emphasizeIncomplete;
  final bool extraGenreUnset;
  final bool isNextFocus;
  final VoidCallback onTap;

  static const Color _orange = Color(0xFFE65100);
  static const Color _orangeSurface = Color(0xFFFFF7E8);

  @override
  Widget build(BuildContext context) {
    final accent = emphasizeIncomplete ? _orange : AppColors.divider;
    final bg = isDone
        ? AppColors.surfaceVariant.withValues(alpha: 0.45)
        : emphasizeIncomplete
        ? _orangeSurface
        : AppColors.surfaceVariant.withValues(alpha: 0.35);
    final borderW = (emphasizeIncomplete && extraGenreUnset) || isNextFocus
        ? 2.0
        : 1.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            border: Border.all(color: accent, width: borderW),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  if (isDone)
                    Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 22)
                  else
                    Icon(Icons.circle_outlined,
                        color: emphasizeIncomplete ? _orange : AppColors.textSecondary,
                        size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stepLabel,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: emphasizeIncomplete
                                        ? _orange
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary, size: 22),
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
    required this.onTapCandidates,
    required this.onTapDone,
    required this.onTapSavedShops,
  });

  final int savedShopCount;
  final int candidateCount;
  final int doneCount;
  final VoidCallback onTapCandidates;
  final VoidCallback onTapDone;
  final VoidCallback onTapSavedShops;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(
            title: '状態サマリー',
            subtitle: 'タップして各画面へ進みます',
            icon: Icons.list_alt_outlined,
          ),
          const SizedBox(height: 8),
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
        ],
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
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyPageTodayRecommendationCard extends StatelessWidget {
  const MyPageTodayRecommendationCard({
    super.key,
    required this.recommendationProvider,
    required this.onOpenRecommendations,
    required this.onOpenColeCandidateSearch,
  });

  final TodayRecommendationProvider recommendationProvider;
  final VoidCallback onOpenRecommendations;
  final VoidCallback onOpenColeCandidateSearch;

  @override
  Widget build(BuildContext context) {
    final isLoading = recommendationProvider.isLoading;

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(
            title: '今日のおすすめ',
            subtitle: '候補の提案とコレ探索',
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            label: 'おすすめを見る',
            icon: const Icon(Icons.travel_explore_rounded),
            isLoading: isLoading,
            onPressed:
                isLoading ? null : onOpenRecommendations,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: onOpenColeCandidateSearch,
              icon: const Icon(Icons.bookmark_add_outlined, size: 20),
              label: const Text('コレ候補を探す'),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: const Size(48, 48),
                foregroundColor: AppColors.accentPrimary,
              ),
            ),
          ),
        ],
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

class MyPageOperationMenuCard extends StatelessWidget {
  const MyPageOperationMenuCard({
    super.key,
    required this.savedShopCount,
    required this.onOpenComments,
    required this.onOpenActivity,
    required this.onOpenSavedShops,
    required this.onOpenShopDiscovery,
    required this.onOpenRoomColle,
  });

  final int savedShopCount;
  final VoidCallback onOpenComments;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenSavedShops;
  final VoidCallback onOpenShopDiscovery;
  final VoidCallback onOpenRoomColle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(
            title: 'ショートカット',
            subtitle: 'よく使う画面へ。',
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _OperationTile(
                    width: tileWidth,
                    icon: Icons.collections_bookmark_outlined,
                    title: 'ROOMコレ',
                    subtitle: '候補・コレ済',
                    onTap: onOpenRoomColle,
                  ),
                  _OperationTile(
                    width: tileWidth,
                    icon: Icons.storefront_outlined,
                    title: '保存ショップ',
                    subtitle: '$savedShopCount件',
                    onTap: onOpenSavedShops,
                  ),
                  _OperationTile(
                    width: tileWidth,
                    icon: Icons.travel_explore_outlined,
                    title: 'ショップ発掘',
                    subtitle: '新しい店を探す',
                    onTap: onOpenShopDiscovery,
                  ),
                  _OperationTile(
                    width: tileWidth,
                    icon: Icons.add_comment_outlined,
                    title: 'コメント',
                    subtitle: 'テンプレ確認',
                    onTap: onOpenComments,
                  ),
                  _OperationTile(
                    width: tileWidth,
                    icon: Icons.insights_outlined,
                    title: '活動',
                    subtitle: '運用状況',
                    onTap: onOpenActivity,
                  ),
                ],
              );
            },
          ),
        ],
      ),
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final limitReached = _selected.length >= 5;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '好きなジャンルを選ぶ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '今日のおすすめ候補の精度に使います（${_selected.length}/5）。',
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
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final e = _entries[index];
                    final id = e.genreId;
                    final selected = _selected.contains(id);
                    final disabledByLimit = limitReached && !selected;
                    // 年齢制限が関係しそうなジャンルは将来のおすすめ生成側で除外対象にできるよう、
                    // ここではID/名称を保持したまま通常ジャンルとして表示する。
                    return CheckboxListTile(
                      value: selected,
                      onChanged: disabledByLimit ? null : (v) => _toggle(id, v),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(e.genreName),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
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
                        height: 44,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppPrimaryButton(
                        label: '決定',
                        onPressed: _apply,
                        height: 44,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

class _OperationTile extends StatelessWidget {
  const _OperationTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
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
