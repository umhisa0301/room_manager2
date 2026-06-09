import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/config/dev_automation_config.dart';
import 'package:room_manager2/models/rakuten_managed_product.dart';
import 'package:room_manager2/models/rakuten_product_search_condition.dart';
import 'package:room_manager2/models/rakuten_search_item.dart';
import 'package:room_manager2/navigation/app_shell_controller.dart';
import 'package:room_manager2/repository/pending_collect_notice_repository.dart';
import 'package:room_manager2/repository/rakuten_managed_product_repository.dart';
import 'package:room_manager2/repository/rakuten_search_repository.dart';
import 'package:room_manager2/repository/room_activity_event_repository.dart';
import 'package:room_manager2/repository/saved_shop_repository.dart';
import 'package:room_manager2/services/dev_automation_runner.dart';
import 'package:room_manager2/services/rakuten_api_service.dart';
import 'package:room_manager2/state/rakuten_managed_product_provider.dart';
import 'package:room_manager2/state/rakuten_search_provider.dart';
import 'package:room_manager2/state/room_activity_event_provider.dart';
import 'package:room_manager2/state/saved_shop_provider.dart';
import 'package:room_manager2/utils/dev_automation_log_buffer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubSearchRepository extends RakutenSearchRepository {
  _StubSearchRepository() : super(apiService: RakutenApiService());

  @override
  Future<List<RakutenSearchItem>> search({
    required RakutenProductSearchCondition condition,
    int maxPages = 4,
    int startPage = 1,
    RakutenSearchPurpose searchPurpose = RakutenSearchPurpose.normal,
    String fetchScreen = 'productSearch',
  }) async {
    return <RakutenSearchItem>[
      RakutenSearchItem(
        productId: 'stub-shop:item001',
        itemName: '水筒 500ml',
        itemPrice: 1980,
        itemUrl: 'https://item.rakuten.co.jp/stub-shop/item001/',
        affiliateUrl: '',
        imageUrl:
            'https://thumbnail.image.rakuten.co.jp/@0_mall/stub-shop/cabinet/a.jpg',
        shopName: 'Stub Shop',
        shopCode: 'stub-shop',
        shopUrl: 'https://www.rakuten.co.jp/stub-shop/',
        genreId: '100227',
        genreName: '水・ソフトドリンク',
      ),
    ];
  }
}

