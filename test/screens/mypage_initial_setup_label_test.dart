import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/screens/mypage_placeholder_screen.dart';

Widget _settingsSection({required VoidCallback onOpenInitialSetup}) {
  return SingleChildScrollView(
    child: MyPageSettingsSection(
      onOpenPlan: () {},
      onOpenInitialSetup: onOpenInitialSetup,
      onOpenSavedShops: () {},
    ),
  );
}

void main() {
  group('MyPage initial setup label', () {
    testWidgets('shows profile bulk edit label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _settingsSection(onOpenInitialSetup: () {}),
          ),
        ),
      );

      expect(find.text('プロフィール設定をまとめて編集'), findsOneWidget);
      expect(find.text('初期設定をやり直す'), findsNothing);
    });
  });
}
