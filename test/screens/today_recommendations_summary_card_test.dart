import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/recommend_cooldown_policy.dart';
import 'package:room_manager2/widgets/app_button.dart';

void main() {
  testWidgets('regenerate button enabled after cooldown when not completed', (
    tester,
  ) async {
    const uiState = RegenerateButtonUiState(
      canPress: true,
      showCooldownMessage: false,
      waitLabel: '',
      blockReason: 'none',
      needsPeriodicRefresh: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestSummaryCard(
            total: 10,
            pending: 10,
            completed: false,
            uiState: uiState,
          ),
        ),
      ),
    );

    final button = tester.widget<AppSecondaryButton>(
      find.widgetWithText(AppSecondaryButton, '今日の候補を再生成'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.byKey(const Key('today_recommendation_skip_message')), findsNothing);
  });

  testWidgets('regenerate button disabled during cooldown with wait label', (
    tester,
  ) async {
    const uiState = RegenerateButtonUiState(
      canPress: false,
      showCooldownMessage: true,
      waitLabel: 'あと約4分後に再生成できます',
      blockReason: 'manualCooldown',
      needsPeriodicRefresh: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestSummaryCard(
            total: 10,
            pending: 10,
            completed: false,
            uiState: uiState,
          ),
        ),
      ),
    );

    final button = tester.widget<AppSecondaryButton>(
      find.widgetWithText(AppSecondaryButton, '今日の候補を再生成'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('あと約4分後に再生成できます'), findsOneWidget);
  });

  testWidgets('completed with cooldown elapsed enables button and regeneratable hint', (
    tester,
  ) async {
    const uiState = RegenerateButtonUiState(
      canPress: true,
      showCooldownMessage: false,
      waitLabel: '',
      blockReason: 'none',
      needsPeriodicRefresh: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestSummaryCard(
            total: 10,
            pending: 0,
            completed: true,
            uiState: uiState,
          ),
        ),
      ),
    );

    final button = tester.widget<AppSecondaryButton>(
      find.widgetWithText(AppSecondaryButton, '今日の候補を再生成'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.textContaining('翌日'), findsNothing);
    expect(
      find.text('すべて確認済みです。新しい候補を見たい場合は再生成できます。'),
      findsOneWidget,
    );
  });

  testWidgets('completed during cooldown disables button with wait label', (
    tester,
  ) async {
    const uiState = RegenerateButtonUiState(
      canPress: false,
      showCooldownMessage: true,
      waitLabel: 'あと約4分後に再生成できます',
      blockReason: 'manualCooldown',
      needsPeriodicRefresh: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestSummaryCard(
            total: 10,
            pending: 0,
            completed: true,
            uiState: uiState,
          ),
        ),
      ),
    );

    final button = tester.widget<AppSecondaryButton>(
      find.widgetWithText(AppSecondaryButton, '今日の候補を再生成'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('あと約4分後に再生成できます'), findsOneWidget);
    expect(find.textContaining('翌日'), findsNothing);
    expect(find.text('すべて確認済みです。'), findsOneWidget);
  });
}

class _TestSummaryCard extends StatelessWidget {
  const _TestSummaryCard({
    required this.total,
    required this.pending,
    required this.completed,
    required this.uiState,
  });

  final int total;
  final int pending;
  final bool completed;
  final RegenerateButtonUiState uiState;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          completed ? '本日のおすすめはチェック完了です' : '本日のおすすめ $total件（未処理 $pending件）',
        ),
        Text(uiState.summaryBodyText(completed: completed)),
        if (uiState.showCooldownMessage)
          Text(
            uiState.waitLabel,
            key: const Key('today_recommendation_skip_message'),
          ),
        AppSecondaryButton(
          label: '今日の候補を再生成',
          onPressed: uiState.canPress ? () {} : null,
        ),
      ],
    );
  }
}
