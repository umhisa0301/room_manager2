import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/monetization_plan_config.dart';
import '../../constants/legal_urls.dart';
import '../../models/user_profile.dart';
import '../../services/app_action_service.dart';
import '../../theme/mypage_screen_tokens.dart';
import '../../utils/monetization_plan_display.dart';
import '../tutorial/tutorial_target_keys.dart';

/// マイページ共通カード。
class MyPageCard extends StatelessWidget {
  const MyPageCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MyPageScreenUi.cardPadding),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MyPageScreenUi.cardFill,
        borderRadius: BorderRadius.circular(MyPageScreenUi.cardRadius),
        border: Border.all(color: MyPageScreenUi.cardBorder),
        boxShadow: MyPageScreenUi.cardShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// 設定済み / 未設定 / 件数などの状態チップ。
class MyPageStatusChip extends StatelessWidget {
  const MyPageStatusChip({
    super.key,
    required this.label,
    this.variant = MyPageStatusChipVariant.set,
  });

  final String label;
  final MyPageStatusChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final (fill, text, border) = switch (variant) {
      MyPageStatusChipVariant.set => (
          MyPageScreenUi.chipSetFill,
          MyPageScreenUi.chipSetText,
          MyPageScreenUi.chipSetBorder,
        ),
      MyPageStatusChipVariant.unset => (
          MyPageScreenUi.chipUnsetFill,
          MyPageScreenUi.chipUnsetText,
          MyPageScreenUi.chipUnsetBorder,
        ),
      MyPageStatusChipVariant.neutral => (
          MyPageScreenUi.chipUnsetFill,
          MyPageScreenUi.textPrimary,
          MyPageScreenUi.chipUnsetBorder,
        ),
      MyPageStatusChipVariant.optional => (
          MyPageScreenUi.chipUnsetFill,
          MyPageScreenUi.textSecondary,
          MyPageScreenUi.chipUnsetBorder,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: text,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
      ),
    );
  }
}

enum MyPageStatusChipVariant { set, unset, neutral, optional }

/// マイページ系画面の Primary CTA（ティール塗りつぶし）。
class MyPagePrimaryButton extends StatelessWidget {
  const MyPagePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 48,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          )
        : icon == null
            ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconTheme(
                    data: const IconThemeData(size: 18, color: Colors.white),
                    child: icon!,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );

    return SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: MyPageScreenUi.primaryButtonStyle(height: height),
        child: child,
      ),
    );
  }
}

/// マイページ系画面のアウトラインボタン（白背景 + ティール枠）。
class MyPageOutlineButton extends StatelessWidget {
  const MyPageOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 44,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(
                  size: 18,
                  color: onPressed == null
                      ? MyPageScreenUi.textSecondary.withValues(alpha: 0.5)
                      : MyPageScreenUi.primary,
                ),
                child: icon!,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: MyPageScreenUi.outlineButtonStyle(height: height),
        child: child,
      ),
    );
  }
}

/// 見出し行（タイトル + 任意チップ）。
class MyPageSectionHeaderRow extends StatelessWidget {
  const MyPageSectionHeaderRow({
    super.key,
    required this.title,
    this.trailingChip,
  });

  final String title;
  final Widget? trailingChip;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: MyPageScreenUi.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
          ),
        ),
        if (trailingChip != null) ...[
          const SizedBox(width: 8),
          trailingChip!,
        ],
      ],
    );
  }
}

/// ラベル + チップ行（設定状態カード向け）。
class MyPageSettingStatusRow extends StatelessWidget {
  const MyPageSettingStatusRow({
    super.key,
    required this.label,
    required this.chipLabel,
    required this.chipVariant,
    this.showDivider = true,
  });

  final String label;
  final String chipLabel;
  final MyPageStatusChipVariant chipVariant;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MyPageScreenUi.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                ),
              ),
              MyPageStatusChip(label: chipLabel, variant: chipVariant),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: MyPageScreenUi.cardBorder),
      ],
    );
  }
}

/// 設定行（左: 項目名 / 右: 状態チップ + chevron、タップで編集導線）。
class MyPageSettingNavRow extends StatelessWidget {
  const MyPageSettingNavRow({
    super.key,
    required this.label,
    required this.chipLabel,
    required this.chipVariant,
    required this.onTap,
    this.showDivider = true,
    this.semanticsLabel,
  });

