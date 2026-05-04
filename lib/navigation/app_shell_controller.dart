import 'package:flutter/foundation.dart';

import '../models/room_colle_list_filters.dart';

/// ホームなどから「ROOMコレ」タブを開くときに渡す一次ナビゲーション情報。
class RoomCollectNavigationIntent {
  const RoomCollectNavigationIntent({
    required this.initialTabIndex,
    this.doneFilterLocalDay,
    this.focusCandidateProductId,
    this.candidateStalePreset,
  });

  /// 0: コレ候補、1: コレ済
  final int initialTabIndex;

  /// コレ済タブの暦日フィルター。`null` のときはコレ済を日付で絞り込まない。
  final DateTime? doneFilterLocalDay;

  /// コレ候補タブ内でフォーカスする商品ID。
  final String? focusCandidateProductId;

  /// 候補タブを開いたときに適用する「経過日数」整理プリセット。
  final RoomColleStaleCandidatePreset? candidateStalePreset;
}

/// アプリシェル（下部ナビ: ホーム・探す・ROOMコレ・分析・マイページ）の選択インデックスと、
/// タブ間の導線用インテントを集約する。
///
/// [IndexedStack] の対応: 0=ホーム, 1=ROOMコレ, 2=コメント（フッター非表示）, 3=分析, 4=マイページ
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
    RoomColleStaleCandidatePreset? candidateStalePreset,
  }) {
    var idx = initialTabIndex.clamp(0, 1);
    var focus = focusCandidateProductId?.trim();
    if (focus != null && focus.isEmpty) focus = null;
    if (focus != null && idx != 0) focus = null;

    DateTime? dayNorm;
    if (idx == 1 && doneFilterLocalDay != null) {
      try {
        final d = doneFilterLocalDay;
        final y = d.year;
        if (y >= 1900 && y <= 2100) {
          dayNorm = DateTime(d.year, d.month, d.day);
        }
      } catch (_) {}
    }

    RoomColleStaleCandidatePreset? stale;
    if (idx == 0 && candidateStalePreset != null) {
      stale = candidateStalePreset;
    }

    _pendingRoomCollect = RoomCollectNavigationIntent(
      initialTabIndex: idx,
      doneFilterLocalDay: idx == 1 ? dayNorm : null,
      focusCandidateProductId: focus,
      candidateStalePreset: stale,
    );
    _currentIndex = 1;
    notifyListeners();
  }

  /// 分析タブ（インデックス3）へ。フッターを維持。
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
