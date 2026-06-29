import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/post_style_settings.dart';
import 'package:room_manager2/repository/post_style_settings_repository.dart';
import 'package:room_manager2/state/post_style_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PostStyleSettingsProvider', () {
    late SharedPreferences prefs;
    late PostStyleSettingsProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      provider = PostStyleSettingsProvider(
        repository: PostStyleSettingsRepository(prefs),
      );
    });

    test('starts with defaults', () {
      expect(
        provider.settings.toJson(),
        PostStyleSettings.defaults().toJson(),
      );
    });

    test('saveSettings persists and updates state', () async {
      final custom = PostStyleSettings.defaults().copyWith(
        tone: PostTone.casual,
        length: PostLength.short,
      );

      await provider.saveSettings(custom);

      expect(provider.settings.tone, PostTone.casual);
      expect(provider.settings.length, PostLength.short);
      expect(
        PostStyleSettingsRepository(prefs).load().tone,
        PostTone.casual,
      );
      expect(provider.settings.updatedAt.millisecondsSinceEpoch, greaterThan(0));
    });

    test('reload reads latest from repository', () async {
      final repo = PostStyleSettingsRepository(prefs);
      await repo.save(
        PostStyleSettings.defaults().copyWith(
          emojiLevel: EmojiLevel.none,
          updatedAt: DateTime.utc(2026, 6, 29),
        ),
      );

      await provider.reload();

      expect(provider.settings.emojiLevel, EmojiLevel.none);
      expect(provider.settings.updatedAt, DateTime.utc(2026, 6, 29));
    });

    test('resetToDefaults restores defaults', () async {
      await provider.saveSettings(
        PostStyleSettings.defaults().copyWith(
          tone: PostTone.casual,
          kaomojiEnabled: true,
        ),
      );

      await provider.resetToDefaults();

      expect(provider.settings.tone, PostTone.friendlyPolite);
      expect(provider.settings.kaomojiEnabled, isFalse);
      expect(
        PostStyleSettingsRepository(prefs).load().tone,
        PostTone.friendlyPolite,
      );
    });
  });
}
