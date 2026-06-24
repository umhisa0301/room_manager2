import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/operation_tutorial_id.dart';
import 'package:room_manager2/repository/operation_tutorial_repository.dart';
import 'package:room_manager2/repository/easy_initial_setup_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OperationTutorialRepository', () {
    late SharedPreferences prefs;
    late OperationTutorialRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = OperationTutorialRepository(prefs);
    });

    test('profile tutorial starts undismissed', () {
      expect(repo.isDismissed(OperationTutorialId.profile), isFalse);
      expect(repo.isCompleted(OperationTutorialId.profile), isFalse);
      expect(repo.isSkipped(OperationTutorialId.profile), isFalse);
    });

    test('dismiss with completed sets flags', () async {
      await repo.dismiss(
        id: OperationTutorialId.profile,
        markCompleted: true,
      );
      expect(repo.isDismissed(OperationTutorialId.profile), isTrue);
      expect(repo.isCompleted(OperationTutorialId.profile), isTrue);
      expect(repo.isSkipped(OperationTutorialId.profile), isFalse);
      expect(
        prefs.getBool(OperationTutorialRepository.profileDismissedKey),
        isTrue,
      );
    });

    test('dismiss with skipped sets flags', () async {
      await repo.dismiss(
        id: OperationTutorialId.profile,
        markSkipped: true,
      );
      expect(repo.isDismissed(OperationTutorialId.profile), isTrue);
      expect(repo.isCompleted(OperationTutorialId.profile), isFalse);
      expect(repo.isSkipped(OperationTutorialId.profile), isTrue);
    });

    test('uses keys separate from easy initial setup', () async {
      await repo.dismiss(
        id: OperationTutorialId.profile,
        markCompleted: true,
      );
      expect(prefs.containsKey(EasyInitialSetupRepository.dismissedKey), isFalse);
      expect(prefs.containsKey(EasyInitialSetupRepository.completedKey), isFalse);
      expect(prefs.containsKey(EasyInitialSetupRepository.skippedKey), isFalse);
    });
  });
}
