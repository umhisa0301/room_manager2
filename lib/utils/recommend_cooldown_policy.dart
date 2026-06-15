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

/// 再生成ボタン UI の活性/文言を一箇所で解決する。
class RegenerateButtonUiState {
  const RegenerateButtonUiState({
    required this.canPress,
    required this.showCooldownMessage,
    required this.waitLabel,
    required this.blockReason,
    required this.needsPeriodicRefresh,
  });

  final bool canPress;
  final bool showCooldownMessage;
  final String waitLabel;
  final String blockReason;
  final bool needsPeriodicRefresh;

  /// サマリーカードの説明文（completed 状態の案内をクールダウンと整合）。
  String summaryBodyText({required bool completed}) {
    if (!completed) {
      return '今日チェックしたい商品です。候補・コレ済は除外しています';
    }
    if (canPress) {
      return 'すべて確認済みです。新しい候補を見たい場合は再生成できます。';
    }
    return 'すべて確認済みです。';
  }
}

extension RecommendCooldownPolicyUi on RecommendCooldownPolicy {
  static RegenerateButtonUiState resolveRegenerateButtonUiState({
    required RecommendRegenerateCooldownStatus cooldown,
    required bool completed,
    required bool isLoading,
  }) {
    if (isLoading) {
      return const RegenerateButtonUiState(
        canPress: false,
        showCooldownMessage: false,
        waitLabel: '',
        blockReason: 'loading',
        needsPeriodicRefresh: false,
      );
    }
    if (!cooldown.canRegenerate) {
      return RegenerateButtonUiState(
        canPress: false,
        showCooldownMessage: cooldown.userFacingWaitLabel.isNotEmpty,
        waitLabel: cooldown.userFacingWaitLabel,
        blockReason: cooldown.guardReason.isEmpty ? 'cooldown' : cooldown.guardReason,
        needsPeriodicRefresh: true,
      );
    }
    return const RegenerateButtonUiState(
      canPress: true,
      showCooldownMessage: false,
      waitLabel: '',
      blockReason: 'none',
      needsPeriodicRefresh: false,
    );
  }
}
