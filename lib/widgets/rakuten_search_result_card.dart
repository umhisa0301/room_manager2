import 'package:flutter/material.dart';

import '../models/rakuten_managed_product.dart';
import '../models/rakuten_search_item.dart';
import '../services/app_action_service.dart';
import '../theme/app_theme.dart';

/// 楽天検索結果の1商品カード。
class RakutenSearchResultCard extends StatelessWidget {
  const RakutenSearchResultCard({
    super.key,
    required this.item,
    required this.localStatus,
    required this.isRegistering,
    required this.onRegisterCandidate,
  });

  final RakutenSearchItem item;
  final RakutenManagedProductStatus localStatus;
  final bool isRegistering;
  final VoidCallback onRegisterCandidate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '¥${item.itemPrice}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.shopName.isEmpty ? 'ショップ名なし' : item.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 10),
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
        color: AppColors.surfaceVariant,
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
      color: AppColors.textTertiary.withValues(alpha: 0.7),
    );
  }
}
