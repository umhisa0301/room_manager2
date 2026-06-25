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
    testWidgets('プロフィール一括編集の導線は非表示', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _settingsSection(onOpenInitialSetup: () {}),
          ),
        ),
      );

      expect(find.text('プロフィール設定をまとめて編集'), findsNothing);
      expect(find.text('保存ショップを管理'), findsOneWidget);
    });
  });
}
