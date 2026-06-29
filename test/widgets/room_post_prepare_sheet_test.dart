import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/repository/pending_collect_notice_repository.dart';
import 'package:room_manager2/repository/post_style_settings_repository.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/repository/room_activity_event_repository.dart';
import 'package:room_manager2/services/post_comment_generation_service.dart';
import 'package:room_manager2/state/bulk_operation_state_controller.dart';
import 'package:room_manager2/state/post_style_settings_provider.dart';
import 'package:room_manager2/state/rakuten_managed_product_provider.dart';
import 'package:room_manager2/state/room_activity_event_provider.dart';
import 'package:room_manager2/widgets/app_button.dart';
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
  Future<String> generate(PostCommentGenerationInput input) async {
    return 'AI生成テスト文';
  }
}

class _FailingPostCommentGenerationService
    implements PostCommentGenerationService {
  const _FailingPostCommentGenerationService();

  @override
  Future<String> generate(PostCommentGenerationInput input) async {
    throw Exception('stub failure');
  }
}

Future<Widget> _wrapSheet({
  required SharedPreferences prefs,
  RakutenUrlExtractionStatus extractionStatus =
      RakutenUrlExtractionStatus.extracting,
  String extractedUrl = '',
  PostCommentGenerationService? generationService,
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
  await tester.pumpAndSettle();
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

      expect(find.byKey(const Key('room_post_prepare_sheet')), findsOneWidget);
      expect(find.text('投稿の準備'), findsOneWidget);
      expect(find.text('コメントを確認してからROOMへ'), findsOneWidget);
      expect(find.text('おすすめ商品テスト'), findsOneWidget);
      expect(find.text('￥2,980'), findsOneWidget);
      expect(find.textContaining('レビュー 4.35'), findsOneWidget);
      expect(find.textContaining('42件'), findsOneWidget);
      expect(find.byKey(const Key('room_post_prepare_body_field')), findsOneWidget);
    });

    testWidgets('body field accepts input', (tester) async {
      await tester.pumpWidget(await _wrapSheet(prefs: prefs));
      await _openSheet(tester);

      await tester.enterText(
        find.byKey(const Key('room_post_prepare_body_field')),
        '手入力の投稿文',
      );
      expect(find.text('手入力の投稿文'), findsOneWidget);
    });

    testWidgets('AI button shows loading then fills body', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: const StubPostCommentGenerationService(
            delay: Duration(milliseconds: 200),
          ),
        ),
      );
      await _openSheet(tester);

      await tester.tap(find.byKey(const Key('room_post_prepare_ai_button')));
      await tester.pump();
      expect(
        find.byKey(const Key('room_post_prepare_ai_loading')),
        findsOneWidget,
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(
        find.byKey(const Key('room_post_prepare_ai_loading')),
        findsNothing,
      );
      expect(find.textContaining('おすすめ商品テスト'), findsWidgets);
    });

    testWidgets('AI failure shows error message', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          generationService: const _FailingPostCommentGenerationService(),
        ),
      );
      await _openSheet(tester);

      await tester.tap(find.byKey(const Key('room_post_prepare_ai_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('room_post_prepare_ai_error')), findsOneWidget);
      expect(find.textContaining('失敗'), findsOneWidget);
    });

    testWidgets('ROOM button disabled when URL not ready', (tester) async {
      await tester.pumpWidget(
        await _wrapSheet(
          prefs: prefs,
          extractionStatus: RakutenUrlExtractionStatus.extracting,
        ),
      );
      await _openSheet(tester);

      final roomButton = tester.widget<AppPrimaryButton>(
        find.byKey(const Key('room_post_prepare_room_button')),
      );
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

      final roomButton = tester.widget<AppPrimaryButton>(
        find.byKey(const Key('room_post_prepare_room_button')),
      );
      expect(roomButton.onPressed, isNotNull);
      expect(
        find.byKey(const Key('room_post_prepare_url_not_ready_hint')),
        findsNothing,
      );
    });

    testWidgets('楽天で見る button is visible', (tester) async {
      await tester.pumpWidget(await _wrapSheet(prefs: prefs));
      await _openSheet(tester);

      expect(find.byKey(const Key('room_post_prepare_rakuten_button')), findsOneWidget);
      expect(find.text('楽天で見る'), findsOneWidget);
    });

    testWidgets('close button dismisses sheet', (tester) async {
      await tester.pumpWidget(await _wrapSheet(prefs: prefs));
      await _openSheet(tester);

      expect(find.byKey(const Key('room_post_prepare_sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('room_post_prepare_close_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room_post_prepare_sheet')), findsNothing);
    });
  });
}
