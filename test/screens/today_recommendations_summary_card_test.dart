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
            uiState: uiState,
          ),
        ),
      ),
    );

    final button = tester.widget<AppSecondaryButton>(
      find.widgetWithText(AppSecondaryButton, '再生成'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.text('10件の候補'), findsOneWidget);
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
            uiState: uiState,
          ),
        ),
      ),
    );

    final button = tester.widget<AppSecondaryButton>(
      find.widgetWithText(AppSecondaryButton, '再生成'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('あと約4分後に再生成できます'), findsOneWidget);
  });

  testWidgets('completed with cooldown elapsed enables regenerate', (
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
            total: 3,
            uiState: uiState,
          ),
        ),
      ),
    );

    final button = tester.widget<AppSecondaryButton>(
      find.widgetWithText(AppSecondaryButton, '再生成'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.text('3件の候補'), findsOneWidget);
  });
}

class _TestSummaryCard extends StatelessWidget {
  const _TestSummaryCard({
    required this.total,
    required this.uiState,
  });

  final int total;
  final RegenerateButtonUiState uiState;

  @override
  Widget build(BuildContext context) {
    final cooldownHint =
        uiState.showCooldownMessage && uiState.waitLabel.isNotEmpty
            ? uiState.waitLabel
            : '';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$total件の候補'),
              if (cooldownHint.isNotEmpty)
                Text(
                  cooldownHint,
                  key: const Key('today_recommendation_skip_message'),
                ),
            ],
          ),
        ),
        AppSecondaryButton(
          label: '再生成',
          onPressed: uiState.canPress ? () {} : null,
        ),
      ],
    );
  }
}
