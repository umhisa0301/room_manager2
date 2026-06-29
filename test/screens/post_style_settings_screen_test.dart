import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/models/post_style_settings.dart';
import 'package:room_manager2/repository/post_style_settings_repository.dart';
import 'package:room_manager2/screens/post_style_settings_screen.dart';
import 'package:room_manager2/state/post_style_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _setTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Widget _wrap({
  required SharedPreferences prefs,
  required Widget child,
  PostStyleSettings? initialSettings,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => PostStyleSettingsProvider(
          repository: PostStyleSettingsRepository(prefs),
        ),
      ),
    ],
    child: MaterialApp(
      home: PostStyleSettingsScreen(initialSettings: initialSettings),
    ),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  PostStyleSettings? initialSettings,
}) async {
  _setTallViewport(tester);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    _wrap(
      prefs: prefs,
      initialSettings: initialSettings,
      child: const SizedBox.shrink(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PostStyleSettingsScreen', () {
    testWidgets('displays screen and all setting sections', (tester) async {
      await _pumpScreen(tester);

      expect(find.text('投稿スタイル設定'), findsOneWidget);
      expect(
        find.text('AIで投稿文を作るときの文体や長さを調整できます。'),
        findsOneWidget,
      );
      expect(find.text('文体'), findsOneWidget);
      expect(find.text('文章量'), findsOneWidget);
      expect(find.text('絵文字'), findsOneWidget);
      expect(find.text('顔文字'), findsOneWidget);
      expect(find.text('ハッシュタグ'), findsOneWidget);
      expect(find.text('推し方'), findsOneWidget);
      expect(find.text('読者層'), findsOneWidget);
      expect(find.text('誇張表現を避ける'), findsOneWidget);
      expect(find.text('生成イメージ'), findsOneWidget);
      expect(find.byKey(const Key('post_style_save_button')), findsOneWidget);
      expect(find.byKey(const Key('post_style_reset_button')), findsOneWidget);
    });

    testWidgets('can change tone', (tester) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('フランク'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, 'フランク'), findsOneWidget);
    });

    testWidgets('can change length', (tester) async {
      await _pumpScreen(tester);

      await _scrollTo(tester, find.text('短め'));
      await tester.tap(find.text('短め'));
      await tester.pumpAndSettle();

      expect(find.text('60〜90字'), findsOneWidget);
    });

    testWidgets('can change emoji level', (tester) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('使わない'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, '使わない'), findsOneWidget);
    });

    testWidgets('can toggle kaomoji switch', (tester) async {
      await _pumpScreen(tester);

      final switchFinder = find.byType(SwitchListTile).first;
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    });

    testWidgets('can change hashtag level', (tester) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('3個程度'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, '3個程度'), findsOneWidget);
    });

    testWidgets('can select up to 3 focus points', (tester) async {
      await _pumpScreen(
        tester,
        initialSettings: PostStyleSettings.defaults().copyWith(
          focusPoints: const [],
        ),
      );

      await _scrollTo(tester, find.text('コスパ'));
      await tester.tap(find.text('コスパ'));
      await tester.tap(find.text('便利さ'));
      await tester.tap(find.text('口コミ'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, 'コスパ'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '便利さ'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '口コミ'), findsOneWidget);
    });

    testWidgets('shows snackbar when selecting 4th focus point', (tester) async {
      await _pumpScreen(
        tester,
        initialSettings: PostStyleSettings.defaults().copyWith(
          focusPoints: const [
            PostFocusPoint.costPerformance,
            PostFocusPoint.convenience,
            PostFocusPoint.reviews,
          ],
        ),
      );

      await _scrollTo(tester, find.text('デザイン'));
      await tester.tap(find.text('デザイン'));
      await tester.pumpAndSettle();

      expect(find.text('推し方は3つまで選べます'), findsOneWidget);
    });

    testWidgets('can change target audience', (tester) async {
      await _pumpScreen(tester);

      await _scrollTo(tester, find.text('女性向け'));
      await tester.tap(find.text('女性向け'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, '女性向け'), findsOneWidget);
    });

    testWidgets('can toggle avoid overstatement switch', (tester) async {
      await _pumpScreen(tester);

      final switchFinder =
          find.widgetWithText(SwitchListTile, '誇張表現を避ける');
      await _scrollTo(tester, switchFinder);
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    });

    testWidgets('preview updates when settings change', (tester) async {
      await _pumpScreen(tester);

      await _scrollTo(tester, find.byKey(const Key('post_style_preview_text')));
      final before = tester
          .widget<Text>(find.byKey(const Key('post_style_preview_text')))
          .data;

      await _scrollTo(tester, find.text('フランク'));
      await tester.tap(find.text('フランク'));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.byKey(const Key('post_style_preview_text')));
      final after = tester
          .widget<Text>(find.byKey(const Key('post_style_preview_text')))
          .data;

      expect(before, isNot(equals(after)));
      expect(after, contains('見つけたよ'));
    });

    testWidgets('save button persists settings to provider', (tester) async {
      _setTallViewport(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      late PostStyleSettingsProvider provider;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) {
                provider = PostStyleSettingsProvider(
                  repository: PostStyleSettingsRepository(prefs),
                );
                return provider;
              },
            ),
          ],
          child: const MaterialApp(
            home: PostStyleSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('フランク'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post_style_save_button')));
      await tester.pumpAndSettle();

      expect(provider.settings.tone, PostTone.casual);
      expect(find.text('投稿スタイルを保存しました'), findsOneWidget);
    });

    testWidgets('reset restores defaults', (tester) async {
      _setTallViewport(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      late PostStyleSettingsProvider provider;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) {
                provider = PostStyleSettingsProvider(
                  repository: PostStyleSettingsRepository(prefs),
                );
                return provider;
              },
            ),
          ],
          child: MaterialApp(
            home: PostStyleSettingsScreen(
              initialSettings: PostStyleSettings.defaults().copyWith(
                tone: PostTone.casual,
                kaomojiEnabled: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.byKey(const Key('post_style_reset_button')));
      await tester.tap(find.byKey(const Key('post_style_reset_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('戻す'));
      await tester.pumpAndSettle();

      expect(provider.settings.tone, PostTone.friendlyPolite);
      expect(provider.settings.kaomojiEnabled, isFalse);
      expect(find.text('初期設定に戻しました'), findsOneWidget);
    });
  });
}
