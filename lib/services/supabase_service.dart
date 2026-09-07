import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/problem.dart';
import 'notification_service.dart';

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
    await NotificationService.instance.deactivateCurrentEndpoint();
    await client.auth.signOut();
  }

  Future<Map<String, dynamic>> fetchNotificationSettings() async {
    final userId = currentSession?.user.id;
    if (userId == null) return const <String, dynamic>{};

    final row = await client
        .from('notification_settings')
        .select(
          'notifications_enabled,daily_prep_reminder_enabled,'
          'daily_goal_reminder_enabled,achievement_notifications_enabled,'
          'streak_reminder_enabled',
        )
        .eq('user_id', userId)
        .maybeSingle();

    return row ?? const <String, dynamic>{};
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final userId = currentSession?.user.id;
    if (userId == null) return;

    await client.from('notification_settings').upsert(
      {
        'user_id': userId,
        'notifications_enabled': enabled,
      },
      onConflict: 'user_id',
    );
  }

  Future<void> updateDailyPrepReminderEnabled(bool enabled) async {
    final userId = currentSession?.user.id;
    if (userId == null) return;

    await client.from('notification_settings').upsert(
      {
        'user_id': userId,
        'daily_prep_reminder_enabled': enabled,
      },
      onConflict: 'user_id',
    );
  }

  Future<void> updateDailyGoalReminderEnabled(bool enabled) async {
    final userId = currentSession?.user.id;
    if (userId == null) return;

    await client.from('notification_settings').upsert(
      {
        'user_id': userId,
        'daily_goal_reminder_enabled': enabled,
      },
      onConflict: 'user_id',
    );
  }

  Future<void> updateAchievementNotificationsEnabled(bool enabled) async {
    final userId = currentSession?.user.id;
    if (userId == null) return;

    await client.from('notification_settings').upsert(
      {
        'user_id': userId,
        'achievement_notifications_enabled': enabled,
      },
      onConflict: 'user_id',
    );
  }

  Future<void> updateStreakReminderEnabled(bool enabled) async {
    final userId = currentSession?.user.id;
    if (userId == null) return;

    await client.from('notification_settings').upsert(
      {
        'user_id': userId,
        'streak_reminder_enabled': enabled,
      },
      onConflict: 'user_id',
    );
  }

  Future<void> upsertFcmEndpoint(String token) async {
    final userId = currentSession?.user.id;
    if (userId == null) return;

    final existing = await client
        .from('notification_endpoints')
        .select('id')
        .eq('user_id', userId)
        .eq('provider', 'fcm')
        .eq('device_token', token)
        .maybeSingle();

    final values = {
      'user_id': userId,
      'provider': 'fcm',
      'platform': 'android',
      'device_token': token,
      'active': true,
      'last_seen_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (existing == null) {
      await client.from('notification_endpoints').insert(values);
    } else {
      await client
          .from('notification_endpoints')
          .update(values)
          .eq('id', existing['id']);
    }
  }

  Future<void> deactivateFcmEndpoint(String token) async {
    final userId = currentSession?.user.id;
    if (userId == null) return;

    await client
        .from('notification_endpoints')
        .update({
          'active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('provider', 'fcm')
        .eq('device_token', token);
  }

  Future<void> upsertWebPushEndpoint({
    required String endpoint,
    required String p256dh,
    required String auth,
    required Map<String, dynamic> metadata,
  }) async {
    final userId = currentSession?.user.id;
    if (userId == null) return;

    final values = {
      'user_id': userId,
      'provider': 'web_push',
      'platform': 'web',
      'endpoint': endpoint,
      'p256dh': p256dh,
      'auth': auth,
      'subscription_metadata': metadata,
      'active': true,
      'last_seen_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final existing = await client
        .from('notification_endpoints')
        .select('id')
        .eq('user_id', userId)
        .eq('provider', 'web_push')
        .eq('endpoint', endpoint)
        .maybeSingle();

    if (existing == null) {
      await client.from('notification_endpoints').insert(values);
    } else {
      await client
          .from('notification_endpoints')
          .update(values)
          .eq('id', existing['id']);
    }
  }

  Future<void> deactivateWebPushEndpoint(String endpoint) async {
    final userId = currentSession?.user.id;
    if (userId == null) return;

    await client
        .from('notification_endpoints')
        .update({
          'active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('provider', 'web_push')
        .eq('endpoint', endpoint);
  }

  Future<void> deactivateOtherWebPushEndpoints(String endpoint) async {
    final userId = currentSession?.user.id;
    if (userId == null) return;

    await client
        .from('notification_endpoints')
        .update({
          'active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('provider', 'web_push')
        .eq('active', true)
        .neq('endpoint', endpoint);
  }

  // ---------------------------------------------------------------------------
  // PROBLEM UUID
  // ---------------------------------------------------------------------------

  /// Finds the actual UUID of a problem in Supabase
  /// using the stable slug bundled with the Flutter app.
  Future<String> getProblemUuid(String slug) async {
    final result = await client
        .from('problems')
        .select('id')
        .eq('slug', slug)
        .maybeSingle();

    if (result == null) {
      throw Exception('Problem not found: $slug');
    }

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
  // INTERVIEW ATTEMPTS
  // ---------------------------------------------------------------------------

  /// Saves one answered interview question.
  ///
  /// `user_interview_attempts` is the canonical table for interview history.
  /// Q1 is stored with session_completed=false and Q2 with true.
  Future<void> saveInterviewAttempt({
    required String userId,
    required Problem problem,
    required int questionNumber,
    required String question,
    required String answer,
    required String feedback,
    required int? score,
    required bool sessionCompleted,
  }) async {
    final problemUuid = await getProblemUuid(problem.slug);

    await client.from('user_interview_attempts').insert({
      'user_id': userId,
      'problem_id': problemUuid,
      'question_number': questionNumber,
      'question': question,
      'answer': answer,
      'feedback': feedback,
      'score': score,
      'session_completed': sessionCompleted,
    });
  }

  /// Fetches the raw interview-attempt rows for the current user.
  ///
  /// The existing `user_interview_attempts` table is the canonical source for
  /// Interview History, so history does not introduce a second persistence
  /// path or table. Rows are returned newest-first.
  Future<List<Map<String, dynamic>>> fetchInterviewHistory(
    String userId,
  ) async {
    final result = await client
        .from('user_interview_attempts')
        .select(
          '''
          id,
          problem_id,
          question_number,
          question,
          answer,
          feedback,
          score,
          session_completed,
          created_at,
          problems!inner(title,topic,difficulty,order_index,slug)
          ''',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(result);
  }

  /// Returns problem UUIDs for which this user has completed at least one
  /// two-question interview session.
  Future<Set<String>> fetchCompletedInterviewProblemIds(
    String userId,
  ) async {
    final rows = await client
        .from('user_interview_attempts')
        .select('problem_id')
        .eq('user_id', userId)
        .eq('session_completed', true);

    return rows.map<String>((row) => row['problem_id'] as String).toSet();
  }

  /// Counts the number of completed interview sessions for this user.
  /// A completed session is represented by the Q2 row in the existing
  /// `user_interview_attempts` table (`session_completed = true`).
  Future<int> fetchCompletedInterviewSessionCount(
    String userId,
  ) async {
    final rows = await client
        .from('user_interview_attempts')
        .select('id')
        .eq('user_id', userId)
        .eq('session_completed', true);

    return rows.length;
  }

  /// Checks whether the supplied problem has already had a completed
  /// interview session for this user.
  Future<bool> hasCompletedInterview(
    String userId,
    Problem problem,
  ) async {
    final problemUuid = await getProblemUuid(problem.slug);

    final row = await client
        .from('user_interview_attempts')
        .select('id')
        .eq('user_id', userId)
        .eq('problem_id', problemUuid)
        .eq('session_completed', true)
        .limit(1);

    return row.isNotEmpty;
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

  Future<int> fetchLongestStreak(String userId) async {
    final row = await client
        .from('user_stats')
        .select('longest_streak')
        .eq('user_id', userId)
        .maybeSingle();

    return (row?['longest_streak'] as int?) ?? 0;
  }

  Future<void> saveLongestStreak(String userId, int longestStreak) async {
    await client.from('user_stats').upsert(
      {
        'user_id': userId,
        'longest_streak': longestStreak,
      },
      onConflict: 'user_id',
    );
  }

  // ---------------------------------------------------------------------------
  // DAILY FOCUS AREAS
  // ---------------------------------------------------------------------------

  /// Loads the fixed focus topics selected for the current day for this user.
  /// The topics are stored separately from problem progress; their percentages
  /// are always derived from the user's account-specific progress.
  Future<Map<String, dynamic>?> fetchDailyFocus(String userId) async {
    final result = await client
        .from('user_preferences')
        .select('daily_focus_date,daily_focus_topics')
        .eq('user_id', userId)
        .maybeSingle();

    if (result == null) {
      return null;
    }

    final rawTopics = result['daily_focus_topics'];
    final topics = rawTopics is List
        ? rawTopics.map((topic) => topic.toString()).toList()
        : <String>[];

    return {
      'date': result['daily_focus_date']?.toString(),
      'topics': topics,
    };
  }

  /// Persists the fixed focus topics for a specific user/day.
  Future<void> saveDailyFocus(
    String userId,
    String date,
    List<String> topics,
  ) async {
    await client.from('user_preferences').upsert(
      {
        'user_id': userId,
        'daily_focus_date': date,
        'daily_focus_topics': topics,
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
    );

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

  Future<Map<String, dynamic>?> fetchRecentInterviewStats(
    String userId, {
    int limit = 10,
  }) async {
    final rows = await client
        .from('user_interview_attempts')
        .select('score,created_at')
        .eq('user_id', userId)
        .not('score', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);

    if (rows.isEmpty) {
      return null;
    }

    final scores = rows
        .map((row) => (row['score'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    if (scores.isEmpty) {
      return null;
    }

    final recentScores = scores.take(3).toList();
    final olderScores = scores.skip(3).take(3).toList();
    final average = scores.reduce((a, b) => a + b) / scores.length;
    final recentAverage =
        recentScores.reduce((a, b) => a + b) / recentScores.length;
    final olderAverage = olderScores.isEmpty
        ? recentAverage
        : olderScores.reduce((a, b) => a + b) / olderScores.length;

    String trend;
    if (recentAverage > olderAverage + 0.5) {
      trend = 'improving';
    } else if (recentAverage < olderAverage - 0.5) {
      trend = 'declining';
    } else {
      trend = 'stable';
    }

    return {
      'session_count': rows.length,
      'average_score': double.parse((average).toStringAsFixed(1)),
      'recent_score': double.parse((recentScores.first).toStringAsFixed(1)),
      'trend': trend,
    };
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
