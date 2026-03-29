import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../services/app_action_service.dart';
import '../state/rakuten_managed_product_provider.dart';
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

  bool get _canCollectRoom =>
      product.extractionStatus == RakutenUrlExtractionStatus.success &&
      product.extractedUrl.trim().isNotEmpty;

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
                    if (isCandidate) ...[
                      const SizedBox(height: 6),
                      _extractionStatusLine(context),
                    ],
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
                      _footerLine(isCandidate),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isCandidate)
            _candidateActions(context)
          else
            _doneActions(context),
        ],
      ),
    );
  }

  String _footerLine(bool isCandidate) {
    if (!isCandidate && product.doneAt != null) {
      return 'コレ済: ${_formatDateTime(product.doneAt!)}';
    }
    return '更新: ${_formatDateTime(product.updatedAt)}';
  }

  Widget _candidateActions(BuildContext context) {
    final provider = context.read<RakutenManagedProductProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message:
              _canCollectRoom ? 'ROOMのURLを開き、コレ済に移します' : 'ROOM用URLが取得できるまでお待ちください',
          child: FilledButton(
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: _candidateAccent,
              disabledForegroundColor: AppColors.textTertiary,
              disabledBackgroundColor: AppColors.surfaceVariant,
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: _canCollectRoom
                ? () => provider.collectRoomAndLaunch(context, product.productId)
                : null,
            child: Text(_canCollectRoom ? 'コレする' : 'コレする（URL未取得）'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _candidateAccent,
                  minimumSize: const Size.fromHeight(40),
                ),
                onPressed: () async {
                  final err = await provider.openRakutenItemPage(
                    context,
                    product.productId,
                  );
                  if (!context.mounted) return;
                  if (err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err)),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_browser, size: 18),
                label: const Text('楽天で見る'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  minimumSize: const Size.fromHeight(40),
                ),
                onPressed: () => _confirmRemoveCandidate(context, provider),
                child: const Text('候補から外す'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmRemoveCandidate(
    BuildContext context,
    RakutenManagedProductProvider provider,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('候補から外す'),
        content: Text(
          '「${product.itemName}」をコレ候補から削除します。よろしいですか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await provider.removeCandidate(context, product.productId);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  Widget _doneActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _doneAccent,
              side: BorderSide(color: Colors.grey.shade500),
              minimumSize: const Size.fromHeight(40),
            ),
            onPressed: () => AppActionService.openUrl(
              context,
              url: product.itemUrl.trim().isNotEmpty
                  ? product.itemUrl.trim()
                  : product.browserLaunchUrl,
            ),
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: const Text('楽天で見る'),
          ),
        ),
        if (product.extractedUrl.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _doneAccent,
              side: BorderSide(color: _doneAccent.withValues(alpha: 0.5)),
              minimumSize: const Size.fromHeight(40),
            ),
            onPressed: () => AppActionService.openUrl(
              context,
              url: product.extractedUrl.trim(),
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('ROOMを開く'),
          ),
        ],
      ],
    );
  }

  Widget _extractionStatusLine(BuildContext context) {
    final s = product.extractionStatus;
    late final String label;
    late final Color bg;
    late final Color fg;
    switch (s) {
      case RakutenUrlExtractionStatus.notStarted:
        label = 'URL準備: 待機';
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
      case RakutenUrlExtractionStatus.extracting:
        label = 'URL準備中…';
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
      case RakutenUrlExtractionStatus.success:
        label = 'URL取得済み';
        bg = const Color(0xFFE8F5E9);
        fg = _doneAccent;
      case RakutenUrlExtractionStatus.failed:
        label = 'URL取得失敗';
        bg = AppColors.error.withValues(alpha: 0.1);
        fg = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
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
