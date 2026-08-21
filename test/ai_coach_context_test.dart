import 'package:flutter_test/flutter_test.dart';
import 'package:mins_prep/models/problem.dart';
import 'package:mins_prep/providers/app_controller.dart';

void main() {
  test(
      'buildAiCoachContext returns compact summary without duplicating problem data',
      () {
    final problems = [
      const Problem(
        id: 'p1',
        title: 'Two Sum',
        topic: 'Arrays',
        difficulty: 'Easy',
        order: 1,
        slug: 'two-sum',
        externalUrl: 'https://example.com',
      ),
      const Problem(
        id: 'p2',
        title: 'Group Anagrams',
        topic: 'Hash Map',
        difficulty: 'Medium',
        order: 2,
        slug: 'group-anagrams',
        externalUrl: 'https://example.com',
      ),
      const Problem(
        id: 'p3',
        title: 'Binary Tree Level Order',
        topic: 'Trees',
        difficulty: 'Medium',
        order: 3,
        slug: 'binary-tree-level-order',
        externalUrl: 'https://example.com',
      ),
    ];

    final progress = {
      'p1': const ProblemProgress(completed: true),
      'p2': const ProblemProgress(completed: false),
      'p3': const ProblemProgress(completed: true),
    };

    final state = AppState(
      problems: problems,
      progress: progress,
      dailyGoal: 2,
      dailyFocusTopics: const ['Arrays', 'Trees'],
      dailyPrepProblemIds: const ['p1', 'p2'],
    );

    final context = state.buildAiCoachContext();

    expect(context['progress'], {
      'completed': 2,
      'total': 3,
      'completion_percentage': 67,
    });
    expect(context['daily_prep'], {
      'daily_goal': 2,
      'completed_today': 0,
      'remaining_today': 2,
    });
    expect(context['focus_areas'], {
      'topics': ['Arrays', 'Trees'],
    });
    expect(context['streak'], {
      'current': 0,
      'longest': 0,
    });
    expect(context.containsKey('current_problem'), isFalse);
    expect(context['topic_performance'], isA<Map<String, dynamic>>());
  });
}
