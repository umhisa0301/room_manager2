import 'package:flutter/material.dart';

import '../models/rakuten_managed_product.dart'
    show RakutenManagedProduct, RakutenUrlExtractionStatus;
import '../services/app_action_service.dart';
import '../theme/app_theme.dart';

/// 一覧カードの見た目バリアント（候補 / コレ済）。
enum RakutenManagedProductCardVariant {
  candidate,
  done,
}

/// 楽天ROOM管理の保存済み商品カード（候補・コレ済で配色を変える）。
class RakutenManagedProductCard extends StatelessWidget {
  const RakutenManagedProductCard({
    super.key,
    required this.product,
    required this.variant,
  });

  final RakutenManagedProduct product;
  final RakutenManagedProductCardVariant variant;

  static const Color _candidateAccent = Color(0xFF1565C0);
  static const Color _candidateSurface = Color(0xFFE3F2FD);
  static const Color _doneAccent = Color(0xFF2E7D32);
  static const Color _doneSurface = Color(0xFFF1F8F4);

  @override
  Widget build(BuildContext context) {
    final isCandidate = variant == RakutenManagedProductCardVariant.candidate;
    final accent = isCandidate ? _candidateAccent : _doneAccent;
    final surfaceTint = isCandidate ? _candidateSurface : _doneSurface;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: isCandidate
              ? _candidateAccent.withValues(alpha: 0.35)
              : Colors.grey.shade400,
          width: isCandidate ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(surfaceTint),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statusBadge(context, accent, isCandidate),
                    const SizedBox(height: 6),
                    Text(
                      product.itemName,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '¥${product.itemPrice}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.shopName.isEmpty ? 'ショップ名なし' : product.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '更新: ${_formatDateTime(product.updatedAt)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                    if (isCandidate) ...[
                      const SizedBox(height: 6),
                      _extractionStatusRow(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: isCandidate
                ? FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      foregroundColor: _candidateAccent,
                      backgroundColor: _candidateSurface,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    onPressed: () => AppActionService.openUrl(
                      context,
                      url: product.browserLaunchUrl,
                    ),
                    child: const Text('楽天で見る'),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _doneAccent,
                      side: BorderSide(color: Colors.grey.shade500),
                      minimumSize: const Size.fromHeight(40),
                    ),
                    onPressed: () => AppActionService.openUrl(
                      context,
                      url: product.browserLaunchUrl,
                    ),
                    child: const Text('楽天で見る'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _extractionStatusRow(BuildContext context) {
    final label = _extractionLabel(product.extractionStatus);
    final color = _extractionColor(product.extractionStatus);
    return Row(
      children: [
        Icon(Icons.link, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  static String _extractionLabel(RakutenUrlExtractionStatus s) {
    switch (s) {
      case RakutenUrlExtractionStatus.notStarted:
        return '抽出URL: 未開始';
      case RakutenUrlExtractionStatus.extracting:
        return 'URL準備中…';
      case RakutenUrlExtractionStatus.success:
        return 'URL取得済み';
      case RakutenUrlExtractionStatus.failed:
        return 'URL取得失敗';
    }
  }

  static Color _extractionColor(RakutenUrlExtractionStatus s) {
    switch (s) {
      case RakutenUrlExtractionStatus.notStarted:
        return AppColors.textTertiary;
      case RakutenUrlExtractionStatus.extracting:
        return const Color(0xFF1565C0);
      case RakutenUrlExtractionStatus.success:
        return AppColors.success;
      case RakutenUrlExtractionStatus.failed:
        return AppColors.error;
    }
  }

  Widget _statusBadge(
    BuildContext context,
    Color accent,
    bool isCandidate,
  ) {
    if (isCandidate) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '候補',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
        ),
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        Icon(Icons.check_circle, size: 18, color: accent),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'コレ済',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }

  Widget _thumb(Color placeholderTint) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 88,
        height: 88,
        color: placeholderTint,
        child: product.imageUrl.isNotEmpty
            ? Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbPlaceholder(),
              )
            : _thumbPlaceholder(),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Icon(
      Icons.image_outlined,
      size: 28,
      color: AppColors.textTertiary.withValues(alpha: 0.7),
    );
  }

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
