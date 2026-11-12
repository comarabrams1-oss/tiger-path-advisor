import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/services/course_section_repository.dart';
import 'package:tiger_path/services/preferences_service.dart';
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
}
