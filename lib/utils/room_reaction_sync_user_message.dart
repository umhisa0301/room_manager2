/// 反応確認完了時のユーザー向け短文（SnackBar 等）。
String roomReactionSyncSnackBarSummary({
  required int checkedItems,
  required int hasReactionItems,
  required int commentedItems,
  required int unchangedItems,
  required String stopReason,
  required bool hasNextCursor,
}) {
  final c = checkedItems;
  final timeLimited = stopReason == 'maxDurationReached';
  final cont = timeLimited && hasNextCursor;

  if (hasReactionItems <= 0 && commentedItems <= 0) {
    if (cont) {
      return '反応を確認しました：確認$c件 / 変更なし。続きは次回確認します。';
    }
    return '反応を確認しました：確認$c件 / 変更なし';
  }

  final parts = <String>['確認$c件', '反応あり$hasReactionItems件'];
  if (commentedItems > 0) {
    parts.add('コメントあり$commentedItems件');
  }
  var line = '反応を確認しました：${parts.join(' / ')}';
  if (cont && hasReactionItems > 0) {
    line += '。続きは次回確認します。';
  }
  return line;
}
