import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../services/room_import_enrichment_cooldown_store.dart';
import '../services/room_import_limit_policy.dart';
import '../services/room_import_metadata_enrichment.dart';
import '../state/bulk_operation_state_controller.dart';
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
    return Consumer2<BulkOperationStateController, RakutenManagedProductProvider>(
      builder: (context, bulk, managed, _) {
        final n = RoomImportMetadataEnrichmentService.countPendingEnrichment(
          managed.items,
        );
        if (n <= 0 && !bulk.hasManualEnrichSummary) {
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
        final sum = bulk.hasManualEnrichSummary;
        final succ = bulk.lastManualEnrichSuccess;
        final fail = bulk.lastManualEnrichFail;
        final pausedRl = bulk.lastManualEnrichPausedRateLimit;

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
                        ? 'ショップ名・ジャンルの確認を一時停止しています'
                        : 'ショップ名・ジャンルを確認中です',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sum
                        ? '未確認：$n件 / 今回成功：$succ件 / 今回失敗：$fail件'
                        : '未確認：$n件',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: subtle,
                      height: 1.35,
                    ),
                  ),
                  if (pausedRl && sum) ...[
                    const SizedBox(height: 2),
                    Text(
                      '直近の実行はAPI制限で途中終了しました。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtle,
                        height: 1.35,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
                  ],
                  const SizedBox(height: 2),
                  Text(
                    '商品名・価格・画像はROOMから取得し、ショップ名・ジャンルは確認できた商品から反映されます',
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
