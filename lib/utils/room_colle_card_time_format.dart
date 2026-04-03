import 'package:flutter/material.dart';

/// ROOMコレ一覧カード用の相対日時文字列（intl 不使用・数値比較のみ）。
String? formatRoomColleCardTimestamp(DateTime? at, DateTime referenceNow) {
  if (at == null) return null;
  final a = DateTime(at.year, at.month, at.day);
  final r = DateTime(
    referenceNow.year,
    referenceNow.month,
    referenceNow.day,
  );
  final dDiff = a.difference(r).inDays;
  String two(int n) => n < 10 ? '0$n' : '$n';
  final hm = '${two(at.hour)}:${two(at.minute)}';
  if (dDiff == 0) {
    return '今日 $hm';
  }
  if (dDiff == -1) {
    return '昨日 $hm';
  }
  return '${at.month}/${at.day}';
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
