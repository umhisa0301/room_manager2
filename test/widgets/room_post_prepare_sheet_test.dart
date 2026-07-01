import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/models/post_comment_generation_result.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/repository/pending_collect_notice_repository.dart';
import 'package:room_manager2/repository/post_style_settings_repository.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/repository/room_activity_event_repository.dart';
import 'package:room_manager2/services/post_comment_generation_count_store.dart';
import 'package:room_manager2/services/post_comment_generation_exception.dart';
import 'package:room_manager2/services/post_comment_generation_service.dart';
import 'package:room_manager2/services/post_comment_generation_user_message.dart';
import 'package:room_manager2/state/bulk_operation_state_controller.dart';
import 'package:room_manager2/state/post_style_settings_provider.dart';
import 'package:room_manager2/state/rakuten_managed_product_provider.dart';
import 'package:room_manager2/state/room_activity_event_provider.dart';
import 'package:room_manager2/theme/home_screen_colors.dart';
import 'package:room_manager2/widgets/room_post_prepare_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

RakutenSearchItem _item() {
  return const RakutenSearchItem(
    productId: 'shop:item001',
    itemName: 'おすすめ商品テスト',
    itemPrice: 2980,
    itemUrl: 'https://item.rakuten.co.jp/shop/item001/',
    affiliateUrl: '',
    imageUrl: 'https://example.com/p.jpg',
    shopName: 'テストショップ',
    shopCode: 'shop',
    shopUrl: 'https://www.rakuten.co.jp/shop/',
    genreId: '100',
    genreName: 'ジャンル',
    reviewCount: 42,
    reviewAverage: 4.35,
  );
}

class _InstantStubPostCommentGenerationService
    implements PostCommentGenerationService {
  const _InstantStubPostCommentGenerationService();

  @override
  Future<PostCommentGenerationResult> generate(
    PostCommentGenerationInput input,
  ) async {
    return const PostCommentGenerationResult(
      body: 'AI生成テスト文',
      fullText: 'AI生成テスト文',
    );
  }
}

class _NeverCompletingPostCommentGenerationService
    implements PostCommentGenerationService {
  const _NeverCompletingPostCommentGenerationService();

  @override
  Future<PostCommentGenerationResult> generate(
    PostCommentGenerationInput input,
  ) {
    return Completer<PostCommentGenerationResult>().future;
  }
}

class _CountingPostCommentGenerationService
    implements PostCommentGenerationService {
  _CountingPostCommentGenerationService({this.delay = Duration.zero});

  final Duration delay;
  int callCount = 0;

  @override
  Future<PostCommentGenerationResult> generate(
    PostCommentGenerationInput input,
  ) async {
    callCount++;
    await Future<void>.delayed(delay);
    return const PostCommentGenerationResult(
      body: 'AI生成テスト文',
      fullText: 'AI生成テスト文',
    );
  }
}

class _SequentialPostCommentGenerationService
    implements PostCommentGenerationService {
  _SequentialPostCommentGenerationService(this.results);

  final List<PostCommentGenerationResult> results;
  int callCount = 0;

  @override
  Future<PostCommentGenerationResult> generate(
    PostCommentGenerationInput input,
  ) async {
    final index = callCount.clamp(0, results.length - 1);
    callCount++;
    return results[index];
  }
}

class _FailingPostCommentGenerationService
    implements PostCommentGenerationService {
  const _FailingPostCommentGenerationService();

  @override
  Future<PostCommentGenerationResult> generate(
    PostCommentGenerationInput input,
  ) async {
    throw Exception('stub failure');
  }
}

class _CodeThrowingPostCommentGenerationService
    implements PostCommentGenerationService {
  const _CodeThrowingPostCommentGenerationService(this.exception);

  final PostCommentGenerationException exception;

  @override
  Future<PostCommentGenerationResult> generate(
    PostCommentGenerationInput input,
  ) async {
    throw exception;
  }
}

