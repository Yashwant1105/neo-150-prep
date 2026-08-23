class StreakResult {
  final int current;
  final int longest;

  const StreakResult({
    required this.current,
    required this.longest,
  });
}

class StreakCalculator {
  const StreakCalculator._();

  static StreakResult calculate(
    Iterable<DateTime> completionTimestamps, {
    DateTime? now,
  }) {
    final days = completionTimestamps.map(_localDate).toSet().toList()..sort();

    if (days.isEmpty) {
      return const StreakResult(current: 0, longest: 0);
    }

    final daySet = days.toSet();
    final today = _localDate(now ?? DateTime.now());
    var cursor = today;

    if (!daySet.contains(cursor)) {
      cursor = _previousDay(cursor);
    }

    var current = 0;
    while (daySet.contains(cursor)) {
      current++;
      cursor = _previousDay(cursor);
    }

    var longest = 1;
    var run = 1;

    for (var i = 1; i < days.length; i++) {
      if (_calendarDistance(days[i - 1], days[i]) == 1) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }

    return StreakResult(current: current, longest: longest);
  }

  static DateTime _localDate(DateTime timestamp) {
    final local = timestamp.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _previousDay(DateTime date) =>
      DateTime(date.year, date.month, date.day - 1);

  static int _calendarDistance(DateTime first, DateTime second) {
    final firstUtc = DateTime.utc(first.year, first.month, first.day);
    final secondUtc = DateTime.utc(second.year, second.month, second.day);
    return secondUtc.difference(firstUtc).inDays;
  }
}
