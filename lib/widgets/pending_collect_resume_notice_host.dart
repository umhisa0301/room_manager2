import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_messenger.dart';
import '../repository/pending_collect_notice_repository.dart';

/// アプリが [AppLifecycleState.resumed] になったとき、
/// 保留中の「コレ済へ移動」通知を一度だけ表示する。
class PendingCollectResumeNoticeHost extends StatefulWidget {
  const PendingCollectResumeNoticeHost({super.key, required this.child});

  final Widget child;

  @override
  State<PendingCollectResumeNoticeHost> createState() =>
      _PendingCollectResumeNoticeHostState();
}

class _PendingCollectResumeNoticeHostState
    extends State<PendingCollectResumeNoticeHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _presentPendingNotices();
    }
  }

  Future<void> _presentPendingNotices() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final repo = context.read<PendingCollectNoticeRepository>();
      final names = await repo.consumeAllPendingItemNames();
      if (!mounted || names.isEmpty) return;
      final text = _formatCollectMovedMessage(names);
      appRootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(text, maxLines: 4, overflow: TextOverflow.ellipsis),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    });
  }

  /// 管理アプリ上でコレ済へ移したことの通知（ROOM本番投稿の保証ではない）。
  String _formatCollectMovedMessage(List<String> rawNames) {
    final names = rawNames.map(_truncateName).toList(growable: false);
    if (names.isEmpty) return '';
    if (names.length == 1) {
      return '「${names.first}」をコレ済へ移動しました（このアプリの一覧を更新しました）';
    }
    if (names.length == 2) {
      return '「${names[0]}」「${names[1]}」をコレ済へ移動しました（一覧を更新）';
    }
    return '「${names.first}」ほか${names.length - 1}件をコレ済へ移動しました（一覧を更新）';
  }

  String _truncateName(String name, {int maxChars = 28}) {
    final t = name.trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars)}…';
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