Future<Widget> _wrapSheet({
  required SharedPreferences prefs,
  RakutenUrlExtractionStatus extractionStatus =
      RakutenUrlExtractionStatus.extracting,
  String extractedUrl = '',
  PostCommentGenerationService? generationService,
  bool? enforceDailyGenerationLimit,
}) async {
  final managedRepo = RakutenManagedProductRepository(prefs);
  await managedRepo.registerCandidateFromSearchItem(_item());
  if (extractionStatus == RakutenUrlExtractionStatus.success) {
    await managedRepo.completeExtractionSuccess(
      'shop:item001',
      extractedUrl.isNotEmpty
          ? extractedUrl
          : 'https://room.rakuten.co.jp/r/post/1',
    );
  } else if (extractionStatus == RakutenUrlExtractionStatus.extracting) {
    await managedRepo.markExtractionExtracting('shop:item001');
  }

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => PostStyleSettingsProvider(
          repository: PostStyleSettingsRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => RoomActivityEventProvider(
          repository: RoomActivityEventRepository(prefs),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => BulkOperationStateController(),
      ),
      ChangeNotifierProvider(
        create: (ctx) => RakutenManagedProductProvider(
          repository: managedRepo,
          pendingCollectNoticeRepository: PendingCollectNoticeRepository(prefs),
          activityEventProvider: ctx.read<RoomActivityEventProvider>(),
          bulkOperationState: ctx.read<BulkOperationStateController>(),
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showRoomPostPrepareBottomSheet(
                  context: context,
                  item: _item(),
                  recommendationReason: '人気の定番',
                  generationService: generationService ??
                      const _InstantStubPostCommentGenerationService(),
                  enforceDailyGenerationLimit: enforceDailyGenerationLimit,
                );
              },
              child: const Text('open_sheet'),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open_sheet'));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('RoomPostPrepareSheet', () {
    testWidgets('shows product summary and body field', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(prefs: prefs),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('room_post_prepare_sheet')), findsOneWidget);
      expect(find.text('投稿の準備'), findsOneWidget);
      expect(find.text('コメントを確認してからROOMへ'), findsOneWidget);
      expect(find.text('おすすめ商品テスト'), findsOneWidget);
      expect(find.text('￥2,980'), findsOneWidget);
      expect(find.textContaining('レビュー 4.35'), findsOneWidget);
      expect(find.textContaining('42件'), findsOneWidget);
      expect(find.text('投稿文'), findsOneWidget);
      expect(find.byKey(const Key('room_post_prepare_body_field')), findsOneWidget);
      expect(find.text('AIで作り直す'), findsOneWidget);
      expect(find.text('コピーしてROOMを開く'), findsOneWidget);
      expect(
        find.byKey(const Key('room_post_prepare_clear_button')),
        findsOneWidget,
      );
    });

    testWidgets('AI regenerate button is on the body label row', (tester) async {
      await tester.pumpWidget(await _wrapSheet(prefs: prefs));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      final label = find.text('投稿文');
      final aiButton = find.byKey(const Key('room_post_prepare_ai_button'));
      expect(label, findsOneWidget);
      expect(aiButton, findsOneWidget);
      final labelRow = find.ancestor(
        of: label,
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: labelRow, matching: aiButton),
        findsOneWidget,
      );
    });

    testWidgets('body field accepts input', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: const _NeverCompletingPostCommentGenerationService(),
        ),
      );
      await _openSheet(tester);
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('room_post_prepare_body_field')),
        '手入力の投稿文',
      );
      expect(find.text('手入力の投稿文'), findsOneWidget);
    });

    testWidgets('auto-generates comment when body is empty on open',
        (tester) async {
      final generationService = _CountingPostCommentGenerationService();
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: generationService,
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(generationService.callCount, 1);
      expect(find.text('AI生成テスト文'), findsOneWidget);
    });

    testWidgets('auto-generate shows loading message', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: const StubPostCommentGenerationService(
            delay: Duration(milliseconds: 200),
          ),
        ),
      );
      await _openSheet(tester);
      await tester.pump();

      expect(
        find.byKey(const Key('room_post_prepare_ai_loading')),
        findsOneWidget,
      );
      expect(find.text('投稿文を作成中…'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(
        find.byKey(const Key('room_post_prepare_ai_loading')),
        findsNothing,
      );
    });

    testWidgets('auto-generate failure shows error message', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: const _FailingPostCommentGenerationService(),
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('room_post_prepare_ai_error')), findsOneWidget);
      expect(find.textContaining('作成できませんでした'), findsOneWidget);
    });

    testWidgets('regenerate without edit skips confirm dialog', (tester) async {
      final generationService = _SequentialPostCommentGenerationService(const [
        PostCommentGenerationResult(
          body: '初回生成文',
          fullText: '初回生成文',
        ),
        PostCommentGenerationResult(
          body: '再生成文',
          fullText: '再生成文',
        ),
      ]);
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: generationService,
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.text('初回生成文'), findsOneWidget);

      await tester.tap(find.byKey(const Key('room_post_prepare_ai_button')));
      await tester.pumpAndSettle();

      expect(find.text('投稿文を作り直しますか？'), findsNothing);
      expect(find.text('再生成文'), findsOneWidget);
    });

    testWidgets('regenerate with edited body shows confirm dialog',
        (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(prefs: prefs),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('room_post_prepare_body_field')),
        '編集済みの投稿文',
      );

      await tester.tap(find.byKey(const Key('room_post_prepare_ai_button')));
      await tester.pumpAndSettle();

      expect(find.text('投稿文を作り直しますか？'), findsOneWidget);
      expect(find.text('現在の投稿文は上書きされます。'), findsOneWidget);
    });

    testWidgets('regenerate confirm cancel keeps edited body', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(prefs: prefs),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('room_post_prepare_body_field')),
        '編集済みの投稿文',
      );

      await tester.tap(find.byKey(const Key('room_post_prepare_ai_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(find.text('編集済みの投稿文'), findsOneWidget);
    });

    testWidgets('regenerate confirm accept overwrites body', (tester) async {
      final generationService = _SequentialPostCommentGenerationService(const [
        PostCommentGenerationResult(
          body: '初回生成文',
          fullText: '初回生成文',
        ),
        PostCommentGenerationResult(
          body: '作り直し後の文',
          fullText: '作り直し後の文',
        ),
      ]);
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: generationService,
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('room_post_prepare_body_field')),
        '編集済みの投稿文',
      );

      await tester.tap(find.byKey(const Key('room_post_prepare_ai_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('作り直す'));
      await tester.pumpAndSettle();

      expect(find.text('作り直し後の文'), findsOneWidget);
      expect(find.text('編集済みの投稿文'), findsNothing);
    });

    testWidgets('ROOM button disabled when URL not ready', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          extractionStatus: RakutenUrlExtractionStatus.extracting,
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.text('コピーしてROOMを開く'), findsOneWidget);
      final roomButtonFinder = find.descendant(
        of: find.byKey(const Key('room_post_prepare_room_button')),
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      expect(roomButtonFinder, findsOneWidget);
      final roomButton = tester.widget<ButtonStyleButton>(roomButtonFinder);
      expect(roomButton.onPressed, isNull);
      expect(
        find.byKey(const Key('room_post_prepare_url_not_ready_hint')),
        findsOneWidget,
      );
      expect(
        find.text('ROOM用URLを取得中です。数十秒かかることがあります。'),
        findsOneWidget,
      );
    });

    testWidgets('ROOM button enabled when URL ready', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          extractionStatus: RakutenUrlExtractionStatus.success,
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      final roomButtonFinder = find.descendant(
        of: find.byKey(const Key('room_post_prepare_room_button')),
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      final roomButton = tester.widget<ButtonStyleButton>(roomButtonFinder);
      expect(roomButton.onPressed, isNotNull);
      expect(
        find.byKey(const Key('room_post_prepare_url_not_ready_hint')),
        findsNothing,
      );
    });

    testWidgets('copy and open room copies text then launches ROOM',
        (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          extractionStatus: RakutenUrlExtractionStatus.success,
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.text('AI生成テスト文'), findsOneWidget);

      const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
      final callLog = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, (call) async {
        callLog.add(call.method);
        return true;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(launcherChannel, null);
      });

      final roomButtonFinder = find.descendant(
        of: find.byKey(const Key('room_post_prepare_room_button')),
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      final roomButton = tester.widget<ButtonStyleButton>(roomButtonFinder);
      expect(roomButton.onPressed, isNotNull);

      String? copiedText;
      final actionLog = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = call.arguments['text'] as String?;
          actionLog.add('clipboard');
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.tap(find.byKey(const Key('room_post_prepare_room_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(copiedText, 'AI生成テスト文');
      expect(actionLog, ['clipboard']);

      final managedRepo = RakutenManagedProductRepository(prefs);
      final product = managedRepo.getByProductId('shop:item001');
      expect(product?.status, RakutenManagedProductStatus.done);
      expect(callLog, contains('launch'));
      expect(find.byKey(const Key('room_post_prepare_sheet')), findsNothing);
    });

    testWidgets('clear button shows confirm dialog and clears on accept',
        (tester) async {
      await tester.pumpWidget(await _wrapSheet(prefs: prefs));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.text('AI生成テスト文'), findsOneWidget);

      await tester.tap(find.byKey(const Key('room_post_prepare_clear_button')));
      await tester.pumpAndSettle();

      expect(find.text('投稿文をクリアしますか？'), findsOneWidget);
      expect(find.text('入力中の投稿文が削除されます。'), findsOneWidget);

      await tester.tap(find.text('クリア'));
      await tester.pumpAndSettle();

      expect(find.text('AI生成テスト文'), findsNothing);
      final field = tester.widget<TextField>(
        find.byKey(const Key('room_post_prepare_body_field')),
      );
      expect(field.controller?.text, isEmpty);
    });

    testWidgets('clear confirm cancel keeps body text', (tester) async {
      await tester.pumpWidget(await _wrapSheet(prefs: prefs));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('room_post_prepare_clear_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(find.text('AI生成テスト文'), findsOneWidget);
    });

    testWidgets('楽天で見る and 閉じる are on the same row', (tester) async {
      await tester.pumpWidget(await _wrapSheet(prefs: prefs));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      final rakuten = find.byKey(const Key('room_post_prepare_rakuten_button'));
      final close = find.byKey(const Key('room_post_prepare_close_button'));
      expect(rakuten, findsOneWidget);
      expect(close, findsOneWidget);

      final rakutenTop = tester.getTopLeft(rakuten);
      final closeTop = tester.getTopLeft(close);
      expect(rakutenTop.dy, closeTop.dy);
    });

    testWidgets('楽天で見る button is visible', (tester) async {
      await tester.pumpWidget(await _wrapSheet(prefs: prefs));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('room_post_prepare_rakuten_button')), findsOneWidget);
      expect(find.text('楽天で見る'), findsOneWidget);
    });

    testWidgets('close button dismisses sheet', (tester) async {
      await tester.pumpWidget(await _wrapSheet(prefs: prefs));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('room_post_prepare_sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('room_post_prepare_close_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room_post_prepare_sheet')), findsNothing);
    });

    testWidgets('body field displays long text with hashtags', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: const _NeverCompletingPostCommentGenerationService(),
        ),
      );
      await _openSheet(tester);
      await tester.pump();

      const longBody =
          'おすすめの一品です。レビューも高くて気になっていました。\n'
          '#おすすめ #楽天ROOM #買ってよかった #日用品 #ルームコレ';
      await tester.enterText(
        find.byKey(const Key('room_post_prepare_body_field')),
        longBody,
      );
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('room_post_prepare_body_field')),
      );
      expect(field.minLines, 5);
      expect(field.controller?.text, longBody);
      expect(find.textContaining('#おすすめ'), findsOneWidget);
    });

    testWidgets('楽天で見る uses outline style and 閉じる is weaker', (
      tester,
    ) async {
      await tester.pumpWidget(await _wrapSheet(prefs: prefs));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      final rakutenButton = tester.widget<TextButton>(
        find.descendant(
          of: find.byKey(const Key('room_post_prepare_rakuten_button')),
          matching: find.byType(TextButton),
        ),
      );
      final closeButton = tester.widget<TextButton>(
        find.descendant(
          of: find.byKey(const Key('room_post_prepare_close_button')),
          matching: find.byType(TextButton),
        ),
      );

      expect(
        rakutenButton.style?.backgroundColor?.resolve({}),
        Colors.white,
      );
      expect(
        rakutenButton.style?.foregroundColor?.resolve({}),
        HomeScreenColors.homeAccentTeal,
      );
      expect(
        closeButton.style?.backgroundColor?.resolve({}),
        Colors.transparent,
      );
      expect(
        closeButton.style?.foregroundColor?.resolve({}),
        isNot(HomeScreenColors.homeAccentTeal),
      );
    });

    testWidgets('daily limit blocks API call when already used today',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        PostCommentGenerationCountStore.dateKey: '2026-07-01',
        PostCommentGenerationCountStore.countKey: 1,
      });
      final limitedPrefs = await SharedPreferences.getInstance();
      final generationService = _CountingPostCommentGenerationService();

      await tester.pumpWidget(
        await _wrapSheet(
          prefs: limitedPrefs,
          generationService: generationService,
          enforceDailyGenerationLimit: true,
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(generationService.callCount, 0);
      expect(
        find.text(kPostCommentGenerationDailyLimitMessage),
        findsOneWidget,
      );
    });

    testWidgets('increments count only on successful generation', (tester) async {
      final now = DateTime(2026, 7, 1);
      SharedPreferences.setMockInitialValues({});
      final limitedPrefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        await _wrapSheet(
          prefs: limitedPrefs,
          generationService: const _InstantStubPostCommentGenerationService(),
          enforceDailyGenerationLimit: true,
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(
        await PostCommentGenerationCountStore.readTodayCount(now: now),
        1,
      );
    });

    testWidgets('failed generation does not increment daily count', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final limitedPrefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        await _wrapSheet(
          prefs: limitedPrefs,
          generationService: const _FailingPostCommentGenerationService(),
          enforceDailyGenerationLimit: true,
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(await PostCommentGenerationCountStore.readTodayCount(), 0);
    });

    testWidgets('shows RATE_LIMIT_EXCEEDED user message', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: const _CodeThrowingPostCommentGenerationService(
            PostCommentGenerationException('RATE_LIMIT_EXCEEDED', 'limit'),
          ),
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(kPostCommentGenerationDailyLimitMessage),
        findsOneWidget,
      );
    });

    testWidgets('shows AI_GENERATION_DISABLED user message', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: const _CodeThrowingPostCommentGenerationService(
            PostCommentGenerationException(
              'AI_GENERATION_DISABLED',
              'disabled',
            ),
          ),
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(kPostCommentGenerationDisabledMessage),
        findsOneWidget,
      );
    });

    testWidgets('shows network error user message for TIMEOUT', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: const _CodeThrowingPostCommentGenerationService(
            PostCommentGenerationException('TIMEOUT', 'timeout'),
          ),
        ),
      );
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(kPostCommentGenerationNetworkMessage),
        findsOneWidget,
      );
    });

    testWidgets('double execution prevention still works with daily limit',
        (tester) async {
      final generationService = const _NeverCompletingPostCommentGenerationService();
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: generationService,
        ),
      );
      await _openSheet(tester);
      await tester.pump();

      expect(
        find.byKey(const Key('room_post_prepare_ai_loading')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('room_post_prepare_ai_button')));
      await tester.pump();

      expect(
        find.byKey(const Key('room_post_prepare_ai_loading')),
        findsOneWidget,
      );
    });
  });
}
