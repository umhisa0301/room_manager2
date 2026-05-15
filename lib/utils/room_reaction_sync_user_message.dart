/// 反応同期完了時のユーザー向け短文（SnackBar 等）。
String roomReactionSyncSnackBarSummary({
  required int checkedItems,
  required int updatedItems,
  required int unchangedItems,
  required int likeIncreasedItems,
  required int commentIncreasedItems,
  required String stopReason,
  required bool hasNextCursor,
}) {
  final c = checkedItems;
  final u = updatedItems;
  final timeLimited = stopReason == 'maxDurationReached';
  final cont = timeLimited && hasNextCursor && u > 0;

  if (u <= 0 && likeIncreasedItems <= 0 && commentIncreasedItems <= 0) {
    if (timeLimited && hasNextCursor) {
      return '反応数を確認しました：確認$c件 / 変更なし。続きは次回同期します。';
    }
    return '反応数を確認しました：確認$c件 / 変更なし';
  }

  final parts = <String>['確認$c件', '更新$u件'];
  if (likeIncreasedItems > 0) {
    parts.add('いいね増$likeIncreasedItems件');
  }
  if (commentIncreasedItems > 0) {
    parts.add('コメント増$commentIncreasedItems件');
  }
  var line = '反応数を同期しました：${parts.join(' / ')}';
  if (cont) {
    line += '。続きは次回同期します。';
  }
  return line;
}
