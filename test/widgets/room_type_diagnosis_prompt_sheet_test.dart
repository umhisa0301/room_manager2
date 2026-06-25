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
  });
}
