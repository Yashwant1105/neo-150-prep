import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_repository.dart';
import '../models/achievement.dart';
import '../models/problem.dart';
import '../services/supabase_service.dart';

final appControllerProvider =
    AsyncNotifierProvider<AppController, AppState>(AppController.new);

class AppState {
  final List<Problem> problems;
  final Map<String, ProblemProgress> progress;
  final int dailyGoal;
  final bool syncing;
  final List<Achievement> achievements;

  const AppState({
    required this.problems,
    required this.progress,
    required this.achievements,
    this.dailyGoal = 2,
    this.syncing = false,
  });

  int get completed => progress.values.where((p) => p.completed).length;

  int get remaining => problems.length - completed;

  double get completionRate =>
      problems.isEmpty ? 0 : completed / problems.length;

  int get xp => progress.entries.fold(0, (sum, e) {
        if (!e.value.completed) return sum;

        final p = problems.firstWhere(
          (p) => p.id == e.key,
        );

        return sum +
            (p.difficulty == 'Easy'
                ? 10
                : p.difficulty == 'Medium'
                    ? 20
                    : 30);
      });

  int get level => math.sqrt(xp / 50).floor() + 1;

  int get todayCompleted {
    final now = DateTime.now();

    return progress.values.where((p) {
      if (!p.completed || p.completedAt == null) {
        return false;
      }

      final completedAt = p.completedAt!.toLocal();

      return completedAt.year == now.year &&
          completedAt.month == now.month &&
          completedAt.day == now.day;
    }).length;
  }

  int get currentStreak {
    final days = <String>{};

    for (final p in progress.values) {
      final d = p.completedAt;

      if (p.completed && d != null) {
        days.add(_dayKey(d.toLocal()));
      }
    }

    var cursor = DateTime.now();

    if (!days.contains(_dayKey(cursor))) {
      cursor = cursor.subtract(
        const Duration(days: 1),
      );
    }

    var streak = 0;

    while (days.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(
        const Duration(days: 1),
      );
    }

    return streak;
  }

  int get longestStreak {
    final dates = progress.values
        .where(
          (p) => p.completed && p.completedAt != null,
        )
        .map((p) {
          final local = p.completedAt!.toLocal();

          return DateTime(
            local.year,
            local.month,
            local.day,
          );
        })
        .toSet()
        .toList()
      ..sort();

    if (dates.isEmpty) return 0;

    var best = 1;
    var run = 1;

    for (var i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays == 1) {
        run++;
        best = math.max(best, run);
      } else {
        run = 1;
      }
    }

    return best;
  }

  List<Problem> get dueReviews => problems.where((p) {
        final r = progress[p.id];

        return r?.reviewDueAt != null &&
            !r!.reviewDueAt!.isAfter(
              DateTime.now(),
            );
      }).toList();

  Problem? get nextProblem {
    final incomplete = problems
        .where(
          (p) => !(progress[p.id]?.completed ?? false),
        )
        .toList();

    if (incomplete.isEmpty) return null;

    final unfinishedTopics = <String>{
      ...incomplete.map((p) => p.topic),
    };

    for (final p in incomplete) {
      if (unfinishedTopics.contains(p.topic)) {
        return p;
      }
    }

    return incomplete.first;
  }

  int get unlockedAchievements => achievements.where((a) => a.unlocked).length;

  AppState copyWith({
    Map<String, ProblemProgress>? progress,
    int? dailyGoal,
    bool? syncing,
    List<Achievement>? achievements,
  }) {
    return AppState(
      problems: problems,
      progress: progress ?? this.progress,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      syncing: syncing ?? this.syncing,
      achievements: achievements ?? this.achievements,
    );
  }

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
}

class AppController extends AsyncNotifier<AppState> {
  final _local = LocalRepository();
  final _remote = SupabaseService();
  final _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _flushInProgress = false;

