import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/data/program_registry.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/screens/ai_advisor_screen.dart';
import 'package:tiger_path/screens/generated_schedule_screen.dart';
import 'package:tiger_path/services/ai_advisor_service.dart';
import 'package:tiger_path/services/advisor_history_service.dart';
import 'package:tiger_path/services/schedule_assistant_service.dart';
import 'package:tiger_path/services/schedule_draft_service.dart';
import 'package:tiger_path/services/schedule_generation_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';
import 'package:tiger_path/services/preferences_service.dart';

void main() {
  testWidgets(
    'main chat applies the original request to its own profile draft through one action tap',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      selectDemoStudent(null);
      PreferencesService.useProfile('chat-draft-profile');
      addTearDown(() => PreferencesService.useProfile('demo-cs-2024'));
      final sections =
          (jsonDecode(
                File('assets/data/course_sections_spring_2027.json')
                    .readAsStringSync(),
              ) as List)
              .map((j) => CourseSection.fromJson(Map<String, dynamic>.from(j)))
              .toList();
      const prefs = SchedulePreferences(
        preferredTime: 'No Preference',
        preferredDays: [],
        avoidedDays: [],
        preferredProfessors: [],
        maxCredits: 16,
        avoidEarlyClasses: false,
        avoidLateClasses: false,
        minimizeGaps: true,
      );
      PreferencesService.savePreferences(prefs);
      final plan = SemesterPlanService().generatePlan(
        student: testStudent,
        program: activeProgram,
        catalog: activeCatalog,
        maxCredits: 16,
        sections: sections,
        preferences: prefs,
        preferredSections: {'PHYS 234': '02'},
        preferredCourses: ['PHYS 234'],
        priorityCourseCodes: ['PHYS 234'],
      );
      final schedule = ScheduleGenerationService().generateSchedule(
        plan: plan,
        sections: sections,
        instructors: [],
        preferences: prefs,
        preferredSections: {'PHYS 234': '02'},
      );
      ScheduleDraftService.save(
        ScheduleDraft(
          plan: plan,
          schedule: schedule,
          preferences: prefs,
          sectionPreferences: {'PHYS 234': '02'},
        ),
      );
      PreferencesService.useProfile('other-student');
      expect(ScheduleDraftService.current, isNull);
      PreferencesService.useProfile('chat-draft-profile');
      var calls = 0;
      final chat = AiAdvisorService(
        client: MockClient(
          (_) async => throw StateError(
            'A schedule edit must not become an explanation-only reply.',
          ),
        ),
      );
      final assistant = ScheduleAssistantService(
        client: MockClient((request) async {
          calls++;
          final body = jsonDecode(request.body);
          expect(
            body['messages'].single['text'],
            'i want to take dr pandits physics class',
          );
          expect(
            (body['context']['schedule']['selected'] as List).any(
              (s) => s['courseCode'] == 'PHYS 234',
            ),
            isTrue,
          );
          return http.Response(
            jsonEncode({
              'summary': 'Select the eligible Pandit Physics II section',
              'preferences': {
                ...prefs.toJson(),
                'preferredProfessors': ['Pandit, Rishi'],
              },
              'sectionChoices': [
                {'courseCode': 'PHYS 234', 'section': '01'},
              ],
              'courseChoices': [],
              'excludedCourses': [],
              'excludedSections': [],
              'needsClarification': false,
              'advisorReview': true,
            }),
            200,
          );
        }),
      );
      addTearDown(chat.dispose);
      addTearDown(assistant.dispose);
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
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: AiAdvisorScreen(
            student: testStudent,
            service: chat,
            scheduleAssistant: assistant,
            history: const AdvisorHistoryService(
              profileId: 'chat-draft-profile',
            ),
          ),
        ),
      );
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await tester.pumpAndSettle();
      }

      await settle();
      await tester.enterText(
        find.byType(TextField),
        'i want to take dr pandits physics class',
      );
      await tester.tap(find.byTooltip('Send question'));
      await settle();
      expect(calls, 0);
      final action = find.widgetWithText(
        FilledButton,
        'Update current schedule',
      );
      expect(action, findsOneWidget);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await settle();
      await settle();
      expect(find.byType(GeneratedScheduleScreen), findsOneWidget);
      expect(calls, 1);
      expect(
        ScheduleDraftService.current!.schedule.scheduled
            .singleWhere((s) => s.section.courseCode == 'PHYS 234')
            .section
            .instructorDisplay,
        'Pandit, Rishi',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
