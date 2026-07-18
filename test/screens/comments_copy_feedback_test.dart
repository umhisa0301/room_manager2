import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/models/comment_template.dart';
import 'package:room_manager2/repository/activity_log_repository.dart';
import 'package:room_manager2/repository/comment_template_repository.dart';
import 'package:room_manager2/screens/comments_placeholder_screen.dart';
import 'package:room_manager2/state/activity_log_provider.dart';
import 'package:room_manager2/state/comment_template_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

CommentTemplate _template({
  required String id,
  required String title,
  required String body,
}) {
  final now = DateTime(2026, 7, 18);
  return CommentTemplate(
    id: id,
    title: title,
    body: body,
    category: 'テスト',
    createdAt: now,
    updatedAt: now,
  );
}

Future<Widget> _wrapComments(SharedPreferences prefs) async {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => CommentTemplateProvider(
          repository: CommentTemplateRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            ActivityLogProvider(repository: ActivityLogRepository(prefs)),
      ),
    ],
    child: const MaterialApp(home: CommentsPlaceholderScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    final t1 = _template(id: 't1', title: 'テンプレ1', body: '本文いち');
    final t2 = _template(id: 't2', title: 'テンプレ2', body: '本文に');
    SharedPreferences.setMockInitialValues({
      'comment_templates': jsonEncode([t1.toJson(), t2.toJson()]),
      'comment_builtin_templates_seeded_v1': true,
    });
    prefs = await SharedPreferences.getInstance();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('copy switches icon/label and restores after 1.5s', (
    tester,
  ) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = call.arguments['text'] as String?;
          }
          return null;
        });

    await tester.pumpWidget(await _wrapComments(prefs));
    await tester.pumpAndSettle();

    expect(find.text('クリップボードにコピーする'), findsWidgets);
    await tester.tap(find.byKey(const Key('comment_template_copy_t1')));
    await tester.pump();

    expect(copied, '本文いち');
    expect(find.text('コピー済み'), findsOneWidget);
    expect(find.text('コピーしました'), findsOneWidget);
    expect(find.text('直近にコピー'), findsOneWidget);

    // Timer 復帰 + AnimatedSwitcher 退場（SnackBar の pumpAndSettle は使わない）
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('コピー済み'), findsNothing);
    expect(find.text('クリップボードにコピーする'), findsWidgets);
    expect(find.text('直近にコピー'), findsOneWidget);
  });

  testWidgets('copying another template switches feedback target', (
    tester,
  ) async {
    // 2カード＋SnackBar でヒットがずれないよう高めの画面にする
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(await _wrapComments(prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('comment_template_copy_t1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.descendant(
        of: find.byKey(const Key('comment_template_copy_t1')),
        matching: find.text('コピー済み'),
      ),
      findsOneWidget,
    );

    ScaffoldMessenger.of(
      tester.element(find.byType(CommentsPlaceholderScreen)),
    ).clearSnackBars();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('comment_template_copy_t2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.descendant(
        of: find.byKey(const Key('comment_template_copy_t1')),
        matching: find.text('コピー済み'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('comment_template_copy_t2')),
        matching: find.text('コピー済み'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('dispose during feedback timer does not throw', (tester) async {
    await tester.pumpWidget(await _wrapComments(prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('comment_template_copy_t1')));
    await tester.pump();
    expect(find.text('コピー済み'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 1600));
    // Timer 発火後も例外なく完了すれば成功
  });
}
