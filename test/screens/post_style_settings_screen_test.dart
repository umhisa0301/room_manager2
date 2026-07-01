import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/config/post_style_preview_sample_product.dart';
import 'package:room_manager2/models/post_comment_generation_result.dart';
import 'package:room_manager2/models/post_style_settings.dart';
import 'package:room_manager2/repository/post_style_settings_repository.dart';
import 'package:room_manager2/screens/post_style_settings_screen.dart';
import 'package:room_manager2/services/post_comment_generation_count_store.dart';
import 'package:room_manager2/services/post_comment_generation_service.dart';
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

class _FakeGenerationService implements PostCommentGenerationService {
  _FakeGenerationService({
    this.result = const PostCommentGenerationResult(
      body: 'AI生成サンプル本文です。',
      hashtags: ['#楽天ROOM'],
      fullText: 'AI生成サンプル本文です。\n\n#楽天ROOM',
    ),
    this.shouldThrow = false,
  });

  final PostCommentGenerationResult result;
  final bool shouldThrow;
  PostCommentGenerationInput? lastInput;

  @override
  Future<PostCommentGenerationResult> generate(
    PostCommentGenerationInput input,
  ) async {
    lastInput = input;
    if (shouldThrow) {
      throw Exception('generation failed');
    }
    return result;
  }
}

Widget _wrap({
  required SharedPreferences prefs,
  PostStyleSettings? initialSettings,
  PostCommentGenerationService? generationService,
  bool withHostRoute = false,
}) {
  final screen = PostStyleSettingsScreen(
    initialSettings: initialSettings,
    generationService: generationService,
  );

  if (!withHostRoute) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PostStyleSettingsProvider(
            repository: PostStyleSettingsRepository(prefs),
          ),
        ),
      ],
      child: MaterialApp(home: screen),
    );
  }

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => PostStyleSettingsProvider(
          repository: PostStyleSettingsRepository(prefs),
        ),
      ),
    ],
    child: MaterialApp(
      home: _PostStyleSettingsHost(screen: screen),
    ),
  );
}

