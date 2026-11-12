import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/data/program_registry.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/screens/schedule_preferences_screen.dart';
import 'package:tiger_path/screens/semester_plan_screen.dart';
import 'package:tiger_path/services/course_section_repository.dart';
import 'package:tiger_path/services/preferences_service.dart';
import 'package:tiger_path/services/schedule_change_history_service.dart';
import 'package:tiger_path/services/schedule_draft_service.dart';
import 'package:tiger_path/services/schedule_generation_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a cold load restores the saved selections only for their profile',
    () async {
      SharedPreferences.setMockInitialValues({});
      selectDemoStudent(null);
      PreferencesService.useProfile('draft-writer');
      addTearDown(() {
        selectDemoStudent(null);
        PreferencesService.useProfile('demo-cs-2024');
      });
      const preferences = SchedulePreferences(
        preferredTime: 'Afternoon',
        preferredDays: ['Monday'],
        avoidedDays: [],
        preferredProfessors: ['Pandit'],
        maxCredits: 15,
        avoidEarlyClasses: true,
        avoidLateClasses: false,
        minimizeGaps: true,
      );
      const physics = SemesterPlanItem(
        type: SemesterPlanItemType.course,
        title: 'Principles of Physics II',
        category: 'Support',
        credits: 3,
        courseCode: 'PHYS 234',
        reason: 'Take after passing current prerequisites.',
        projectedEligibility: true,
      );
      const deferred = SemesterPlanItem(
        type: SemesterPlanItemType.course,
        title: 'Introduction to Computer Security',
        category: 'Major',
        credits: 3,
        courseCode: 'CSC 238',
        reason: 'Conflicts with the pinned Physics section.',
      );
      const plan = SemesterPlan(
        items: [physics],
        totalCredits: 3,
        maxCredits: 15,
        reviewItems: [deferred],
      );
      final sections = await CourseSectionRepository.loadForTerm(
        CourseSectionRepository.spring2027Term,
      );
      final selected = sections.firstWhere(
        (section) =>
            section.courseCode == 'PHYS 234' && section.sectionNumber == '01',
      );
      final schedule = ScheduleGenerationService().generateSchedule(
        plan: plan,
        sections: [selected],
        instructors: [],
        preferences: preferences,
      );
      expect(schedule.scheduled.single.section.sectionNumber, '01');
      expect(
        await ScheduleDraftService.save(
          ScheduleDraft(
            plan: plan,
            schedule: schedule,
            preferences: preferences,
            sectionPreferences: const {'PHYS 234': '01'},
            excludedCourses: const ['CSC 238'],
            excludedSections: const ['PHYS 234|02'],
            deferred: const [deferred],
            advisorReview: true,
          ),
        ),
        isTrue,
      );

      PreferencesService.useProfile('unrelated-student');
      await ScheduleDraftService.restore();
      expect(ScheduleDraftService.current, isNull);

      // An uncached profile simulates a fresh process reading the stored draft.
      final storage = await SharedPreferences.getInstance();
      await storage.setString(
        'schedule_draft_v1_draft-reader',
        storage.getString('schedule_draft_v1_draft-writer')!,
      );
      PreferencesService.useProfile('draft-reader');
      await ScheduleDraftService.restore();
      final restored = ScheduleDraftService.current!;
      expect(restored.schedule.scheduled.single.section.sectionNumber, '01');
      expect(restored.plan.items.single.projectedEligibility, isTrue);
      expect(restored.excludedCourses, ['CSC 238']);
      expect(restored.excludedSections, ['PHYS 234|02']);
      expect(restored.deferred.single.courseCode, 'CSC 238');
      expect(restored.advisorReview, isTrue);
      expect(PreferencesService.preferences!.preferredProfessors, ['Pandit']);
    },
  );

  test(
    'saving preferences persists independently of a generated draft',
    () async {
      SharedPreferences.setMockInitialValues({});
      PreferencesService.useProfile('preferences-writer');
      addTearDown(() => PreferencesService.useProfile('demo-cs-2024'));
      const preferences = SchedulePreferences(
        preferredTime: 'Morning',
        preferredDays: ['Friday'],
        avoidedDays: ['Monday'],
        preferredProfessors: ['Pandit'],
        maxCredits: 18,
        avoidEarlyClasses: true,
        avoidLateClasses: false,
        minimizeGaps: true,
      );
      expect(await PreferencesService.savePreferences(preferences), isTrue);
      final storage = await SharedPreferences.getInstance();
      await storage.setString(
        'schedule_preferences_v1_preferences-reader',
        storage.getString('schedule_preferences_v1_preferences-writer')!,
      );

      PreferencesService.useProfile('preferences-unrelated');
      await PreferencesService.restore();
      expect(PreferencesService.preferences, isNull);

      PreferencesService.useProfile('preferences-reader');
      await PreferencesService.restore();
      expect(PreferencesService.preferences?.toJson(), preferences.toJson());
      expect(ScheduleDraftService.current, isNull);
    },
  );

  testWidgets(
    'credit slider rebuild preserves manual choices and logs the actual change',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      selectDemoStudent(null);
      const profile = 'credit-slider-rebuild';
      PreferencesService.useProfile(profile);
      addTearDown(() => PreferencesService.useProfile('demo-cs-2024'));

      rootBundle.clear();
      final rows = jsonDecode(
        File('assets/data/course_sections_spring_2027.json').readAsStringSync(),
      ) as List;
      const eligibleCodes = {
        'CSC 237',
        'CSC 238',
        'CSC 338',
        'CSC 434',
        'CSC 436',
        'PHYS 234',
        'PHYS 214L',
      };
      final fixture = const StringCodec().encodeMessage(
        jsonEncode(
          rows
              .where((row) => eligibleCodes.contains(row['courseCode']))
              .toList(),
        ),
      );
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final path = const StringCodec().decodeMessage(message)!;
        if (path.endsWith('course_sections_spring_2027.json')) return fixture;
        return ByteData.sublistView(
          File('build/unit_test_assets/$path').readAsBytesSync(),
        );
      });
      addTearDown(() {
        rootBundle.clear();
        messenger.setMockMessageHandler('flutter/assets', null);
      });
      final published = await CourseSectionRepository.loadForTerm(
        CourseSectionRepository.spring2027Term,
      );
      const preferences = SchedulePreferences(
        preferredTime: 'Afternoon',
        preferredDays: [],
        avoidedDays: [],
        preferredProfessors: [],
        maxCredits: 15,
        avoidEarlyClasses: false,
        avoidLateClasses: false,
        minimizeGaps: true,
      );
      const pins = {'PHYS 234': '02'};
      const excludedCourses = ['CSC 434'];
      const excludedSections = ['PHYS 214L|02'];
      final permitted = ScheduleDraftService.permittedSections(
        published,
        excludedCourses: excludedCourses,
        excludedSections: excludedSections,
        sectionPreferences: pins,
      );
      final plan = SemesterPlanService().generatePlan(
        student: testStudent,
        program: programFor(testStudent),
        catalog: catalogFor(testStudent),
        maxCredits: 15,
        sections: permitted,
        preferences: preferences,
      );
      final schedule = ScheduleGenerationService().generateSchedule(
        plan: plan,
        sections: permitted,
        instructors: [],
        preferences: preferences,
      );
      expect(schedule.scheduledCredits, 15);
      final before = ScheduleDraft(
        plan: plan,
        schedule: schedule,
        preferences: preferences,
        sectionPreferences: pins,
        excludedCourses: excludedCourses,
        excludedSections: excludedSections,
      );
      await PreferencesService.savePreferences(preferences);
      await ScheduleDraftService.save(before);

      tester.view.physicalSize = const Size(1000, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: SchedulePreferencesScreen()),
      );
      Finder pageScroll() => find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      final slider = find.byType(Slider);
      await tester.scrollUntilVisible(slider, 400, scrollable: pageScroll());
      tester.widget<Slider>(slider).onChanged!(18);
      await tester.pumpAndSettle();

      Future<void> tapVisible(String text) async {
        final button = find.text(text);
        await tester.scrollUntilVisible(button, 400, scrollable: pageScroll());
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await tapVisible('Find courses for my semester');
      expect(find.text('16 course credits · 18-credit limit'), findsOneWidget);
      expect(ScheduleDraftService.current, same(before));
      await tapVisible('Generate Class Schedule');

      final after = ScheduleDraftService.current!;
      expect(after.preferences.maxCredits, 18);
      expect(after.schedule.scheduledCredits, 16);
      expect(after.schedule.unscheduled, isEmpty);
      expect(after.sectionPreferences, pins);
      expect(after.excludedCourses, excludedCourses);
      expect(after.excludedSections, excludedSections);
      expect(
        after.schedule.scheduled.map((item) => item.section.fullCourseCode),
        containsAll(['PHYS 234 02', 'PHYS 214L 01']),
      );
      expect(find.textContaining('Credit target: 15 → 18.'), findsOneWidget);
      expect(find.textContaining('Added PHYS 214L.'), findsOneWidget);
      const history = ScheduleChangeHistoryService(profile);
      final savedLog = await history.load();
      expect(savedLog.single.changes, contains('Scheduled credits: 15 → 16.'));
      expect(savedLog.single.result, contains('16 of 18 credits'));

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      final resume = find.text('Continue schedule');
      await tester.scrollUntilVisible(resume, -400, scrollable: pageScroll());
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(ScheduleDraftService.current!.schedule.scheduledCredits, 16);
      expect((await history.load()).length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('semester plan retries after the section asset fails to load', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    selectDemoStudent(null);
    PreferencesService.useProfile('semester-offerings-retry');
    addTearDown(() => PreferencesService.useProfile('demo-cs-2024'));
    rootBundle.clear();
    final published = jsonDecode(
      File('assets/data/course_sections_spring_2027.json').readAsStringSync(),
    ) as List;
    final valid = jsonEncode(
      published.where((row) => row['courseCode'] == 'CSC 237').toList(),
    );
    var available = false;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final path = const StringCodec().decodeMessage(message);
      if (path?.endsWith('course_sections_spring_2027.json') ?? false) {
        return const StringCodec().encodeMessage(
          available ? valid : 'invalid section data',
        );
      }
      return null;
    });
    addTearDown(() {
      rootBundle.clear();
      messenger.setMockMessageHandler('flutter/assets', null);
    });

    await tester.pumpWidget(const MaterialApp(home: SemesterPlanScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Spring 2027 sections could not load.'), findsOneWidget);
    expect(find.text('Generate Class Schedule'), findsNothing);
    available = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('3 course credits · 15-credit limit'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });
}
