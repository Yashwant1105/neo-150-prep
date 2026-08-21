import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/app_controller.dart';
import '../widgets/ui.dart';
import '../widgets/app_theme.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appControllerProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (e, _) => Center(
        child: Text('$e'),
      ),
      data: (s) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Progress',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            30,
          ),
          children: [
            // ===============================================================
            // CLEARED + XP
            // ===============================================================

            Row(
              children: [
                Expanded(
                  child: GlowCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SvgPicture.asset(
                              'assets/icons/core/progress.svg',
                              width: 19,
                              height: 19,
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'CLEARED',
                              style: TextStyle(
                                color: muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${s.completed}',
                          style: technicalTextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '/ 150',
                          style: technicalTextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${(s.completionRate * 100).round()}% complete',
                          style: technicalTextStyle(
                            color: acid,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlowCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SvgPicture.asset(
                              'assets/icons/core/xp.svg',
                              width: 19,
                              height: 19,
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'XP',
                              style: TextStyle(
                                color: muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${s.xp}',
                          style: technicalTextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Level ${s.level}',
                          style: technicalTextStyle(
                            color: acid,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ===============================================================
            // STREAK
            // ===============================================================

            const SectionTitle(
              title: 'Streak',
            ),

            const SizedBox(height: 10),

            _StreakCard(
              state: s,
            ),

            const SizedBox(height: 24),

            // ===============================================================
            // DIFFICULTY
            // ===============================================================

            const SectionTitle(
              title: 'Difficulty',
            ),

            const SizedBox(height: 10),

            ...[
              'Easy',
              'Medium',
              'Hard',
            ].map(
              (d) => _difficultyRow(s, d),
            ),

            const SizedBox(height: 24),

            // ===============================================================
            // TOPICS
            // ===============================================================

            const SectionTitle(
              title: 'Topics',
            ),

            const SizedBox(height: 10),

            ...s.problems.map((p) => p.topic).toSet().map((topic) {
              final all = s.problems
                  .where(
                    (p) => p.topic == topic,
                  )
                  .toList();

              final done = all
                  .where(
                    (p) => s.progress[p.id]?.completed ?? false,
                  )
                  .length;

              final double value = all.isEmpty ? 0.0 : done / all.length;

              return _topicRow(
                topic: topic,
                done: done,
                total: all.length,
                value: value,
              );
            }),

            const SizedBox(height: 24),

            // ===============================================================
            // FOCUS AREAS
            // ===============================================================

            const SectionTitle(
              title: 'Focus areas',
            ),

            const SizedBox(height: 10),

            if (s.focusTopics.isEmpty)
              GlowCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/core/check.svg',
                      width: 22,
                      height: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'All topics are cleared. Keep reviewing to stay sharp.',
                        style: humanTextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...s.focusTopics.map(
                (topic) => _focusTopicRow(
                  state: s,
                  topic: topic,
                ),
              ),

            const SizedBox(height: 18),

            // ===============================================================
            // ACTIVITY
            // ===============================================================

            const SectionTitle(
              title: 'Activity',
            ),

            const SizedBox(height: 10),

            _WeeklyActivity(
              state: s,
            ),

            const SizedBox(height: 14),

            const Text(
              '70-DAY ACTIVITY',
              style: TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),

            const SizedBox(height: 8),

            _Heatmap(
              state: s,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // DIFFICULTY ROW
  // =========================================================================

  Widget _difficultyRow(
    AppState s,
    String d,
  ) {
    final all = s.problems
        .where(
          (p) => p.difficulty == d,
        )
        .length;

    final done = s.problems
        .where(
          (p) => p.difficulty == d && s.progress[p.id]?.completed == true,
        )
        .length;

    final double value = all == 0 ? 0.0 : done / all;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: GlowCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Text(
              d,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  backgroundColor: line,
                  color: acid,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(value * 100).round()}%',
              style: technicalTextStyle(
                color: acid,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$done/$all',
              style: technicalTextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _focusTopicRow({
    required AppState state,
    required String topic,
  }) {
    final all = state.problems.where((p) => p.topic == topic).toList();
    final done =
        all.where((p) => state.progress[p.id]?.completed ?? false).length;
    final remaining = all.length - done;
    final value = all.isEmpty ? 0.0 : done / all.length;
    final icon = _topicIcon(topic);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlowCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (icon != null)
              SvgPicture.asset(
                icon,
                width: 24,
                height: 24,
              ),
            if (icon != null) const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          topic,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${(value * 100).round()}%',
                        style: technicalTextStyle(
                          color: acid,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: line,
                      color: acid,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$remaining remaining',
                    style: humanTextStyle(
                      color: muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TOPIC ROW
  // =========================================================================

  Widget _topicRow({
    required String topic,
    required int done,
    required int total,
    required double value,
  }) {
    final icon = _topicIcon(topic);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 13,
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (icon != null) ...[
                SvgPicture.asset(
                  icon,
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  topic,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$done/$total',
                style: technicalTextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: line,
              color: acid,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TOPIC → SVG
  // =========================================================================

  String? _topicIcon(String topic) {
    switch (topic) {
      case 'Arrays & Hashing':
        return 'assets/icons/topics/array.svg';

      case 'Two Pointers':
        return 'assets/icons/topics/two_pointers.svg';

      case 'Sliding Window':
        return 'assets/icons/topics/sliding_window.svg';

      case 'Stack':
        return 'assets/icons/topics/stack.svg';

      case 'Binary Search':
        return 'assets/icons/topics/binary_search.svg';

      case 'Trees':
        return 'assets/icons/topics/tree.svg';

      case 'Heap / Priority Queue':
        return 'assets/icons/topics/heap.svg';

      case 'Backtracking':
        return 'assets/icons/topics/backtracking.svg';

      case 'Graphs':
        return 'assets/icons/topics/graph.svg';

      case 'Advanced Graphs':
        return 'assets/icons/topics/advanced_graph.svg';

      case '1-D Dynamic Programming':
        return 'assets/icons/topics/dp_1d.svg';

      case '2-D Dynamic Programming':
        return 'assets/icons/topics/dp_2d.svg';

      case 'Greedy':
        return 'assets/icons/topics/greedy.svg';

      // Dedicated topic SVGs.
      case 'Linked List':
        return 'assets/icons/topics/linked_list.svg';

      case 'Tries':
        return 'assets/icons/topics/tries.svg';

      case 'Intervals':
        return 'assets/icons/topics/intervals.svg';

      case 'Math & Geometry':
        return 'assets/icons/topics/math_geometry.svg';

      case 'Bit Manipulation':
        return 'assets/icons/topics/bit_manipulation.svg';

      default:
        return null;
    }
  }
}

// =============================================================================
// STREAK CARD
// =============================================================================

class _StreakCard extends StatelessWidget {
  final AppState state;

  const _StreakCard({
    required this.state,
  });

  int _nextMilestone(int streak) {
    const milestones = [
      3,
      7,
      14,
      30,
      50,
      100,
    ];

    for (final milestone in milestones) {
      if (streak < milestone) {
        return milestone;
      }
    }

    return 100;
  }

  String _message(
    int streak,
    int todayCompleted,
    int dailyGoal,
  ) {
    if (streak == 0) {
      return 'Start today. One problem is enough to begin the chain.';
    }

    if (todayCompleted >= dailyGoal) {
      return 'Daily goal cleared. The streak is safe.';
    }

    if (streak >= 30) {
      return '30+ days. This is a habit now.';
    }

    if (streak >= 14) {
      return 'Two weeks straight. Stay locked in.';
    }

    if (streak >= 7) {
      return 'A full week. Keep the chain alive.';
    }

    if (streak >= 3) {
      return 'Momentum is building. Don’t break the chain.';
    }

    return 'Nice start. Come back tomorrow.';
  }

  @override
  Widget build(BuildContext context) {
    final streak = state.currentStreak;
    final best = state.longestStreak;
    final today = state.todayCompleted;
    final goal = state.dailyGoal;

    final next = _nextMilestone(streak);

    final previous = next == 3
        ? 0
        : next == 7
            ? 3
            : next == 14
                ? 7
                : next == 30
                    ? 14
                    : next == 50
                        ? 30
                        : 50;

    final range = next - previous;

    final progress =
        range == 0 ? 0.0 : ((streak - previous) / range).clamp(0.0, 1.0);

    return GlowCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: acid.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: acid.withValues(
                      alpha: 0.25,
                    ),
                  ),
                ),
                child: SvgPicture.asset(
                  'assets/icons/core/streak.svg',
                  width: 30,
                  height: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$streak DAY STREAK',
                      style: technicalTextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Best: $best days',
                      style: technicalTextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (today >= goal)
                SvgPicture.asset(
                  'assets/icons/core/check.svg',
                  width: 22,
                  height: 22,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _message(
              streak,
              today,
              goal,
            ),
            style: humanTextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'NEXT MILESTONE',
                style: TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                '$next DAYS',
                style: technicalTextStyle(
                  color: acid,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: line,
              color: acid,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/core/progress.svg',
                width: 16,
                height: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Today: $today / $goal',
                style: technicalTextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (today < goal)
                Text(
                  '${goal - today} more to protect it',
                  style: humanTextStyle(
                    color: acid,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                const Text(
                  'STREAK SAFE',
                  style: TextStyle(
                    color: acid,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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
// WEEKLY ACTIVITY
// =============================================================================

class _WeeklyActivity extends StatelessWidget {
  final AppState state;

  const _WeeklyActivity({
    required this.state,
  });

  List<int> _counts() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final counts = List<int>.filled(7, 0);

    for (final progress in state.progress.values) {
      final completedAt = progress.completedAt;
      if (!progress.completed || completedAt == null) continue;

      final day = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );
      final index = day.difference(start).inDays;

      if (index >= 0 && index < 7) {
        counts[index]++;
      }
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts();
    final total = counts.fold<int>(0, (sum, value) => sum + value);
    final maxCount = counts.fold<int>(0, mathMax);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));

    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return GlowCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'THIS WEEK',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text(
                '$total problems',
                style: technicalTextStyle(
                  color: acid,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(7, (index) {
            final day = start.add(Duration(days: index));
            final count = counts[index];
            final ratio = maxCount == 0 ? 0.0 : count / maxCount;
            final isToday = day == today;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      labels[day.weekday - 1],
                      style: TextStyle(
                        color: isToday ? acid : muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 7,
                        backgroundColor: line,
                        color: acid,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 18,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.right,
                      style: technicalTextStyle(
                        color: count > 0 ? null : muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

int mathMax(int a, int b) => a > b ? a : b;

// =============================================================================
// ACTIVITY HEATMAP
// =============================================================================

class _Heatmap extends StatelessWidget {
  final AppState state;

  const _Heatmap({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(
      const Duration(days: 69),
    );

    return GlowCard(
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: List.generate(
          70,
          (i) {
            final day = start.add(Duration(days: i));

            final count = state.progress.values.where(
              (p) {
                final d = p.completedAt;

                return d != null &&
                    d.year == day.year &&
                    d.month == day.month &&
                    d.day == day.day;
              },
            ).length;

            return Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: count == 0
                    ? line
                    : acid.withValues(
                        alpha: count >= 3 ? .95 : .35,
                      ),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          },
        ),
      ),
    );
  }
}
