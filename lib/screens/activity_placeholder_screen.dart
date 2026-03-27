import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/activity_log_provider.dart';
import '../models/activity_log.dart';
import '../theme/app_theme.dart';

/// 活動画面（今日の記録 + ログ一覧）。
class ActivityPlaceholderScreen extends StatefulWidget {
  const ActivityPlaceholderScreen({
    super.key,
    this.openTodayEditorOnStart = false,
  });

  final bool openTodayEditorOnStart;

  static Route<void> createRecordRoute() {
    return MaterialPageRoute<void>(
      builder: (_) => const ActivityPlaceholderScreen(openTodayEditorOnStart: true),
    );
  }

  @override
  State<ActivityPlaceholderScreen> createState() => _ActivityPlaceholderScreenState();
}

class _ActivityPlaceholderScreenState extends State<ActivityPlaceholderScreen> {
  bool _openedInitialEditor = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.openTodayEditorOnStart && !_openedInitialEditor) {
      _openedInitialEditor = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openTodayEditor(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ActivityLogProvider>();
    final today = provider.getTodayLog();
    final logs = provider.logs;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('活動')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTodayEditor(context),
        icon: const Icon(Icons.edit_note),
        label: const Text('今日を記録'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenPaddingH,
            AppDimensions.spacingMd,
            AppDimensions.screenPaddingH,
            90,
          ),
          children: [
            _Card(
              title: '今日のサマリー',
              child: today == null
                  ? Text(
                      '今日はまだ活動ログがありません。\nコレ件数やコメント件数を記録しましょう。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('コレ件数: ${today.collectedCount}'),
                        const SizedBox(height: 4),
                        Text('コメント件数: ${today.commentCount}'),
                        if ((today.memo ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'メモ: ${today.memo!}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            _Card(
              title: '活動ログ一覧',
              child: logs.isEmpty
                  ? Text(
                      'まだ活動ログがありません',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    )
                  : Column(
                      children: [
                        for (int i = 0; i < logs.length; i++) ...[
                          _LogTile(log: logs[i]),
                          if (i != logs.length - 1) const Divider(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTodayEditor(BuildContext context) async {
    final provider = context.read<ActivityLogProvider>();
    final current = provider.getTodayLog();
    final collectedController = TextEditingController(
      text: current?.collectedCount.toString() ?? '',
    );
    final commentController = TextEditingController(
      text: current?.commentCount.toString() ?? '',
    );
    final memoController = TextEditingController(
      text: current?.memo ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.screenPaddingH,
            AppDimensions.spacingSm,
            AppDimensions.screenPaddingH,
            MediaQuery.of(sheetContext).viewInsets.bottom + AppDimensions.spacingLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: collectedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '今日のコレ件数',
                  hintText: '例: 3',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: commentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '今日のコメント件数',
                  hintText: '例: 5',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: memoController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'メモ（任意）',
                  hintText: '一言メモ',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final collected = int.tryParse(collectedController.text.trim()) ?? 0;
                    final comments = int.tryParse(commentController.text.trim()) ?? 0;
                    final memo = memoController.text.trim().isEmpty
                        ? null
                        : memoController.text.trim();
                    provider.upsertToday(
                      collectedCount: collected,
                      commentCount: comments,
                      memo: memo,
                    );
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        );
      },
    );

    collectedController.dispose();
    commentController.dispose();
    memoController.dispose();
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});
  final ActivityLog log;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            log.dateKey,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          'コレ ${log.collectedCount} / コメント ${log.commentCount}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
