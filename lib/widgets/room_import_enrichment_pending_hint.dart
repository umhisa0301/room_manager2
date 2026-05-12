import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../services/room_import_enrichment_cooldown_store.dart';
import '../services/room_import_limit_policy.dart';
import '../services/room_import_metadata_enrichment.dart';
import '../state/rakuten_managed_product_provider.dart';

/// ROOM 取り込みメタの未補完があるときの控えめな案内（ROOMコレ・マイページ共通）。
class RoomImportEnrichmentPendingHint extends StatefulWidget {
  const RoomImportEnrichmentPendingHint({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  State<RoomImportEnrichmentPendingHint> createState() =>
      _RoomImportEnrichmentPendingHintState();
}

class _RoomImportEnrichmentPendingHintState
    extends State<RoomImportEnrichmentPendingHint> {
  bool? _rateLimitCooldown;
  var _cooldownCheckScheduled = false;

  Future<void> _refreshCooldown() async {
    final c = await RoomImportEnrichmentCooldownStore.isInCooldown();
    if (mounted) setState(() => _rateLimitCooldown = c);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RakutenManagedProductProvider>(
      builder: (context, managed, _) {
        final n = RoomImportMetadataEnrichmentService.countPendingEnrichment(
          managed.items,
        );
        if (n <= 0) {
          _cooldownCheckScheduled = false;
          return const SizedBox.shrink();
        }

        if (!_cooldownCheckScheduled) {
          _cooldownCheckScheduled = true;
          SchedulerBinding.instance.addPostFrameCallback((_) {
            unawaited(_refreshCooldown());
          });
        }

        final theme = Theme.of(context);
        final subtle = theme.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.92,
        );
        final cooldown = _rateLimitCooldown == true;

        return Padding(
          padding:
              widget.padding ??
              const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                    cooldown
                        ? '商品情報の補完を一時停止しています'
                        : '商品情報を順番に補完中です',
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
                  if (cooldown) ...[
                    const SizedBox(height: 2),
                    Text(
                      '楽天API制限のため少し時間をおいて補完します'
                      '（目安${RoomImportLimitPolicy.enrichCooldownAfter429Minutes}分）。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtle,
                        height: 1.35,
                        fontSize: 12,
                      ),
                    ),
                  ] else ...[
                    Text(
                      '価格・画像は少しずつ反映されます',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtle,
                        height: 1.35,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
