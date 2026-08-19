import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            Row(
              children: [
                Expanded(
                  child: GlowCard(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CLEARED',
                          style: TextStyle(
                            color: muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${s.completed}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          '/ 150',
                          style: TextStyle(
                            color: muted,
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
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'XP',
                          style: TextStyle(
                            color: muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${s.xp}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Level ${s.level}',
                          style: const TextStyle(
                            color: acid,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const SectionTitle(
              title: 'Streak',
            ),

            const SizedBox(height: 10),

            _StreakCard(state: s),

            const SizedBox(height: 24),

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

            const SectionTitle(
              title: 'Topics',
            ),

            const SizedBox(height: 10),

            ...s.problems
                .map((p) => p.topic)
                .toSet()
                .map((topic) {
              final all = s.problems
                  .where((p) => p.topic == topic)
                  .toList();

              final done = all
                  .where(
                    (p) =>
                        s.progress[p.id]?.completed ??
                        false,
                  )
                  .length;

              final double value =
                  all.isEmpty ? 0.0 : done / all.length;

              return Padding(
                padding:
                    const EdgeInsets.only(bottom: 13),
                child: Column(
                  children: [
                    Row(
                      children: [
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
                          '$done/${all.length}',
                          style: const TextStyle(
                            color: muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(99),
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
            }),

            const SizedBox(height: 18),

            const SectionTitle(
              title: 'Activity',
            ),

            const SizedBox(height: 10),

            _Heatmap(state: s),
          ],
        ),
      ),
    );
  }

  Widget _difficultyRow(
    AppState s,
    String d,
  ) {
    final all = s.problems
        .where((p) => p.difficulty == d)
        .length;

    final done = s.problems
        .where(
          (p) =>
              p.difficulty == d &&
              s.progress[p.id]?.completed == true,
        )
        .length;

    final double value =
        all == 0 ? 0.0 : done / all;

    return Padding(
      padding:
          const EdgeInsets.only(bottom: 14),
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
                borderRadius:
                    BorderRadius.circular(99),
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
              '$done/$all',
              style: const TextStyle(
                color: muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

    final progress = range == 0
        ? 0.0
        : ((streak - previous) / range)
            .clamp(0.0, 1.0);

    return GlowCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
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
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: acid.withValues(
                      alpha: 0.25,
                    ),
                  ),
                ),
                child: const Text(
                  '🔥',
                  style: TextStyle(
                    fontSize: 27,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$streak DAY STREAK',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Best: $best days',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              if (today >= goal)
                const Icon(
                  Icons.check_circle,
                  color: acid,
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
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NEXT MILESTONE',
                style: const TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                '$next DAYS',
                style: const TextStyle(
                  color: acid,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(99),
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
              const Icon(
                Icons.today_rounded,
                size: 15,
                color: muted,
              ),
              const SizedBox(width: 6),
              Text(
                'Today: $today / $goal',
                style: const TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (today < goal)
                Text(
                  '${goal - today} more to protect it',
                  style: const TextStyle(
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
            final day =
                start.add(Duration(days: i));

            final count =
                state.progress.values.where((p) {
              final d = p.completedAt;

              return d != null &&
                  d.year == day.year &&
                  d.month == day.month &&
                  d.day == day.day;
            }).length;

            return Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: count == 0
                    ? line
                    : acid.withValues(
                        alpha:
                            count >= 3 ? .95 : .35,
                      ),
                borderRadius:
                    BorderRadius.circular(3),
              ),
            );
          },
        ),
      ),
    );
  }
}