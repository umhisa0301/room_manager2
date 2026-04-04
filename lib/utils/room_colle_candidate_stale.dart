import 'package:flutter/material.dart';

/// コレ候補カード用「経過日数の目立ち」定義（7日 / 30日）。
@immutable
class RoomColleCandidateStaleSpec {
  const RoomColleCandidateStaleSpec._({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.fontWeight,
    this.borderColor,
    this.borderWidth = 0,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final FontWeight fontWeight;
  final Color? borderColor;
  final double borderWidth;

  /// [addedAt] を基準に、ローカル暦日で何日経過したかを数える（当日なら 0）。
  static int calendarDaysElapsed(DateTime addedAt, DateTime now) {
    final from = DateTime(addedAt.year, addedAt.month, addedAt.day);
    final to = DateTime(now.year, now.month, now.day);
    return to.difference(from).inDays;
  }

  /// 候補のみ。null / 7日未満はチップなし。30日以上は [strong]、7日以上は [mild]。
  static RoomColleCandidateStaleSpec? resolve(DateTime? addedAt, DateTime now) {
    if (addedAt == null) return null;
    final days = calendarDaysElapsed(addedAt, now);
    if (days >= 30) {
      return RoomColleCandidateStaleSpec._(
        label: '30日以上',
        backgroundColor: const Color(0xFFFFEBEE),
        foregroundColor: const Color(0xFFB71C1C),
        fontWeight: FontWeight.w600,
        borderColor: const Color(0xFFEF9A9A),
        borderWidth: 1,
      );
    }
    if (days >= 7) {
      return RoomColleCandidateStaleSpec._(
        label: '7日以上経過',
        backgroundColor: const Color(0xFFFFF3E0),
        foregroundColor: const Color(0xFFE65100),
        fontWeight: FontWeight.w500,
      );
    }
    return null;
  }
}

/// 経過警告チップ（候補カード内・日時付近）。
class RoomColleCandidateStaleChip extends StatelessWidget {
  const RoomColleCandidateStaleChip({super.key, required this.spec});

  final RoomColleCandidateStaleSpec spec;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: spec.backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: spec.borderColor != null && spec.borderWidth > 0
            ? Border.all(color: spec.borderColor!, width: spec.borderWidth)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          spec.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9.5,
            height: 1.15,
            fontWeight: spec.fontWeight,
            color: spec.foregroundColor,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}
