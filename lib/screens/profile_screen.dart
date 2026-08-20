import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_controller.dart';
import '../services/supabase_service.dart';
import '../widgets/ui.dart';
import '../widgets/app_theme.dart';
import 'package:flutter/foundation.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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
              // =============================================================
              // GOOGLE ACCOUNT
              // =============================================================

              GlowCard(
                child: Row(
                  children: [
                    _ProfileAvatar(
                      avatarUrl: avatarUrl,
                    ),
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
                            style: humanTextStyle(
                              color: muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'LV ${s.level}',
                      style: technicalTextStyle(
                        color: acid,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =============================================================
              // DAILY GOAL
              // =============================================================

              const SectionTitle(
                title: 'Daily goal',
              ),

              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [1, 2, 3, 5]
                    .map(
                      (n) => ChoiceChip(
                        label: Text(
                          '$n / day',
                          style: technicalTextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        selected: s.dailyGoal == n,
                        onSelected: (_) {
                          ref
                              .read(
                                appControllerProvider.notifier,
                              )
                              .setDailyGoal(n);
                        },
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 24),

              // =============================================================
              // ACCOUNT & DATA
              // =============================================================

              const SectionTitle(
                title: 'Account & data',
              ),

              const SizedBox(height: 8),

              GlowCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // ---------------------------------------------------------
                    // CLOUD SYNC
                    // ---------------------------------------------------------

                    ListTile(
                      leading: SvgPicture.asset(
                        'assets/icons/core/cloud.svg',
                        width: 25,
                        height: 25,
                      ),
                      title: const Text(
                        'Cloud sync',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        s.syncing
                            ? 'Syncing...'
                            : 'Local cache + Supabase when signed in',
                        style: humanTextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
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

                    const Divider(
                      height: 1,
                    ),

                    // ---------------------------------------------------------
                    // EXPORT
                    // ---------------------------------------------------------

                    ListTile(
                      leading: SvgPicture.asset(
                        'assets/icons/core/export.svg',
                        width: 25,
                        height: 25,
                      ),
                      title: const Text(
                        'Export progress',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'JSON or CSV backup of your progress',
                        style: humanTextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () => _export(
                        context,
                        s,
                      ),
                    ),

                    // ---------------------------------------------------------
                    // LOG OUT
                    // ---------------------------------------------------------

                    if (SupabaseService.isConfigured) ...[
                      const Divider(
                        height: 1,
                      ),
                      ListTile(
                        leading: SvgPicture.asset(
                          'assets/icons/core/logout.svg',
                          width: 25,
                          height: 25,
                        ),
                        title: const Text(
                          'Log out',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () => SupabaseService().signOut(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // =============================================================
              // FOOTER
              // =============================================================

              const Text(
                'NEO 150 PREP',
                style: TextStyle(
                  color: acid,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Built for the daily interview grind.',
                style: humanTextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // EXPORT FORMAT PICKER
  // ===========================================================================

  Future<void> _export(
    BuildContext context,
    AppState s,
  ) async {
    final format = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surface,
          title: const Text(
            'Export progress',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Choose a format for your progress export.',
            style: humanTextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  'csv',
                );
              },
              child: const Text(
                'CSV',
                style: TextStyle(
                  color: acid,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  'json',
                );
              },
              child: const Text(
                'JSON',
              ),
            ),
          ],
        );
      },
    );

    if (format == null || !context.mounted) {
      return;
    }

    // =======================================================================
    // COMMON DATA
    // =======================================================================

    final payload = {
      'app': "Neo 150 Prep",
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

    // =======================================================================
    // CHOOSE FORMAT
    // =======================================================================

    late final String content;
    late final String fileName;
    late final String mimeType;

    if (format == 'json') {
      content = const JsonEncoder.withIndent(
        '  ',
      ).convert(payload);

      fileName = 'neo_150_prep_progress.json';
      mimeType = 'application/json';
    } else {
      content = _buildCsv(payload);

      fileName = 'neo_150_prep_progress.csv';
      mimeType = 'text/csv';
    }

    // =======================================================================
    // SHARE FILE
    // =======================================================================

    try {
      final box = context.findRenderObject() as RenderBox?;

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(content),
              mimeType: mimeType,
            ),
          ],
          fileNameOverrides: [
            fileName,
          ],
          title: 'Neo 150 Prep Progress',
          text: format == 'json'
              ? 'My Neo 150 Prep progress - JSON backup'
              : 'My Neo 150 Prep progress - CSV export',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(
                    Offset.zero,
                  ) &
                  box.size,
        ),
      );

      if (!context.mounted) {
        return;
      }

      if (!kIsWeb && result.status == ShareResultStatus.unavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Export sharing is unavailable on this device.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Export failed: $e',
          ),
        ),
      );
    }
  }

  // ===========================================================================
  // CSV GENERATOR
  // ===========================================================================

  String _buildCsv(
    Map<String, dynamic> payload,
  ) {
    final problems = payload['problems'] as List<dynamic>;

    final buffer = StringBuffer();

    buffer.writeln(
      'id,title,topic,difficulty,completed,completed_at,notes,review_due_at',
    );

    for (final problem in problems) {
      final p = problem as Map<String, dynamic>;

      buffer.writeln(
        [
          _csvValue(p['id']),
          _csvValue(p['title']),
          _csvValue(p['topic']),
          _csvValue(p['difficulty']),
          _csvValue(p['completed']),
          _csvValue(p['completed_at']),
          _csvValue(p['notes']),
          _csvValue(p['review_due_at']),
        ].join(','),
      );
    }

    return buffer.toString();
  }

  // ===========================================================================
  // CSV ESCAPING
  // ===========================================================================

  String _csvValue(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    final text = value.toString();

    if (text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }

    return text;
  }
}

// =============================================================================
// GOOGLE PROFILE AVATAR
// =============================================================================

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
        color: acid.withValues(
          alpha: 0.13,
        ),
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