DevAutomationDependencies _newDependencies({
  required SharedPreferences prefs,
  required AppShellController appShell,
  Future<void> Function(Duration duration)? delay,
}) {
  final searchProvider = RakutenSearchProvider(
    repository: _StubSearchRepository(),
  );
  final activityEventProvider = RoomActivityEventProvider(
    repository: RoomActivityEventRepository(prefs),
  );
  return DevAutomationDependencies(
    appShell: appShell,
    searchProvider: searchProvider,
    managedProductProvider: RakutenManagedProductProvider(
      repository: RakutenManagedProductRepository(prefs),
      pendingCollectNoticeRepository: PendingCollectNoticeRepository(prefs),
      activityEventProvider: activityEventProvider,
      rakutenSearchRepository: _StubSearchRepository(),
    ),
    savedShopProvider: SavedShopProvider(
      repository: SavedShopRepository(prefs),
    ),
    delay: delay ?? (_) async {},
    waitForFrame: () async {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DevAutomationRunner.classifyCandidateAddOutcome', () {
    test('classifies added', () {
      expect(
        DevAutomationRunner.classifyCandidateAddOutcome(
          before: RakutenManagedProductStatus.none,
          after: RakutenManagedProductStatus.candidate,
          error: null,
        ),
        DevAutomationCandidateAddResult.added,
      );
    });

    test('classifies alreadyCandidate', () {
      expect(
        DevAutomationRunner.classifyCandidateAddOutcome(
          before: RakutenManagedProductStatus.candidate,
          after: RakutenManagedProductStatus.candidate,
          error: null,
        ),
        DevAutomationCandidateAddResult.alreadyCandidate,
      );
    });

    test('classifies alreadyManaged', () {
      expect(
        DevAutomationRunner.classifyCandidateAddOutcome(
          before: RakutenManagedProductStatus.done,
          after: RakutenManagedProductStatus.done,
          error: null,
        ),
        DevAutomationCandidateAddResult.alreadyManaged,
      );
    });

    test('classifies skippedDuplicate', () {
      expect(
        DevAutomationRunner.classifyCandidateAddOutcome(
          before: RakutenManagedProductStatus.none,
          after: RakutenManagedProductStatus.none,
          error: null,
        ),
        DevAutomationCandidateAddResult.skippedDuplicate,
      );
    });

    test('classifies userVisibleError', () {
      expect(
        DevAutomationRunner.classifyCandidateAddOutcome(
          before: RakutenManagedProductStatus.none,
          after: RakutenManagedProductStatus.none,
          error: 'ROOM同期中です',
        ),
        DevAutomationCandidateAddResult.userVisibleError,
      );
    });
  });

  group('DevAutomationRunner.validateIterations', () {
    test('accepts values within range', () {
      final result = DevAutomationRunner.validateIterations(3);
      expect(result.isValid, isTrue);
      expect(result.value, 3);
    });

    test('rejects null', () {
      final result = DevAutomationRunner.validateIterations(null);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, isNotEmpty);
    });

    test('rejects out of range values', () {
      expect(DevAutomationRunner.validateIterations(0).isValid, isFalse);
      expect(
        DevAutomationRunner.validateIterations(
          DevAutomationRunner.maxIterations + 1,
        ).isValid,
        isFalse,
      );
    });

    test('default iterations constant is 3', () {
      expect(DevAutomationRunner.defaultIterations, 3);
    });
  });

  group('DevAutomationRunner stop flag', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    test('requestStop is ignored when not running', () {
      final logBuffer = DevAutomationLogBuffer();
      final runner = DevAutomationRunner(
        dependencies: _newDependencies(
          prefs: prefs,
          appShell: AppShellController(),
        ),
        logBuffer: logBuffer,
      );

      runner.requestStop();

      expect(runner.stopRequested, isFalse);
      expect(logBuffer.entries, isEmpty);
    });

    test('requestStop is logged while a run is in progress', () async {
      if (!DevAutomationFlags.isEnabled) return;

      final logBuffer = DevAutomationLogBuffer();
      final runner = DevAutomationRunner(
        dependencies: _newDependencies(
          prefs: prefs,
          appShell: AppShellController(),
          delay: (_) async {},
        ),
        logBuffer: logBuffer,
        stepDelayMs: 0,
      );

      final future = runner.runTabTourProductSearch(iterations: 5);
      await Future<void>.delayed(Duration.zero);
      runner.requestStop();
      await future;

      expect(runner.stopRequested, isTrue);
      expect(
        logBuffer.entries.any(
          (line) => line.contains('[DEV_AUTOMATION_RUN_STOP]'),
        ),
        isTrue,
      );
    });

    test('logs addCandidateFromSearch step result on full run', () async {
      if (!DevAutomationFlags.isEnabled) return;

      final logBuffer = DevAutomationLogBuffer();
      final runner = DevAutomationRunner(
        dependencies: _newDependencies(
          prefs: prefs,
          appShell: AppShellController(),
          delay: (_) async {},
        ),
        logBuffer: logBuffer,
        stepDelayMs: 0,
      );

      await runner.runTabTourProductSearch(iterations: 1);

      expect(
        logBuffer.entries.any(
          (line) =>
              line.contains('step=addCandidateFromSearch') &&
              line.contains('result='),
        ),
        isTrue,
      );
      expect(
        logBuffer.entries.any(
          (line) =>
              line.contains('step=openRecommendation') &&
              line.contains('result=skippedNotImplemented'),
        ),
        isTrue,
      );
      expect(
        logBuffer.entries.any(
          (line) => line.contains('[DEV_AUTOMATION_STEP_DELAY]'),
        ),
        isFalse,
      );
    });
  });

  group('DevAutomationRunner step delay', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    test('logs and waits after each step when stepDelayMs > 0', () async {
      if (!DevAutomationFlags.isEnabled) return;

      final logBuffer = DevAutomationLogBuffer();
      final delayCalls = <Duration>[];
      final runner = DevAutomationRunner(
        dependencies: _newDependencies(
          prefs: prefs,
          appShell: AppShellController(),
          delay: (duration) async {
            delayCalls.add(duration);
          },
        ),
        logBuffer: logBuffer,
        stepDelayMs: 100,
      );

      await runner.runTabTourProductSearch(iterations: 1);

      expect(
        logBuffer.entries.where(
          (line) => line.contains('[DEV_AUTOMATION_STEP_DELAY]'),
        ).length,
        10,
      );
      expect(
        logBuffer.entries.any(
          (line) =>
              line.contains('step=managedTab') &&
              line.contains('delayMs=100'),
        ),
        isTrue,
      );
      expect(
        delayCalls.where((d) => d == const Duration(milliseconds: 100)).length,
        10,
      );
    });

    test('skips delay and log when stepDelayMs is 0', () async {
      if (!DevAutomationFlags.isEnabled) return;

      final logBuffer = DevAutomationLogBuffer();
      final delayCalls = <Duration>[];
      final runner = DevAutomationRunner(
        dependencies: _newDependencies(
          prefs: prefs,
          appShell: AppShellController(),
          delay: (duration) async {
            delayCalls.add(duration);
          },
        ),
        logBuffer: logBuffer,
        stepDelayMs: 0,
      );

      await runner.runTabTourProductSearch(iterations: 1);

      expect(
        logBuffer.entries.any(
          (line) => line.contains('[DEV_AUTOMATION_STEP_DELAY]'),
        ),
        isFalse,
      );
      expect(
        delayCalls.where((d) => d == Duration.zero).length,
        0,
      );
    });
  });
}
