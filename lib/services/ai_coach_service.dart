import 'package:supabase_flutter/supabase_flutter.dart';

class AiCoachService {
  final SupabaseClient _client;

  AiCoachService({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  Future<String> getHint({
    required String title,
    required String topic,
    required String difficulty,
    required String mode,
    String notes = '',
  }) async {
    final response = await _client.functions.invoke(
      'ai-coach',
      body: {
        'title': title,
        'topic': topic,
        'difficulty': difficulty,
        'mode': mode,
        'notes': notes,
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
}
