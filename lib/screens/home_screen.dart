import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/problem.dart';
import '../providers/app_controller.dart';
import '../widgets/app_theme.dart';
import '../widgets/ui.dart';
import 'problem_detail_screen.dart';
import 'problems_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appControllerProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Something went wrong: $e',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (s) => SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(appControllerProvider.notifier).syncFromCloud(),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // -----------------------------------------------------------------
              // HEADER
              // -----------------------------------------------------------------

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  8,
                ),
                sliver: SliverToBoxAdapter(
                  child: _Header(state: s),
                ),
              ),

              // -----------------------------------------------------------------
              // PROGRESS
              // -----------------------------------------------------------------

              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                sliver: SliverToBoxAdapter(
                  child: _ProgressHero(state: s),
                ),
              ),

              // -----------------------------------------------------------------
              // QUICK STATS
              // -----------------------------------------------------------------

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _QuickStats(state: s),
                ),
              ),

              // -----------------------------------------------------------------
              // CONTINUE SOLVING
              // -----------------------------------------------------------------

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  8,
                ),
                sliver: SliverToBoxAdapter(
                  child: const SectionTitle(
                    title: 'Continue solving',
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                sliver: SliverToBoxAdapter(
                  child: s.nextProblem == null
                      ? GlowCard(
                          child: Text(
                            "You cleared the board. That's a serious grind. 🫡",
                            style: humanTextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : GlowCard(
                          onTap: () {
                            FocusScope.of(context).unfocus();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProblemDetailScreen(
                                  problem: s.nextProblem!,
                                ),
                              ),
                            );
                          },
                          child: _NextProblemContent(
                            problem: s.nextProblem!,
                          ),
                        ),
                ),
              ),

              // -----------------------------------------------------------------
              // DUE REVIEWS
              // -----------------------------------------------------------------

              if (s.dueReviews.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    24,
                    20,
                    8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: const SectionTitle(
                      title: 'Due for review',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: GlowCard(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProblemsScreen(
                              initialReviewOnly: true,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const _CoreIcon(
                            asset: 'assets/icons/core/review.svg',
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${s.dueReviews.length} '
                              '${s.dueReviews.length == 1 ? 'problem is' : 'problems are'} '
                              'ready for a second pass.',
                              style: humanTextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const _CoreIcon(
                            asset: 'assets/icons/core/arrow_forward.svg',
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // -----------------------------------------------------------------
              // FOOTER
              // -----------------------------------------------------------------

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  28,
                  20,
                  30,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Core loop: solve → complete → reward → one more.',
                    style: humanTextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SVG CORE ICON
// =============================================================================

class _CoreIcon extends StatelessWidget {
  final String asset;
  final double size;

  const _CoreIcon({
    required this.asset,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

// =============================================================================
// HEADER
// =============================================================================

class _Header extends StatelessWidget {
  final AppState state;

  const _Header({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 370;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _BrandLabel(),
                  ),
                  const SizedBox(width: 12),
                  _StreakBadge(
                    streak: state.currentStreak,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Ready to grind?',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: humanTextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BrandLabel(),
                  SizedBox(height: 18),
                  _ReadyToGrindText(),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _StreakBadge(
              streak: state.currentStreak,
            ),
          ],
        );
      },
    );
  }
}

class _ReadyToGrindText extends StatelessWidget {
  const _ReadyToGrindText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ready to grind?',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: humanTextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _BrandLabel extends StatelessWidget {
  const _BrandLabel();

  @override
  Widget build(BuildContext context) {
    return const Text(
      "MIN'S PREP",
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: acid,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.2,
      ),
    );
  }
}

// =============================================================================
// STREAK BADGE
// =============================================================================

class _StreakBadge extends StatelessWidget {
  final int streak;

  const _StreakBadge({
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 76,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CoreIcon(
            asset: 'assets/icons/core/streak.svg',
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            '$streak',
            style: technicalTextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PROGRESS HERO
// =============================================================================

class _ProgressHero extends StatelessWidget {
  final AppState state;

  const _ProgressHero({
    required this.state,
  });

  double _levelProgress() {
    final currentLevel = state.level;

    final currentThreshold = ((currentLevel - 1) * (currentLevel - 1) * 50);

    final nextThreshold = (currentLevel * currentLevel * 50);

    if (nextThreshold <= currentThreshold) {
      return 0;
    }

    final progress =
        (state.xp - currentThreshold) / (nextThreshold - currentThreshold);

    return progress.clamp(0.0, 1.0);
  }

  int _xpForNextLevel() {
    final nextLevel = state.level + 1;

    return (nextLevel - 1) * (nextLevel - 1) * 50;
  }

  @override
  Widget build(BuildContext context) {
    final pct = state.completionRate;
    final levelProgress = _levelProgress();
    final nextLevelXp = _xpForNextLevel();

    return GlowCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          final veryCompact = width < 300;
          final compact = width < 350;

          final circleSize = veryCompact
              ? 92.0
              : compact
                  ? 104.0
                  : 118.0;

          final progressCircle = _ProgressCircle(
            percentage: pct,
            size: circleSize,
          );

          final progressInfo = _ProgressInfo(
            state: state,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                Center(
                  child: progressCircle,
                ),
                const SizedBox(height: 18),
                progressInfo,
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    progressCircle,
                    const SizedBox(width: 20),
                    Expanded(
                      child: progressInfo,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'LEVEL ${state.level}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: technicalTextStyle(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      '${nextLevelXp - state.xp} XP '
                      'TO LVL ${state.level + 1}',
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: technicalTextStyle(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: levelProgress,
                  minHeight: 7,
                  backgroundColor: line,
                  color: acid,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// PROGRESS CIRCLE
// =============================================================================

class _ProgressCircle extends StatelessWidget {
  final double percentage;
  final double size;

  const _ProgressCircle({
    required this.percentage,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: percentage,
              strokeWidth: 9,
              backgroundColor: line,
              color: acid,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${(percentage * 100).round()}%',
                  style: technicalTextStyle(
                    fontSize: size < 110 ? 23 : 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'COMPLETE',
                style: technicalTextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PROGRESS INFO
// =============================================================================

class _ProgressInfo extends StatelessWidget {
  final AppState state;

  const _ProgressInfo({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '${state.completed} / ${state.problems.length}',
            style: technicalTextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'problems cleared',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: humanTextStyle(
            color: muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(
              'LVL ${state.level}',
              style: technicalTextStyle(
                color: acid,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${state.xp} XP',
              style: technicalTextStyle(
                color: muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// NEXT PROBLEM
// =============================================================================

class _NextProblemContent extends StatelessWidget {
  final Problem problem;

  const _NextProblemContent({
    required this.problem,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: acid.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            '${problem.order}'.padLeft(2, '0'),
            style: technicalTextStyle(
              color: acid,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                problem.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 190,
                    ),
                    child: Text(
                      problem.topic,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: humanTextStyle(
                        color: muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DifficultyPill(
                    difficulty: problem.difficulty,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const _CoreIcon(
          asset: 'assets/icons/core/arrow_forward.svg',
          size: 26,
        ),
      ],
    );
  }
}

// =============================================================================
// QUICK STATS
// =============================================================================

class _QuickStats extends StatelessWidget {
  final AppState state;

  const _QuickStats({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Stat(
            icon: 'assets/icons/core/streak.svg',
            value: '${state.currentStreak}',
            label: 'streak',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            icon: 'assets/icons/core/target.svg',
            value: '${state.todayCompleted}/${state.dailyGoal}',
            label: 'today',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            icon: 'assets/icons/core/xp.svg',
            value: '${state.remaining}',
            label: 'left',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: SvgPicture.asset(
              icon,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: technicalTextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: humanTextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
