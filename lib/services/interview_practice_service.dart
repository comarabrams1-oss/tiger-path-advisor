import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'advisor_endpoint.dart';

class InterviewQuestion {
  final String id;
  final String text;
  const InterviewQuestion(this.id, this.text);
}

class InterviewFeedback {
  final int relevance;
  final int specificity;
  final int clarity;
  final String strength;
  final String nextStep;

  const InterviewFeedback({
    required this.relevance,
    required this.specificity,
    required this.clarity,
    required this.strength,
    required this.nextStep,
  });

  factory InterviewFeedback.fromJson(Object? data) {
    if (data is! Map) throw const FormatException('Invalid interview feedback');
    int score(String key) {
      final value = data[key];
      if (value is int && value >= 1 && value <= 5) return value;
      throw const FormatException('Invalid interview score');
    }

    String note(String key) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty && value.length <= 600) {
        return value.trim();
      }
      throw const FormatException('Invalid interview feedback');
    }

    return InterviewFeedback(
      relevance: score('relevance'),
      specificity: score('specificity'),
      clarity: score('clarity'),
      strength: note('strength'),
      nextStep: note('nextStep'),
    );
  }

  Map<String, Object> toJson() => {
    'relevance': relevance,
    'specificity': specificity,
    'clarity': clarity,
    'strength': strength,
    'nextStep': nextStep,
  };
}

class InterviewPracticeException implements Exception {
  final String message;
  const InterviewPracticeException(this.message);
}

class InterviewPracticeService {
  final http.Client _client;
  final Uri endpoint;
  InterviewPracticeService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      endpoint = endpoint ?? advisorEndpoint;

  static Future<List<InterviewQuestion>> loadQuestions() async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/data/interview_questions.json'),
    ) as List;
    return [
      for (final item in data)
        InterviewQuestion(item['id'] as String, item['text'] as String),
    ];
  }

  Future<InterviewFeedback> review(
    InterviewQuestion question,
    String answer,
  ) async {
    final text = answer.trim();
    if (text.isEmpty || text.length > 4000) {
      throw const InterviewPracticeException(
        'Write an answer between 1 and 4,000 characters.',
      );
    }
    try {
      final response = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mode': 'interview',
              'questionId': question.id,
              'answer': text,
            }),
          )
          .timeout(const Duration(seconds: 50));
      final Object? data = jsonDecode(response.body);
      if (response.statusCode == 200) return InterviewFeedback.fromJson(data);
      final code = data is Map ? data['code'] : null;
      throw InterviewPracticeException(switch (code) {
        'PROVIDER_BUSY' => 'Gemini is busy. Try again in a moment.',
        'QUOTA' => 'Gemini has reached its request quota. Try again later.',
        'NOT_CONFIGURED' || 'MODEL_UNAVAILABLE' || 'PROVIDER_ACCESS' => 'AI feedback is unavailable while the server configuration needs attention.',
        'TIMEOUT' => 'Gemini took too long. Try rating your answer again.',
        _ =>
          response.statusCode == 429
              ? 'Too many AI requests. Wait a moment and try again.'
              : 'Could not rate your answer. Try again.',
      });
    } on TimeoutException {
      throw const InterviewPracticeException(
        'Gemini took too long. Try rating your answer again.',
      );
    } on InterviewPracticeException {
      rethrow;
    } on Object {
      throw const InterviewPracticeException(
        'Could not rate your answer. Try again.',
      );
    }
  }

  void dispose() => _client.close();
}
