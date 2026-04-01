import 'package:flutter/foundation.dart';

/// ホームなどから「ROOMコレ」タブを開くときに渡す一次ナビゲーション情報。
class RoomCollectNavigationIntent {
  const RoomCollectNavigationIntent({
    required this.initialTabIndex,
    this.doneFilterLocalDay,
    this.focusCandidateProductId,
  });

  /// 0: コレ候補、1: コレ済
  final int initialTabIndex;

  /// コレ済タブの暦日フィルター。`null` のときはコレ済を日付で絞り込まない。
  final DateTime? doneFilterLocalDay;

  /// コレ候補タブ内でフォーカスする商品ID。
  final String? focusCandidateProductId;
}

/// アプリシェル（下部5タブ）の選択インデックスと、タブ間の導線用インテントを集約する。
///
/// - タブ切り替えは [selectTab]（= フッタータップ相当）。
/// - ホームから ROOMコレ／活動へは `Navigator.push` せず [openRoomCollect] / [openActivityTab] で統一する。
class AppShellController extends ChangeNotifier {
  AppShellController() : _currentIndex = 0;

  int _currentIndex;
  RoomCollectNavigationIntent? _pendingRoomCollect;

  int get currentIndex => _currentIndex;

  /// フッターまたは同等の「タブ選択」のみ。同一指数では通知しない。
  void selectTab(int index) {
    final i = index.clamp(0, 4);
    if (_currentIndex == i) return;
    _currentIndex = i;
    notifyListeners();
  }

  /// ホーム等から ROOMコレ（インデックス1）へ。フッターを維持したままタブを切り替え、
  /// [ProductsPlaceholderScreen] が [takePendingRoomCollectIntent] で一度だけ取り込む。
  void openRoomCollect({
    int initialTabIndex = 0,
    DateTime? doneFilterLocalDay,
    String? focusCandidateProductId,
  }) {
    var idx = initialTabIndex.clamp(0, 1);
    var focus = focusCandidateProductId?.trim();
    if (focus != null && focus.isEmpty) focus = null;
    if (focus != null && idx != 0) focus = null;

    DateTime? dayNorm;
    if (idx == 1 && doneFilterLocalDay != null) {
      final d = doneFilterLocalDay;
      dayNorm = DateTime(d.year, d.month, d.day);
    }

    _pendingRoomCollect = RoomCollectNavigationIntent(
      initialTabIndex: idx,
      doneFilterLocalDay: idx == 1 ? dayNorm : null,
      focusCandidateProductId: focus,
    );
    _currentIndex = 1;
    notifyListeners();
  }

  /// 活動タブ（インデックス3）へ。フッターを維持。
  void openActivityTab() {
    if (_currentIndex == 3) return;
    _currentIndex = 3;
    notifyListeners();
  }

  /// ROOMコレ用の保留インテントを取り出して消費する（未設定なら `null`）。
  RoomCollectNavigationIntent? takePendingRoomCollectIntent() {
    final p = _pendingRoomCollect;
    _pendingRoomCollect = null;
    return p;
  }
}
