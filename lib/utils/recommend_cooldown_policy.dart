/// おすすめコレ再生成のクールダウン（1箇所定義）。
abstract final class RecommendCooldownPolicy {
  static const Duration manualRegenerateCooldown = Duration(minutes: 5);
  static const Duration recentGenerateCooldown = Duration(minutes: 15);
  static const Duration rateLimitCooldown = Duration(minutes: 12);

  static String remainingMinutesLabel(Duration remaining) {
    final sec = remaining.inSeconds;
    if (sec <= 0) return 'まもなく';
    final min = (sec / 60).ceil();
    return '$min分';
  }
}

/// おすすめ再生成ボタンのクールダウン表示用。
class RecommendRegenerateCooldownStatus {
  const RecommendRegenerateCooldownStatus({
    required this.canRegenerate,
    required this.cooldownMinutes,
    required this.remainingSeconds,
    required this.remainingLabel,
    required this.guardReason,
    this.nextAvailableAt,
  });

  final bool canRegenerate;
  final int cooldownMinutes;
  final int remainingSeconds;
  final String remainingLabel;
  final String guardReason;
  final DateTime? nextAvailableAt;

  int get remainingMinutes => (remainingSeconds / 60).ceil();

  String get reason => guardReason;

  String get userFacingWaitLabel {
    if (canRegenerate) return '';
    if (remainingLabel == 'まもなく') return 'まもなく再生成できます';
    return 'あと約$remainingLabel後に再生成できます';
  }
}
