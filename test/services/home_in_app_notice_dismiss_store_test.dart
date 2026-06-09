import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/services/home_in_app_notice_dismiss_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeInAppNoticeDismissStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('todayDateKey formats local calendar day', () {
      expect(
        HomeInAppNoticeDismissStore.todayDateKey(
          DateTime(2026, 6, 9, 15, 30),
        ),
        '2026-06-09',
      );
    });

    test('dismissForToday persists key for the same day', () async {
      final now = DateTime(2026, 6, 9, 10);
      await HomeInAppNoticeDismissStore.dismissForToday(
        'post_milestone_2026-06-09_1',
        now: now,
      );
      final keys = await HomeInAppNoticeDismissStore.loadDismissedKeysForToday(
        now: now,
      );
      expect(keys, {'post_milestone_2026-06-09_1'});
    });

    test('dismissed keys from previous day are ignored', () async {
      final yesterday = DateTime(2026, 6, 8, 23);
      await HomeInAppNoticeDismissStore.dismissForToday(
        'rec_completed_2026-06-08',
        now: yesterday,
      );
      final keys = await HomeInAppNoticeDismissStore.loadDismissedKeysForToday(
        now: DateTime(2026, 6, 9, 8),
      );
      expect(keys, isEmpty);
    });

    test('multiple dismissals accumulate for today', () async {
      final now = DateTime(2026, 6, 9);
      await HomeInAppNoticeDismissStore.dismissForToday('a', now: now);
      await HomeInAppNoticeDismissStore.dismissForToday('b', now: now);
      final keys = await HomeInAppNoticeDismissStore.loadDismissedKeysForToday(
        now: now,
      );
      expect(keys, {'a', 'b'});
    });
  });
}
