/// おすすめコレ再生成のクールダウン（1箇所定義）。
abstract final class RecommendCooldownPolicy {
  static const Duration manualRegenerateCooldown = Duration(minutes: 5);
  static const Duration recentGenerateCooldown = Duration(minutes: 15);
  static const Duration rateLimitCooldown = Duration(minutes: 12);

  /// 手動再生成ボタンのクールダウン状態（純粋関数・テスト用）。
  static RecommendRegenerateCooldownStatus resolveManualRegenerateCooldownStatus({
    required DateTime clock,
    DateTime? lastRegenerateAt,
    DateTime? rateLimitCooldownUntil,
    bool lastRateLimitFailure = false,
  }) {
    if (lastRateLimitFailure && rateLimitCooldownUntil != null) {
      final remaining = rateLimitCooldownUntil.difference(clock);
      if (remaining > Duration.zero) {
        return RecommendRegenerateCooldownStatus(
          canRegenerate: false,
          cooldownMinutes: rateLimitCooldown.inMinutes,
          remainingSeconds: remaining.inSeconds,
          remainingLabel: remainingMinutesLabel(remaining),
          guardReason: 'rateLimitCooldown',
          nextAvailableAt: rateLimitCooldownUntil,
        );
      }
    }
    if (lastRegenerateAt != null) {
      final remaining = manualRegenerateCooldown - clock.difference(lastRegenerateAt);
      if (remaining > Duration.zero) {
        return RecommendRegenerateCooldownStatus(
          canRegenerate: false,
          cooldownMinutes: manualRegenerateCooldown.inMinutes,
          remainingSeconds: remaining.inSeconds,
          remainingLabel: remainingMinutesLabel(remaining),
          guardReason: 'manualCooldown',
          nextAvailableAt: lastRegenerateAt.add(manualRegenerateCooldown),
        );
      }
    }
    return const RecommendRegenerateCooldownStatus(
      canRegenerate: true,
      cooldownMinutes: 5,
      remainingSeconds: 0,
      remainingLabel: '',
      guardReason: '',
    );
  }

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
