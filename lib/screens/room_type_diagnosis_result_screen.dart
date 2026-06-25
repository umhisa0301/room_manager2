import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/room_type_definitions.dart';
import '../models/room_recommendation_profile.dart';
import '../services/room_diagnosis_service.dart';
import '../state/today_recommendation_provider.dart';
import '../state/user_profile_provider.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/saved_shop_provider.dart';
import '../theme/mypage_screen_tokens.dart';
import '../widgets/mypage/mypage_widgets.dart';
import '../widgets/room_type_diagnosis_widgets.dart';
import 'today_recommendations_screen.dart';

/// 診断完了後にタイプ結果を表示する画面。
class RoomTypeDiagnosisResultScreen extends StatelessWidget {
  const RoomTypeDiagnosisResultScreen({
    super.key,
    required this.profile,
  });

  final RoomRecommendationProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeDef = RoomTypeDefinitions.byId(profile.primaryTypeId);
    final typeName = typeDef?.displayName ??
        RoomTypeDefinitions.displayNameFor(profile.primaryTypeId);
    final typeDescription = typeDef?.description ?? '';
    final interestLabel =
        RoomDiagnosisService.interestCategoriesLabel(profile.interestCategoryIds);
    final priorityLabel =
        RoomDiagnosisService.priorityRulesLabel(profile.priorityRuleIds);

    return Scaffold(
      backgroundColor: MyPageScreenUi.canvas,
      appBar: AppBar(
        title: const Text('診断結果'),
        backgroundColor: MyPageScreenUi.canvas,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'あなたは',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: MyPageScreenUi.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            RoomTypeBadge(typeDisplayName: typeName),
            if (typeDescription.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                typeDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _recommendationHint(typeDef?.id ?? profile.primaryTypeId),
              style: theme.textTheme.bodySmall?.copyWith(
                color: MyPageScreenUi.textSecondary,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (interestLabel.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '関心ジャンル',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: MyPageScreenUi.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                interestLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (priorityLabel.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '重視する条件',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: MyPageScreenUi.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                priorityLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: MyPageScreenUi.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 28),
            MyPagePrimaryButton(
              label: 'おすすめコレを見る',
              onPressed: () => _openRecommendations(context),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              style: MyPageScreenUi.outlineButtonStyle(height: 48),
              child: const Text('マイページへ戻る'),
            ),
          ],
        ),
      ),
    );
  }

  String _recommendationHint(String typeId) {
    switch (typeId) {
      case 'visual_mood':
        return 'おすすめコレでは、ファッション・美容・写真映えしやすい商品を優先して提案します。';
      case 'life_convenience':
        return 'おすすめコレでは、時短・収納・日用品など暮らしをラクにする商品を優先して提案します。';
      case 'value_balance':
        return 'おすすめコレでは、コスパや高評価のバランスが良い商品を優先して提案します。';
      case 'gift_event':
        return 'おすすめコレでは、ギフトやイベント向けの商品を優先して提案します。';
      default:
        return 'おすすめコレに診断結果が反映されます。';
    }
  }

  Future<void> _openRecommendations(BuildContext context) async {
    final recommender = context.read<TodayRecommendationProvider>();
    await recommender.ensureToday(
      profile: context.read<UserProfileProvider>().profile,
      managedItems: context.read<RakutenManagedProductProvider>().items,
      savedShops: context.read<SavedShopProvider>().shops,
      recommendationProfile: profile,
      trigger: 'diagnosisResult',
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TodayRecommendationsScreen(skipInitialEnsure: true),
      ),
    );
  }
}
