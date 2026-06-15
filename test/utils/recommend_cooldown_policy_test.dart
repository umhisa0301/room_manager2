import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/recommend_cooldown_policy.dart';

void main() {
  group('RecommendCooldownPolicy.resolveManualRegenerateCooldownStatus', () {
    final lastRegenerate = DateTime(2026, 6, 15, 12, 0, 0);

    test('immediately after generation cannot regenerate', () {
      final status = RecommendCooldownPolicy.resolveManualRegenerateCooldownStatus(
        clock: lastRegenerate,
        lastRegenerateAt: lastRegenerate,
      );
      expect(status.canRegenerate, isFalse);
      expect(status.guardReason, 'manualCooldown');
      expect(status.remainingSeconds, greaterThan(0));
      expect(status.userFacingWaitLabel, isNotEmpty);
    });

    test('during 5 minute window cannot regenerate', () {
      final status = RecommendCooldownPolicy.resolveManualRegenerateCooldownStatus(
        clock: lastRegenerate.add(const Duration(minutes: 4, seconds: 59)),
        lastRegenerateAt: lastRegenerate,
      );
      expect(status.canRegenerate, isFalse);
      expect(status.guardReason, 'manualCooldown');
    });

    test('after 5 minutes can regenerate', () {
      final status = RecommendCooldownPolicy.resolveManualRegenerateCooldownStatus(
        clock: lastRegenerate.add(const Duration(minutes: 5)),
        lastRegenerateAt: lastRegenerate,
      );
      expect(status.canRegenerate, isTrue);
      expect(status.guardReason, isEmpty);
      expect(status.userFacingWaitLabel, isEmpty);
    });

    test('rate limit cooldown blocks manual regenerate', () {
      final until = lastRegenerate.add(const Duration(minutes: 10));
      final status = RecommendCooldownPolicy.resolveManualRegenerateCooldownStatus(
        clock: lastRegenerate.add(const Duration(minutes: 2)),
        lastRegenerateAt: lastRegenerate.subtract(const Duration(minutes: 10)),
        rateLimitCooldownUntil: until,
        lastRateLimitFailure: true,
      );
      expect(status.canRegenerate, isFalse);
      expect(status.guardReason, 'rateLimitCooldown');
    });

    test('expired rate limit falls through to manual cooldown', () {
      final until = lastRegenerate.add(const Duration(minutes: 1));
      final status = RecommendCooldownPolicy.resolveManualRegenerateCooldownStatus(
        clock: lastRegenerate.add(const Duration(minutes: 3)),
        lastRegenerateAt: lastRegenerate,
        rateLimitCooldownUntil: until,
        lastRateLimitFailure: true,
      );
      expect(status.canRegenerate, isFalse);
      expect(status.guardReason, 'manualCooldown');
    });

    test('no prior generation allows regenerate', () {
      final status = RecommendCooldownPolicy.resolveManualRegenerateCooldownStatus(
        clock: lastRegenerate,
      );
      expect(status.canRegenerate, isTrue);
    });
  });

  group('RecommendRegenerateCooldownStatus.userFacingWaitLabel', () {
    test('shows minutes while waiting', () {
      const status = RecommendRegenerateCooldownStatus(
        canRegenerate: false,
        cooldownMinutes: 5,
        remainingSeconds: 240,
        remainingLabel: '4分',
        guardReason: 'manualCooldown',
      );
      expect(status.userFacingWaitLabel, 'あと約4分後に再生成できます');
    });

    test('shows soon label when under one minute', () {
      const status = RecommendRegenerateCooldownStatus(
        canRegenerate: false,
        cooldownMinutes: 5,
        remainingSeconds: 20,
        remainingLabel: 'まもなく',
        guardReason: 'manualCooldown',
      );
      expect(status.userFacingWaitLabel, 'まもなく再生成できます');
    });
  });

  group('RecommendCooldownPolicyUi.resolveRegenerateButtonUiState', () {
    test('cooldown elapsed enables button when not completed', () {
      const cooldown = RecommendRegenerateCooldownStatus(
        canRegenerate: true,
        cooldownMinutes: 5,
        remainingSeconds: 0,
        remainingLabel: '',
        guardReason: '',
      );
      final ui = RecommendCooldownPolicyUi.resolveRegenerateButtonUiState(
        cooldown: cooldown,
        completed: false,
        isLoading: false,
      );
      expect(ui.canPress, isTrue);
      expect(ui.showCooldownMessage, isFalse);
      expect(ui.blockReason, 'none');
      expect(ui.needsPeriodicRefresh, isFalse);
    });

    test('active cooldown disables button and shows wait label', () {
      const cooldown = RecommendRegenerateCooldownStatus(
        canRegenerate: false,
        cooldownMinutes: 5,
        remainingSeconds: 240,
        remainingLabel: '4分',
        guardReason: 'manualCooldown',
      );
      final ui = RecommendCooldownPolicyUi.resolveRegenerateButtonUiState(
        cooldown: cooldown,
        completed: false,
        isLoading: false,
      );
      expect(ui.canPress, isFalse);
      expect(ui.showCooldownMessage, isTrue);
      expect(ui.waitLabel, 'あと約4分後に再生成できます');
      expect(ui.needsPeriodicRefresh, isTrue);
    });

    test('completed blocks button without cooldown message', () {
      const cooldown = RecommendRegenerateCooldownStatus(
        canRegenerate: true,
        cooldownMinutes: 5,
        remainingSeconds: 0,
        remainingLabel: '',
        guardReason: '',
      );
      final ui = RecommendCooldownPolicyUi.resolveRegenerateButtonUiState(
        cooldown: cooldown,
        completed: true,
        isLoading: false,
      );
      expect(ui.canPress, isFalse);
      expect(ui.showCooldownMessage, isFalse);
      expect(ui.blockReason, 'completed');
    });

    test('completed with active cooldown still prioritizes completed', () {
      const cooldown = RecommendRegenerateCooldownStatus(
        canRegenerate: false,
        cooldownMinutes: 5,
        remainingSeconds: 240,
        remainingLabel: '4分',
        guardReason: 'manualCooldown',
      );
      final ui = RecommendCooldownPolicyUi.resolveRegenerateButtonUiState(
        cooldown: cooldown,
        completed: true,
        isLoading: false,
      );
      expect(ui.canPress, isFalse);
      expect(ui.showCooldownMessage, isFalse);
      expect(ui.blockReason, 'completed');
    });

    test('loading blocks button', () {
      const cooldown = RecommendRegenerateCooldownStatus(
        canRegenerate: true,
        cooldownMinutes: 5,
        remainingSeconds: 0,
        remainingLabel: '',
        guardReason: '',
      );
      final ui = RecommendCooldownPolicyUi.resolveRegenerateButtonUiState(
        cooldown: cooldown,
        completed: false,
        isLoading: true,
      );
      expect(ui.canPress, isFalse);
      expect(ui.blockReason, 'loading');
    });
  });
}
