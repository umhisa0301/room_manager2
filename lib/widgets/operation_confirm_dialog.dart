import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// ROOM投稿取り込み前の確認ダイアログ。
Future<bool> showRoomImportConfirmDialog(
  BuildContext context, {
  required String screen,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ROOM投稿を取り込む'),
      content: const Text(
        'ROOM投稿を取り込みます。\n'
        '更新が終わるまで、探す・候補追加は一時停止します。\n'
        'よろしいですか？',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('開始する'),
        ),
      ],
    ),
  );
  if (kDebugMode) {
    debugPrint(
      '[OPERATION_CONFIRM_DIALOG] operation=roomImport screen=$screen '
      'shown=true confirmed=${ok == true}',
    );
  }
  return ok == true;
}

/// 反応確認開始前の確認ダイアログ。
Future<bool> showRoomReactionSyncConfirmDialog(
  BuildContext context, {
  required String screen,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('反応を確認する'),
      content: const Text(
        'ROOM投稿のいいね・コメントを確認します。\n'
        '更新が終わるまで、探す・候補追加は一時停止します。\n'
        'よろしいですか？',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('開始する'),
        ),
      ],
    ),
  );
  if (kDebugMode) {
    debugPrint(
      '[OPERATION_CONFIRM_DIALOG] operation=roomReactionSync screen=$screen '
      'shown=true confirmed=${ok == true}',
    );
  }
  return ok == true;
}
