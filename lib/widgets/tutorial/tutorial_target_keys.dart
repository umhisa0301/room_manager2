import 'package:flutter/foundation.dart';

/// 操作ガイドのハイライト対象ウィジェット用 Key（一元管理）。
abstract final class TutorialTargetKeys {
  static const roomSettingsCard = Key('tutorial_mypage_room_settings_card');
  static const nicknameRow = Key('tutorial_mypage_nickname_row');
  static const roomUrlRow = Key('tutorial_mypage_room_url_row');
  static const genreRow = Key('tutorial_mypage_genre_row');
  static const savedShopRow = Key('tutorial_mypage_saved_shop_row');
  static const postStyleRow = Key('tutorial_mypage_post_style_row');
}
