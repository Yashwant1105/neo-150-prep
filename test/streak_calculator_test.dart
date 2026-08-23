import 'package:flutter_test/flutter_test.dart';
import 'package:mins_prep/models/problem.dart';
import 'package:mins_prep/providers/app_controller.dart';
import 'package:mins_prep/services/streak_calculator.dart';

void main() {
  final today = DateTime(2026, 8, 23, 12);

  test('calculates current and longest streaks from unique completed days', () {
    final result = StreakCalculator.calculate(
      [
        today,
        DateTime(2026, 8, 23, 18),
        DateTime(2026, 8, 22),
        DateTime(2026, 8, 21),
      ],
      now: today,
    );

    expect(result.current, 3);
    expect(result.longest, 3);
  });

  test('allows yesterday to start the current streak', () {
    final result = StreakCalculator.calculate(
      [DateTime(2026, 8, 22)],
      now: today,
    );

    expect(result.current, 1);
    expect(result.longest, 1);
  });

  test('a missing day breaks current streak but preserves historical longest',
      () {
    final result = StreakCalculator.calculate(
      [
        today,
        DateTime(2026, 8, 21),
        DateTime(2026, 8, 20),
      ],
      now: today,
    );

    expect(result.current, 1);
    expect(result.longest, 2);
  });

  test('returns zero when there are no completion timestamps', () {
    final result = StreakCalculator.calculate([], now: today);

    expect(result.current, 0);
    expect(result.longest, 0);
  });

  test('normalizes offset timestamps to the local calendar date', () {
    final result = StreakCalculator.calculate(
      [DateTime.parse('2026-08-22T23:30:00-05:00')],
      now: DateTime(2026, 8, 23, 12),
    );

    expect(result.longest, 1);
  });

  test('persisted longest streak remains a high-water mark', () {
    final state = AppState(
      problems: const [],
      progress: const <String, ProblemProgress>{},
      persistedLongestStreak: 7,
    );

    expect(state.currentStreak, 0);
    expect(state.longestStreak, 7);
  });

  test('separate AppState instances only calculate from their own progress',
      () {
    final first = AppState(
      problems: const [],
      progress: {
        'first': ProblemProgress(
          completed: true,
          completedAt: DateTime.now(),
        ),
      },
    );
    final second = AppState(
      problems: const [],
      progress: const <String, ProblemProgress>{},
    );

    expect(first.currentStreak, 1);
    expect(second.currentStreak, 0);
  });
}
