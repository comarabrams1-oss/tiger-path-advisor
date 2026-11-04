import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/course_section.dart';
import '../models/schedule_preferences.dart';

class ScheduleUpdate {
  final String summary;
  final List<String> courseChoices;
  final bool advisorReview;
  final SchedulePreferences preferences;
  final Map<String, String> sectionChoices;
  const ScheduleUpdate(
    this.summary,
    this.preferences,
    this.sectionChoices,
    this.courseChoices,
    this.advisorReview,
  );
}

class ScheduleAssistantService {
  final http.Client _client;
  final Uri endpoint;
  ScheduleAssistantService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      endpoint = endpoint ?? Uri.base.resolve('/.netlify/functions/advisor');

  /// Preserve one unambiguous numeric credit request even if the model
  /// accidentally echoes the old limit. Complex/range requests stay with Gemini.
  static int? explicitCreditTarget(String question) {
    final matches = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*(?:credit(?:s| hours?)?|hours?|hrs?)\b',
      caseSensitive: false,
    ).allMatches(question).toList();
    if (matches.length != 1) return null;
    final value = double.parse(matches.single[1]!);
    if (value != value.roundToDouble() || value < 12 || value > 18) {
      throw const FormatException(
        'Choose a whole-credit target between 12 and 18.',
      );
    }
    return value.toInt();
  }

  Future<ScheduleUpdate> update(
    String question,
    Map<String, Object?> context,
    SchedulePreferences current,
    List<CourseSection> available, {
    List<String> eligibleCourses = const [],
  }) async {
    final requestedCredits = explicitCreditTarget(question);
    final response = await _client
        .post(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'mode': 'schedule',
            'messages': [
              {'role': 'user', 'text': question},
            ],
            'context': {
              'schedule': {...context, 'requestedCredits': requestedCredits},
            },
          }),
        )
        .timeout(const Duration(seconds: 50));
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      data = null;
    }
    if (response.statusCode != 200) {
      final code = data is Map ? data['code'] : null;
      throw StateError(switch (code) {
        'PROVIDER_BUSY' => 'Gemini is busy. Please retry shortly.',
        'QUOTA' => 'Gemini quota reached. Please wait and retry.',
        'NOT_CONFIGURED' => 'Schedule assistance needs server configuration.',
        'TIMEOUT' => 'Gemini took too long. Please retry.',
        'MODEL_UNAVAILABLE' => 'The configured AI model is unavailable. The server setting needs updating.',
        'PROVIDER_ACCESS' =>
          'AI server access needs attention. Your schedule is unchanged.',
        _ =>
          response.statusCode == 429
              ? 'AI request limit reached. Please wait before retrying.'
              : 'Schedule assistance is unavailable. Please retry.',
      });
    }
    if (data is! Map ||
        data['preferences'] is! Map ||
        data['summary'] is! String ||
        (data['summary'] as String).length > 1500 ||
        data['sectionChoices'] is! List ||
        (data['sectionChoices'] as List).length > 18) {
      throw const FormatException('Invalid schedule update');
    }
    final courses = data['courseChoices'];
    if (courses is! List ||
        courses.length > 18 ||
        courses.any((code) => !eligibleCourses.contains(code)) ||
        data['advisorReview'] is! bool) {
      throw const FormatException('Unverified course alternatives');
    }
    final p = data['preferences'] as Map;
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    List<String> dayList(String key) {
      final list = p[key];
      if (list is! List ||
          list.length > 5 ||
          list.any((d) => !days.contains(d))) {
        throw const FormatException('Invalid days');
      }
      return list.cast<String>().toSet().toList();
    }

    if (![
          'No Preference',
          'Morning',
          'Afternoon',
          'Evening',
        ].contains(p['preferredTime']) ||
        p['maxCredits'] is! int ||
        p['maxCredits'] < 12 ||
        p['maxCredits'] > 18 ||
        p['avoidEarlyClasses'] is! bool ||
        p['avoidLateClasses'] is! bool ||
        p['minimizeGaps'] is! bool) {
      throw const FormatException('Invalid schedule preferences');
    }
    final selections = <String, String>{};
    for (final choice in data['sectionChoices'] as List) {
      if (choice is! Map ||
          choice['courseCode'] is! String ||
          choice['section'] is! String ||
          selections.containsKey(choice['courseCode']) ||
          !available.any(
            (section) =>
                section.courseCode == choice['courseCode'] &&
                section.sectionNumber == choice['section'] &&
                section.isOpen &&
                section.hasOpenSeats,
          )) {
        throw const FormatException('Unverified section choice');
      }
      selections[choice['courseCode'] as String] = choice['section'] as String;
    }
    return ScheduleUpdate(
      data['summary'] as String,
      SchedulePreferences(
        preferredTime: p['preferredTime'] as String,
        preferredDays: dayList('preferredDays'),
        avoidedDays: dayList('avoidedDays'),
        preferredProfessors: current.preferredProfessors,
        maxCredits: requestedCredits ?? p['maxCredits'] as int,
        avoidEarlyClasses: p['avoidEarlyClasses'] as bool,
        avoidLateClasses: p['avoidLateClasses'] as bool,
        minimizeGaps: p['minimizeGaps'] as bool,
      ),
      selections,
      courses.cast<String>(),
      data['advisorReview'] as bool,
    );
  }

  void dispose() => _client.close();
}
