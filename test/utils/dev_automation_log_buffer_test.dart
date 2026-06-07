import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/dev_automation_log_buffer.dart';

void main() {
  group('DevAutomationLogBuffer', () {
    test('keeps only the latest maxEntries lines', () {
      final buffer = DevAutomationLogBuffer(maxEntries: 3);
      buffer.add('line-1');
      buffer.add('line-2');
      buffer.add('line-3');
      buffer.add('line-4');

      expect(buffer.entries, ['line-2', 'line-3', 'line-4']);
    });

    test('ignores empty messages', () {
      final buffer = DevAutomationLogBuffer();
      buffer.add('   ');
      expect(buffer.entries, isEmpty);
    });

    test('notifies listeners when a line is added', () {
      final buffer = DevAutomationLogBuffer();
      var notified = 0;
      buffer.addListener(() => notified++);
      buffer.add('[DEV_AUTOMATION_TEST] ok');
      expect(notified, 1);
    });
  });
}
