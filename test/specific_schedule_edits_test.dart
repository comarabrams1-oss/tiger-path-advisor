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
import 'package:tiger_path/screens/generated_schedule_screen.dart';
import 'package:tiger_path/services/course_priority_service.dart';
import 'package:tiger_path/services/schedule_assistant_service.dart';
import 'package:tiger_path/services/schedule_draft_service.dart';
import 'package:tiger_path/services/schedule_edit_context_service.dart';
import 'package:tiger_path/services/schedule_generation_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';
import 'package:tiger_path/services/preferences_service.dart';
import 'package:tiger_path/widgets/manual_schedule_editor.dart';

void main() {
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
  testWidgets('manual class picker fits a phone with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManualScheduleEditor(
            courseNames: const {'PHYS 234': 'Principles of Physics II'},
            schedule: const GeneratedSchedule(scheduled: [], unscheduled: []),
            sections: sections
                .where((s) => s.courseCode == 'PHYS 234')
                .toList(),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Principles');
    await tester.pumpAndSettle();
    expect(find.text('PHYS 234 · 01'), findsOneWidget);
    expect(find.text('PHYS 234 · 02'), findsOneWidget);
    expect(find.text('Principles of Physics II'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'Pandit');
    await tester.pumpAndSettle();
    expect(find.text('PHYS 234 · 02'), findsNothing);
    expect(find.text('Add'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('requested instructor survives choice truncation and selected times are sent', () {
    final chosen = sections.firstWhere((s) => s.courseCode == 'CSC 338');
    final plan = SemesterPlan(
      items: [
        SemesterPlanItem(
          type: SemesterPlanItemType.course,
          title: 'AI',
          courseCode: 'CSC 338',
          category: 'Major',
          credits: 3,
          reason: '',
        ),
      ],
      totalCredits: 3,
      maxCredits: 16,
    );
    final generated = ScheduleGenerationService().generateSchedule(
      plan: plan,
      sections: sections,
      instructors: [],
      preferences: prefs,
    );
    final filler = List.generate(
      130,
      (i) => CourseSection.fromJson({
        ...chosen.toJson(),
        'sectionNumber': 'noise$i',
      }),
    );
    final physics = sections.where((s) => s.courseCode == 'PHYS 234').toList();
    final context = ScheduleEditContextService.build(
      program: 'Computer Science',
      classification: 'Junior',
      term: 'Spring 2027',
      schedule: generated,
      preferences: prefs,
      candidates: [],
      available: [...filler, chosen, ...physics],
      question: "I want Dr Pandit's Physics class",
    );
    expect((context['choices'] as List).length, lessThanOrEqualTo(100));
    expect(
      (context['choices'] as List).any(
        (s) => s['courseCode'] == 'PHYS 234' && s['section'] == '01',
      ),
      isTrue,
    );
    expect(
      (context['selected'] as List).single['schedule'],
      contains('4:00 PM-5:15 PM'),
    );
    expect(
      (context['selected'] as List).single['instructors'],
      contains('Das, Debashis'),
    );
  });
  test('chat edit detection matches both real requests without hijacking ordinary advice or themes', () {
    expect(
      ScheduleDraftService.isEditRequest(
        'change the suggested 4 pm to 5:15 to a different class if possible',
      ),
      isTrue,
    );
    expect(
      ScheduleDraftService.isEditRequest(
        'i want to take dr pandits physics class',
      ),
      isTrue,
    );
    expect(
      ScheduleDraftService.isEditRequest('What classes do I still need?'),
      isFalse,
    );
    expect(
      ScheduleDraftService.isEditRequest('Change to the classic layout'),
      isFalse,
    );
  });
  testWidgets(
    'time replacement and Pandit request change the actual timetable, preserve exclusions and ask before guessing',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      selectDemoStudent(null);
      PreferencesService.useProfile('specific-edits');
      PreferencesService.savePreferences(prefs);
      addTearDown(() => PreferencesService.useProfile('demo-cs-2024'));
      final plan = SemesterPlanService().generatePlan(
        student: testStudent,
        program: activeProgram,
        catalog: activeCatalog,
        maxCredits: 16,
        sections: sections,
        preferences: prefs,
        preferredCourses: ['CSC 338', 'PHYS 234'],
        priorityCourseCodes: ['CSC 338', 'PHYS 234'],
        preferredSections: {'PHYS 234': '02'},
      );
      final before = ScheduleGenerationService().generateSchedule(
        plan: plan,
        sections: sections,
        instructors: [],
        preferences: prefs,
        preferredSections: {'PHYS 234': '02'},
      );
      expect(
        before.scheduled.any((s) => s.section.courseCode == 'CSC 338'),
        isTrue,
      );
      expect(
        before.scheduled
            .singleWhere((s) => s.section.courseCode == 'PHYS 234')
            .section
            .sectionNumber,
        '02',
      );
      var step = 0;
      var apiCalls = 0;
      final assistant = ScheduleAssistantService(
        client: MockClient((request) async {
          apiCalls++;
          final context = jsonDecode(request.body)['context']['schedule'];
          final teachers = step == 0 ? <String>[] : ['Pandit, Rishi'];
          if (step == 0) {
            expect(
              (context['selected'] as List).any(
                (s) =>
                    s['courseCode'] == 'CSC 338' &&
                    (s['schedule'] as String).contains('4:00 PM'),
              ),
              isTrue,
            );
          }
          return http.Response(
            jsonEncode({
              'summary': step == 2
                  ? 'Which 4 PM class do you mean?'
                  : 'Proposed verified schedule changes',
              'preferences': {
                ...prefs.toJson(),
                'preferredProfessors': teachers,
              },
              'sectionChoices': step == 0
                  ? []
                  : [
                      {'courseCode': 'PHYS 234', 'section': '01'},
                    ],
              'courseChoices': [],
              'excludedCourses': ['CSC 338'],
              'excludedSections': [],
              'advisorReview': true,
              'needsClarification': step == 2,
            }),
            200,
          );
        }),
      );
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
          home: GeneratedScheduleScreen(
            plan: plan,
            assistant: assistant,
            draft: ScheduleDraft(
              plan: plan,
              schedule: before,
              preferences: prefs,
              sectionPreferences: {'PHYS 234': '02'},
            ),
          ),
        ),
      );
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
      }

      await settle();
      await tester.enterText(
        find.byType(TextField),
        'change the suggested 4 pm to 5:15 to a different class if possible',
      );
      await tester.tap(find.text('Update schedule'));
      await settle();
      final swapped = ScheduleDraftService.current!;
      expect(
        swapped.schedule.scheduled.any(
          (s) => s.section.courseCode == 'CSC 338',
        ),
        isFalse,
      );
      expect(swapped.excludedCourses, ['CSC 338']);
      expect(swapped.schedule.scheduledCredits, greaterThan(0));
      expect(
        testStudent.courses.any((c) => c.courseCode == 'CSC 338'),
        isFalse,
      );
      step = 1;
      await tester.enterText(
        find.byType(TextField),
        'i want to take dr pandits physics class',
      );
      await tester.tap(find.text('Update schedule'));
      await settle();
      final changed = ScheduleDraftService.current!;
      final physics = changed.schedule.scheduled.singleWhere(
        (s) => s.section.courseCode == 'PHYS 234',
      );
      expect(physics.section.sectionNumber, '01');
      expect(physics.section.instructorDisplay, 'Pandit, Rishi');
      expect(
        changed.schedule.scheduled.any(
          (s) => s.section.courseCode == 'CSC 238',
        ),
        isFalse,
        reason:
            'CSC 238 conflicts with Pandit physics and must not silently win.',
      );
      expect(
        changed.schedule.scheduled.any(
          (s) => s.section.courseCode == 'CSC 338',
        ),
        isFalse,
      );
      expect(changed.preferences.preferredProfessors, ['Pandit, Rishi']);
      expect(changed.schedule.unscheduled, isEmpty);
      await tester.tap(find.text('View section results'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('PHYS 234 section 01 selected with Pandit, Rishi.'),
        findsOneWidget,
      );
      step = 2;
      final codes = changed.schedule.scheduled
          .map((s) => s.section.fullCourseCode)
          .toList();
      await tester.enterText(find.byType(TextField), 'Change the 4 PM class');
      await tester.tap(find.text('Update schedule'));
      await settle();
      expect(
        find.textContaining(
          'Which 4 PM class do you mean? Your schedule is unchanged.',
        ),
        findsOneWidget,
      );
      expect(
        ScheduleDraftService.current!.schedule.scheduled
            .map((s) => s.section.fullCourseCode)
            .toList(),
        codes,
      );
      final callsBeforeManual = apiCalls;
      Future<void> openEditor() async {
        await tester.ensureVisible(find.text('Add or edit classes'));
        await tester.tap(find.text('Add or edit classes'));
        await tester.pumpAndSettle();
      }

      await openEditor();
      await tester.tap(find.byTooltip('Remove PHYS 234'));
      await settle();
      expect(
        ScheduleDraftService.current!.schedule.scheduled.any(
          (s) => s.section.courseCode == 'PHYS 234',
        ),
        isFalse,
      );
      expect(
        ScheduleDraftService.current!.excludedCourses,
        contains('PHYS 234'),
      );
      await openEditor();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search course, instructor, or time'),
        'PHYS 234',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add').first);
      await settle();
      expect(
        ScheduleDraftService.current!.schedule.scheduled.any(
          (s) =>
              s.section.courseCode == 'PHYS 234' &&
              s.section.sectionNumber == '01',
        ),
        isTrue,
      );
      await openEditor();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search course, instructor, or time'),
        'PHYS 234',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch'));
      await settle();
      expect(
        ScheduleDraftService.current!.schedule.scheduled
            .singleWhere((s) => s.section.courseCode == 'PHYS 234')
            .section
            .sectionNumber,
        '02',
      );
      final pinnedDraft = ScheduleDraftService.current!;
      await openEditor();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search course, instructor, or time'),
        'CSC 434',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await settle();
      expect(ScheduleDraftService.current, same(pinnedDraft));
      expect(find.textContaining('Your draft is unchanged.'), findsOneWidget);

      final repair = find.text('Resolve issues and fill schedule');
      await tester.ensureVisible(repair);
      await tester.tap(repair);
      await settle();
      expect(
        ScheduleDraftService.current!.schedule.scheduled
            .singleWhere((item) => item.section.courseCode == 'PHYS 234')
            .section
            .sectionNumber,
        '02',
      );
      expect(
        ScheduleDraftService.current!.excludedCourses,
        contains('CSC 338'),
      );
      expect(
        apiCalls,
        callsBeforeManual,
        reason: 'Manual edits and the built-in repair button must work without Gemini',
      );
      expect(ScheduleDraftService.current!.schedule.unscheduled, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
