import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/problem.dart';

class SupabaseService {
  static bool get isConfigured {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Session? get currentSession {
    try {
      return Supabase.instance.client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // GOOGLE SIGN IN
  // ---------------------------------------------------------------------------

  Future<void> signInWithGoogle() async {
    await client.auth.signInWithOAuth(
      OAuthProvider.google,

      // Web:
      // Let Supabase return to the current web application.
      //
      // Android / iOS:
      // Return through the app deep link.
      redirectTo: kIsWeb ? Uri.base.origin : 'io.minsprep://login-callback/',
    );
  }

  // ---------------------------------------------------------------------------
  // SIGN OUT
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // PROBLEM UUID
  // ---------------------------------------------------------------------------

  /// Finds the actual UUID of a problem in Supabase
  /// using the stable slug bundled with the Flutter app.
  Future<String> getProblemUuid(String slug) async {
    final result =
        await client.from('problems').select('id').eq('slug', slug).single();

    return result['id'] as String;
  }

  // ---------------------------------------------------------------------------
  // PROGRESS
  // ---------------------------------------------------------------------------

  Future<void> upsertProgress(
    String userId,
    Problem problem,
    ProblemProgress progress,
  ) async {
    final problemUuid = await getProblemUuid(problem.slug);

    await client.from('user_problem_progress').upsert(
      {
        'user_id': userId,
        'problem_id': problemUuid,
        'completed': progress.completed,
        'completed_at': progress.completedAt?.toIso8601String(),
        'notes': progress.notes,
        'review_flagged': progress.reviewDueAt != null,
        'review_due_at': progress.reviewDueAt?.toIso8601String(),
        'last_reviewed_at': progress.lastReviewedAt?.toIso8601String(),
      },
      onConflict: 'user_id,problem_id',
    );
  }

  Future<List<Map<String, dynamic>>> fetchProgress(
    String userId,
  ) async {
    final result = await client.from('user_problem_progress').select(
      '''
          problem_id,
          completed,
          completed_at,
          notes,
          review_flagged,
          review_due_at,
          last_reviewed_at,
          problems!inner(slug)
          ''',
    ).eq('user_id', userId);

    return List<Map<String, dynamic>>.from(result);
  }

  // ---------------------------------------------------------------------------
  // DAILY GOAL
  // ---------------------------------------------------------------------------

  Future<int?> fetchDailyGoal(String userId) async {
    final result = await client
        .from('user_preferences')
        .select('daily_goal')
        .eq('user_id', userId)
        .maybeSingle();

    if (result == null) {
      return null;
    }

    return result['daily_goal'] as int;
  }

  Future<void> saveDailyGoal(
    String userId,
    int dailyGoal,
  ) async {
    await client.from('user_preferences').upsert(
      {
        'user_id': userId,
        'daily_goal': dailyGoal,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  // ---------------------------------------------------------------------------
  // ACHIEVEMENTS
  // ---------------------------------------------------------------------------

  /// Fetches ALL achievement definitions and attaches
  /// the current user's unlock time when available.
  Future<List<Map<String, dynamic>>> fetchAchievements(
    String userId,
  ) async {
    final achievements = await client.from('achievements').select(
      '''
          id,
          name,
          description,
          icon
          ''',
    ).order('created_at');

    final unlocked = await client.from('user_achievements').select(
      '''
          achievement_id,
          unlocked_at
          ''',
    ).eq('user_id', userId);

    final unlockedMap = <String, dynamic>{};

    for (final row in unlocked) {
      unlockedMap[row['achievement_id'] as String] = row['unlocked_at'];
    }

    return List<Map<String, dynamic>>.from(
      achievements.map((achievement) {
        final id = achievement['id'] as String;

        return {
          'achievements': achievement,
          'unlocked_at': unlockedMap[id],
        };
      }),
    );
  }

  Future<void> unlockAchievement(
    String userId,
    String achievementId,
  ) async {
    await client.from('user_achievements').upsert(
      {
        'user_id': userId,
        'achievement_id': achievementId,
        'unlocked_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,achievement_id',
    );
  }

  Future<void> unlockAchievements(
    String userId,
    List<String> achievementIds,
  ) async {
    if (achievementIds.isEmpty) {
      return;
    }

    final now = DateTime.now().toIso8601String();

    await client.from('user_achievements').upsert(
          achievementIds
              .map(
                (id) => {
                  'user_id': userId,
                  'achievement_id': id,
                  'unlocked_at': now,
                },
              )
              .toList(),
          onConflict: 'user_id,achievement_id',
        );
  }
}
