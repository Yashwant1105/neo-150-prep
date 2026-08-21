import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_repository.dart';
import '../models/problem.dart';
import '../models/achievement.dart';
import '../services/supabase_service.dart';

final appControllerProvider =
    AsyncNotifierProvider<AppController, AppState>(AppController.new);

enum DailyPrepType {
  review,
  solve,
  interview,
  weakTopic,
}

class DailyPrepRecommendation {
  final Problem problem;
  final DailyPrepType type;

  const DailyPrepRecommendation({
    required this.problem,
    required this.type,
  });
}

class AppState {
  final List<Problem> problems;
  final Map<String, ProblemProgress> progress;
  final int dailyGoal;
  final bool syncing;
  final Set<String> interviewedProblemIds;
  final List<Achievement> achievements;
  final List<String> dailyPrepProblemIds;
  final String? dailyPrepDate;

  const AppState({
    required this.problems,
    required this.progress,
    this.dailyGoal = 2,
    this.syncing = false,
    this.interviewedProblemIds = const <String>{},
    this.achievements = const <Achievement>[],
    this.dailyPrepProblemIds = const <String>[],
    this.dailyPrepDate,
  });

  int get completed => progress.values.where((p) => p.completed).length;

  int get remaining => problems.length - completed;

  double get completionRate =>
      problems.isEmpty ? 0 : completed / problems.length;

  int get xp => progress.entries.fold(0, (sum, e) {
        if (!e.value.completed) return sum;

        final p = problems.firstWhere((p) => p.id == e.key);

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
      final d = p.completedAt;

      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).length;
  }

