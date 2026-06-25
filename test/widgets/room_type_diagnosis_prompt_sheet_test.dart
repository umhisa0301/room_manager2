import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/state/room_recommendation_profile_provider.dart';
import 'package:room_manager2/repository/room_recommendation_profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:room_manager2/widgets/room_type_diagnosis_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoomTypeDiagnosisPromptSheet', () {
    testWidgets('未診断の場合、おすすめコレ押下時に診断促進BottomSheetが表示される',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = RoomRecommendationProfileRepository(
        await SharedPreferences.getInstance(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => RoomRecommendationProfileProvider(
              repository: repository,
            ),
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          RoomTypeDiagnosisPromptSheet.show(context),
                      child: const Text('おすすめコレ'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('おすすめコレ'));
      await tester.pumpAndSettle();

      expect(
        find.text('ROOMタイプを設定すると、あなたに合ったコレ候補を出しやすくなります。'),
        findsOneWidget,
      );
      expect(find.text('かんたん診断する'), findsOneWidget);
      expect(find.text('診断せずに見る'), findsOneWidget);
    });

    testWidgets('診断せずに見る選択後はスキップフラグが保存される', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = RoomRecommendationProfileRepository(prefs);
      final provider = RoomRecommendationProfileProvider(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: provider,
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        final skip = await RoomTypeDiagnosisPromptSheet.show(
                          context,
                        );
                        if (skip == false) {
                          await provider.markDiagnosisPromptSkipped();
                        }
                      },
                      child: const Text('おすすめコレ'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('おすすめコレ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('診断せずに見る'));
      await tester.pumpAndSettle();

      expect(provider.isDiagnosisPromptSkipped, isTrue);
      expect(repository.isDiagnosisPromptSkipped(), isTrue);
    });
  });
}
