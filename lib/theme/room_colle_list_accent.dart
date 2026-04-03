import 'package:flutter/material.dart';

/// ROOM コレ一覧・楽天検索結果で共有する「候補 / コレ済」役割色（状態チップ・アウトラインに使用）。
abstract final class RoomColleListAccent {
  RoomColleListAccent._();

  /// コレ候補（ROOM 一覧の候補行と同一トーン）。
  static const Color candidate = Color(0xFF1565C0);

  /// コレ済（ROOM 一覧のコレ済行と同一トーン）。
  static const Color done = Color(0xFF2E7D32);
}