  int get currentStreak {
    final days = <String>{};

    for (final p in progress.values) {
      final d = p.completedAt;

      if (p.completed && d != null) {
        days.add(_dayKey(d));
      }
    }

    var cursor = DateTime.now();

    if (!days.contains(_dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;

    while (days.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  int get longestStreak {
    final dates = progress.values
        .where((p) => p.completedAt != null)
        .map(
          (p) => DateTime(
            p.completedAt!.year,
            p.completedAt!.month,
            p.completedAt!.day,
          ),
        )
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
            !r!.reviewDueAt!.isAfter(DateTime.now());
      }).toList();

  Problem? get nextProblem {
    final incomplete =
        problems.where((p) => !(progress[p.id]?.completed ?? false)).toList();

    if (incomplete.isEmpty) return null;

    return incomplete.first;
  }

  /// First completed problem that has not yet had a completed interview.
  /// If every completed problem has already been interviewed, fall back to
  /// the first completed problem so the Interview Me flow never disappears.
  Problem? get nextInterviewProblem {
    final completedProblems =
        problems.where((p) => progress[p.id]?.completed == true).toList();

    if (completedProblems.isEmpty) return null;

    for (final problem in completedProblems) {
      if (!interviewedProblemIds.contains(problem.id)) {
        return problem;
      }
    }

    return completedProblems.first;
  }

  bool hasCompletedInterview(String problemId) =>
      interviewedProblemIds.contains(problemId);

  /// Returns today's fixed Daily Prep plan.
  ///
  /// The plan is generated once per day and persisted by AppController.
  /// Completion changes the visual state of a task but never swaps that task
  /// out for another problem during the same day.
  List<DailyPrepRecommendation> get dailyPrep {
    if (dailyGoal <= 0 || problems.isEmpty) {
      return const <DailyPrepRecommendation>[];
    }

    final problemById = <String, Problem>{
      for (final problem in problems) problem.id: problem,
    };

    final recommendations = <DailyPrepRecommendation>[];

    for (final id in dailyPrepProblemIds.take(dailyGoal)) {
      final problem = problemById[id];
      if (problem == null) continue;

      final progress = this.progress[problem.id];
      final due = progress?.reviewDueAt;
      final isDue = due != null && !due.isAfter(DateTime.now());

      recommendations.add(
        DailyPrepRecommendation(
          problem: problem,
          type: isDue ? DailyPrepType.review : DailyPrepType.solve,
        ),
      );
    }

    return recommendations;
  }

  /// Builds a deterministic plan for a new day.
  ///
  /// Priority: review due -> new/incomplete -> weak topic -> remaining.
  /// The resulting IDs are persisted so the plan stays stable for the day.
  List<String> buildDailyPrepPlan() {
    if (dailyGoal <= 0 || problems.isEmpty) {
      return const <String>[];
    }

    final selectedIds = <String>{};
    final result = <String>[];

    void add(Problem problem) {
      if (result.length >= dailyGoal) return;
      if (selectedIds.add(problem.id)) {
        result.add(problem.id);
      }
    }

    final reviews = problems.where((problem) {
      final due = progress[problem.id]?.reviewDueAt;
      return due != null && !due.isAfter(DateTime.now());
    }).toList()
      ..sort((a, b) {
        final aDue = progress[a.id]!.reviewDueAt!;
        final bDue = progress[b.id]!.reviewDueAt!;
        final compare = aDue.compareTo(bDue);
        return compare != 0 ? compare : a.order.compareTo(b.order);
      });

    for (final problem in reviews) {add(problem);}

    final newProblems = problems
        .where((problem) => !(progress[problem.id]?.completed ?? false))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final problem in newProblems) {add(problem);}

    final topicTotals = <String, int>{};
    final topicCompleted = <String, int>{};
    final weakCandidates = <Problem>[];

    for (final problem in problems) {
      topicTotals[problem.topic] = (topicTotals[problem.topic] ?? 0) + 1;
      if (progress[problem.id]?.completed == true) {
        topicCompleted[problem.topic] =
            (topicCompleted[problem.topic] ?? 0) + 1;
      }

      final due = progress[problem.id]?.reviewDueAt;
      final isDue = due != null && !due.isAfter(DateTime.now());

      if (!selectedIds.contains(problem.id) &&
          progress[problem.id]?.completed == true &&
          !isDue) {
        weakCandidates.add(problem);
      }
    }

    weakCandidates.sort((a, b) {
      final aRate =
          (topicCompleted[a.topic] ?? 0) / (topicTotals[a.topic] ?? 1);
      final bRate =
          (topicCompleted[b.topic] ?? 0) / (topicTotals[b.topic] ?? 1);
      final compare = aRate.compareTo(bRate);
      return compare != 0 ? compare : a.order.compareTo(b.order);
    });

    for (final problem in weakCandidates) {add(problem);}

    // Safe fallback if the user has completed almost everything.
    final remaining = problems.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final problem in remaining) add(problem);

    return result;
  }

  AppState copyWith({
    Map<String, ProblemProgress>? progress,
    int? dailyGoal,
    bool? syncing,
    Set<String>? interviewedProblemIds,
    List<Achievement>? achievements,
    List<String>? dailyPrepProblemIds,
    String? dailyPrepDate,
  }) {
    return AppState(
      problems: problems,
      progress: progress ?? this.progress,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      syncing: syncing ?? this.syncing,
      interviewedProblemIds:
          interviewedProblemIds ?? this.interviewedProblemIds,
      achievements: achievements ?? this.achievements,
      dailyPrepProblemIds: dailyPrepProblemIds ?? this.dailyPrepProblemIds,
      dailyPrepDate: dailyPrepDate ?? this.dailyPrepDate,
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

    // Start listening for internet connectivity.
    // When the device comes back online, pending
    // offline changes will automatically be uploaded.
    _startConnectivityListener();

    final localProgress = await _local.loadProgress(userId);

    final prefs = await _local.loadPrefs(userId);

    var progress = localProgress;
    var interviewedProblemIds = <String>{};
    var achievements = <Achievement>[];

    var dailyGoal = prefs['dailyGoal'] ?? 2;

    if (userId != null) {
      try {
        interviewedProblemIds =
            await _remote.fetchCompletedInterviewProblemIds(userId);
      } catch (e, stack) {
        // Interview history must never prevent the normal progress data from
        // loading (for example if its RLS policy is temporarily unavailable).
        debugPrint('Initial interview history sync failed: $e');
        debugPrintStack(stackTrace: stack);
      }

      try {
        final achievementRows = await _remote.fetchAchievements(userId);

        achievements = achievementRows.map((row) {
          final achievementData =
              Map<String, dynamic>.from(row['achievements'] as Map);

          final unlockedAtRaw = row['unlocked_at'];

          final unlockedAt = unlockedAtRaw == null
              ? null
              : DateTime.tryParse(unlockedAtRaw.toString());

          return Achievement.fromMap(
            achievementData,
            unlockedAt: unlockedAt,
          );
        }).toList();
      } catch (e, stack) {
        debugPrint('Achievement sync failed: $e');
        debugPrintStack(stackTrace: stack);
      }

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

        // Load the daily goal from Supabase.
        final cloudDailyGoal = await _remote.fetchDailyGoal(userId);

        if (cloudDailyGoal != null) {
          dailyGoal = cloudDailyGoal;

          final updatedPrefs = await _local.loadPrefs(userId);
          updatedPrefs['dailyGoal'] = dailyGoal;
          await _local.savePrefs(userId, updatedPrefs);
        } else {
          // First login/device: upload the locally stored goal.
          await _remote.saveDailyGoal(
            userId,
            dailyGoal,
          );
        }
      } catch (e, stack) {
        debugPrint(
          'Initial cloud sync failed: $e',
        );
        debugPrintStack(stackTrace: stack);
      }
    }

    final todayKey = AppState._dayKey(DateTime.now());
    final savedPlanDate = prefs['dailyPrepDate']?.toString();
    final savedPlanRaw = prefs['dailyPrepProblemIds'];
    var dailyPrepProblemIds = savedPlanRaw is List
        ? savedPlanRaw.map((e) => e.toString()).toList()
        : <String>[];

    // Generate a fresh plan once per day, or when the saved plan no longer
    // matches the current Daily Goal.
    if (savedPlanDate != todayKey ||
        dailyPrepProblemIds.length != dailyGoal ||
        dailyPrepProblemIds.any((id) => !problems.any((p) => p.id == id))) {
      final planningState = AppState(
        problems: problems,
        progress: progress,
        dailyGoal: dailyGoal,
        interviewedProblemIds: interviewedProblemIds,
        achievements: achievements,
      );

      dailyPrepProblemIds = planningState.buildDailyPrepPlan();

      final existingPrefs = Map<String, dynamic>.from(prefs);
      existingPrefs['dailyGoal'] = dailyGoal;
      existingPrefs['dailyPrepDate'] = todayKey;
      existingPrefs['dailyPrepProblemIds'] = dailyPrepProblemIds;
      await _local.savePrefs(userId, existingPrefs);
    }

    return AppState(
      problems: problems,
      progress: progress,
      dailyGoal: dailyGoal,
      interviewedProblemIds: interviewedProblemIds,
      achievements: achievements,
      dailyPrepProblemIds: dailyPrepProblemIds,
      dailyPrepDate: todayKey,
    );
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

    // Always save locally first.
    final prefs = await _local.loadPrefs(userId);
    prefs['dailyGoal'] = value;
    prefs['dailyPrepDate'] = null;
    prefs['dailyPrepProblemIds'] = <String>[];
    await _local.savePrefs(
      userId,
      prefs,
    );

    // Generate a new plan for the new goal immediately.
    final planningState = current.copyWith(
      dailyGoal: value,
      dailyPrepProblemIds: const <String>[],
      dailyPrepDate: null,
    );
    final newPlan = planningState.buildDailyPrepPlan();

    // Update UI immediately.
    state = AsyncData(
      current.copyWith(
        dailyGoal: value,
        dailyPrepProblemIds: newPlan,
        dailyPrepDate: AppState._dayKey(DateTime.now()),
      ),
    );

    // Then save to Supabase if signed in.
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
        debugPrintStack(stackTrace: stack);
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

    // Update UI immediately.
    state = AsyncData(
      current.copyWith(
        progress: updated,
      ),
    );

    final userId = SupabaseService.currentSession?.user.id;

    // Save locally first.
    await _local.saveProgress(
      userId,
      updated,
    );

    // Check achievements immediately after completion.
    if (completed && userId != null) {
      await _checkAchievements(
        updated,
        userId,
      );
    }

    // Upload or queue for later.
    await _sync(
      problem,
      updated[problem.id]!,
    );
  }

  Future<void> _checkAchievements(
    Map<String, ProblemProgress> progress,
    String userId,
  ) async {
    try {
      var current = state.value!;

      // Make sure achievement definitions are available.
      if (current.achievements.isEmpty) {
        final rows = await _remote.fetchAchievements(userId);

        final loadedAchievements = rows.map((row) {
          final data = Map<String, dynamic>.from(row['achievements'] as Map);

          final unlockedAtRaw = row['unlocked_at'];

          return Achievement.fromMap(
            data,
            unlockedAt: unlockedAtRaw == null
                ? null
                : DateTime.tryParse(
                    unlockedAtRaw.toString(),
                  ),
          );
        }).toList();

        if (loadedAchievements.isEmpty) {
          debugPrint(
            'Achievement check skipped: no definitions loaded.',
          );
          return;
        }

        state = AsyncData(
          current.copyWith(
            achievements: loadedAchievements,
          ),
        );

        current = state.value!;
      }

      final completedProblems = current.problems
          .where(
            (p) => progress[p.id]?.completed == true,
          )
          .toList();

      final completedCount = completedProblems.length;

      debugPrint(
        'Achievement check: '
        '$completedCount completed, '
        '${current.achievements.length} definitions loaded.',
      );

      final newlyUnlocked = <Achievement>[];

      for (final achievement in current.achievements) {
        if (achievement.unlocked) {
          continue;
        }

        final name = achievement.name.trim().toLowerCase();

        bool shouldUnlock = false;

        switch (name) {
          case 'first blood':
            shouldUnlock = completedCount >= 1;
            break;

          case 'getting started':
            shouldUnlock = completedCount >= 10;
            break;

          case 'momentum':
            shouldUnlock = completedCount >= 25;
            break;

          case 'brain builder':
            shouldUnlock = completedCount >= 50;
            break;

          case 'halfway there':
            shouldUnlock = completedCount >= 75;
            break;

          case 'neetcode master':
            shouldUnlock = completedCount >= 150;
            break;

          case 'tree climber':
            shouldUnlock = completedProblems.any(
              (p) => p.topic.toLowerCase().contains('tree'),
            );
            break;

          case 'graph explorer':
            shouldUnlock = completedProblems.any(
              (p) => p.topic.toLowerCase().contains('graph'),
            );
            break;

          case 'dp warrior':
            shouldUnlock = completedProblems.any(
              (p) =>
                  p.topic.toLowerCase().contains('dynamic') ||
                  p.topic.toLowerCase().contains('dp'),
            );
            break;
        }

        debugPrint(
          'Achievement "${achievement.name}": $shouldUnlock',
        );

        if (shouldUnlock) {
          newlyUnlocked.add(achievement);
        }
      }

      if (newlyUnlocked.isEmpty) {
        return;
      }

      final now = DateTime.now();

      final updatedAchievements = current.achievements.map((achievement) {
        final unlock = newlyUnlocked.any(
          (a) => a.id == achievement.id,
        );

        if (!unlock) {
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

      // Update UI immediately.
      state = AsyncData(
        current.copyWith(
          achievements: updatedAchievements,
        ),
      );

      // Persist unlocks.
      await _remote.unlockAchievements(
        userId,
        newlyUnlocked.map((a) => a.id).toList(),
      );

      for (final achievement in newlyUnlocked) {
        debugPrint(
          '🏆 Achievement unlocked: ${achievement.name}',
        );
      }
    } catch (e, stack) {
      debugPrint(
        'Achievement check failed: $e',
      );
      debugPrintStack(
        stackTrace: stack,
      );
    }
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

      // Cloud upload succeeded, so remove any
      // previous queued operation for this problem.
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
      debugPrintStack(stackTrace: stack);

      // Local state is already safe.
      // Queue the latest state for retry.
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
      final queue = await _local.loadSyncQueue(user.id);

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
            'Offline sync successful: ${problem.title}',
          );
        } catch (e, stack) {
          debugPrint(
            'Offline sync failed. Keeping operation queued: $e',
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

  Future<void> saveInterviewAttempt({
    required Problem problem,
    required int questionNumber,
    required String question,
    required String answer,
    required String feedback,
    required int? score,
    required bool sessionCompleted,
  }) async {
    final userId = SupabaseService.currentSession?.user.id;

    if (userId == null) {
      throw StateError('You must be signed in to save interview history.');
    }

    await _remote.saveInterviewAttempt(
      userId: userId,
      problem: problem,
      questionNumber: questionNumber,
      question: question,
      answer: answer,
      feedback: feedback,
      score: score,
      sessionCompleted: sessionCompleted,
    );

    if (sessionCompleted && state.hasValue) {
      final current = state.value!;
      final updated = <String>{
        ...current.interviewedProblemIds,
        problem.id,
      };

      state = AsyncData(
        current.copyWith(
          interviewedProblemIds: updated,
        ),
      );
    }
  }

  Future<void> refreshInterviewHistory() async {
    final userId = SupabaseService.currentSession?.user.id;
    if (userId == null || !state.hasValue) return;

    try {
      final ids = await _remote.fetchCompletedInterviewProblemIds(userId);
      state = AsyncData(
        state.value!.copyWith(
          interviewedProblemIds: ids,
        ),
      );
    } catch (e, stack) {
      debugPrint('Interview history sync failed: $e');
      debugPrintStack(stackTrace: stack);
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

      // Upload any pending offline changes first.
      await _flushPendingSync();

      Set<String> interviewIds = current.interviewedProblemIds;
      try {
        interviewIds = await _remote.fetchCompletedInterviewProblemIds(user.id);
      } catch (e, stack) {
        debugPrint('Interview history refresh failed: $e');
        debugPrintStack(stackTrace: stack);
      }

      final rows = await _remote.fetchProgress(user.id);

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

      state = AsyncData(
        current.copyWith(
          progress: updated,
          syncing: false,
          interviewedProblemIds: interviewIds,
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
