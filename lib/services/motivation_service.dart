import 'package:supabase_flutter/supabase_flutter.dart';

class MotivationService {
  final SupabaseClient _client;

  MotivationService({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  Future<String> getMotivation({
    required String progressFacts,
  }) async {
    final response = await _client.functions.invoke(
      'ai-coach',
      body: {
        'title': '',
        'topic': '',
        'difficulty': '',
        'mode': 'motivation',
        'notes': progressFacts,
      },
    );

    final data = response.data;

    if (data is! Map) {
      throw Exception('Invalid AI response.');
    }

    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    final text = data['text'];

    if (text == null || text.toString().trim().isEmpty) {
      throw Exception('AI returned an empty response.');
    }

    return text.toString().trim();
  }

  static String getFallbackMessage({
    required String eventType,
    int sessionCompleted = 0,
  }) {
    switch (eventType) {
      case 'daily_goal':
        return 'Goal complete. Nice work today.';
      case 'streak_7':
        return 'Seven days straight. You\'re building a habit.';
      case 'streak_14':
        return 'Two weeks of consistency. That\'s real progress.';
      case 'streak_30':
        return 'Thirty days. You\'re locked in.';
      case 'achievement':
        return 'Achievement unlocked. Keep pushing.';
      case 'hard_problem':
        if (sessionCompleted >= 3) {
          return 'Solid session with a hard problem.';
        }
        return 'That wasn\'t easy, but you got through it.';
      default:
        return 'Solid progress today.';
    }
  }
}
