import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_controller.dart';
import '../services/supabase_service.dart';
import '../widgets/ui.dart';
import '../widgets/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appControllerProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (s) {
        final user = SupabaseService.currentSession?.user;

        final name = user?.userMetadata?['full_name']?.toString() ??
            user?.userMetadata?['name']?.toString() ??
            'Your grind';

        final email = user?.email ?? 'Signed-in account';

        final avatarUrl = user?.userMetadata?['avatar_url']?.toString() ??
            user?.userMetadata?['picture']?.toString();

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Profile',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              // -----------------------------------------------------------------
              // GOOGLE ACCOUNT
              // -----------------------------------------------------------------
              GlowCard(
                child: Row(
                  children: [
                    _ProfileAvatar(avatarUrl: avatarUrl),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'LV ${s.level}',
                      style: const TextStyle(
                        color: acid,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const SectionTitle(title: 'Daily goal'),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                children: [1, 2, 3, 5]
                    .map(
                      (n) => ChoiceChip(
                        label: Text('$n / day'),
                        selected: s.dailyGoal == n,
                        onSelected: (_) => ref
                            .read(appControllerProvider.notifier)
                            .setDailyGoal(n),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 24),

              const SectionTitle(title: 'Account & data'),
              const SizedBox(height: 8),

              GlowCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.cloud_done_outlined,
                        color: acid,
                      ),
                      title: const Text('Cloud sync'),
                      subtitle: Text(
                        s.syncing
                            ? 'Syncing...'
                            : 'Local cache + Supabase when signed in',
                      ),
                      trailing: s.syncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined),
                      title: const Text('Export progress'),
                      subtitle: const Text(
                        'JSON dump of your notes and completion state',
                      ),
                      onTap: () => _export(context, s),
                    ),
                    if (SupabaseService.isConfigured) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Log out'),
                        onTap: () => SupabaseService().signOut(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                "MIN'S PREP",
                style: TextStyle(
                  color: acid,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Built for the daily interview grind.',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _export(BuildContext context, AppState s) async {
    final payload = {
      'exported_at': DateTime.now().toIso8601String(),
      'xp': s.xp,
      'level': s.level,
      'current_streak': s.currentStreak,
      'longest_streak': s.longestStreak,
      'daily_goal': s.dailyGoal,
      'problems': s.problems.map((p) {
        final r = s.progress[p.id];

        return {
          'id': p.id,
          'title': p.title,
          'topic': p.topic,
          'difficulty': p.difficulty,
          'completed': r?.completed ?? false,
          'completed_at': r?.completedAt?.toIso8601String(),
          'notes': r?.notes ?? '',
          'review_due_at': r?.reviewDueAt?.toIso8601String(),
        };
      }).toList(),
    };

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'mins_export_preview',
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: surface,
        title: const Text('Export ready'),
        content: const Text(
          'Your JSON export is prepared in the app cache. '
          'Wire this payload to share/save APIs for production distribution.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// GOOGLE PROFILE AVATAR
// -----------------------------------------------------------------------------

class _ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _ProfileAvatar({
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: acid.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? Image.network(
              avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.person,
                  color: acid,
                );
              },
            )
          : const Icon(
              Icons.person,
              color: acid,
            ),
    );
  }
}