  final String label;
  final String chipLabel;
  final MyPageStatusChipVariant chipVariant;
  final VoidCallback onTap;
  final bool showDivider;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final row = Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: MyPageScreenUi.textPrimary,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: MyPageStatusChip(
                      label: chipLabel,
                      variant: chipVariant,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: MyPageScreenUi.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: MyPageScreenUi.cardBorder),
      ],
    );
    final semantics = semanticsLabel;
    if (semantics == null) return row;
    return Semantics(label: semantics, button: true, child: row);
  }
}

/// 登録情報など、右端 chevron の ListTile 行。
class MyPageNavListTile extends StatelessWidget {
  const MyPageNavListTile({
    super.key,
    required this.title,
    required this.onTap,
    this.showDivider = true,
    this.dense = false,
  });

  final String title;
  final VoidCallback onTap;
  final bool showDivider;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: dense ? 8 : 12,
                horizontal: 2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: MyPageScreenUi.textPrimary,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: MyPageScreenUi.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: MyPageScreenUi.cardBorder),
      ],
    );
  }
}

/// 未設定項目行（右端に「設定する」ボタン）。
class MyPageUnsetItemRow extends StatelessWidget {
  const MyPageUnsetItemRow({
    super.key,
    required this.label,
    required this.onConfigure,
    this.showDivider = true,
  });

  final String label;
  final VoidCallback onConfigure;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MyPageScreenUi.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              OutlinedButton(
                onPressed: onConfigure,
                style: MyPageScreenUi.subtleOutlineButtonStyle(height: 36)
                    .copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                child: const Text('設定する'),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: MyPageScreenUi.cardBorder),
      ],
    );
  }
}

/// 初期設定不足時のガイドカード。
class MyPageSetupIncompleteCard extends StatelessWidget {
  const MyPageSetupIncompleteCard({
    super.key,
    required this.profile,
    required this.savedShopCount,
    required this.onOpenSetup,
    required this.onLater,
  });

  final UserProfile profile;
  final int savedShopCount;
  final VoidCallback onOpenSetup;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final hasRoomUrl = profile.hasRoomUrl;
    final hasGenres = profile.favoriteGenreIdList.isNotEmpty;
    final hasSavedShops = savedShopCount > 0;
    final stepDone = [hasRoomUrl, hasGenres, hasSavedShops];
    final completedCount = stepDone.where((e) => e).length;
    final progress = completedCount / 3;

    return MyPageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MyPageSectionHeaderRow(title: '設定を完了しましょう'),
          const SizedBox(height: 8),
          Text(
            '不足している設定を完了すると、候補提案が使いやすくなります',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            '$completedCount/3 完了',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: MyPageScreenUi.progressTrack,
              color: MyPageScreenUi.primary,
            ),
          ),
          const SizedBox(height: 16),
          MyPagePrimaryButton(
            label: '初期設定を再開',
            onPressed: onOpenSetup,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onLater,
            style: MyPageScreenUi.outlineButtonStyle(height: 44),
            child: const Text('あとで'),
          ),
        ],
      ),
    );
  }
}

/// 設定完了時の ROOM 運用設定カード。
class MyPageRoomSettingsCard extends StatelessWidget {
  const MyPageRoomSettingsCard({
    super.key,
    required this.profile,
    required this.savedShopCount,
    required this.onEditNickname,
    required this.onEditRoomUrl,
    required this.onEditGenres,
    required this.onOpenSavedShops,
    required this.onEditPostStyle,
  });

  final UserProfile profile;
  final int savedShopCount;
  final VoidCallback onEditNickname;
  final VoidCallback onEditRoomUrl;
  final VoidCallback onEditGenres;
  final VoidCallback onOpenSavedShops;
  final VoidCallback onEditPostStyle;