  @override
  Future<AppState> build() async {
    final problems = await _local.loadProblems();

    final userId = SupabaseService.currentSession?.user.id;

    _startConnectivityListener();

    final localProgress = await _local.loadProgress(userId);

    final prefs = await _local.loadPrefs(userId);

    var progress = localProgress;
    var dailyGoal = prefs['dailyGoal'] ?? 2;

    var achievements = <Achievement>[];

    if (userId != null) {
      try {
        final rows = await _remote.fetchProgress(userId);

        final cloudProgress = Map<String, ProblemProgress>.from(
          localProgress,
        );

        for (final row in rows) {
          final slug = row['problems']['slug'] as String;

          final problem = problems.firstWhere(
            (p) => p.slug == slug,
          );

          cloudProgress[problem.id] = ProblemProgress(
            completed: row['completed'] == true,
            completedAt: row['completed_at'] == null
                ? null
                : DateTime.tryParse(
                    row['completed_at'],
                  ),
            notes: row['notes'] ?? '',
            reviewDueAt: row['review_due_at'] == null
                ? null
                : DateTime.tryParse(
                    row['review_due_at'],
                  ),
            lastReviewedAt: row['last_reviewed_at'] == null
                ? null
                : DateTime.tryParse(
                    row['last_reviewed_at'],
                  ),
          );
        }

        progress = cloudProgress;

        await _local.saveProgress(
          userId,
          progress,
        );

        final cloudDailyGoal = await _remote.fetchDailyGoal(userId);

        if (cloudDailyGoal != null) {
          dailyGoal = cloudDailyGoal;

          await _local.savePrefs(
            userId,
            {
              'dailyGoal': dailyGoal,
            },
          );
        } else {
          await _remote.saveDailyGoal(
            userId,
            dailyGoal,
          );
        }

        achievements = await _loadAchievements(userId);
      } catch (e, stack) {
        debugPrint(
          'Initial cloud sync failed: $e',
        );
        debugPrintStack(
          stackTrace: stack,
        );
      }
    }

    return AppState(
      problems: problems,
      progress: progress,
      dailyGoal: dailyGoal,
      achievements: achievements,
    );
  }

  Future<List<Achievement>> _loadAchievements(
    String userId,
  ) async {
    try {
      final rows = await _remote.fetchAchievements(userId);

      return rows.map((row) {
        final data = row['achievements'] as Map<String, dynamic>;

        final unlockedAt = row['unlocked_at'] == null
            ? null
            : DateTime.tryParse(
                row['unlocked_at'] as String,
              );

        return Achievement.fromMap(
          data,
          unlockedAt: unlockedAt,
        );
      }).toList();
    } catch (e, stack) {
      debugPrint(
        'Achievement load failed: $e',
      );
      debugPrintStack(
        stackTrace: stack,
      );
      return [];
    }
  }

