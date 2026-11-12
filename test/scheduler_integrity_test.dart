import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/data/program_registry.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/models/course.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/models/degree_program.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/models/student.dart';
import 'package:tiger_path/models/student_course.dart';
import 'package:tiger_path/services/course_eligibility_service.dart';
import 'package:tiger_path/services/course_section_repository.dart';
import 'package:tiger_path/services/degree_audit_service.dart';
import 'package:tiger_path/services/schedule_generation_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';

SchedulePreferences preferences(int limit, [String time = 'No Preference']) =>
    SchedulePreferences(
      preferredTime: time,
      preferredDays: time == 'Morning' ? ['Monday', 'Wednesday'] : [],
      avoidedDays: time == 'Afternoon' ? ['Friday'] : [],
      preferredProfessors: time == 'Afternoon' ? ['Pandit'] : [],
      maxCredits: limit,
      avoidEarlyClasses: time == 'Afternoon',
      avoidLateClasses: time == 'Morning',
      minimizeGaps: time != 'No Preference',
    );

SemesterPlan plan(List<String> codes, {int limit = 18}) => SemesterPlan(
  items: [
    for (final code in codes)
      SemesterPlanItem(
        type: SemesterPlanItemType.course,
        title: code,
        category: 'Major',
        courseCode: code,
        credits: 3,
        reason: '',
      ),
  ],
  totalCredits: codes.length * 3.0,
  maxCredits: limit,
);

CourseSection section(
  String code,
  String id,
  int start, {
  List<String> days = const ['Monday'],
  List<CourseMeeting> meetings = const [],
  String? begins,
  String? ends,
  String? professor,
}) => CourseSection(
  courseCode: code,
  sectionNumber: id,
  instructorId: '',
  term: 'test',
  days: days,
  startMinutes: start,
  endMinutes: start + 50,
  location: '',
  deliveryMethod: 'In person',
  openSeats: 5,
  status: 'Open',
  instructorName: professor,
  beginDate: begins,
  endDate: ends,
  meetings: meetings,
);

