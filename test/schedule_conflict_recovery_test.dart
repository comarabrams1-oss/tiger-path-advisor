import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/services/schedule_generation_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';

void main() {
  test(
    'tries another order to recover a conflict without using full sections',
    () {
      CourseSection section(
        String code,
        String id,
        int hour, {
        int seats = 5,
      }) => CourseSection(
        courseCode: code,
        sectionNumber: id,
        instructorId: '',
        term: 'test',
        days: const ['Monday'],
        startMinutes: hour * 60,
        endMinutes: hour * 60 + 50,
        location: '',
        deliveryMethod: '',
        status: 'Open',
        openSeats: seats,
      );
      const plan = SemesterPlan(
        items: [
          SemesterPlanItem(
            type: SemesterPlanItemType.course,
            title: 'A',
            category: 'Major',
            credits: 3,
            reason: '',
            courseCode: 'A',
          ),
          SemesterPlanItem(
            type: SemesterPlanItemType.course,
            title: 'B',
            category: 'Major',
            credits: 3,
            reason: '',
            courseCode: 'B',
          ),
        ],
        totalCredits: 6,
        maxCredits: 15,
      );
      final result = ScheduleGenerationService().generateSchedule(
        plan: plan,
        sections: [
          section('A', 'first', 9),
          section('A', 'alternative', 10),
          section('B', 'only', 9),
          section('B', 'full', 12, seats: 0),
        ],
        instructors: [],
        preferences: const SchedulePreferences(
          preferredTime: 'Morning',
          preferredDays: [],
          avoidedDays: [],
          preferredProfessors: [],
          maxCredits: 15,
          avoidEarlyClasses: false,
          avoidLateClasses: false,
          minimizeGaps: false,
        ),
      );
      expect(result.unscheduled, isEmpty);
      expect(result.scheduledCredits, 6);
      expect(
        result.scheduled.map((item) => item.section.sectionNumber),
        containsAll(['only', 'alternative']),
      );
      expect(
        result.scheduled.any((item) => item.section.sectionNumber == 'full'),
        isFalse,
      );
    },
  );
}
