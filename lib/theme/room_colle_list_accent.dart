import 'package:flutter/material.dart';

import 'home_screen_colors.dart';

/// ROOM コレ一覧・楽天検索結果で共有する「候補 / コレ済」役割色（状態チップ・アウトラインに使用）。
abstract final class RoomColleListAccent {
  RoomColleListAccent._();

  /// コレ候補（ホーム画面のティール基調に揃える）。
  static const Color candidate = HomeScreenColors.homeAccentTeal;

  /// コレ済（完了・達成のグリーン）。
  static const Color done = HomeScreenColors.homeSuccess;
}
