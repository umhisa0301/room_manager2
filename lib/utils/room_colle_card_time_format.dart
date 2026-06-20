import 'package:flutter/material.dart';

/// 相対表示の上限（暦日）。これを超えると mm/dd 固定表示。
const int roomColleCardRelativeDayCap = 7;

/// ROOMコレ一覧カード用の相対日時文字列（intl 不使用・数値比較のみ）。
///
/// - 7暦日以内: 「今日」「1日前」…「7日前」
/// - 8暦日以上: 「06/12」形式（ゼロ埋め）
String? formatRoomColleCardTimestamp(DateTime? at, DateTime referenceNow) {
  if (at == null) return null;
  final a = DateTime(at.year, at.month, at.day);
  final r = DateTime(referenceNow.year, referenceNow.month, referenceNow.day);
  final daysAgo = r.difference(a).inDays;
  if (daysAgo < 0) {
    return _roomColleCardMmDd(at);
  }
  if (daysAgo == 0) {
    return '今日';
  }
  if (daysAgo <= roomColleCardRelativeDayCap) {
    return '$daysAgo日前';
  }
  return _roomColleCardMmDd(at);
}

String _roomColleCardMmDd(DateTime at) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${two(at.month)}/${two(at.day)}';
}

/// カード用1行表示（[instant] が null のときはレイアウト上の穴を開けない）。
class RoomColleCardTimestampText extends StatelessWidget {
  const RoomColleCardTimestampText({
    super.key,
    required this.instant,
    this.style,
  });

  final DateTime? instant;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (instant == null) return const SizedBox.shrink();
    final label = formatRoomColleCardTimestamp(instant!, DateTime.now());
    if (label == null || label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