  void _startConnectivityListener() {
    _connectivitySubscription?.cancel();

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final online = results.any(
          (result) => result != ConnectivityResult.none,
        );

        if (online) {
          unawaited(_flushPendingSync());
        }
      },
    );

    ref.onDispose(() {
      _connectivitySubscription?.cancel();
    });
  }

  Future<void> setDailyGoal(int value) async {
    final current = state.value!;

    final userId = SupabaseService.currentSession?.user.id;

    await _local.savePrefs(
      userId,
      {
        'dailyGoal': value,
      },
    );

    state = AsyncData(
      current.copyWith(
        dailyGoal: value,
      ),
    );

    if (userId != null) {
      try {
        await _remote.saveDailyGoal(
          userId,
          value,
        );
      } catch (e, stack) {
        debugPrint(
          'Daily goal cloud sync failed: $e',
        );
        debugPrintStack(
          stackTrace: stack,
        );
      }
    }
  }

  Future<void> toggleComplete(
    Problem problem,
  ) async {
    final current = state.value!;

    final old = current.progress[problem.id] ?? const ProblemProgress();

    final completed = !old.completed;

    final updated = Map<String, ProblemProgress>.from(
      current.progress,
    );

    updated[problem.id] = old.copyWith(
      completed: completed,
      completedAt: completed ? DateTime.now() : null,
      clearCompletedAt: !completed,
    );

    state = AsyncData(
      current.copyWith(
        progress: updated,
      ),
    );

    final userId = SupabaseService.currentSession?.user.id;

    await _local.saveProgress(
      userId,
      updated,
    );

    await _sync(
      problem,
      updated[problem.id]!,
    );

    // Only evaluate achievements when a problem
    // is actually being completed.
    if (completed && userId != null) {
      await _checkAchievements(
        updated,
        userId,
      );
    }
  }

  Future<void> _checkAchievements(
    Map<String, ProblemProgress> progress,
    String userId,
  ) async {
    final current = state.value!;

    if (current.achievements.isEmpty) {
      return;
    }

    final completedProblems = current.problems
        .where(
          (p) => progress[p.id]?.completed == true,
        )
        .toList();

    final completedCount = completedProblems.length;

    final unlockedIds =
        current.achievements.where((a) => a.unlocked).map((a) => a.id).toSet();

    final newlyUnlocked = <Achievement>[];

    for (final achievement in current.achievements) {
      if (unlockedIds.contains(achievement.id)) {
        continue;
      }

      final shouldUnlock = _achievementConditionMet(
        achievement,
        completedProblems,
        completedCount,
        current.problems,
        current.currentStreak,
      );

      if (shouldUnlock) {
        newlyUnlocked.add(
          achievement,
        );
      }
    }

    if (newlyUnlocked.isEmpty) {
      return;
    }

    final now = DateTime.now();

    final updatedAchievements = current.achievements.map((achievement) {
      final unlocked = newlyUnlocked.any(
        (a) => a.id == achievement.id,
      );

      if (!unlocked) {
        return achievement;
      }

      return Achievement(
        id: achievement.id,
        name: achievement.name,
        description: achievement.description,
        icon: achievement.icon,
        unlockedAt: now,
      );
    }).toList();

    state = AsyncData(
      current.copyWith(
        achievements: updatedAchievements,
      ),
    );

    try {
      await _remote.unlockAchievements(
        userId,
        newlyUnlocked.map((a) => a.id).toList(),
      );

      debugPrint(
        'Unlocked ${newlyUnlocked.length} achievement(s).',
      );

      for (final achievement in newlyUnlocked) {
        debugPrint(
          '🏆 ${achievement.name}',
        );
      }
    } catch (e, stack) {
      debugPrint(
        'Achievement sync failed: $e',
      );
      debugPrintStack(
        stackTrace: stack,
      );
    }
  }

  bool _achievementConditionMet(
    Achievement achievement,
    List<Problem> completedProblems,
    int completedCount,
    List<Problem> allProblems,
    int currentStreak,
  ) {
    switch (achievement.id) {
      // ⚔️ First Blood
      case '0c10b13f-e664-46cf-9261-953126cfa001':
        return completedCount >= 1;

      // 🚀 Getting Started
      case 'af5de5e5-3151-491b-8e06-fd5fafb4622b':
        return completedCount >= 10;

      // 🔥 Momentum
      case 'ef0f3651-3e56-4edb-ae3c-3901db43d3bb':
        return completedCount >= 25;

      // 🧠 Brain Builder
      case '4bc8e69c-9cbf-4317-a6dd-0dbeb2fa7c03':
        return completedCount >= 50;

      // 🏁 Halfway There
      case '015be0ea-64cd-476a-982d-cf769983e484':
        return completedCount >= 75;

      // 👑 NeetCode Master
      case '83ca92d2-d5d8-4f2e-a70b-5bd20f4be37e':
        return completedCount >= 150;

      // 🌲 Tree Climber
      case 'a0b02d91-60bb-417b-8c57-21097ab08587':
        return _completedEntireTopic(
          'Trees',
          completedProblems,
          allProblems,
        );

      // 🕸️ Graph Explorer
      case '2022a003-879e-454f-bcf7-e2f05d984adc':
        return _completedEntireTopic(
          'Graphs',
          completedProblems,
          allProblems,
        );

      // ⚡ DP Warrior
      // ⚡ DP Warrior
      case '4c708a9f-5d5a-44e5-a5b5-02fe0b9b44e5':
        final dpProblems = allProblems.where(
          (p) =>
              p.topic.toLowerCase() == '1-d dynamic programming' ||
              p.topic.toLowerCase() == '2-d dynamic programming',
        );

        return dpProblems.every(
          (problem) => completedProblems.any(
            (completed) => completed.id == problem.id,
          ),
        );

      default:
        return false;
    }
  }

  bool _completedEntireTopic(
    String topic,
    List<Problem> completedProblems,
    List<Problem> allProblems,
  ) {
    final topicProblems = allProblems
        .where(
          (p) => p.topic.toLowerCase() == topic.toLowerCase(),
        )
        .toList();

    if (topicProblems.isEmpty) {
      return false;
    }

    return topicProblems.every(
      (problem) => completedProblems.any(
        (completed) => completed.id == problem.id,
      ),
    );
  }

  Future<void> saveNotes(
    Problem problem,
    String notes,
  ) async {
    final current = state.value!;

    final old = current.progress[problem.id] ?? const ProblemProgress();

    final updated = Map<String, ProblemProgress>.from(
      current.progress,
    );

    updated[problem.id] = old.copyWith(
      notes: notes,
    );

    state = AsyncData(
      current.copyWith(
        progress: updated,
      ),
    );

    final userId = SupabaseService.currentSession?.user.id;

    await _local.saveProgress(
      userId,
      updated,
    );

    await _sync(
      problem,
      updated[problem.id]!,
    );
  }

  Future<void> flagForReview(
    Problem problem, {
    Duration interval = const Duration(days: 14),
  }) async {
    final current = state.value!;

    final old = current.progress[problem.id] ?? const ProblemProgress();

    final updated = Map<String, ProblemProgress>.from(
      current.progress,
    );

    updated[problem.id] = old.copyWith(
      reviewDueAt: DateTime.now().add(interval),
      lastReviewedAt: DateTime.now(),
    );

    state = AsyncData(
      current.copyWith(
        progress: updated,
      ),
    );

    final userId = SupabaseService.currentSession?.user.id;

    await _local.saveProgress(
      userId,
      updated,
    );

    await _sync(
      problem,
      updated[problem.id]!,
    );
  }

  Future<void> clearReview(
    Problem problem,
  ) async {
    final current = state.value!;

    final old = current.progress[problem.id] ?? const ProblemProgress();

    final updated = Map<String, ProblemProgress>.from(
      current.progress,
    );

    updated[problem.id] = old.copyWith(
      clearReviewDueAt: true,
    );

    state = AsyncData(
      current.copyWith(
        progress: updated,
      ),
    );

    final userId = SupabaseService.currentSession?.user.id;

    await _local.saveProgress(
      userId,
      updated,
    );

    await _sync(
      problem,
      updated[problem.id]!,
    );
  }

  Future<void> _sync(
    Problem problem,
    ProblemProgress progress,
  ) async {
    final user = SupabaseService.currentSession?.user;

    if (user == null) return;

    try {
      state = AsyncData(
        state.value!.copyWith(
          syncing: true,
        ),
      );

      await _remote.upsertProgress(
        user.id,
        problem,
        progress,
      );

      await _local.removeSyncOperation(
        user.id,
        problem.id,
      );

      state = AsyncData(
        state.value!.copyWith(
          syncing: false,
        ),
      );
    } catch (e, stack) {
      debugPrint(
        'Progress sync failed: $e',
      );
      debugPrintStack(
        stackTrace: stack,
      );

      await _local.enqueueSync(
        user.id,
        problem.id,
        progress,
      );

      state = AsyncData(
        state.value!.copyWith(
          syncing: false,
        ),
      );
    }
  }

  Future<void> _flushPendingSync() async {
    if (_flushInProgress) return;

    final user = SupabaseService.currentSession?.user;

    if (user == null) return;

    _flushInProgress = true;

    try {
      final queue = await _local.loadSyncQueue(
        user.id,
      );

      if (queue.isEmpty) return;

      if (state.hasValue) {
        state = AsyncData(
          state.value!.copyWith(
            syncing: true,
          ),
        );
      }

      for (final operation in List<Map<String, dynamic>>.from(
        queue,
      )) {
        try {
          final problemId = operation['problemId'] as String;

          final problem = state.value!.problems.firstWhere(
            (p) => p.id == problemId,
          );

          final progress = ProblemProgress(
            completed: operation['completed'] == true,
            completedAt: operation['completedAt'] == null
                ? null
                : DateTime.tryParse(
                    operation['completedAt'] as String,
                  ),
            notes: operation['notes'] ?? '',
            reviewDueAt: operation['reviewDueAt'] == null
                ? null
                : DateTime.tryParse(
                    operation['reviewDueAt'] as String,
                  ),
            lastReviewedAt: operation['lastReviewedAt'] == null
                ? null
                : DateTime.tryParse(
                    operation['lastReviewedAt'] as String,
                  ),
          );

          await _remote.upsertProgress(
            user.id,
            problem,
            progress,
          );

          await _local.removeSyncOperation(
            user.id,
            problemId,
          );

          debugPrint(
            'Offline sync successful: '
            '${problem.title}',
          );
        } catch (e, stack) {
          debugPrint(
            'Offline sync failed. '
            'Keeping operation queued: $e',
          );
          debugPrintStack(
            stackTrace: stack,
          );
        }
      }

      if (state.hasValue) {
        state = AsyncData(
          state.value!.copyWith(
            syncing: false,
          ),
        );
      }
    } finally {
      _flushInProgress = false;
    }
  }

  Future<void> syncFromCloud() async {
    final user = SupabaseService.currentSession?.user;

    if (user == null) return;

    final current = state.value!;

    try {
      state = AsyncData(
        current.copyWith(
          syncing: true,
        ),
      );

      await _flushPendingSync();

      final rows = await _remote.fetchProgress(
        user.id,
      );

      final updated = Map<String, ProblemProgress>.from(
        current.progress,
      );

      for (final row in rows) {
        final problem = current.problems.firstWhere(
          (p) => p.slug == (row['problems']['slug'] as String),
        );

        updated[problem.id] = ProblemProgress(
          completed: row['completed'] == true,
          completedAt: row['completed_at'] == null
              ? null
              : DateTime.tryParse(
                  row['completed_at'],
                ),
          notes: row['notes'] ?? '',
          reviewDueAt: row['review_due_at'] == null
              ? null
              : DateTime.tryParse(
                  row['review_due_at'],
                ),
          lastReviewedAt: row['last_reviewed_at'] == null
              ? null
              : DateTime.tryParse(
                  row['last_reviewed_at'],
                ),
        );
      }

      await _local.saveProgress(
        user.id,
        updated,
      );

      final achievements = await _loadAchievements(
        user.id,
      );

      state = AsyncData(
        current.copyWith(
          progress: updated,
          achievements: achievements,
          syncing: false,
        ),
      );
    } catch (e, stack) {
      debugPrint(
        'Cloud download failed: $e',
      );
      debugPrintStack(
        stackTrace: stack,
      );

      state = AsyncData(
        current.copyWith(
          syncing: false,
        ),
      );
    }
  }
}
