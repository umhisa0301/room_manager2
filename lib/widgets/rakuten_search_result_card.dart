import 'package:flutter/material.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../services/app_action_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';

/// 楽天検索結果の1商品カード。
class RakutenSearchResultCard extends StatelessWidget {
  const RakutenSearchResultCard({
    super.key,
    required this.item,
    required this.localStatus,
    required this.isRegistering,
    required this.onRegisterCandidate,
    this.selectionMode = false,
    this.isSelected = false,
    this.isSelectionEnabled = true,
    this.onToggleSelected,
    this.selectionDisabledLabel,
  });

  final RakutenSearchItem item;
  final RakutenManagedProductStatus localStatus;
  final bool isRegistering;
  final VoidCallback onRegisterCandidate;
  final bool selectionMode;
  final bool isSelected;
  final bool isSelectionEnabled;
  final VoidCallback? onToggleSelected;
  final String? selectionDisabledLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomeScreenColors.roomMetricTileFill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: HomeScreenColors.roomMetricTileBorder),
        boxShadow: HomeScreenColors.roomMetricTileShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: _buildSelectionControl(context),
            ),
          _buildImage(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.itemName,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: HomeScreenColors.metricTileTitleColor,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '¥${item.itemPrice}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: HomeScreenColors.sectionTitleAccent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.shopName.isEmpty ? 'ショップ名なし' : item.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HomeScreenColors.metricTileCaptionColor,
                      ),
                ),
                const SizedBox(height: 10),
                if (selectionMode && !isSelectionEnabled) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: HomeScreenColors.subActionRowFill,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HomeScreenColors.deckOutline),
                    ),
                    child: Text(
                      selectionDisabledLabel ?? 'この商品は選択できません',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: HomeScreenColors.groupedSectionBody,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => AppActionService.openUrl(
                          context,
                          url: item.browserLaunchUrl,
                        ),
                        child: const Text('楽天で見る'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCandidateAction(context),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionControl(BuildContext context) {
    if (!isSelectionEnabled) {
      return Icon(
        Icons.block_rounded,
        size: 22,
        color: HomeScreenColors.footnoteMuted,
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onToggleSelected,
      child: Icon(
        isSelected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        size: 24,
        color: isSelected
            ? HomeScreenColors.statusAccentStrong
            : HomeScreenColors.groupedSectionBody,
      ),
    );
  }

  Widget _buildCandidateAction(BuildContext context) {
    final isCandidate = localStatus == RakutenManagedProductStatus.candidate;
    final isDone = localStatus == RakutenManagedProductStatus.done;

    if (isDone) {
      return OutlinedButton(
        onPressed: null,
        child: const Text('コレ済'),
      );
    }

    if (isCandidate) {
      return OutlinedButton(
        onPressed: null,
        child: const Text('コレ候補登録済'),
      );
    }

    return FilledButton.tonal(
      onPressed: isRegistering ? null : onRegisterCandidate,
      child: isRegistering
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('コレ候補へ登録'),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 88,
        height: 88,
        color: HomeScreenColors.candidateThumbPlaceholder
            .withValues(alpha: 0.35),
        child: item.imageUrl.isNotEmpty
            ? Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Icon(
      Icons.image_outlined,
      size: 28,
      color: HomeScreenColors.footnoteMuted,
    );
  }
}
