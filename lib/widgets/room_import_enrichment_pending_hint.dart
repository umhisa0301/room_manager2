import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/room_import_metadata_enrichment.dart';
import '../state/rakuten_managed_product_provider.dart';

/// ROOM 取り込みメタの未補完があるときの控えめな案内（ROOMコレ・マイページ共通）。
class RoomImportEnrichmentPendingHint extends StatelessWidget {
  const RoomImportEnrichmentPendingHint({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Consumer<RakutenManagedProductProvider>(
      builder: (context, managed, _) {
        final n = RoomImportMetadataEnrichmentService.countPendingEnrichment(
          managed.items,
        );
        if (n <= 0) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final subtle = theme.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.92,
        );
        return Padding(
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '商品情報を順番に補完中です',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '未補完：$n件',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: subtle,
                      height: 1.35,
                    ),
                  ),
                  Text(
                    '価格・画像は少しずつ反映されます',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: subtle,
                      height: 1.35,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
