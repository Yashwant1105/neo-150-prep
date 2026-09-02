import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_repository.dart';
import '../models/problem.dart';
import '../models/achievement.dart';
import '../services/supabase_service.dart';
import '../services/streak_calculator.dart';
import '../services/motivation_service.dart';

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
  final int persistedLongestStreak;
  final List<String> dailyPrepProblemIds;
  final String? dailyPrepDate;
  final List<String> dailyFocusTopics;
  final String? dailyFocusDate;

  const AppState({
    required this.problems,
    required this.progress,
    this.dailyGoal = 2,
    this.syncing = false,
    this.interviewedProblemIds = const <String>{},
    this.achievements = const <Achievement>[],
    this.persistedLongestStreak = 0,
    this.dailyPrepProblemIds = const <String>[],
    this.dailyPrepDate,
    this.dailyFocusTopics = const <String>[],
    this.dailyFocusDate,
  });

  int get completed => progress.values.where((p) => p.completed).length;

  int get remaining => problems.length - completed;

  double get completionRate =>
      problems.isEmpty ? 0 : completed / problems.length;

  int get xp => progress.entries.fold(0, (sum, e) {
        if (!e.value.completed) return sum;

        final p = problems.firstWhere(
          (p) => p.id == e.key,
          orElse: () => problems.first,
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
      final d = p.completedAt;

      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).length;
  }

  int get currentStreak {
    return _streaks.current;
  }

  int get longestStreak {
    return math.max(_streaks.longest, persistedLongestStreak);
  }

  StreakResult get _streaks => StreakCalculator.calculate(
        progress.values
            .where((p) => p.completed && p.completedAt != null)
            .map((p) => p.completedAt!),
      );

  List<Problem> get dueReviews => problems.where((p) {
        final r = progress[p.id];

        return r?.reviewDueAt != null &&
            !r!.reviewDueAt!.isAfter(DateTime.now());
      }).toList();

  /// Completion rate for every topic.
  ///
  /// A lower rate means the topic has received less practice and is therefore
  /// a stronger candidate for focused practice.
  Map<String, double> get topicCompletionRates {
    final totals = <String, int>{};
    final completed = <String, int>{};

    for (final problem in problems) {
      totals[problem.topic] = (totals[problem.topic] ?? 0) + 1;

      if (progress[problem.id]?.completed == true) {
        completed[problem.topic] = (completed[problem.topic] ?? 0) + 1;
      }
    }

    return {
      for (final topic in totals.keys)
        topic: (completed[topic] ?? 0) / totals[topic]!,
    };
  }

  /// Topics ordered from weakest completion rate to strongest.
  ///
  /// Completion percentage is the primary signal. Remaining problem count and
  /// the stable problem order are used as deterministic tie-breakers.
  List<String> get weakTopics {
    final rates = topicCompletionRates;
    final topicTotals = <String, int>{};

    for (final problem in problems) {
      topicTotals[problem.topic] = (topicTotals[problem.topic] ?? 0) + 1;
    }

    final topics = rates.keys.toList()
      ..sort((a, b) {
        final rateCompare = rates[a]!.compareTo(rates[b]!);
        if (rateCompare != 0) return rateCompare;

        final remainingA =
            topicTotals[a]! - (rates[a]! * topicTotals[a]!).round();
        final remainingB =
            topicTotals[b]! - (rates[b]! * topicTotals[b]!).round();

        final remainingCompare = remainingB.compareTo(remainingA);
        if (remainingCompare != 0) return remainingCompare;

        final orderA = problems.where((p) => p.topic == a).fold<int>(1 << 30,
            (minOrder, problem) {
          return problem.order < minOrder ? problem.order : minOrder;
        });
        final orderB = problems.where((p) => p.topic == b).fold<int>(1 << 30,
            (minOrder, problem) {
          return problem.order < minOrder ? problem.order : minOrder;
        });

        return orderA.compareTo(orderB);
      });

    return topics;
  }

  /// The user's fixed daily focus snapshot for this day.
  ///
  /// Percentages remain live because they are derived from the current progress
  /// map for each selected topic; the selection itself is only recalculated when
  /// a new day begins.
  List<String> get focusTopics => dailyFocusTopics;

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

      final type = isDue
          ? DailyPrepType.review
          : focusTopics.contains(problem.topic)
              ? DailyPrepType.weakTopic
              : DailyPrepType.solve;

      recommendations.add(
        DailyPrepRecommendation(
          problem: problem,
          type: type,
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

    for (final problem in reviews) {
      add(problem);
    }

    final topicRates = topicCompletionRates;
    final weakTopicSet = focusTopics.toSet();

    final newProblems = problems
        .where((problem) => !(progress[problem.id]?.completed ?? false))
        .toList()
      ..sort((a, b) {
        final aIsFocus = weakTopicSet.contains(a.topic);
        final bIsFocus = weakTopicSet.contains(b.topic);

        if (aIsFocus != bIsFocus) {
          return aIsFocus ? -1 : 1;
        }

        final aRate = topicRates[a.topic] ?? 1.0;
        final bRate = topicRates[b.topic] ?? 1.0;
        final rateCompare = aRate.compareTo(bRate);

        return rateCompare != 0 ? rateCompare : a.order.compareTo(b.order);
      });

    for (final problem in newProblems) {
      add(problem);
    }

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

    for (final problem in weakCandidates) {
      add(problem);
    }

    // Safe fallback if the user has completed almost everything.
    final remaining = problems.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final problem in remaining) {
      add(problem);
    }

    return result;
  }

  Map<String, dynamic> buildAiCoachContext({
    Map<String, dynamic>? interviewContext,
  }) {
    final completed = progress.values.where((p) => p.completed).length;
    final total = problems.length;
    final completionPercentage =
        total == 0 ? 0 : ((completed / total) * 100).round();

    final focusTopics = dailyFocusTopics.take(3).toList();

    final weakest = weakTopics
        .take(3)
        .map((topic) => {
              'topic': topic,
              'completion_percentage':
                  ((topicCompletionRates[topic] ?? 0) * 100).round(),
            })
        .toList();

    final strongest = topicCompletionRates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final strongestTopics = strongest
        .map((entry) => {
              'topic': entry.key,
              'completion_percentage': (entry.value * 100).round(),
            })
        .take(3)
        .toList();

    final context = <String, dynamic>{
      'progress': {
        'completed': completed,
        'total': total,
        'completion_percentage': completionPercentage,
      },
      'daily_prep': {
        'daily_goal': dailyGoal,
        'completed_today': todayCompleted,
        'remaining_today': (dailyGoal - todayCompleted).clamp(0, dailyGoal),
      },
      'focus_areas': {
        'topics': focusTopics,
      },
      'topic_performance': {
        'weakest': weakest,
        'strongest': strongestTopics,
      },
      'streak': {
        'current': currentStreak,
        'longest': longestStreak,
      },
    };

    if (interviewContext != null && interviewContext.isNotEmpty) {
      context['interview_context'] = interviewContext;
    }

    return context;
  }

  AppState copyWith({
    Map<String, ProblemProgress>? progress,
    int? dailyGoal,
    bool? syncing,
    Set<String>? interviewedProblemIds,
    List<Achievement>? achievements,
    int? persistedLongestStreak,
    List<String>? dailyPrepProblemIds,
    String? dailyPrepDate,
    List<String>? dailyFocusTopics,
    String? dailyFocusDate,
  }) {
    return AppState(
      problems: problems,
      progress: progress ?? this.progress,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      syncing: syncing ?? this.syncing,
      interviewedProblemIds:
          interviewedProblemIds ?? this.interviewedProblemIds,
      achievements: achievements ?? this.achievements,
      persistedLongestStreak:
          persistedLongestStreak ?? this.persistedLongestStreak,
      dailyPrepProblemIds: dailyPrepProblemIds ?? this.dailyPrepProblemIds,
      dailyPrepDate: dailyPrepDate ?? this.dailyPrepDate,
      dailyFocusTopics: dailyFocusTopics ?? this.dailyFocusTopics,
      dailyFocusDate: dailyFocusDate ?? this.dailyFocusDate,
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

  List<String> _computeDailyFocusTopics(
    List<Problem> problems,
    Map<String, ProblemProgress> progress,
  ) {
    final state = AppState(
      problems: problems,
      progress: progress,
    );

    return state.weakTopics
        .where((topic) => state.topicCompletionRates[topic]! < 1.0)
        .take(3)
        .toList();
  }

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
    var persistedLongestStreak = (prefs['longestStreak'] as num?)?.toInt() ?? 0;

    var dailyGoal = prefs['dailyGoal'] ?? 2;
    var dailyFocusDate = prefs['dailyFocusDate']?.toString();
    var dailyFocusTopics = prefs['dailyFocusTopics'] is List
        ? (prefs['dailyFocusTopics'] as List).map((e) => e.toString()).toList()
        : <String>[];

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

        final cloudProgress = <String, ProblemProgress>{};

        for (final row in rows) {
          final slug = row['problems']['slug'] as String;

          final problem = problems.firstWhere(
            (p) => p.slug == slug,
            orElse: () {
              debugPrint('Skipping progress for unknown slug: $slug');
              return problems.first;
            },
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

        final pending = await _local.loadSyncQueue(userId);
        for (final operation in pending) {
          final problemId = operation['problemId']?.toString();
          if (problemId == null) continue;

          cloudProgress[problemId] = _progressFromMap(operation);
        }

        progress = cloudProgress;

        await _local.saveProgress(
          userId,
          progress,
        );

        persistedLongestStreak = await _persistLongestStreak(userId, progress);

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

        final cloudDailyFocus = await _remote.fetchDailyFocus(userId);
        if (cloudDailyFocus != null) {
          dailyFocusDate = cloudDailyFocus['date']?.toString();
          final cloudTopics = cloudDailyFocus['topics'] is List
              ? (cloudDailyFocus['topics'] as List)
                  .map((e) => e.toString())
                  .toList()
              : <String>[];

          if (cloudTopics.isNotEmpty) {
            dailyFocusTopics = cloudTopics;
          }

          final updatedPrefs = await _local.loadPrefs(userId);
          updatedPrefs['dailyFocusDate'] = dailyFocusDate;
          updatedPrefs['dailyFocusTopics'] = dailyFocusTopics;
          await _local.savePrefs(userId, updatedPrefs);
        }
      } catch (e, stack) {
        debugPrint(
          'Initial cloud sync failed: $e',
        );
        debugPrintStack(stackTrace: stack);
      }
    }

    final todayKey = AppState._dayKey(DateTime.now());
    if (dailyFocusDate != todayKey || dailyFocusTopics.isEmpty) {
      dailyFocusTopics = _computeDailyFocusTopics(problems, progress);
      dailyFocusDate = todayKey;

      final existingPrefs = Map<String, dynamic>.from(prefs);
      existingPrefs['dailyFocusDate'] = dailyFocusDate;
      existingPrefs['dailyFocusTopics'] = dailyFocusTopics;
      await _local.savePrefs(userId, existingPrefs);

      if (userId != null) {
        try {
          await _remote.saveDailyFocus(
            userId,
            todayKey,
            dailyFocusTopics,
          );
        } catch (e, stack) {
          debugPrint('Daily focus cloud sync failed: $e');
          debugPrintStack(stackTrace: stack);
        }
      }
    }
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
      persistedLongestStreak: persistedLongestStreak,
      dailyPrepProblemIds: dailyPrepProblemIds,
      dailyPrepDate: todayKey,
      dailyFocusTopics: dailyFocusTopics,
      dailyFocusDate: dailyFocusDate,
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

  Future<String?> toggleComplete(
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

    if (userId != null) {
      final persistedLongestStreak =
          await _persistLongestStreak(userId, updated);
      state = AsyncData(
        state.value!.copyWith(
          persistedLongestStreak: persistedLongestStreak,
        ),
      );
    }

    // Check achievements immediately after completion.
    // Capture achievements before check to detect newly unlocked ones.
    final achievementsBeforeCheck = state.value!.achievements;
    List<String>? newlyUnlockedAchievementIds;
    if (completed && userId != null) {
      newlyUnlockedAchievementIds = await _checkAchievements(
        updated,
        userId,
        achievementsBeforeCheck,
      );

      // Track session activity
      await _local.incrementSessionCompleted(userId);
    }

    // Check for AI motivation after achievements are checked
    String? motivation;
    if (completed && newlyUnlockedAchievementIds != null) {
      motivation = await checkAndGenerateMotivation(
        completedProblem: problem,
        updatedProgress: updated,
        newlyUnlockedAchievementIds: newlyUnlockedAchievementIds,
      );
    }

    // Upload or queue for later.
    await _sync(
      problem,
      updated[problem.id]!,
    );

    return motivation;
  }

  Future<List<String>> _checkAchievements(
    Map<String, ProblemProgress> progress,
    String userId,
    List<Achievement> previousAchievements,
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
          return [];
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
      final streakDays = current.currentStreak;
      final topicTotals = <String, int>{};
      final topicCompleted = <String, int>{};
      final dayCounts = <String, int>{};

      for (final problem in current.problems) {
        topicTotals[problem.topic] = (topicTotals[problem.topic] ?? 0) + 1;

        if (progress[problem.id]?.completed == true) {
          topicCompleted[problem.topic] =
              (topicCompleted[problem.topic] ?? 0) + 1;
        }
      }

      for (final problem in current.problems) {
        final completedAt = progress[problem.id]?.completedAt;
        if (progress[problem.id]?.completed != true || completedAt == null) {
          continue;
        }

        final dayKey =
            '${completedAt.year}-${completedAt.month}-${completedAt.day}';
        dayCounts[dayKey] = (dayCounts[dayKey] ?? 0) + 1;
      }

      final completedInterviewSessions =
          await _remote.fetchCompletedInterviewSessionCount(userId);
      final daysMeetingDailyGoal =
          dayCounts.values.where((count) => count >= current.dailyGoal).length;

      debugPrint(
        'Achievement check: $completedCount completed, '
        '${current.achievements.length} definitions loaded.',
      );

      final newlyUnlocked = <Achievement>[];

      for (final achievement in current.achievements) {
        if (achievement.unlocked) {
          continue;
        }

        bool shouldUnlock = false;

        switch (achievement.name.trim().toLowerCase()) {
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

          case 'century':
            shouldUnlock = completedCount >= 100;
            break;

          case 'deep grind':
            shouldUnlock = completedCount >= 125;
            break;

          case 'tree climber':
            shouldUnlock = topicTotals.entries.any(
              (entry) =>
                  entry.key.toLowerCase().contains('tree') &&
                  (topicCompleted[entry.key] ?? 0) == entry.value,
            );
            break;

          case 'graph explorer':
            shouldUnlock = topicTotals.entries.any(
              (entry) =>
                  entry.key.toLowerCase().contains('graph') &&
                  (topicCompleted[entry.key] ?? 0) == entry.value,
            );
            break;

          case 'dp warrior':
            shouldUnlock = topicTotals.entries.any(
              (entry) =>
                  (entry.key.toLowerCase().contains('dynamic') ||
                      entry.key.toLowerCase().contains('dp')) &&
                  (topicCompleted[entry.key] ?? 0) == entry.value,
            );
            break;

          case 'neetcode master':
            shouldUnlock = completedCount >= 150;
            break;

          case 'streak starter':
            shouldUnlock = streakDays >= 3;
            break;

          case 'on fire':
            shouldUnlock = streakDays >= 7;
            break;

          case 'daily grinder':
            shouldUnlock = daysMeetingDailyGoal >= 7;
            break;

          case 'topic master':
            shouldUnlock = topicTotals.entries.any(
              (entry) => (topicCompleted[entry.key] ?? 0) == entry.value,
            );
            break;

          case 'productive day':
            shouldUnlock = dayCounts.values.any((count) => count >= 5);
            break;

          case 'interview ready':
            shouldUnlock = completedInterviewSessions >= 5;
            break;
        }

        debugPrint(
          'Achievement "${achievement.name}" (${achievement.id}): $shouldUnlock',
        );

        if (shouldUnlock) {
          newlyUnlocked.add(achievement);
        }
      }

      if (newlyUnlocked.isEmpty) {
        return [];
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

      // Enqueue achievement notifications if enabled.
      final settings = await _remote.fetchNotificationSettings();
      if (settings['notifications_enabled'] == true &&
          settings['achievement_notifications_enabled'] == true) {
        for (final achievement in newlyUnlocked) {
          await _remote.enqueueAchievementNotification(userId, achievement.id);
        }
      }

      for (int i = 0; i < newlyUnlocked.length; i++) {
        debugPrint('Achievement unlocked.');
      }

      // Return IDs of newly unlocked achievements for motivation detection
      return newlyUnlocked.map((a) => a.id).toList();
    } catch (e, stack) {
      debugPrint(
        'Achievement check failed: $e',
      );
      debugPrintStack(
        stackTrace: stack,
      );
      return [];
    }
  }

  Future<String?> checkAndGenerateMotivation({
    required Problem completedProblem,
    required Map<String, ProblemProgress> updatedProgress,
    required List<String> newlyUnlockedAchievementIds,
  }) async {
    final current = state.value!;
    final userId = SupabaseService.currentSession?.user.id;

    if (userId == null) {
      return null;
    }

    String? eventType;

    // Check for meaningful events
    if (current.todayCompleted == current.dailyGoal) {
      eventType = 'daily_goal';
    } else if (current.currentStreak == 7) {
      eventType = 'streak_7';
    } else if (current.currentStreak == 14) {
      eventType = 'streak_14';
    } else if (current.currentStreak == 30) {
      eventType = 'streak_30';
    } else if (completedProblem.difficulty == 'Hard') {
      // Hard problem only triggers if session is meaningful (3+ problems)
      final sessionCompleted = await _local.getSessionCompletedCount(userId);
      if (sessionCompleted >= 3) {
        eventType = 'hard_problem';
      }
    }

    // Check for newly unlocked achievements (passed from toggleComplete)
    if (newlyUnlockedAchievementIds.isNotEmpty) {
      eventType = 'achievement';
    }

    if (eventType == null) {
      return null;
    }

    final shouldShow = await _local.shouldShowMotivation(userId, eventType);
    if (!shouldShow) {
      return null;
    }

    await _local.recordMotivationShown(userId, eventType);

    final sessionCompleted = await _local.getSessionCompletedCount(userId);
    final progressFacts = _buildMotivationFacts(
      current: current,
      completedProblem: completedProblem,
      eventType: eventType,
      sessionCompleted: sessionCompleted,
    );

    try {
      final motivation = await MotivationService().getMotivation(
        progressFacts: progressFacts,
      );
      return motivation;
    } catch (e) {
      debugPrint('Motivation generation failed: $e');
      return MotivationService.getFallbackMessage(
        eventType: eventType,
        sessionCompleted: sessionCompleted,
      );
    }
  }

  String _buildMotivationFacts({
    required AppState current,
    required Problem completedProblem,
    required String eventType,
    required int sessionCompleted,
  }) {
    final facts = <String, dynamic>{};

    facts['event_type'] = eventType;
    facts['completed_today'] = current.todayCompleted;
    facts['session_completed'] = sessionCompleted;
    facts['daily_goal'] = current.dailyGoal;
    facts['current_streak'] = current.currentStreak;
    facts['total_completed'] = current.completed;
    facts['total_problems'] = current.problems.length;
    facts['problem_difficulty'] = completedProblem.difficulty;
    facts['problem_topic'] = completedProblem.topic;

    if (eventType == 'daily_goal') {
      facts['goal_reached'] = true;
    }

    if (eventType.startsWith('streak_')) {
      facts['streak_milestone'] = eventType.replaceAll('streak_', '');
    }

    return facts.entries.map((e) => '${e.key}: ${e.value}').join('\n');
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
            orElse: () {
              debugPrint('Skipping sync for unknown problem ID: $problemId');
              return state.value!.problems.first;
            },
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

      final updated = <String, ProblemProgress>{};

      for (final row in rows) {
        final slug = row['problems']['slug'] as String;
        final problem = current.problems.firstWhere(
          (p) => p.slug == slug,
          orElse: () {
            debugPrint('Skipping cloud sync for unknown slug: $slug');
            return current.problems.first;
          },
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

      final persistedLongestStreak =
          await _persistLongestStreak(user.id, updated);

      await _local.saveProgress(
        user.id,
        updated,
      );

      state = AsyncData(
        current.copyWith(
          progress: updated,
          persistedLongestStreak: persistedLongestStreak,
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

  ProblemProgress _progressFromMap(Map<String, dynamic> value) {
    return ProblemProgress(
      completed: value['completed'] == true,
      completedAt: value['completedAt'] == null
          ? null
          : DateTime.tryParse(value['completedAt'].toString()),
      notes: value['notes'] ?? '',
      reviewDueAt: value['reviewDueAt'] == null
          ? null
          : DateTime.tryParse(value['reviewDueAt'].toString()),
      lastReviewedAt: value['lastReviewedAt'] == null
          ? null
          : DateTime.tryParse(value['lastReviewedAt'].toString()),
    );
  }

  Future<int> _persistLongestStreak(
    String userId,
    Map<String, ProblemProgress> progress,
  ) async {
    final calculated = StreakCalculator.calculate(
      progress.values
          .where((p) => p.completed && p.completedAt != null)
          .map((p) => p.completedAt!),
    ).longest;

    final prefs = await _local.loadPrefs(userId);
    final locallyStored = (prefs['longestStreak'] as num?)?.toInt() ?? 0;

    try {
      final stored = await _remote.fetchLongestStreak(userId);
      final highWaterMark =
          math.max(calculated, math.max(stored, locallyStored));
      if (highWaterMark > stored) {
        await _remote.saveLongestStreak(userId, highWaterMark);
      }
      prefs['longestStreak'] = highWaterMark;
      await _local.savePrefs(userId, prefs);
      return highWaterMark;
    } catch (e, stack) {
      debugPrint('Longest streak sync failed: $e');
      debugPrintStack(stackTrace: stack);
      final highWaterMark = math.max(calculated, locallyStored);
      prefs['longestStreak'] = highWaterMark;
      await _local.savePrefs(userId, prefs);
      return highWaterMark;
    }
  }
}
