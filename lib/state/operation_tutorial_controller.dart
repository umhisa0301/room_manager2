import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/profile_tutorial_flow.dart';
import '../models/operation_tutorial_flow.dart';
import '../models/operation_tutorial_id.dart';
import '../models/operation_tutorial_step.dart';
import '../repository/operation_tutorial_repository.dart';

/// 操作ガイドの表示状態とステップ進行。
class OperationTutorialController extends ChangeNotifier {
  OperationTutorialController(this._repository);

  final OperationTutorialRepository _repository;

  OperationTutorialFlow? _activeFlow;
  int _stepIndex = 0;
  bool _forceReplay = false;

  bool get isActive => _activeFlow != null;

  bool get isForceReplay => _forceReplay;

  OperationTutorialFlow? get activeFlow => _activeFlow;

  int get stepIndex => _stepIndex;

  int get stepCount => _activeFlow?.steps.length ?? 0;

  OperationTutorialStep? get currentStep {
    final flow = _activeFlow;
    if (flow == null || flow.steps.isEmpty) return null;
    final i = _stepIndex.clamp(0, flow.steps.length - 1);
    return flow.steps[i];
  }

  bool get isLastStep {
    final flow = _activeFlow;
    if (flow == null || flow.steps.isEmpty) return true;
    return _stepIndex >= flow.steps.length - 1;
  }

  /// 初回自動表示用。未 dismiss のときのみ起動する。
  void maybeAutoStartProfileTutorial() {
    if (isActive) return;
    if (_repository.isDismissed(OperationTutorialId.profile)) return;
    startProfileTutorial(forceReplay: false);
  }

  /// プロフィール登録ガイドを開始する。
  void startProfileTutorial({required bool forceReplay}) {
    if (isActive) return;
    if (!forceReplay &&
        _repository.isDismissed(OperationTutorialId.profile)) {
      return;
    }
    _forceReplay = forceReplay;
    _activeFlow = profileTutorialFlow;
    _stepIndex = 0;
    notifyListeners();
  }

  void nextStep() {
    final flow = _activeFlow;
    if (flow == null) return;
    if (_stepIndex >= flow.steps.length - 1) {
      unawaited(_finish(completed: true));
      return;
    }
    _stepIndex++;
    notifyListeners();
  }

  void skip() {
    if (_activeFlow == null) return;
    if (_forceReplay) {
      _clearActive();
      return;
    }
    unawaited(_finish(skipped: true));
  }

  Future<void> _finish({bool completed = false, bool skipped = false}) async {
    final flow = _activeFlow;
    if (flow == null) return;
    final id = flow.id;
    final replay = _forceReplay;
    _clearActive();
    if (!replay) {
      await _repository.dismiss(
        id: id,
        markCompleted: completed,
        markSkipped: skipped,
      );
    }
  }

  void _clearActive() {
    _activeFlow = null;
    _stepIndex = 0;
    _forceReplay = false;
    notifyListeners();
  }
}
