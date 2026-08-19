import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
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
              GlowCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: acid.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Text(
                        '🏆',
                        style: TextStyle(fontSize: 29),
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
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Keep solving. More trophies are waiting.',
                            style: TextStyle(
                              color: muted,
                              fontSize: 12,
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

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;

  const _AchievementCard({
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlowCard(
        padding: EdgeInsets.zero,
        child: Opacity(
          opacity: unlocked ? 1 : .48,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unlocked ? acid.withValues(alpha: .12) : line,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: unlocked ? acid.withValues(alpha: .28) : line,
                    ),
                  ),
                  child: Text(
                    achievement.icon,
                    style: TextStyle(
                      fontSize: 27,
                      color: unlocked ? null : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
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
                          Icon(
                            unlocked ? Icons.check_circle : Icons.lock_outline,
                            size: 18,
                            color: unlocked ? acid : muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        achievement.description,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      if (unlocked && achievement.unlockedAt != null) ...[
                        const SizedBox(height: 7),
                        Text(
                          'Unlocked ${_formatDate(achievement.unlockedAt!)}',
                          style: const TextStyle(
                            color: acid,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
