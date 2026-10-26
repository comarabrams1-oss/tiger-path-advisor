import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/models/course.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/services/course_eligibility_service.dart';
import 'package:tiger_path/services/course_priority_service.dart';
import 'package:tiger_path/services/schedule_recovery_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';

void main() {
  test('fills from eligible degree candidates and keeps missing requirements deferred', () {
    SemesterPlanItem item(String code) => SemesterPlanItem(
      type: SemesterPlanItemType.course,
      title: code,
      category: 'Major',
      credits: 3,
      reason: '',
      courseCode: code,
    );
    CoursePriorityResult candidate(String code, EligibilityStatus status) {
      final course = Course(
        code: code,
        title: code,
        credits: 3,
        category: 'Major',
      );
      return CoursePriorityResult(
        course: course,
        eligibility: CourseEligibilityResult(course: course, status: status),
        score: 10,
        reasons: [],
        unlocks: [],
      );
    }

    CourseSection section(String code, int hour) => CourseSection(
      courseCode: code,
      sectionNumber: '01',
      instructorId: '',
      term: 'test',
      days: ['Monday'],
      startMinutes: hour * 60,
      endMinutes: hour * 60 + 50,
      location: '',
      deliveryMethod: '',
      openSeats: 5,
    );
    final result = ScheduleRecoveryService().recover(
      plan: SemesterPlan(
        items: [item('A'), item('MISSING')],
        totalCredits: 6,
        maxCredits: 6,
      ),
      candidates: [
        candidate('C', EligibilityStatus.eligibleAfterCurrentTerm),
        candidate('BLOCKED', EligibilityStatus.blocked),
      ],
      requestedCourses: ['invented', 'BLOCKED', 'C', 'C'],
      sections: [section('A', 9), section('C', 10), section('BLOCKED', 11)],
      instructors: [],
      preferences: const SchedulePreferences(
        preferredTime: 'No Preference',
        preferredDays: [],
        avoidedDays: [],
        preferredProfessors: [],
        maxCredits: 6,
        avoidEarlyClasses: false,
        avoidLateClasses: false,
        minimizeGaps: false,
      ),
    );
    expect(result.plan.items.map((item) => item.courseCode), ['A', 'C']);
    expect(result.plan.totalCredits, 6);
    expect(result.plan.items.last.projectedEligibility, isTrue);
    expect(result.deferred.single.courseCode, 'MISSING');
  });
}
