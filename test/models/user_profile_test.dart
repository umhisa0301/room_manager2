import 'package:flutter_test/flutter_test.dart';
import 'package:room_manager2/models/user_profile.dart';

void main() {
  group('UserProfile postStyles', () {
    test('fromJson keeps existing data and reads first postStyle', () {
      final profile = UserProfile.fromJson({
        'displayName': 'mai',
        'genderKey': UserProfile.genderFemale,
        'postStyles': 'premium、social、highly_rated',
      });

      expect(profile.displayName, 'mai');
      expect(profile.genderKey, UserProfile.genderFemale);
      expect(profile.postStyleList, [UserProfile.postStylePremium]);
      expect(profile.selectedSearchStyle, UserProfile.postStylePremium);
    });

    test('postStyleList ignores unknown values and keeps single value', () {
      const profile = UserProfile(
        postStyles: 'premium、unknown、social、highly_rated、affordable',
      );

      expect(profile.postStyleList, [UserProfile.postStylePremium]);
    });

    test(
      'effectivePostStyleList uses balance without showing it as selected',
      () {
        const profile = UserProfile();

        expect(profile.postStyleList, isEmpty);
        expect(profile.effectivePostStyleList, [UserProfile.postStyleBalance]);
        expect(profile.postStyleLabelsText, '未設定');
      },
    );
  });
}
