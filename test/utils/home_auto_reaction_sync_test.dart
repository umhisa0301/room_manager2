import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/utils/home_auto_reaction_sync.dart';

void main() {
  final now = DateTime.utc(2026, 6, 9, 12, 0, 0);
  final oldEnough = now.subtract(const Duration(hours: 5));
  final tooRecent = now.subtract(const Duration(hours: 2));

  Map<String, Object?> baseArgs({DateTime? lastSyncAtUtc}) => {
    'isOnHomeTab': true,
    'hasRoomUrl': true,
    'postedProductCount': 3,
    'importRunning': false,
    'metadataEnriching': false,
    'reactionSyncRunning': false,
    'bulkCandidateRegistering': false,
    'lastSyncAtUtc': lastSyncAtUtc,
    'nowUtc': now,
  };

  group('HomeAutoReactionSyncPolicy.skipReason', () {
    test('returns null when all conditions pass', () {
      expect(
        HomeAutoReactionSyncPolicy.skipReason(
          isOnHomeTab: true,
          hasRoomUrl: true,
          postedProductCount: 1,
          importRunning: false,
          metadataEnriching: false,
          reactionSyncRunning: false,
          bulkCandidateRegistering: false,
          lastSyncAtUtc: oldEnough,
          nowUtc: now,
        ),
        isNull,
      );
    });

    test('skips when not on home tab', () {
      expect(
        HomeAutoReactionSyncPolicy.skipReason(
          isOnHomeTab: false,
          hasRoomUrl: true,
          postedProductCount: 1,
          importRunning: false,
          metadataEnriching: false,
          reactionSyncRunning: false,
          bulkCandidateRegistering: false,
          lastSyncAtUtc: oldEnough,
          nowUtc: now,
        ),
        'notOnHome',
      );
    });

    test('skips when no history', () {
      expect(
        HomeAutoReactionSyncPolicy.skipReason(
          isOnHomeTab: true,
          hasRoomUrl: true,
          postedProductCount: 1,
          importRunning: false,
          metadataEnriching: false,
          reactionSyncRunning: false,
          bulkCandidateRegistering: false,
          lastSyncAtUtc: null,
          nowUtc: now,
        ),
        'noHistory',
      );
    });

    test('skips when last sync is within 4 hours', () {
      expect(
        HomeAutoReactionSyncPolicy.skipReason(
          isOnHomeTab: true,
          hasRoomUrl: true,
          postedProductCount: 1,
          importRunning: false,
          metadataEnriching: false,
          reactionSyncRunning: false,
          bulkCandidateRegistering: false,
          lastSyncAtUtc: tooRecent,
          nowUtc: now,
        ),
        'recentSync',
      );
    });

    test('skips when busy', () {
      for (final busy in <String, bool>{
        'import': true,
        'enrich': true,
        'reaction': true,
        'bulk': true,
      }.entries) {
        final args = baseArgs(lastSyncAtUtc: oldEnough);
        switch (busy.key) {
          case 'import':
            args['importRunning'] = true;
          case 'enrich':
            args['metadataEnriching'] = true;
          case 'reaction':
            args['reactionSyncRunning'] = true;
          case 'bulk':
            args['bulkCandidateRegistering'] = true;
        }
        expect(
          HomeAutoReactionSyncPolicy.skipReason(
            isOnHomeTab: args['isOnHomeTab']! as bool,
            hasRoomUrl: args['hasRoomUrl']! as bool,
            postedProductCount: args['postedProductCount']! as int,
            importRunning: args['importRunning']! as bool,
            metadataEnriching: args['metadataEnriching']! as bool,
            reactionSyncRunning: args['reactionSyncRunning']! as bool,
            bulkCandidateRegistering: args['bulkCandidateRegistering']! as bool,
            lastSyncAtUtc: args['lastSyncAtUtc'] as DateTime?,
            nowUtc: args['nowUtc']! as DateTime,
          ),
          'busy',
        );
      }
    });

    test('skips when no posted products or room url', () {
      expect(
        HomeAutoReactionSyncPolicy.skipReason(
          isOnHomeTab: true,
          hasRoomUrl: false,
          postedProductCount: 1,
          importRunning: false,
          metadataEnriching: false,
          reactionSyncRunning: false,
          bulkCandidateRegistering: false,
          lastSyncAtUtc: oldEnough,
          nowUtc: now,
        ),
        'noRoomUrl',
      );
      expect(
        HomeAutoReactionSyncPolicy.skipReason(
          isOnHomeTab: true,
          hasRoomUrl: true,
          postedProductCount: 0,
          importRunning: false,
          metadataEnriching: false,
          reactionSyncRunning: false,
          bulkCandidateRegistering: false,
          lastSyncAtUtc: oldEnough,
          nowUtc: now,
        ),
        'noPostedProducts',
      );
    });
  });
}
