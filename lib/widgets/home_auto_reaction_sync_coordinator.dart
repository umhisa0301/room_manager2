import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_managed_product.dart';
import '../navigation/app_shell_controller.dart';
import '../services/room_profile_url_validation_service.dart';
import '../services/room_reaction_sync_history_store.dart';
import '../state/bulk_operation_state_controller.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../state/room_import_controller.dart';
import '../state/user_profile_provider.dart';
import '../utils/home_auto_reaction_sync.dart';

/// ホーム表示後、セッション内1回だけ silent 反応確認を試みる。
class HomeAutoReactionSyncCoordinator extends StatefulWidget {
  const HomeAutoReactionSyncCoordinator({
    super.key,
    required this.onSyncCompleted,
  });

  final VoidCallback onSyncCompleted;

  @visibleForTesting
  static bool sessionAttempted = false;

  @visibleForTesting
  static void resetSessionForTest() {
    sessionAttempted = false;
  }

  @override
  State<HomeAutoReactionSyncCoordinator> createState() =>
      _HomeAutoReactionSyncCoordinatorState();
}

class _HomeAutoReactionSyncCoordinatorState
    extends State<HomeAutoReactionSyncCoordinator> {
  Timer? _startTimer;
  AppShellController? _shell;
  bool _shellListenerAttached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || HomeAutoReactionSyncCoordinator.sessionAttempted) return;
      _shell = context.read<AppShellController>();
      if (_shell!.currentIndex == 0) {
        _scheduleAttempt();
      } else {
        _shell!.addListener(_onShellIndexChanged);
        _shellListenerAttached = true;
      }
    });
  }

  void _onShellIndexChanged() {
    if (!mounted || HomeAutoReactionSyncCoordinator.sessionAttempted) {
      _detachShellListener();
      return;
    }
    if (_startTimer != null) {
      _detachShellListener();
      return;
    }
    if (_shell?.currentIndex == 0) {
      _detachShellListener();
      _scheduleAttempt();
    }
  }

  void _scheduleAttempt() {
    if (_startTimer != null || HomeAutoReactionSyncCoordinator.sessionAttempted) {
      return;
    }
    debugPrint('[AUTO_REACTION_SYNC] scheduled');
    _startTimer = Timer(
      HomeAutoReactionSyncPolicy.autoReactionSyncStartDelay,
      () => unawaited(_attemptOnce()),
    );
  }

  void _detachShellListener() {
    if (_shellListenerAttached && _shell != null) {
      _shell!.removeListener(_onShellIndexChanged);
      _shellListenerAttached = false;
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _detachShellListener();
    super.dispose();
  }

  Future<void> _attemptOnce() async {
    if (!mounted) return;
    if (HomeAutoReactionSyncCoordinator.sessionAttempted) return;
    HomeAutoReactionSyncCoordinator.sessionAttempted = true;

    final shell = context.read<AppShellController>();
    if (shell.currentIndex != 0) {
      debugPrint('[AUTO_REACTION_SYNC] skipped reason=notOnHome');
      return;
    }

    final profileUrl = RoomProfileUrlValidationService.normalizeProfileUrl(
      context.read<UserProfileProvider>().profile.roomUrl,
    );
    final postedCount = context
        .read<RakutenManagedProductProvider>()
        .items
        .where(
          (e) =>
              e.status == RakutenManagedProductStatus.done &&
              e.roomUrl.trim().isNotEmpty,
        )
        .length;

    final ctl = context.read<RoomImportController>();
    final bulk = context.read<BulkOperationStateController>();

    final latest = await RoomReactionSyncHistoryStore.loadLatest();
    DateTime? lastSyncAtUtc;
    if (latest != null) {
      try {
        lastSyncAtUtc = DateTime.parse(latest.syncedAtIso).toUtc();
      } catch (_) {}
    }

    final reason = HomeAutoReactionSyncPolicy.skipReason(
      isOnHomeTab: true,
      hasRoomUrl: profileUrl.isNotEmpty,
      postedProductCount: postedCount,
      importRunning: ctl.isRunning,
      metadataEnriching: bulk.isMetadataEnriching,
      reactionSyncRunning: bulk.isRoomReactionSyncRunning,
      bulkCandidateRegistering: bulk.isBulkCandidateRegistering,
      lastSyncAtUtc: lastSyncAtUtc,
      nowUtc: DateTime.now().toUtc(),
    );
    if (reason != null) {
      debugPrint('[AUTO_REACTION_SYNC] skipped reason=$reason');
      return;
    }

    if (!mounted) return;
    if (context.read<AppShellController>().currentIndex != 0) {
      debugPrint('[AUTO_REACTION_SYNC] skipped reason=notOnHome');
      return;
    }

    debugPrint('[AUTO_REACTION_SYNC] started');
    final result = await ctl.runReactionSync(context, silent: true);
    if (!mounted) return;

    if (result == null) {
      debugPrint('[AUTO_REACTION_SYNC] failed nullResult');
      return;
    }
    if (result.hasFatalError) {
      debugPrint('[AUTO_REACTION_SYNC] failed fatalError');
      return;
    }

    final like = result.likeIncreasedItems;
    final comment = result.commentIncreasedItems;
    if (like > 0 || comment > 0) {
      debugPrint(
        '[AUTO_REACTION_SYNC] completed likeIncreased=$like '
        'commentIncreased=$comment',
      );
    } else {
      debugPrint('[AUTO_REACTION_SYNC] completed noChange');
    }
    widget.onSyncCompleted();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
