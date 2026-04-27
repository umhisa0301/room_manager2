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
                      onEditProfile: () => _openProfileEditSheet(context),
                    ),
                    const SizedBox(height: _gap),
                    MyPageQuickSummaryCard(
                      profile: profile,
                      savedShopCount: saved.shops.length,
                      candidateCount: candidateCount,
                      doneCount: doneCount,
                      onEditProfile: () => _openProfileEditSheet(context),
                      onEditGenres: () =>
                          _openFavoriteGenrePickerSheet(context),
                      onEditRoomUrl: () => _openRoomUrlEditSheet(context),
                    ),
                    const SizedBox(height: _gap),
                    MyPageTodayRecommendationCard(
                      profile: profile,
                      recommendationProvider: rec,
                      onOpenRecommendations: () =>
                          _openTodayRecommendations(context),
                      onEditGenres: () =>
                          _openFavoriteGenrePickerSheet(context),
                    ),
                    const SizedBox(height: _gap),
                    MyPageRoomLinkCard(
                      profile: profile,
                      onEditRoomUrl: () => _openRoomUrlEditSheet(context),
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
    required this.onEditProfile,
  });

  final UserProfile profile;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName.trim();
    final title = name.isEmpty ? 'おすすめ精度を上げる設定' : '$nameさんの運用設定';
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '今日のコレ探しに使う情報をここで整えます。',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppSecondaryButton(
            label: '編集',
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit_outlined),
            height: 38,
          ),
        ],
      ),
    );
  }
}

class MyPageQuickSummaryCard extends StatelessWidget {
  const MyPageQuickSummaryCard({
    super.key,
    required this.profile,
    required this.savedShopCount,
    required this.candidateCount,
    required this.doneCount,
    required this.onEditProfile,
    required this.onEditGenres,
    required this.onEditRoomUrl,
  });

  final UserProfile profile;
  final int savedShopCount;
  final int candidateCount;
  final int doneCount;
  final VoidCallback onEditProfile;
  final VoidCallback onEditGenres;
  final VoidCallback onEditRoomUrl;

  @override
  Widget build(BuildContext context) {
    final genreCount = profile.favoriteGenreIdList.length;
    final profileConfigured =
        profile.displayName.trim().isNotEmpty ||
        profile.age != null ||
        profile.genderKey != null ||
        profile.occupation.trim().isNotEmpty;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: 'クイック概要',
            subtitle: 'おすすめ生成に使う情報の状態',
            icon: Icons.dashboard_customize_outlined,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                label: 'プロフィール',
                value: profileConfigured ? '設定済み' : '未設定',
                icon: Icons.person_outline,
                onTap: onEditProfile,
              ),
              _SummaryChip(
                label: '好きなジャンル',
                value: '$genreCount件',
                icon: Icons.category_outlined,
                onTap: onEditGenres,
              ),
              _SummaryChip(
                label: 'ROOM URL',
                value: profile.hasRoomUrl ? '登録済み' : '未登録',
                icon: Icons.link_rounded,
                onTap: onEditRoomUrl,
              ),
              _SummaryChip(
                label: '保存ショップ',
                value: '$savedShopCount件',
                icon: Icons.bookmarks_outlined,
              ),
              _SummaryChip(
                label: 'コレ候補',
                value: '$candidateCount件',
                icon: Icons.bookmark_add_outlined,
              ),
              _SummaryChip(
                label: 'コレ済',
                value: '$doneCount件',
                icon: Icons.collections_bookmark_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MyPageTodayRecommendationCard extends StatelessWidget {
  const MyPageTodayRecommendationCard({
    super.key,
    required this.profile,
    required this.recommendationProvider,
    required this.onOpenRecommendations,
    required this.onEditGenres,
  });

  final UserProfile profile;
  final TodayRecommendationProvider recommendationProvider;
  final VoidCallback onOpenRecommendations;
  final VoidCallback onEditGenres;

  @override
  Widget build(BuildContext context) {
    final hasGenres = profile.favoriteGenreIdList.isNotEmpty;
    final generated = recommendationProvider.totalCount > 0;
    final isLoading = recommendationProvider.isLoading;
    final title = !hasGenres
        ? '好きなジャンルで候補を探しやすく'
        : generated
        ? '前回のおすすめを見る'
        : '今日のコレ候補を探す';
    final body = !hasGenres
        ? '好きなジャンルを登録すると、今日の候補を探しやすくなります。'
        : generated
        ? '未処理 ${recommendationProvider.pendingCount}件 / 全${recommendationProvider.totalCount}件'
        : 'プロフィールや保存ショップをもとに、今日見る候補をまとめます。';

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.accentPrimary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            label: hasGenres
                ? (generated ? 'おすすめを見る' : '今日のコレを探す')
                : '好きなジャンルを設定',
            icon: Icon(
              hasGenres ? Icons.travel_explore_rounded : Icons.category_rounded,
            ),
            isLoading: isLoading,
            onPressed: isLoading
                ? null
                : hasGenres
                ? onOpenRecommendations
                : onEditGenres,
          ),
          if (generated && hasGenres) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: AppSecondaryButton(
                label: '再生成はおすすめ画面で実行',
                onPressed: onOpenRecommendations,
                icon: const Icon(Icons.refresh_rounded),
                height: 36,
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: hasUrl ? 'ROOM連携済み' : 'ROOM URL未登録',
            subtitle: hasUrl ? '投稿先をすぐ開けます' : '登録すると投稿導線が短くなります',
            icon: Icons.link_rounded,
          ),
          const SizedBox(height: 10),
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
                  height: 42,
                  expand: true,
                ),
              ),
              if (hasUrl) ...[
                const SizedBox(width: 8),
                AppSecondaryButton(
                  label: '編集',
                  onPressed: onEditRoomUrl,
                  icon: const Icon(Icons.edit_outlined),
                  height: 42,
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
            title: '運用メニュー',
            subtitle: 'よく使う画面へ移動',
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: 10),
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
                ...[
                  UserProfile.genderMale,
                  UserProfile.genderFemale,
                  UserProfile.genderOther,
                  UserProfile.genderPreferNot,
                ].map(
                  (key) => DropdownMenuItem<String?>(
                    value: key,
                    child: Text(UserProfile.genderLabelJa(key) ?? ''),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _genderKey = v),
            ),
          ),
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
                    return CheckboxListTile(
                      value: _selected.contains(id),
                      onChanged: (v) => _toggle(id, v),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(e.genreName),
                      dense: true,
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.85)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
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
