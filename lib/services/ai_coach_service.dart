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
    return _invoke(
      title: title,
      topic: topic,
      difficulty: difficulty,
      mode: mode,
      notes: notes,
    );
  }

  Future<String> getInterviewQuestion({
    required String title,
    required String topic,
    required String difficulty,
    required int questionNumber,
    String notes = '',
  }) async {
    return _invoke(
      title: title,
      topic: topic,
      difficulty: difficulty,
      mode: 'interview_question',
      notes: notes,
      questionNumber: questionNumber,
    );
  }

  Future<String> getInterviewFeedback({
    required String title,
    required String topic,
    required String difficulty,
    required String question,
    required String answer,
    required int questionNumber,
    String notes = '',
  }) async {
    return _invoke(
      title: title,
      topic: topic,
      difficulty: difficulty,
      mode: 'interview_feedback',
      notes: notes,
      question: question,
      answer: answer,
      questionNumber: questionNumber,
    );
  }

  Future<String> _invoke({
    required String title,
    required String topic,
    required String difficulty,
    required String mode,
    String notes = '',
    String? question,
    String? answer,
    int? questionNumber,
  }) async {
    final response = await _client.functions.invoke(
      'ai-coach',
      body: {
        'title': title,
        'topic': topic,
        'difficulty': difficulty,
        'mode': mode,
        'notes': notes,
        if (question != null) 'question': question,
        if (answer != null) 'answer': answer,
        if (questionNumber != null) 'question_number': questionNumber,
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
