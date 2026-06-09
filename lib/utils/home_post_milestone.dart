/// ホーム「今日の小さな目標」用マイルストーン判定（UI専用・純粋関数）。
class HomePostMilestoneSnapshot {
  const HomePostMilestoneSnapshot({
    required this.postCount,
    required this.nextMilestone,
    required this.isHighProgress,
    required this.hintMessage,
    required this.useCalendarDayLabel,
  });

  static const List<int> milestones = [1, 5, 10, 20];

  final int postCount;
  final int? nextMilestone;
  final bool isHighProgress;
  final String hintMessage;
  final bool useCalendarDayLabel;

  String get sectionTitle =>
      useCalendarDayLabel ? '今日の小さな目標' : '直近24時間の目標';

  String? get countSummaryLine {
    if (postCount <= 0) return null;
    return useCalendarDayLabel
        ? '今日は$postCount件投稿できています'
        : '直近24時間で$postCount件投稿できています';
  }

  int get previousMilestone {
    if (isHighProgress) return milestones.last;
    final next = nextMilestone;
    if (next == null) return milestones.last;
    final idx = milestones.indexOf(next);
    if (idx <= 0) return 0;
    return milestones[idx - 1];
  }

  bool isMilestoneReached(int milestone) => postCount >= milestone;

  double get segmentProgress {
    if (isHighProgress) return 1;
    final next = nextMilestone;
    if (next == null) return 1;
    final prev = previousMilestone;
    if (next <= prev) return 1;
    return ((postCount - prev) / (next - prev)).clamp(0.0, 1.0);
  }

  static HomePostMilestoneSnapshot fromPostCount(
    int count, {
    required bool useCalendarDayLabel,
  }) {
    final c = count < 0 ? 0 : count;
    if (c >= milestones.last) {
      return HomePostMilestoneSnapshot(
        postCount: c,
        nextMilestone: null,
        isHighProgress: true,
        hintMessage: '今日はかなり進んでいます。無理なく続けましょう',
        useCalendarDayLabel: useCalendarDayLabel,
      );
    }
    if (c >= 10) {
      return HomePostMilestoneSnapshot(
        postCount: c,
        nextMilestone: 20,
        isHighProgress: false,
        hintMessage: '20件まであと${20 - c}件です',
        useCalendarDayLabel: useCalendarDayLabel,
      );
    }
    if (c >= 5) {
      return HomePostMilestoneSnapshot(
        postCount: c,
        nextMilestone: 10,
        isHighProgress: false,
        hintMessage: '10件まであと${10 - c}件です',
        useCalendarDayLabel: useCalendarDayLabel,
      );
    }
    if (c >= 1) {
      return HomePostMilestoneSnapshot(
        postCount: c,
        nextMilestone: 5,
        isHighProgress: false,
        hintMessage: '5件まであと${5 - c}件です',
        useCalendarDayLabel: useCalendarDayLabel,
      );
    }
    return HomePostMilestoneSnapshot(
      postCount: c,
      nextMilestone: 1,
      isHighProgress: false,
      hintMessage: 'まずは1件投稿してみましょう',
      useCalendarDayLabel: useCalendarDayLabel,
    );
  }
}
