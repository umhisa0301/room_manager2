import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/repository/room_recommendation_profile_repository.dart';
import 'package:room_manager2/state/room_recommendation_profile_provider.dart';
import 'package:room_manager2/widgets/room_type_diagnosis_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        find.text('あなたに合うコレ候補を見つけやすくします'),
        findsOneWidget,
      );
      expect(find.text('かんたん診断する'), findsOneWidget);
      expect(find.text('診断せずに見る'), findsOneWidget);
    });

    testWidgets('診断せずに見る選択後は同一セッションで再表示されない', (tester) async {
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
                        if (provider.isDiagnosisPromptSkipped) return;
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

      await tester.tap(find.text('おすすめコレ'));
      await tester.pumpAndSettle();

      expect(
        find.text('あなたに合うコレ候補を見つけやすくします'),
        findsNothing,
      );
    });
  });

  group('MyPageRoomTypeDiagnosisCard', () {
    testWidgets('診断済みでタイプ名バッジが表示され、詳細は折りたたみ', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MyPageRoomTypeDiagnosisCard(
              isDiagnosed: true,
              typeDisplayName: 'おしゃれ・気分上げ型',
              interestLabel: 'ファッション、美容・コスメ',
              priorityLabel: 'レビューが多い',
              commentToneLabel: 'やわらかく自然に',
              onStartDiagnosis: () {},
              onRetakeDiagnosis: () {},
            ),
          ),
        ),
      );

      expect(find.text('あなたのタイプ'), findsOneWidget);
      expect(find.text('おしゃれ・気分上げ型'), findsOneWidget);
      expect(find.text('関心ジャンル'), findsNothing);

      await tester.tap(find.text('詳細を見る'));
      await tester.pumpAndSettle();

      expect(find.text('関心ジャンル'), findsOneWidget);
      expect(find.text('ファッション、美容・コスメ'), findsOneWidget);
      expect(find.text('重視する条件'), findsOneWidget);
      expect(find.text('投稿文の雰囲気'), findsOneWidget);
    });
  });
}
