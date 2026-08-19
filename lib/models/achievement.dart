class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.unlockedAt,
  });

  bool get unlocked => unlockedAt != null;

  factory Achievement.fromMap(
    Map<String, dynamic> map, {
    DateTime? unlockedAt,
  }) {
    return Achievement(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      icon: map['icon'] as String,
      unlockedAt: unlockedAt,
    );
  }
}