  @override
  Widget build(BuildContext context) {
    final genreCount = profile.favoriteGenreIdList.length;
    final hasNickname = profile.displayName.trim().isNotEmpty;
    final postStyleLabel = profile.postStyleLabelsText.trim();
    final hasPostStyle = postStyleLabel.isNotEmpty;
    final basicConfigured =
        profile.hasRoomUrl && genreCount > 0 && savedShopCount > 0;

    return MyPageCard(
      key: TutorialTargetKeys.roomSettingsCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MyPageSectionHeaderRow(
            title: 'ROOM運用の設定',
            trailingChip: MyPageStatusChip(
              label: basicConfigured ? '基本設定済み' : '未完了',
              variant: basicConfigured
                  ? MyPageStatusChipVariant.set
                  : MyPageStatusChipVariant.unset,
            ),
          ),
          const SizedBox(height: 4),
          MyPageSettingNavRow(
            key: TutorialTargetKeys.nicknameRow,
            label: 'ニックネーム',
            chipLabel: hasNickname ? '設定済み' : '未設定',
            chipVariant: hasNickname
                ? MyPageStatusChipVariant.set
                : MyPageStatusChipVariant.optional,
            onTap: onEditNickname,
            semanticsLabel: 'ニックネーム設定',
          ),
          MyPageSettingNavRow(
            key: TutorialTargetKeys.roomUrlRow,
            label: 'ROOM URL',
            chipLabel: profile.hasRoomUrl ? '登録済み' : '未設定',
            chipVariant: profile.hasRoomUrl
                ? MyPageStatusChipVariant.set
                : MyPageStatusChipVariant.unset,
            onTap: onEditRoomUrl,
            semanticsLabel: 'ROOM URL設定',
          ),
          MyPageSettingNavRow(
            key: TutorialTargetKeys.genreRow,
            label: 'お気に入りジャンル',
            chipLabel: genreCount > 0 ? '$genreCount件' : '未設定',
            chipVariant: genreCount > 0
                ? MyPageStatusChipVariant.set
                : MyPageStatusChipVariant.unset,
            onTap: onEditGenres,
            semanticsLabel: 'お気に入りジャンル設定',
          ),
          MyPageSettingNavRow(
            key: TutorialTargetKeys.savedShopRow,
            label: '保存ショップ',
            chipLabel: savedShopCount > 0 ? '$savedShopCount件' : '未設定',
            chipVariant: savedShopCount > 0
                ? MyPageStatusChipVariant.set
                : MyPageStatusChipVariant.unset,
            onTap: onOpenSavedShops,
            semanticsLabel: '保存ショップ設定',
          ),
          MyPageSettingNavRow(
            key: TutorialTargetKeys.postStyleRow,
            label: '探し方',
            chipLabel: hasPostStyle ? postStyleLabel : '未設定',
            chipVariant: hasPostStyle
                ? MyPageStatusChipVariant.set
                : MyPageStatusChipVariant.optional,
            onTap: onEditPostStyle,
            showDivider: false,
            semanticsLabel: '探し方設定',
          ),
        ],
      ),
    );
  }
}

/// 現在のプランカード。
class MyPagePlanCard extends StatelessWidget {
  const MyPagePlanCard({super.key, required this.onOpenPlan});

  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final plan = resolveCurrentMonetizationPlan();
    final planLabel = monetizationPlanDisplayName(plan);

    return MyPageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MyPageSectionHeaderRow(
            title: '現在のプラン',
            trailingChip: MyPageStatusChip(
              label: planLabel,
              variant: MyPageStatusChipVariant.set,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            plan == MonetizationPlan.free
                ? '必要に応じてBasicプランに変更できます'
                : 'プラン内容はいつでも確認できます',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            key: const Key('mypage_plan_entry'),
            onPressed: onOpenPlan,
            style: MyPageScreenUi.outlineButtonStyle(height: 44),
            child: const Text('プランを見る'),
          ),
        ],
      ),
    );
  }
}

/// アプリ設定カード。
class MyPageAppSettingsCard extends StatelessWidget {
  const MyPageAppSettingsCard({
    super.key,
    required this.onOpenInitialSetup,
    required this.onOpenSavedShops,
    required this.onOpenTutorialReplay,
    this.onOpenDemo,
    this.onOpenDevAutomation,
  });

  final VoidCallback onOpenInitialSetup;
  final VoidCallback onOpenSavedShops;
  final VoidCallback onOpenTutorialReplay;
  final VoidCallback? onOpenDemo;
  final VoidCallback? onOpenDevAutomation;

