import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/models/room_recommendation_profile.dart';
import 'package:room_manager2/navigation/app_shell_controller.dart';
import 'package:room_manager2/screens/room_type_diagnosis_result_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoomTypeDiagnosisResultScreen', () {
    testWidgets('診断結果画面のメインCTAはホームへ戻る', (tester) async {
      final profile = RoomRecommendationProfile(
        primaryTypeId: 'life_convenience',
        interestCategoryIds: const ['gift', 'pet'],
        priorityRuleIds: const ['review_trust'],
        diagnosedAt: DateTime(2026, 6, 26),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => AppShellController(),
            child: RoomTypeDiagnosisResultScreen(profile: profile),
          ),
        ),
      );

      expect(find.text('ホームへ戻る'), findsOneWidget);
      expect(find.text('マイページへ戻る'), findsOneWidget);
      expect(find.text('おすすめコレを見る'), findsNothing);
    });

    testWidgets('数秒待っても自動でホームへ遷移しない', (tester) async {
      final profile = RoomRecommendationProfile(
        primaryTypeId: 'life_convenience',
        interestCategoryIds: const ['gift'],
        priorityRuleIds: const ['review_trust'],
        diagnosedAt: DateTime(2026, 6, 27),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => AppShellController(),
            child: RoomTypeDiagnosisResultScreen(profile: profile),
          ),
        ),
      );

      expect(find.text('診断結果'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('診断結果'), findsOneWidget);
      expect(find.text('あなたは'), findsOneWidget);
    });

    testWidgets('ホームへ戻るでホームタブを選択する', (tester) async {
      final shell = AppShellController()..selectTab(4);
      final profile = RoomRecommendationProfile(
        primaryTypeId: 'life_convenience',
        interestCategoryIds: const ['gift'],
        priorityRuleIds: const ['review_trust'],
        diagnosedAt: DateTime(2026, 6, 27),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: shell,
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => RoomTypeDiagnosisResultScreen(profile: profile),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('diagnosis_result_go_home')));
      await tester.pumpAndSettle();

      expect(shell.currentIndex, 0);
    });

    testWidgets('マイページへ戻るでマイページタブを選択する', (tester) async {
      final shell = AppShellController();
      final profile = RoomRecommendationProfile(
        primaryTypeId: 'life_convenience',
        interestCategoryIds: const ['gift'],
        priorityRuleIds: const ['review_trust'],
        diagnosedAt: DateTime(2026, 6, 27),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: shell,
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => RoomTypeDiagnosisResultScreen(profile: profile),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('diagnosis_result_go_mypage')));
      await tester.pumpAndSettle();

      expect(shell.currentIndex, 4);
    });
  });
}
