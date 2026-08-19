class Problem {
  final String id;
  final String title;
  final String topic;
  final String difficulty;
  final int order;
  final String slug;
  final String externalUrl;

  const Problem({
    required this.id,
    required this.title,
    required this.topic,
    required this.difficulty,
    required this.order,
    required this.slug,
    required this.externalUrl,
  });

  factory Problem.fromJson(Map<String, dynamic> json) => Problem(
    id: json['id'],
    title: json['title'],
    topic: json['topic'],
    difficulty: json['difficulty'],
    order: json['order'],
    slug: json['slug'],
    externalUrl: json['external_url'],
  );
}

class ProblemProgress {
  final bool completed;
  final DateTime? completedAt;
  final String notes;
  final DateTime? reviewDueAt;
  final DateTime? lastReviewedAt;

  const ProblemProgress({
    this.completed = false,
    this.completedAt,
    this.notes = '',
    this.reviewDueAt,
    this.lastReviewedAt,
  });

  ProblemProgress copyWith({
    bool? completed,
    DateTime? completedAt,
    String? notes,
    DateTime? reviewDueAt,
    DateTime? lastReviewedAt,
    bool clearCompletedAt = false,
    bool clearReviewDueAt = false,
  }) => ProblemProgress(
    completed: completed ?? this.completed,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    notes: notes ?? this.notes,
    reviewDueAt: clearReviewDueAt ? null : (reviewDueAt ?? this.reviewDueAt),
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
  );
}