class _PostStyleSettingsHost extends StatelessWidget {
  const _PostStyleSettingsHost({required this.screen});

  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('post_style_settings_host'),
      body: Center(
        child: ElevatedButton(
          key: const Key('open_post_style_settings'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => screen),
          ),
          child: const Text('Open'),
        ),
      ),
    );
  }
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  PostStyleSettings? initialSettings,
  PostCommentGenerationService? generationService,
  bool withHostRoute = false,
}) async {
  _setTallViewport(tester);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    _wrap(
      prefs: prefs,
      initialSettings: initialSettings,
      generationService: generationService,
      withHostRoute: withHostRoute,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openScreenFromHost(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_post_style_settings')));
  await tester.pumpAndSettle();
}

Future<void> _tapBack(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('post_style_back_button')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PostStyleSettingsScreen', () {
    testWidgets('shows empty preview without stub when no saved style example',
        (tester) async {
      await _pumpScreen(tester);

      final field = tester.widget<TextField>(
        find.byKey(const Key('post_style_preview_text_field')),
      );
      expect(field.controller?.text, isEmpty);
      expect(find.textContaining('【収納バスケット】'), findsNothing);
      expect(find.byKey(const Key('post_style_preview_refresh_hint')), findsOneWidget);
    });

    testWidgets('displays compact layout sections', (tester) async {
      await _pumpScreen(tester);

      expect(find.text('投稿スタイル設定'), findsOneWidget);
      expect(find.text('生成イメージ'), findsOneWidget);
      expect(find.text('基本'), findsOneWidget);
      expect(find.text('装飾'), findsOneWidget);
      expect(find.text('内容'), findsOneWidget);
      expect(find.text('文体'), findsOneWidget);
      expect(find.text('文章量'), findsOneWidget);
      expect(find.text('絵文字'), findsOneWidget);
      expect(find.text('顔文字'), findsOneWidget);
      expect(find.text('ハッシュタグ'), findsOneWidget);
      expect(find.text('推し方'), findsOneWidget);
      expect(find.text('読者層'), findsOneWidget);
      expect(find.text('誇張表現を避ける'), findsOneWidget);
      expect(find.text('この文例を参考に投稿文を作ります（本番のAI生成回数は消費しません）'), findsOneWidget);
      expect(find.byKey(const Key('post_style_preview_text_field')), findsOneWidget);
      expect(find.byKey(const Key('post_style_preview_refresh_button')), findsOneWidget);
      expect(find.byKey(const Key('post_style_save_button')), findsOneWidget);
      expect(find.byKey(const Key('post_style_reset_button')), findsOneWidget);
    });

    testWidgets('style example field is editable', (tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.byKey(const Key('post_style_preview_text_field')),
        '編集した文例テキスト',
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byKey(const Key('post_style_preview_text_field')))
            .controller
            ?.text,
        '編集した文例テキスト',
      );
    });

    testWidgets('refresh button enables after settings change', (tester) async {
      await _pumpScreen(
        tester,
        initialSettings: PostStyleSettings.defaults().copyWith(
          styleExample: '保存済み文例',
        ),
      );

      final refreshButton = tester.widget<IconButton>(
        find.byKey(const Key('post_style_preview_refresh_button')),
      );
      expect(refreshButton.onPressed, isNull);

      await tester.tap(find.text('フランク'));
      await tester.pumpAndSettle();

      final enabledRefresh = tester.widget<IconButton>(
        find.byKey(const Key('post_style_preview_refresh_button')),
      );
      expect(enabledRefresh.onPressed, isNotNull);
    });

    testWidgets('refresh button uses stub preview by default', (tester) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('フランク'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post_style_preview_refresh_button')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('【${PostStylePreviewSampleProduct.displayTitle}】'),
        findsOneWidget,
      );
    });

    testWidgets('preview refresh does not increment PostCommentGenerationCountStore',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        _wrap(prefs: prefs),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('フランク'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post_style_preview_refresh_button')));
      await tester.pumpAndSettle();

      expect(await PostCommentGenerationCountStore.readTodayCount(), 0);
    });

    testWidgets('refresh button calls generation service and updates preview',
        (tester) async {
      final fakeService = _FakeGenerationService();
      await _pumpScreen(tester, generationService: fakeService);

      await tester.tap(find.text('フランク'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post_style_preview_refresh_button')));
      await tester.pumpAndSettle();

      expect(fakeService.lastInput, isNotNull);
      expect(fakeService.lastInput!.includeStyleExample, isFalse);
      expect(
        fakeService.lastInput!.itemName,
        PostStylePreviewSampleProduct.displayTitle,
      );
      expect(
        fakeService.lastInput!.genreName,
        PostStylePreviewSampleProduct.genre,
      );
      expect(
        fakeService.lastInput!.shopName,
        PostStylePreviewSampleProduct.shopName,
      );
      expect(
        fakeService.lastInput!.recommendationReason,
        PostStylePreviewSampleProduct.recommendationReason,
      );
      expect(fakeService.lastInput!.styleSettings?.tone, PostTone.casual);
      expect(
        find.text('AI生成サンプル本文です。\n\n#楽天ROOM'),
        findsOneWidget,
      );
    });

    testWidgets('refresh shows inline error on failure', (tester) async {
      final fakeService = _FakeGenerationService(shouldThrow: true);
      await _pumpScreen(tester, generationService: fakeService);

      await tester.tap(find.text('フランク'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post_style_preview_refresh_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('post_style_preview_error')), findsOneWidget);
      expect(find.text('生成イメージの更新に失敗しました。'), findsOneWidget);
    });

    testWidgets('preview does not auto-update when settings change', (tester) async {
      await _pumpScreen(
        tester,
        initialSettings: PostStyleSettings.defaults().copyWith(
          styleExample: '固定文例テキスト',
        ),
      );

      final before = tester
          .widget<TextField>(find.byKey(const Key('post_style_preview_text_field')))
          .controller
          ?.text;

      await tester.tap(find.text('フランク'));
      await tester.pumpAndSettle();

      final after = tester
          .widget<TextField>(find.byKey(const Key('post_style_preview_text_field')))
          .controller
          ?.text;

      expect(after, equals(before));
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

      expect(find.widgetWithText(FilterChip, '短め'), findsOneWidget);
    });

    testWidgets('can change emoji level', (tester) async {
      await _pumpScreen(tester);

      await _scrollTo(tester, find.text('使わない'));
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

      await _scrollTo(tester, find.text('3個程度'));
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

    testWidgets('can change target audience via dropdown', (tester) async {
      await _pumpScreen(tester);

      await _scrollTo(tester, find.text('読者層'));
      await tester.tap(find.byType(DropdownButtonFormField<PostTargetAudience>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('女性向け').last);
      await tester.pumpAndSettle();

      expect(find.text('女性向け'), findsWidgets);
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

    testWidgets('save button persists settings and style example', (tester) async {
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

      await tester.enterText(
        find.byKey(const Key('post_style_preview_text_field')),
        '保存する文例',
      );
      await tester.tap(find.text('フランク'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post_style_save_button')));
      await tester.pumpAndSettle();

      expect(provider.settings.tone, PostTone.casual);
      expect(provider.settings.styleExample, '保存する文例');
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
                styleExample: 'カスタム文例',
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
      expect(provider.settings.styleExample, isNull);
      expect(find.text('初期設定に戻しました'), findsOneWidget);
    });

    group('unsaved changes on back navigation', () {
      testWidgets('pops without confirmation when there are no changes',
          (tester) async {
        await _pumpScreen(tester, withHostRoute: true);
        await _openScreenFromHost(tester);

        expect(find.text('投稿スタイル設定'), findsOneWidget);

        await _tapBack(tester);

        expect(find.text('投稿スタイル設定'), findsNothing);
        expect(find.byKey(const Key('post_style_settings_host')), findsOneWidget);
        expect(find.text('変更を保存しますか？'), findsNothing);
      });

      testWidgets('shows confirmation dialog after tone change', (tester) async {
        await _pumpScreen(tester, withHostRoute: true);
        await _openScreenFromHost(tester);

        await tester.tap(find.text('フランク'));
        await tester.pumpAndSettle();
        await _tapBack(tester);

        expect(find.text('変更を保存しますか？'), findsOneWidget);
        expect(
          find.text('投稿スタイル設定に未保存の変更があります。'),
          findsOneWidget,
        );
        expect(find.text('投稿スタイル設定'), findsOneWidget);
      });

      testWidgets('shows confirmation dialog after preview text edit',
          (tester) async {
        await _pumpScreen(tester, withHostRoute: true);
        await _openScreenFromHost(tester);

        await tester.enterText(
          find.byKey(const Key('post_style_preview_text_field')),
          '編集した文例テキスト',
        );
        await tester.pumpAndSettle();
        await _tapBack(tester);

        expect(find.text('変更を保存しますか？'), findsOneWidget);
      });

      testWidgets('cancel keeps user on settings screen', (tester) async {
        await _pumpScreen(tester, withHostRoute: true);
        await _openScreenFromHost(tester);

        await tester.tap(find.text('フランク'));
        await tester.pumpAndSettle();
        await _tapBack(tester);
        await tester.tap(find.byKey(const Key('post_style_cancel_back_button')));
        await tester.pumpAndSettle();

        expect(find.text('変更を保存しますか？'), findsNothing);
        expect(find.text('投稿スタイル設定'), findsOneWidget);
      });

      testWidgets('discard closes screen without saving', (tester) async {
        _setTallViewport(tester);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = PostStyleSettingsRepository(prefs);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => PostStyleSettingsProvider(
                  repository: repository,
                ),
              ),
            ],
            child: MaterialApp(
              home: const _PostStyleSettingsHost(
                screen: PostStyleSettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _openScreenFromHost(tester);

        await tester.tap(find.text('フランク'));
        await tester.pumpAndSettle();
        await _tapBack(tester);
        await tester.tap(find.byKey(const Key('post_style_discard_changes_button')));
        await tester.pumpAndSettle();

        expect(find.text('投稿スタイル設定'), findsNothing);
        expect(repository.load().tone, PostTone.friendlyPolite);
      });

      testWidgets('save from dialog persists settings and closes screen',
          (tester) async {
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
              home: _PostStyleSettingsHost(
                screen: PostStyleSettingsScreen(
                  initialSettings: PostStyleSettings.defaults(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _openScreenFromHost(tester);

        await tester.enterText(
          find.byKey(const Key('post_style_preview_text_field')),
          'ダイアログ保存文例',
        );
        await tester.tap(find.text('フランク'));
        await tester.pumpAndSettle();
        await _tapBack(tester);
        await tester.tap(find.byKey(const Key('post_style_save_and_back_button')));
        await tester.pumpAndSettle();

        expect(find.text('投稿スタイル設定'), findsNothing);
        expect(provider.settings.tone, PostTone.casual);
        expect(provider.settings.styleExample, 'ダイアログ保存文例');
      });

      testWidgets('does not show confirmation after saving via app bar button',
          (tester) async {
        await _pumpScreen(tester, withHostRoute: true);
        await _openScreenFromHost(tester);

        await tester.tap(find.text('フランク'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('post_style_save_button')));
        await tester.pumpAndSettle();
        await _tapBack(tester);

        expect(find.text('変更を保存しますか？'), findsNothing);
        expect(find.text('投稿スタイル設定'), findsNothing);
        expect(find.byKey(const Key('post_style_settings_host')), findsOneWidget);
      });

      testWidgets('system back shows confirmation when there are unsaved changes',
          (tester) async {
        await _pumpScreen(tester, withHostRoute: true);
        await _openScreenFromHost(tester);

        await tester.tap(find.text('フランク'));
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('変更を保存しますか？'), findsOneWidget);
        expect(find.text('投稿スタイル設定'), findsOneWidget);
      });
    });
  });
}
