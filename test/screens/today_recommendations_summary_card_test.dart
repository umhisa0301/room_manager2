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

  testWidgets('completed state disables button without cooldown message', (
    tester,
  ) async {
    const uiState = RegenerateButtonUiState(
      canPress: false,
      showCooldownMessage: false,
      waitLabel: '',
      blockReason: 'completed',
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
    expect(button.onPressed, isNull);
    expect(find.textContaining('あと約'), findsNothing);
    expect(find.textContaining('翌日'), findsOneWidget);
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
        Text(
          completed
              ? '10件見終わりました。次回は翌日に新しい候補が生成されます。'
              : '今日チェックしたい商品です。候補・コレ済は除外しています',
        ),
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
