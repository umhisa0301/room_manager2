import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/post_style_settings.dart';

void main() {
  group('PostStyleSettings defaults', () {
    test('has expected initial values', () {
      final settings = PostStyleSettings.defaults();

      expect(settings.tone, PostTone.friendlyPolite);
      expect(settings.length, PostLength.standard);
      expect(settings.emojiLevel, EmojiLevel.low);
      expect(settings.kaomojiEnabled, isFalse);
      expect(settings.hashtagLevel, HashtagLevel.standard);
      expect(settings.focusPoints, [
        PostFocusPoint.costPerformance,
        PostFocusPoint.dailyUse,
      ]);
      expect(settings.targetAudience, PostTargetAudience.general);
      expect(settings.avoidOverstatement, isTrue);
    });

    test('derives length limits from length enum', () {
      const cases = <PostLength, ({int target, int min, int max})>{
        PostLength.short: (target: 80, min: 60, max: 90),
        PostLength.standard: (target: 120, min: 100, max: 140),
        PostLength.detailed: (target: 180, min: 160, max: 220),
      };

      for (final entry in cases.entries) {
        final settings = PostStyleSettings.defaults().copyWith(length: entry.key);
        expect(settings.targetLengthChars, entry.value.target);
        expect(settings.minBodyChars, entry.value.min);
        expect(settings.maxBodyChars, entry.value.max);
      }
    });

    test('derives hashtag count from hashtag level', () {
      expect(
        PostStyleSettings.defaults()
            .copyWith(hashtagLevel: HashtagLevel.none)
            .hashtagCount,
        0,
      );
      expect(
        PostStyleSettings.defaults()
            .copyWith(hashtagLevel: HashtagLevel.few)
            .hashtagCount,
        3,
      );
      expect(
        PostStyleSettings.defaults()
            .copyWith(hashtagLevel: HashtagLevel.standard)
            .hashtagCount,
        5,
      );
    });

    test('generationLimits includes maxTotalChars by length', () {
      final short = PostStyleSettings.defaults()
          .copyWith(length: PostLength.short)
          .generationLimits;
      final standard = PostStyleSettings.defaults().generationLimits;
      final detailed = PostStyleSettings.defaults()
          .copyWith(length: PostLength.detailed)
          .generationLimits;

      expect(short.maxTotalChars, 160);
      expect(standard.maxTotalChars, 220);
      expect(detailed.maxTotalChars, 320);

      expect(short.maxOutputTokens, 120);
      expect(standard.maxOutputTokens, 180);
      expect(detailed.maxOutputTokens, 260);
    });
  });

  group('PostStyleSettings JSON', () {
    test('round-trips style_example with snake_case keys', () {
      final original = PostStyleSettings(
        tone: PostTone.friendlyPolite,
        length: PostLength.standard,
        emojiLevel: EmojiLevel.low,
        kaomojiEnabled: false,
        hashtagLevel: HashtagLevel.standard,
        focusPoints: const [
          PostFocusPoint.costPerformance,
          PostFocusPoint.dailyUse,
        ],
        targetAudience: PostTargetAudience.general,
        avoidOverstatement: true,
        updatedAt: DateTime.utc(2026, 6, 29, 12),
        styleExample: '保存済み文例テキスト',
      );

      final json = original.toJson();
      expect(json['style_example'], '保存済み文例テキスト');

      final restored = PostStyleSettings.fromJson(json);
      expect(restored.styleExample, '保存済み文例テキスト');
    });

    test('hasSamePreviewConfig ignores styleExample', () {
      final base = PostStyleSettings.defaults();
      final withExample = base.copyWith(styleExample: '文例');
      expect(base.hasSamePreviewConfig(withExample), isTrue);
      expect(
        base.hasSamePreviewConfig(base.copyWith(tone: PostTone.casual)),
        isFalse,
      );
    });

    test('hasSameSavedContent compares styleExample', () {
      final base = PostStyleSettings.defaults();
      final withExample = base.copyWith(styleExample: '文例');
      expect(base.hasSameSavedContent(withExample), isFalse);
      expect(
        withExample.hasSameSavedContent(
          withExample.copyWith(styleExample: '  文例  '),
        ),
        isTrue,
      );
      expect(
        base.hasSameSavedContent(base.copyWith(tone: PostTone.casual)),
        isFalse,
      );
    });

    test('round-trips with snake_case keys', () {
      final original = PostStyleSettings(
        tone: PostTone.friendlyPolite,
        length: PostLength.standard,
        emojiLevel: EmojiLevel.low,
        kaomojiEnabled: false,
        hashtagLevel: HashtagLevel.standard,
        focusPoints: const [
          PostFocusPoint.costPerformance,
          PostFocusPoint.dailyUse,
        ],
        targetAudience: PostTargetAudience.general,
        avoidOverstatement: true,
        updatedAt: DateTime.utc(2026, 6, 29, 12),
      );

      final json = original.toJson();
      expect(json['tone'], 'friendly_polite');
      expect(json['emoji_level'], 'low');
      expect(json['focus_points'], ['cost_performance', 'daily_use']);
      expect(json['updated_at'], '2026-06-29T12:00:00.000Z');

      final restored = PostStyleSettings.fromJson(json);
      expect(restored.tone, original.tone);
      expect(restored.length, original.length);
      expect(restored.emojiLevel, original.emojiLevel);
      expect(restored.kaomojiEnabled, original.kaomojiEnabled);
      expect(restored.hashtagLevel, original.hashtagLevel);
      expect(restored.focusPoints, original.focusPoints);
      expect(restored.targetAudience, original.targetAudience);
      expect(restored.avoidOverstatement, original.avoidOverstatement);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('fromJson falls back for invalid values', () {
      final settings = PostStyleSettings.fromJson({
        'tone': 'unknown',
        'length': 'unknown',
        'emoji_level': 'unknown',
        'hashtag_level': 'unknown',
        'focus_points': ['unknown'],
        'target_audience': 'unknown',
      });

      expect(settings.tone, PostTone.friendlyPolite);
      expect(settings.length, PostLength.standard);
      expect(settings.emojiLevel, EmojiLevel.low);
      expect(settings.hashtagLevel, HashtagLevel.standard);
      expect(settings.focusPoints, [PostFocusPoint.costPerformance]);
      expect(settings.targetAudience, PostTargetAudience.general);
    });

    test('fromJson does not crash on null or malformed types', () {
      expect(() => PostStyleSettings.fromJson(null), returnsNormally);
      final settings = PostStyleSettings.fromJson({
        'kaomoji_enabled': 'not-a-bool',
        'avoid_overstatement': 1,
        'focus_points': 'not-a-list',
        'updated_at': 'not-a-date',
      });
      expect(settings.kaomojiEnabled, isFalse);
      expect(settings.avoidOverstatement, isTrue);
      expect(settings.focusPoints, PostStyleSettings.defaults().focusPoints);
    });

    test('fromJson limits focusPoints to max 3', () {
      final settings = PostStyleSettings.fromJson({
        'focus_points': [
          'cost_performance',
          'convenience',
          'reviews',
          'design',
          'cute',
        ],
      });
      expect(settings.focusPoints.length, PostStyleSettings.maxFocusPoints);
      expect(settings.focusPoints, [
        PostFocusPoint.costPerformance,
        PostFocusPoint.convenience,
        PostFocusPoint.reviews,
      ]);
    });

    test('fromJson removes duplicate focusPoints', () {
      final settings = PostStyleSettings.fromJson({
        'focus_points': [
          'cost_performance',
          'cost_performance',
          'daily_use',
        ],
      });
      expect(settings.focusPoints, [
        PostFocusPoint.costPerformance,
        PostFocusPoint.dailyUse,
      ]);
    });

    test('normalizeFocusPoints enforces max and dedup', () {
      final normalized = PostStyleSettings.normalizeFocusPoints([
        PostFocusPoint.gift,
        PostFocusPoint.gift,
        PostFocusPoint.cute,
        PostFocusPoint.design,
        PostFocusPoint.reviews,
      ]);
      expect(normalized, [
        PostFocusPoint.gift,
        PostFocusPoint.cute,
        PostFocusPoint.design,
      ]);
    });
  });
}
