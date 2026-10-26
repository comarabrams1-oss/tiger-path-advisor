import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tiger_path/data/program_registry.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/screens/generated_schedule_screen.dart';
import 'package:tiger_path/services/preferences_service.dart';
import 'package:tiger_path/services/schedule_assistant_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';

void main() {
  testWidgets(
    'asking Gemini for 16 credits rebuilds the engineering timetable in place',
    (tester) async {
      selectDemoStudent(engineeringStudentEmail);
      PreferencesService.useProfile('engineering-credit-target-test');
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
      PreferencesService.savePreferences(prefs);
      addTearDown(() {
        selectDemoStudent(null);
        PreferencesService.useProfile('demo-cs-2024');
      });
      final sections =
          (jsonDecode(
                File('assets/data/course_sections_spring_2027.json')
                    .readAsStringSync(),
              ) as List)
              .map((j) => CourseSection.fromJson(Map<String, dynamic>.from(j)))
              .toList();
      final plan = SemesterPlanService().generatePlan(
        student: engineeringStudent,
        program: programFor(engineeringStudent),
        catalog: catalogFor(engineeringStudent),
        maxCredits: 15,
        sections: sections,
        preferences: prefs,
      );
      rootBundle.clear();
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          final path = const StringCodec().decodeMessage(message)!;
          return ByteData.sublistView(
            File('build/unit_test_assets/$path').readAsBytesSync(),
          );
        },
      );
      addTearDown(() {
        rootBundle.clear();
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          null,
        );
      });
      tester.view.physicalSize = const Size(1100, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final assistant = ScheduleAssistantService(
        client: MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['context']['schedule']['requestedCredits'], 16);
          expect(
            body['context']['schedule']['program'],
            'Computer Engineering',
          );
          return http.Response(
            jsonEncode({
              'summary': 'Aim for 16 credits',
              'preferences': prefs.toJson()..remove('preferredProfessors'),
              'sectionChoices': [],
              'courseChoices': ['AA 211'],
              'advisorReview': true,
            }),
            200,
          );
        }),
      );
      addTearDown(assistant.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: GeneratedScheduleScreen(plan: plan, assistant: assistant),
        ),
      );
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
      }

      await settle();
      await tester.enterText(find.byType(TextField), 'Get me to 16 credits');
      await tester.tap(find.text('Update schedule'));
      await settle();
      expect(find.byType(GeneratedScheduleScreen), findsOneWidget);
      expect(find.textContaining('16 of 16 credits'), findsOneWidget);
      expect(PreferencesService.preferences!.maxCredits, 16);
      expect(tester.takeException(), isNull);
    },
  );
}
