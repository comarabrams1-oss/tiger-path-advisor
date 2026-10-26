import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/services/schedule_assistant_service.dart';

void main() {
  const prefs = SchedulePreferences(
    preferredTime: 'No Preference',
    preferredDays: [],
    avoidedDays: [],
    preferredProfessors: [],
    maxCredits: 15,
    avoidEarlyClasses: false,
    avoidLateClasses: false,
    minimizeGaps: true,
  );
  const section = CourseSection(
    courseCode: 'CSC 237',
    sectionNumber: '01',
    instructorId: '',
    term: 'Spring',
    days: ['Monday'],
    startMinutes: 600,
    endMinutes: 650,
    location: '',
    deliveryMethod: '',
    openSeats: 5,
  );
  Map<String, Object?> reply(String sectionNumber) => {
    'summary': 'Updated',
    'courseChoices': <String>[],
    'advisorReview': true,
    'preferences': {
      ...prefs.toJson()..remove('preferredProfessors'),
      'avoidEarlyClasses': true,
      'avoidedDays': ['Friday'],
    },
    'sectionChoices': [
      {'courseCode': 'CSC 237', 'section': sectionNumber},
    ],
  };
  test(
    'accepts verified structured update without changing unrelated preferences',
    () async {
      final service = ScheduleAssistantService(
        client: MockClient((request) async {
          final data = jsonDecode(request.body);
          expect(data['mode'], 'schedule');
          expect(data['messages'].single['text'], 'No early classes or Friday');
          return http.Response(jsonEncode(reply('01')), 200);
        }),
      );
      addTearDown(service.dispose);
      final update = await service.update(
        'No early classes or Friday',
        {},
        prefs,
        [section],
      );
      expect(update.preferences.avoidEarlyClasses, isTrue);
      expect(update.preferences.avoidLateClasses, isFalse);
      expect(update.preferences.avoidedDays, ['Friday']);
      expect(update.sectionChoices, {'CSC 237': '01'});
    },
  );
  test('rejects invented sections and invalid credit limits', () async {
    var payload = reply('invented');
    final service = ScheduleAssistantService(
      client: MockClient((_) async => http.Response(jsonEncode(payload), 200)),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.update('Try another section', {}, prefs, [section]),
      throwsFormatException,
    );
    payload = reply('01');
    (payload['preferences'] as Map)['maxCredits'] = 30;
    await expectLater(
      service.update('30 credits', {}, prefs, [section]),
      throwsFormatException,
    );
  });
  test('explicit requested credits override a stale model target without changing other preferences', () async {
    final service = ScheduleAssistantService(
      client: MockClient((request) async {
        final payload = jsonDecode(request.body);
        expect(payload['context']['schedule']['requestedCredits'], 16);
        return http.Response(jsonEncode(reply('01')), 200);
      }),
    );
    addTearDown(service.dispose);
    final update = await service.update('Get me to 16 credits', {}, prefs, [
      section,
    ]);
    expect(update.preferences.maxCredits, 16);
    expect(update.preferences.avoidEarlyClasses, isTrue);
    expect(update.preferences.minimizeGaps, isTrue);
  });
  test('unsupported credit requests are rejected before an API call', () async {
    var called = false;
    final service = ScheduleAssistantService(
      client: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.update('I want 21 credits', {}, prefs, [section]),
      throwsFormatException,
    );
    expect(called, isFalse);
    expect(
      ScheduleAssistantService.explicitCreditTarget('15 to 18 credits'),
      18,
    );
    expect(
      ScheduleAssistantService.explicitCreditTarget('16 credits or 18 credits'),
      isNull,
    );
  });
}
