import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/achievement.dart';
import '../providers/app_controller.dart';
import '../widgets/app_theme.dart';
import '../widgets/ui.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

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
            'Unable to load achievements: $e',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (state) {
        final achievements = state.achievements;
        final unlocked = achievements.where((a) => a.unlocked).length;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Achievements',
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
              // -------------------------------------------------------------
              // GRIND BOARD HEADER
              // -------------------------------------------------------------

              GlowCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: acid.withValues(
                          alpha: .12,
                        ),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/core/achievements.svg',
                        width: 34,
                        height: 34,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'THE GRIND BOARD',
                            style: TextStyle(
                              color: acid,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$unlocked / ${achievements.length} unlocked',
                            style: technicalTextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Keep solving. More trophies are waiting.',
                            style: humanTextStyle(
                              color: muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const SectionTitle(
                title: 'Milestones',
              ),

              const SizedBox(height: 10),

              if (achievements.isEmpty)
                GlowCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events_outlined,
                        color: muted,
                        size: 34,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No achievements yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Start solving to unlock your first achievement.',
                        textAlign: TextAlign.center,
                        style: humanTextStyle(
                          color: muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...achievements.map(
                  (achievement) => _AchievementCard(
                    achievement: achievement,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// ACHIEVEMENT CARD
// =============================================================================

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;

  const _AchievementCard({
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final resolvedIconPath = _achievementIcon(achievement.name);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: GlowCard(
        padding: EdgeInsets.zero,
        child: Opacity(
          opacity: unlocked ? 1 : .48,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // -----------------------------------------------------------
                // ACHIEVEMENT ICON
                // -----------------------------------------------------------

                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? acid.withValues(
                            alpha: .12,
                          )
                        : line,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: unlocked
                          ? acid.withValues(
                              alpha: .28,
                            )
                          : line,
                    ),
                  ),
                  child: SvgPicture.asset(
                    resolvedIconPath,
                    width: 38,
                    height: 38,
                  ),
                ),

                const SizedBox(width: 15),

                // -----------------------------------------------------------
                // DETAILS
                // -----------------------------------------------------------

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              achievement.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),

                          // -------------------------------------------------
                          // STATUS ICON
                          // -------------------------------------------------

                          unlocked
                              ? SvgPicture.asset(
                                  'assets/icons/core/check.svg',
                                  width: 19,
                                  height: 19,
                                )
                              : const Icon(
                                  Icons.lock_outline,
                                  size: 18,
                                  color: muted,
                                ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        achievement.description,
                        style: humanTextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (unlocked && achievement.unlockedAt != null) ...[
                        const SizedBox(height: 7),
                        Text(
                          'UNLOCKED ${_formatDate(achievement.unlockedAt!)}',
                          style: technicalTextStyle(
                            color: acid,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // ACHIEVEMENT SVG MAPPING
  // =========================================================================

  String _achievementIcon(String achievementName) {
    const fallback = 'assets/icons/core/achievements.svg';
    final normalized = achievementName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    const mapped = {
      'first_blood': 'assets/icons/achievements/first_blood.svg',
      'getting_started': 'assets/icons/achievements/getting_started.svg',
      'momentum': 'assets/icons/achievements/momentum.svg',
      'brain_builder': 'assets/icons/achievements/brain_builder.svg',
      'halfway_there': 'assets/icons/achievements/halfway_there.svg',
      'century': 'assets/icons/achievements/century.svg',
      'deep_grind': 'assets/icons/achievements/deep_grind.svg',
      'tree_climber': 'assets/icons/achievements/tree_climber.svg',
      'graph_explorer': 'assets/icons/achievements/graph_explorer.svg',
      'dp_warrior': 'assets/icons/achievements/dp_warrior.svg',
      'neetcode_master': 'assets/icons/achievements/neetcode_master.svg',
      'streak_starter': 'assets/icons/achievements/streak_starter.svg',
      'on_fire': 'assets/icons/achievements/on_fire.svg',
      'daily_grinder': 'assets/icons/achievements/daily_grinder.svg',
      'topic_master': 'assets/icons/achievements/topic_master.svg',
      'productive_day': 'assets/icons/achievements/productive_day.svg',
      'interview_ready': 'assets/icons/achievements/interview_ready.svg',
    };

    return mapped[normalized] ?? fallback;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
