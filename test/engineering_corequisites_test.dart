import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/data/engineering_program.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/models/degree_program.dart';
import 'package:tiger_path/models/student.dart';
import 'package:tiger_path/models/student_course.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/services/course_priority_service.dart';
import 'package:tiger_path/services/course_eligibility_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';
import 'package:tiger_path/services/schedule_generation_service.dart';
import 'package:tiger_path/services/schedule_recovery_service.dart';

Student student({
  List<StudentCourse> courses = const [],
  String standing = 'Sophomore',
}) => Student(
  name: 'Fixture',
  institution: 'Benedict College',
  major: 'Computer Engineering',
  catalogYear: '2025–2026',
  classification: standing,
  gpa: 3,
  earnedCredits: 40,
  inProgressCredits: 0,
  requiredCredits: 125,
  courses: courses,
);
StudentCourse completed(String code) => StudentCourse(
  courseCode: code,
  grade: 'B',
  term: 'Fall 2026',
  status: CourseStatus.completed,
);
const prefs = SchedulePreferences(
  preferredTime: 'No Preference',
  preferredDays: [],
  avoidedDays: [],
  preferredProfessors: [],
  maxCredits: 4,
  avoidEarlyClasses: false,
  avoidLateClasses: false,
  minimizeGaps: true,
);
CourseSection section(String code, int start, {int seats = 10}) =>
    CourseSection(
      courseCode: code,
      sectionNumber: '01',
      instructorId: '',
      term: 'test',
      days: ['Monday'],
      startMinutes: start,
      endMinutes: start + 50,
      location: '',
      deliveryMethod: '',
      openSeats: seats,
    );
final physicsProgram = DegreeProgram(
  institution: 'Benedict College',
  name: 'Computer Engineering',
  degreeType: 'B.S.',
  catalogYear: '2025–2026',
  totalCreditsRequired: 125,
  majorCreditsRequired: 77,
  requirements: [
    const DegreeRequirement(
      id: 'PHYS 233',
      title: 'Physics I',
      category: 'Support',
      type: RequirementType.requiredCourse,
      courseCodes: ['PHYS 233'],
      creditsRequired: 3,
    ),
    const DegreeRequirement(
      id: 'PHYS 213L',
      title: 'Physics I Lab',
      category: 'Support',
      type: RequirementType.requiredCourse,
      courseCodes: ['PHYS 213L'],
      creditsRequired: 1,
    ),
  ],
);

void main() {
  test('every required engineering course and approved major elective has a catalog rule', () {
    final required = computerEngineeringProgram.requirements
        .where(
          (r) =>
              r.type == RequirementType.requiredCourse || r.id == 'CE_ELECTIVE',
        )
        .expand((r) => r.courseCodes)
        .toSet();
    final mapped = computerEngineeringCatalog.map((c) => c.code).toSet();
    expect(mapped.containsAll(required), isTrue);
    expect(mapped.length, computerEngineeringCatalog.length);
    expect(
      computerEngineeringProgram.requirements
          .singleWhere((r) => r.id == 'MATH 143')
          .minimumGrade,
      'C',
    );
    final stats = computerEngineeringCatalog.singleWhere(
      (c) => c.code == 'MATH 236',
    );
    expect(stats.prerequisiteGroups, [
      ['MATH 138'],
    ]);
    expect(
      CourseEligibilityService()
          .checkCourse(student(courses: [completed('MATH 138')]), stats)
          .status,
      EligibilityStatus.eligible,
    );
  });
  test('planner bundles a lab with its lecture and refuses a full or blocked lecture', () {
    final profile = student(courses: [completed('MATH 143')]);
    SemesterPlan build(List<CourseSection> sections) =>
        SemesterPlanService().generatePlan(
          student: profile,
          program: physicsProgram,
          catalog: computerEngineeringCatalog,
          maxCredits: 4,
          sections: sections,
          preferences: prefs,
        );
    final plan = build([section('PHYS 233', 540), section('PHYS 213L', 660)]);
    expect(plan.totalCredits, 4);
    expect(plan.items.map((i) => i.courseCode).toSet(), {
      'PHYS 233',
      'PHYS 213L',
    });
    final noLecture = build([
      section('PHYS 233', 540, seats: 0),
      section('PHYS 213L', 660),
    ]);
    expect(noLecture.items, isEmpty);
    final blocked = SemesterPlanService().generatePlan(
      student: student(),
      program: physicsProgram,
      catalog: computerEngineeringCatalog,
      maxCredits: 4,
      sections: [section('PHYS 233', 540), section('PHYS 213L', 660)],
    );
    expect(blocked.items, isEmpty);
  });
  test(
    'scheduler removes an orphan lab and recovery requests its lecture first',
    () {
      final profile = student(courses: [completed('MATH 143')]);
      final candidates = CoursePriorityService().rankCourses(
        profile,
        physicsProgram,
        computerEngineeringCatalog,
      );
      final lab = candidates.singleWhere((r) => r.course.code == 'PHYS 213L');
      final labItem = SemesterPlanItem(
        type: SemesterPlanItemType.course,
        title: 'Lab',
        category: 'Support',
        credits: 1,
        courseCode: 'PHYS 213L',
        reason: '',
        priority: lab,
      );
      final orphan = ScheduleGenerationService().generateSchedule(
        plan: SemesterPlan(items: [labItem], totalCredits: 1, maxCredits: 4),
        sections: [section('PHYS 213L', 660)],
        instructors: [],
        preferences: prefs,
      );
      expect(orphan.scheduled, isEmpty);
      expect(orphan.unscheduled.single.reason, contains('co-enrollment'));
      final recovered = ScheduleRecoveryService().recover(
        plan: const SemesterPlan(items: [], totalCredits: 0, maxCredits: 4),
        candidates: candidates,
        requestedCourses: ['PHYS 213L'],
        sections: [section('PHYS 233', 540), section('PHYS 213L', 660)],
        instructors: [],
        preferences: prefs,
      );
      expect(recovered.plan.totalCredits, 4);
    },
  );
  test('passed and current lectures are handled without granting a finished prerequisite', () {
    final lab = computerEngineeringCatalog.singleWhere(
      (c) => c.code == 'PHYS 213L',
    );
    final check = CourseEligibilityService();
    expect(
      check
          .checkCourse(student(courses: [completed('PHYS 233')]), lab)
          .requiredCompanions,
      isEmpty,
    );
    final pending = check.checkCourse(
      student(
        courses: [
          const StudentCourse(
            courseCode: 'PHYS 233',
            term: 'Fall 2026',
            status: CourseStatus.inProgress,
          ),
        ],
      ),
      lab,
    );
    expect(pending.status, EligibilityStatus.eligibleAfterCurrentTerm);
    expect(pending.reason, contains('must first pass PHYS 233'));
    final design = computerEngineeringCatalog.singleWhere(
      (c) => c.code == 'CE 427',
    );
    expect(
      check.checkCourse(student(standing: 'Junior'), design).status,
      EligibilityStatus.blocked,
    );
    expect(
      check.checkCourse(student(standing: 'Senior'), design).status,
      EligibilityStatus.requiresPermission,
    );
  });
}
