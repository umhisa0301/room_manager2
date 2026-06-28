import 'package:flutter/material.dart';

import '../theme/home_screen_colors.dart';
import '../utils/home_post_milestone.dart';

/// ホーム「今日の目標」進捗ライン（マーカー・件数ラベル・挑戦中バッジ）。
class HomeGoalMilestoneProgress extends StatelessWidget {
  const HomeGoalMilestoneProgress({super.key, required this.postCount});

  final int postCount;

  static const _milestones = HomePostMilestoneSnapshot.milestones;
  static const _markerSize = 22.0;
  static const _barHeight = 3.0;
  static const _badgeReserveHeight = 22.0;

  static TextStyle _hintStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.labelSmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 12,
      height: 1.32,
      color: HomeScreenColors.footnoteMuted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = HomePostMilestoneSnapshot.overallProgress(postCount);
    final hintStyle = _hintStyle(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final inset = _markerSize / 2;
        final innerWidth = trackWidth - _markerSize;
        final barTop = (_markerSize - _barHeight) / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: inset,
              right: inset,
              top: barTop,
              child: Container(
                height: _barHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            if (progress > 0)
              Positioned(
                left: inset,
                top: barTop,
                width: innerWidth * progress,
                child: Container(
                  height: _barHeight,
                  decoration: BoxDecoration(
                    color: HomeScreenColors.homeAccentTeal,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final milestone in _milestones)
                  Expanded(
                    child: _HomeGoalMilestoneColumn(
                      milestone: milestone,
                      state: HomePostMilestoneSnapshot.milestoneState(
                        postCount,
                        milestone,
                      ),
                      hintStyle: hintStyle,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HomeGoalMilestoneColumn extends StatelessWidget {
  const _HomeGoalMilestoneColumn({
    required this.milestone,
    required this.state,
    required this.hintStyle,
  });

  final int milestone;
  final HomeGoalMilestoneState state;
  final TextStyle hintStyle;

  @override
  Widget build(BuildContext context) {
    final labelStyle = hintStyle.copyWith(
      fontSize: 12,
      fontWeight: state == HomeGoalMilestoneState.inProgress
          ? FontWeight.w700
          : FontWeight.w500,
      color: state == HomeGoalMilestoneState.inProgress
          ? HomeScreenColors.homeAccentTeal
          : HomeScreenColors.homeTextSecondary,
      height: 1.2,
    );

    return Column(
      key: Key('home_goal_milestone_column_$milestone'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _HomeGoalMarker(milestone: milestone, state: state),
        const SizedBox(height: 6),
        Text(
          '$milestone件',
          key: Key('home_goal_milestone_label_$milestone'),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
        if (state == HomeGoalMilestoneState.inProgress) ...[
          const SizedBox(height: 4),
          Container(
            key: Key('home_goal_in_progress_badge_$milestone'),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: HomeScreenColors.homeAccentTealLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: HomeScreenColors.homeAccentTealBorder.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
            child: Text(
              '挑戦中',
              style: hintStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: HomeScreenColors.homeAccentTeal,
                height: 1.1,
              ),
            ),
          ),
        ] else
          const SizedBox(height: HomeGoalMilestoneProgress._badgeReserveHeight),
      ],
    );
  }
}

class _HomeGoalMarker extends StatelessWidget {
  const _HomeGoalMarker({required this.milestone, required this.state});

  final int milestone;
  final HomeGoalMilestoneState state;

  @override
  Widget build(BuildContext context) {
    late final Color fill;
    late final Color border;
    late final Widget child;

    switch (state) {
      case HomeGoalMilestoneState.achieved:
        fill = HomeScreenColors.homeSuccess;
        border = HomeScreenColors.homeSuccess;
        child = const Icon(Icons.check_rounded, size: 12, color: Colors.white);
      case HomeGoalMilestoneState.inProgress:
        fill = Colors.white;
        border = HomeScreenColors.homeAccentTeal;
        child = Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: HomeScreenColors.homeAccentTeal,
            shape: BoxShape.circle,
          ),
        );
      case HomeGoalMilestoneState.pending:
        fill = const Color(0xFFF3F4F6);
        border = const Color(0xFFD1D5DB);
        child = Icon(
          Icons.add_rounded,
          size: 12,
          color: HomeScreenColors.homeMutedText.withValues(alpha: 0.7),
        );
    }

    return Container(
      key: Key('home_goal_marker_$milestone'),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
