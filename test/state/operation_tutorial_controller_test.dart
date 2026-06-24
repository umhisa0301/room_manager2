import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/operation_tutorial_id.dart';
import 'package:room_manager2/repository/operation_tutorial_repository.dart';
import 'package:room_manager2/state/operation_tutorial_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OperationTutorialController', () {
    late OperationTutorialRepository repo;
    late OperationTutorialController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = OperationTutorialRepository(prefs);
      controller = OperationTutorialController(repo);
    });

    test('maybeAutoStart starts when not dismissed', () {
      controller.maybeAutoStartProfileTutorial();
      expect(controller.isActive, isTrue);
      expect(controller.stepIndex, 0);
    });

    test('maybeAutoStart does nothing when dismissed', () async {
      await repo.dismiss(
        id: OperationTutorialId.profile,
        markSkipped: true,
      );
      controller.maybeAutoStartProfileTutorial();
      expect(controller.isActive, isFalse);
    });

    test('forceReplay starts even when dismissed', () async {
      await repo.dismiss(
        id: OperationTutorialId.profile,
        markCompleted: true,
      );
      controller.startProfileTutorial(forceReplay: true);
      expect(controller.isActive, isTrue);
      expect(controller.isForceReplay, isTrue);
    });

    test('skip during replay does not change persisted flags', () async {
      await repo.dismiss(
        id: OperationTutorialId.profile,
        markCompleted: true,
      );
      controller.startProfileTutorial(forceReplay: true);
      controller.skip();
      expect(controller.isActive, isFalse);
      expect(repo.isCompleted(OperationTutorialId.profile), isTrue);
      expect(repo.isDismissed(OperationTutorialId.profile), isTrue);
    });

    test('complete on last step persists when not replay', () async {
      controller.startProfileTutorial(forceReplay: false);
      while (!controller.isLastStep) {
        controller.nextStep();
      }
      controller.nextStep();
      expect(controller.isActive, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(repo.isCompleted(OperationTutorialId.profile), isTrue);
      expect(repo.isDismissed(OperationTutorialId.profile), isTrue);
    });

    test('skip persists skipped flag when not replay', () async {
      controller.startProfileTutorial(forceReplay: false);
      controller.skip();
      expect(controller.isActive, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(repo.isSkipped(OperationTutorialId.profile), isTrue);
      expect(repo.isDismissed(OperationTutorialId.profile), isTrue);
    });
  });
}
