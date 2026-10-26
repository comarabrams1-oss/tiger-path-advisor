import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AdvisorAction {
  final String type;
  final String target;
  final String? primaryHex;
  final String? accentHex;
  final bool? darkMode;
  const AdvisorAction(
    this.type,
    this.target, {
    this.primaryHex,
    this.accentHex,
    this.darkMode,
  });
  static const themes = [
    'benedict',
    'light',
    'dark',
    'midnightPurple',
    'goldBlack',
    'highContrast',
    'custom',
  ];
  static const pages = [
    'transcript',
    'degreeProgress',
    'recommendations',
    'scheduleBuilder',
    'themeStudio',
  ];
  static AdvisorAction? parse(dynamic value) {
    if (value is! Map) return null;
    final type = value['type'];
    final target = value['target'];
    if (type == 'customTheme' &&
        target == 'custom' &&
        value['primaryHex'] is String &&
        value['accentHex'] is String &&
        RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value['primaryHex'] as String) &&
        RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value['accentHex'] as String) &&
        value['darkMode'] is bool) {
      return AdvisorAction(
        'customTheme',
        'custom',
        primaryHex: (value['primaryHex'] as String).toUpperCase(),
        accentHex: (value['accentHex'] as String).toUpperCase(),
        darkMode: value['darkMode'] as bool,
      );
    }
    if (type == 'changeTheme' && themes.contains(target) ||
        type == 'navigate' && pages.contains(target)) {
      return AdvisorAction(type as String, target as String);
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'type': type,
    'target': target,
    if (type == 'customTheme') ...{
      'primaryHex': primaryHex,
      'accentHex': accentHex,
      'darkMode': darkMode,
    },
  };
}

class AdvisorMessage {
  final String role;
  final String text;
  final List<AdvisorAction> actions;
  const AdvisorMessage(this.role, this.text, [this.actions = const []]);
  Map<String, String> toJson() => {'role': role, 'text': text};
  Map<String, Object?> toStorageJson() => {
    ...toJson(),
    'actions': actions.map((a) => a.toJson()).toList(),
  };
  factory AdvisorMessage.fromStorageJson(Map<String, dynamic> json) {
    if (!['user', 'assistant'].contains(json['role']) ||
        json['text'] is! String) {
      throw const FormatException('Invalid saved message');
    }
    return AdvisorMessage(
      json['role'] as String,
      json['text'] as String,
      (json['actions'] as List? ?? [])
          .map(AdvisorAction.parse)
          .whereType<AdvisorAction>()
          .take(3)
          .toList(),
    );
  }
}

class AdvisorReply {
  final String text;
  final List<AdvisorAction> actions;
  const AdvisorReply(this.text, this.actions);
}

class AdvisorException implements Exception {
  final String message;
  const AdvisorException(this.message);
}

class AiAdvisorService {
  final http.Client _client;
  final Uri endpoint;
  AiAdvisorService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      endpoint = endpoint ?? Uri.base.resolve('/.netlify/functions/advisor');

  Future<AdvisorReply> respond(
    List<AdvisorMessage> messages,
    Map<String, Object?> context,
  ) async {
    try {
      final response = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': messages.map((m) => m.toJson()).toList(),
              'context': context,
            }),
          )
          .timeout(const Duration(seconds: 50));
      dynamic body;
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        body = null;
      }
      if (response.statusCode != 200) {
        final code = body is Map ? body['code'] : null;
        final message = switch (code) {
          'PROVIDER_BUSY' => 'Gemini is temporarily busy. Your message is kept below; please retry shortly.',
          'QUOTA' => 'Gemini request quota reached. Wait a moment and retry; your free-tier quota may need to reset.',
          'MODEL_UNAVAILABLE' => 'The configured Gemini model is unavailable. The server model setting needs updating.',
          'PROVIDER_ACCESS' => 'Gemini rejected access. The server API key or permissions need attention.',
          'INVALID_RESPONSE' || 'INVALID_ACTION' => 'Gemini returned an invalid response or app action. Your message is kept below; please retry.',
          'EMPTY_RESPONSE' =>
            'Gemini returned no answer. Please rephrase or retry.',
          'TIMEOUT' => 'Gemini took too long to respond. Your message is kept below; please retry.',
          'CONNECTION' =>
            'The server could not connect to Gemini. Please try again.',
          _ =>
            response.statusCode == 429
                ? 'AI request limit reached. Wait a moment before retrying.'
                : response.statusCode == 503
                ? 'AI setup is not complete yet. Course Recommendations is still available.'
                : response.statusCode == 413
                ? 'This conversation is too large. Start a new chat.'
                : 'Gemini could not complete this request. Your message is kept below; please retry.',
        };
        throw AdvisorException(message);
      }
      if (body is! Map ||
          body['answer'] is! String ||
          (body['answer'] as String).trim().isEmpty) {
        throw const AdvisorException(
          'Gemini returned an unreadable answer. Please retry.',
        );
      }
      return AdvisorReply(
        body['answer'] as String,
        (body['actions'] as List? ?? [])
            .map(AdvisorAction.parse)
            .whereType<AdvisorAction>()
            .take(3)
            .toList(),
      );
    } on TimeoutException {
      throw const AdvisorException(
        'The advisor request timed out. Your message is kept below; please retry.',
      );
    } on AdvisorException {
      rethrow;
    } on Object {
      throw const AdvisorException(
        'Could not connect to the AI advisor. Please try again.',
      );
    }
  }

  Future<String> ask(
    List<AdvisorMessage> messages,
    Map<String, Object?> context,
  ) async => (await respond(messages, context)).text;

  void dispose() => _client.close();
}