  @override
  Widget build(BuildContext context) {
    return MyPageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MyPageSectionHeaderRow(title: 'アプリ設定'),
          const SizedBox(height: 4),
          MyPageNavListTile(
            title: '初期設定をやり直す',
            onTap: onOpenInitialSetup,
          ),
          MyPageNavListTile(
            title: '保存ショップを管理',
            onTap: onOpenSavedShops,
          ),
          MyPageNavListTile(
            key: const Key('mypage_tutorial_replay_entry'),
            title: '操作ガイドをもう一度見る',
            onTap: onOpenTutorialReplay,
          ),
          MyPageNavListTile(
            title: '通知設定',
            onTap: () => _showComingSoonSnackBar(context, '通知設定'),
          ),
          MyPageNavListTile(
            title: 'データ管理',
            onTap: () => _showComingSoonSnackBar(context, 'データ管理'),
            showDivider: onOpenDemo == null && onOpenDevAutomation == null,
          ),
          if (onOpenDemo != null) ...[
            MyPageNavListTile(
              title: 'クローズドテスト用デモを見る',
              onTap: onOpenDemo!,
              dense: true,
              showDivider: onOpenDevAutomation == null,
            ),
          ],
          if (onOpenDevAutomation != null)
            MyPageNavListTile(
              title: '開発者向け自動検証',
              onTap: onOpenDevAutomation!,
              dense: true,
              showDivider: false,
            ),
        ],
      ),
    );
  }
}

/// サポートカード。
class MyPageSupportCard extends StatelessWidget {
  const MyPageSupportCard({super.key});

  @override
  Widget build(BuildContext context) {
    return MyPageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MyPageSectionHeaderRow(title: 'サポート'),
          const SizedBox(height: 4),
          MyPageNavListTile(
            title: 'ヘルプ',
            onTap: () => _showComingSoonSnackBar(context, 'ヘルプ'),
          ),
          MyPageNavListTile(
            title: 'お問い合わせ',
            onTap: () => _showComingSoonSnackBar(context, 'お問い合わせ'),
          ),
          MyPageNavListTile(
            title: '利用規約',
            onTap: () => AppActionService.openUrl(
              context,
              url: LegalUrls.termsOfService,
            ),
            dense: true,
          ),
          MyPageNavListTile(
            title: 'プライバシーポリシー',
            onTap: () => AppActionService.openUrl(
              context,
              url: LegalUrls.privacyPolicy,
            ),
            dense: true,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

/// 画面最下部のアプリ情報。
class MyPageAppInfoSection extends StatelessWidget {
  const MyPageAppInfoSection({super.key, this.versionLabel = '1.0.0'});

  final String versionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'アプリ情報',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'バージョン $versionLabel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

void _showComingSoonSnackBar(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$featureは準備中です')),
  );
}

/// 後方互換: 既存テストが参照する設定セクション。
class MyPageSettingsSection extends StatelessWidget {
  const MyPageSettingsSection({
    super.key,
    required this.onOpenPlan,
    this.onOpenDemo,
    this.onOpenDevAutomation,
    required this.onOpenInitialSetup,
    this.onOpenSavedShops,
    this.onOpenTutorialReplay,
  });

  final VoidCallback onOpenPlan;
  final VoidCallback? onOpenDemo;
  final VoidCallback? onOpenDevAutomation;
  final VoidCallback onOpenInitialSetup;
  final VoidCallback? onOpenSavedShops;
  final VoidCallback? onOpenTutorialReplay;

  static bool _devAutomationEntryVisibilityLogged = false;

  @override
  Widget build(BuildContext context) {
    if (onOpenDevAutomation != null &&
        kDebugMode &&
        !_devAutomationEntryVisibilityLogged) {
      _devAutomationEntryVisibilityLogged = true;
      debugPrint('[DEV_AUTOMATION_ENTRY_VISIBLE] enabled=true');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyPagePlanCard(onOpenPlan: onOpenPlan),
        const SizedBox(height: MyPageScreenUi.gapSection),
        MyPageAppSettingsCard(
          onOpenInitialSetup: onOpenInitialSetup,
          onOpenSavedShops: onOpenSavedShops ?? () {},
          onOpenTutorialReplay: onOpenTutorialReplay ?? () {},
          onOpenDemo: onOpenDemo,
          onOpenDevAutomation: onOpenDevAutomation,
        ),
        const SizedBox(height: MyPageScreenUi.gapSection),
        const MyPageSupportCard(),
        const SizedBox(height: MyPageScreenUi.gapSection),
        const MyPageAppInfoSection(),
      ],
    );
  }
}
