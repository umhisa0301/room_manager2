import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/post_style_settings.dart';
import 'package:room_manager2/repository/post_style_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PostStyleSettingsRepository', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('load returns defaults when empty', () {
      final repo = PostStyleSettingsRepository(prefs);
      final loaded = repo.load();

      expect(loaded.toJson(), PostStyleSettings.defaults().toJson());
    });

    test('save and load round-trip', () async {
      final repo = PostStyleSettingsRepository(prefs);
      final custom = PostStyleSettings.defaults().copyWith(
        tone: PostTone.casual,
        length: PostLength.short,
        emojiLevel: EmojiLevel.none,
        hashtagLevel: HashtagLevel.few,
        focusPoints: const [PostFocusPoint.reviews],
        targetAudience: PostTargetAudience.parents,
        updatedAt: DateTime.utc(2026, 6, 29, 9, 30),
      );

      await repo.save(custom);
      final loaded = repo.load();

      expect(loaded.tone, PostTone.casual);
      expect(loaded.length, PostLength.short);
      expect(loaded.emojiLevel, EmojiLevel.none);
      expect(loaded.hashtagLevel, HashtagLevel.few);
      expect(loaded.focusPoints, [PostFocusPoint.reviews]);
      expect(loaded.targetAudience, PostTargetAudience.parents);
      expect(loaded.updatedAt, custom.updatedAt);
    });
  });
}
