import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/room_recommendation_profile.dart';
import 'package:room_manager2/screens/room_type_diagnosis_result_screen.dart';

void main() {
  testWidgets('診断結果画面のメインCTAはホームへ戻る', (tester) async {
    final profile = RoomRecommendationProfile(
      primaryTypeId: 'life_convenience',
      interestCategoryIds: const ['gift', 'pet'],
      priorityRuleIds: const ['review_trust'],
      diagnosedAt: DateTime(2026, 6, 26),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoomTypeDiagnosisResultScreen(profile: profile),
      ),
    );

    expect(find.text('ホームへ戻る'), findsOneWidget);
    expect(find.text('マイページへ戻る'), findsOneWidget);
    expect(find.text('おすすめコレを見る'), findsNothing);
  });
}