GeneratedSchedule schedule(
  List<String> codes,
  List<CourseSection> sections, {
  int limit = 18,
}) => ScheduleGenerationService().generateSchedule(
  plan: plan(codes, limit: limit),
  sections: sections,
  instructors: const [],
  preferences: preferences(limit),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('finds the complete combination when every greedy rotation fails', () {
    final sections = [
      section('A', '01', 540),
      section('A', '02', 600),
      section('B', '01', 540),
      section('B', '02', 600),
      section('C', '01', 660),
      section('C', '02', 720),
      section('D', '01', 540),
      section('D', '02', 660),
    ];
    final result = schedule(['A', 'B', 'C', 'D'], sections);
    expect(result.unscheduled, isEmpty);
    expect(result.scheduledCredits, 12);
    expect(
      result.scheduled
          .singleWhere((item) => item.section.courseCode == 'C')
          .section
          .sectionNumber,
      '02',
    );
    final capped = schedule(['A', 'B', 'C', 'D'], sections, limit: 9);
    expect(capped.scheduledCredits, 9);
    expect(capped.unscheduled.single.reason, contains('credit limit'));
  });

  test(
    'keeps the preferred professor when another complete arrangement fits',
    () {
      final result = ScheduleGenerationService().generateSchedule(
        plan: plan(['A', 'B']),
        sections: [
          section('A', '01', 600),
          section('A', '02', 660),
          section('B', '01', 600, professor: 'Pandit, Rishi'),
          section('B', '02', 660),
        ],
        instructors: [],
        preferences: preferences(18, 'Afternoon'),
      );
      expect(result.unscheduled, isEmpty);
      expect(
        result.scheduled
            .singleWhere((item) => item.section.courseCode == 'B')
            .section
            .instructorDisplay,
        'Pandit, Rishi',
      );
    },
  );

  test(
    'checks secondary meetings and permits separate blocks at the same time',
    () {
      const lab = CourseMeeting(
        days: ['Thursday'],
        startMinutes: 780,
        endMinutes: 830,
      );
      final result = schedule(
        ['A', 'B', 'C'],
        [
          section(
            'A',
            '01',
            540,
            meetings: [lab],
            begins: '1/11/2027',
            ends: '3/5/2027',
          ),
          section(
            'B',
            '01',
            780,
            days: ['Thursday'],
            begins: '1/11/2027',
            ends: '5/7/2027',
          ),
          section(
            'B',
            '02',
            840,
            days: ['Thursday'],
            begins: '1/11/2027',
            ends: '5/7/2027',
          ),
          section(
            'C',
            '01',
            780,
            days: ['Thursday'],
            begins: '3/15/2027',
            ends: '5/7/2027',
          ),
        ],
      );
      expect(result.unscheduled, isEmpty);
      expect(
        result.scheduled
            .singleWhere((item) => item.section.courseCode == 'B')
            .section
            .sectionNumber,
        '02',
      );
      final unknownDate = schedule(
        ['A', 'C'],
        [
          section('A', '01', 780, begins: '2/31/2027', ends: '3/5/2027'),
          section('C', '01', 780, begins: '3/15/2027', ends: '5/7/2027'),
        ],
      );
      expect(unknownDate.scheduled, hasLength(1));
      expect(unknownDate.unscheduled.single.reason, contains('conflict'));
    },
  );

  test('failed prerequisites stay outstanding and below-minimum grades can be retaken', () {
    const intro = Course(
      code: 'CSC 100',
      title: 'Intro',
      credits: 3,
      category: 'Major',
    );
    const next = Course(
      code: 'CSC 200',
      title: 'Next',
      credits: 3,
      category: 'Major',
      prerequisiteGroups: [
        ['CSC 100'],
      ],
    );
    const program = DegreeProgram(
      institution: 'Test',
      name: 'Test',
      degreeType: 'B.S.',
      catalogYear: '2026',
      totalCreditsRequired: 6,
      majorCreditsRequired: 6,
      requirements: [
        DegreeRequirement(
          id: 'intro',
          title: 'Intro',
          category: 'Major',
          type: RequirementType.requiredCourse,
          courseCodes: ['CSC 100'],
          creditsRequired: 3,
          minimumGrade: 'C',
        ),
        DegreeRequirement(
          id: 'next',
          title: 'Next',
          category: 'Major',
          type: RequirementType.requiredCourse,
          courseCodes: ['CSC 200'],
          creditsRequired: 3,
        ),
      ],
    );
    Student student(String grade) => Student(
      name: 'Test',
      institution: 'Test',
      major: 'Test',
      catalogYear: '2026',
      classification: 'Sophomore',
      gpa: 2,
      earnedCredits: 0,
      inProgressCredits: 0,
      requiredCredits: 6,
      courses: [
        StudentCourse(
          courseCode: 'CSC 100',
          term: 'Fall',
          status: CourseStatus.completed,
          grade: grade,
        ),
      ],
    );
    final failed = student('F');
    expect(
      DegreeAuditService().auditProgram(failed, program).first.completedCredits,
      0,
    );
    expect(
      CourseEligibilityService().checkCourse(failed, next).status,
      EligibilityStatus.blocked,
    );
    final retake = SemesterPlanService().generatePlan(
      student: student('D'),
      program: program,
      catalog: [intro, next],
      sections: [section('CSC 100', '01', 600)],
      maxCredits: 15,
    );
    expect(retake.items.single.courseCode, 'CSC 100');
  });

  test('Spring schedules satisfy eligibility, sections, credits and meeting constraints across 45 cases', () async {
    final sections = await CourseSectionRepository.loadForTerm(
      CourseSectionRepository.spring2027Term,
    );
    for (final student in [
      fictionalStudent,
      sophomoreStudent,
      juniorStudent,
      seniorStudent,
      testStudent,
    ]) {
      final program = programFor(student);
      final catalog = catalogFor(student);
      final eligibility = {
        for (final item in CourseEligibilityService().checkProgramCourses(
          student,
          program,
          catalog,
        ))
          item.course.code: item,
      };
      for (final limit in [12, 15, 18]) {
        for (final time in ['No Preference', 'Morning', 'Afternoon']) {
          final why =
              '${student.major} ${student.classification}, $limit credits, $time';
          final prefs = preferences(limit, time);
          final plan = SemesterPlanService().generatePlan(
            student: student,
            program: program,
            catalog: catalog,
            maxCredits: limit,
            sections: sections,
            preferences: prefs,
          );
          final result = ScheduleGenerationService().generateSchedule(
            plan: plan,
            sections: sections,
            instructors: [],
            preferences: prefs,
          );
          final codes = result.scheduled
              .map((item) => item.section.courseCode)
              .toSet();
          final expected = switch (student) {
            _ when identical(student, seniorStudent) => 0,
            _ when identical(student, juniorStudent) => 10,
            _ when identical(student, testStudent) && limit == 18 => 16,
            _ => limit,
          };
          expect(result.scheduledCredits, expected, reason: why);
          if (expected == 0) {
            expect(plan.reviewItems, isNotEmpty, reason: why);
            expect(plan.shortfallReason, isNotNull, reason: why);
          }
          expect(result.unscheduled, isEmpty, reason: why);
          expect(codes.length, result.scheduled.length, reason: why);
          expect(result.scheduledCredits, plan.totalCredits, reason: why);
          expect(
            result.scheduledCredits,
            lessThanOrEqualTo(limit),
            reason: why,
          );
          for (var i = 0; i < result.scheduled.length; i++) {
            final assigned = result.scheduled[i];
            final section = assigned.section;
            final course = eligibility[section.courseCode]!;
            expect(
              sections.contains(section) &&
                  section.isOpen &&
                  section.hasOpenSeats,
              isTrue,
              reason: why,
            );
            expect(
              course.status,
              anyOf(
                EligibilityStatus.eligible,
                EligibilityStatus.eligibleAfterCurrentTerm,
              ),
              reason: why,
            );
            expect(
              assigned.planItem.projectedEligibility,
              course.status == EligibilityStatus.eligibleAfterCurrentTerm,
              reason: why,
            );
            expect(codes, containsAll(course.requiredCompanions), reason: why);
            for (final other in result.scheduled.skip(i + 1)) {
              _expectNoOverlap(section, other.section, why);
            }
          }
        }
      }
    }
  });
}

void _expectNoOverlap(CourseSection a, CourseSection b, String reason) {
  final aStart = a.beginsOn;
  final aEnd = a.endsOn;
  final bStart = b.beginsOn;
  final bEnd = b.endsOn;
  if (aStart != null &&
      aEnd != null &&
      bStart != null &&
      bEnd != null &&
      (aEnd.isBefore(bStart) || bEnd.isBefore(aStart))) {
    return;
  }
  for (final first in a.weeklyMeetings) {
    for (final second in b.weeklyMeetings) {
      final overlap =
          first.days.any(second.days.contains) &&
          first.startMinutes! < second.endMinutes! &&
          second.startMinutes! < first.endMinutes!;
      expect(
        overlap,
        isFalse,
        reason: '$reason: ${a.fullCourseCode} and ${b.fullCourseCode}',
      );
    }
  }
}
