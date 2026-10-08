import '../lib/data/cs_course_catalog.dart';
import '../lib/data/cs_program.dart';
import '../lib/data/test_student.dart';
import '../lib/models/course.dart';
import '../lib/models/course_section.dart';
import '../lib/models/degree_program.dart';
import '../lib/models/schedule_preferences.dart';
import '../lib/models/student.dart';
import '../lib/models/student_course.dart';
import '../lib/services/course_completion_service.dart';
import '../lib/services/course_eligibility_service.dart';
import '../lib/services/course_priority_service.dart';
import '../lib/services/degree_audit_service.dart';
import '../lib/services/schedule_generation_service.dart';
import '../lib/services/semester_plan_service.dart';

void _equal(Object? actual, Object? expected) {
  if (actual != expected) {
    throw StateError('Expected $expected, got $actual');
  }
}

Student _student(List<StudentCourse> courses) => Student(
  name: 'Test Student',
  institution: 'Test College',
  major: 'Computer Science',
  catalogYear: '2024',
  classification: 'Senior',
  gpa: 3,
  earnedCredits: 0,
  inProgressCredits: 0,
  requiredCredits: 120,
  courses: courses,
);

StudentCourse _attempt(
  String code,
  String? grade, {
  CourseStatus status = CourseStatus.completed,
}) => StudentCourse(
  courseCode: code,
  grade: grade,
  term: 'Fall 2026',
  status: status,
);

DegreeProgram _program(List<DegreeRequirement> requirements) => DegreeProgram(
  institution: 'Test College',
  name: 'Computer Science',
  degreeType: 'B.S.',
  catalogYear: '2024',
  totalCreditsRequired: 120,
  majorCreditsRequired: 69,
  requirements: requirements,
);

const _required = DegreeRequirement(
  id: 'CSC 233',
  title: 'Data Structures',
  category: 'Major',
  type: RequirementType.requiredCourse,
  creditsRequired: 3,
  courseCodes: ['CSC 233'],
  minimumGrade: 'C',
);

const _catalog = [
  Course(
    code: 'CSC 233',
    title: 'Data Structures',
    credits: 3,
    category: 'Major',
  ),
  Course(
    code: 'CSC 334',
    title: 'Algorithms II',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 233'],
    ],
  ),
];

const _preferences = SchedulePreferences(
  preferredTime: 'No Preference',
  preferredDays: [],
  avoidedDays: [],
  preferredProfessors: [],
  maxCredits: 15,
  avoidEarlyClasses: false,
  avoidLateClasses: false,
  minimizeGaps: true,
);

CourseSection _section({int? seats, String? status, int start = 600}) =>
    CourseSection(
      courseCode: 'CSC 233',
      sectionNumber: '$start',
      instructorId: 'test',
      term: 'Spring 2027',
      days: ['Monday'],
      startMinutes: start,
      endMinutes: start + 60,
      location: 'TBD',
      deliveryMethod: 'In Person',
      openSeats: seats,
      status: status,
    );

void registerAcademicRegressionCases(
  void Function(String, void Function()) test,
) {
  final completion = CourseCompletionService();
  final audit = DegreeAuditService();
  final eligibility = CourseEligibilityService();
  final program = _program([
    _required,
    const DegreeRequirement(
      id: 'CSC 334',
      title: 'Algorithms II',
      category: 'Major',
      type: RequirementType.requiredCourse,
      creditsRequired: 3,
      courseCodes: ['CSC 334'],
      minimumGrade: 'C',
    ),
  ]);

  for (final grade in ['F', 'D', 'C-']) {
    test(
      '$grade remains a retake candidate and cannot satisfy a C prerequisite',
      () {
        final student = _student([_attempt('CSC 233', grade)]);
        _equal(
          audit.auditProgram(student, program).first.status,
          RequirementStatus.remaining,
        );
        final results = eligibility.checkProgramCourses(
          student,
          program,
          _catalog,
        );
        _equal(results.any((result) => result.course.code == 'CSC 233'), true);
        _equal(
          results
              .singleWhere((result) => result.course.code == 'CSC 334')
              .status,
          EligibilityStatus.blocked,
        );
        final plan = SemesterPlanService().generatePlan(
          student: student,
          program: program,
          catalog: _catalog,
          maxCredits: 3,
        );
        _equal(plan.items.single.courseCode, 'CSC 233');
        _equal(plan.totalCredits, 3.0);
      },
    );
  }

  test('C satisfies the audit and prerequisite', () {
    final student = _student([_attempt('CSC 233', 'C')]);
    _equal(
      audit.auditProgram(student, program).first.status,
      RequirementStatus.completed,
    );
    final results = eligibility.checkProgramCourses(student, program, _catalog);
    _equal(results.length, 1);
    _equal(results.single.status, EligibilityStatus.eligible);
  });

  test('passing retake wins regardless of attempt order', () {
    for (final attempts in [
      [
        _attempt('CSC 233', null, status: CourseStatus.inProgress),
        _attempt('CSC 233', 'B'),
      ],
      [_attempt('CSC 233', 'B'), _attempt('CSC 233', 'F')],
      [_attempt('CSC 233', 'F'), _attempt('CSC 233', 'B')],
    ]) {
      final student = _student(attempts);
      _equal(
        audit.auditProgram(student, program).first.status,
        RequirementStatus.completed,
      );
      _equal(
        eligibility
            .checkCourse(student, _catalog.last, program: program)
            .status,
        EligibilityStatus.eligible,
      );
    }
  });

  test('in-progress retake yields conditional eligibility', () {
    final student = _student([
      _attempt('CSC 233', 'F'),
      _attempt('CSC 233', null, status: CourseStatus.inProgress),
    ]);
    _equal(
      audit.auditProgram(student, program).first.status,
      RequirementStatus.inProgress,
    );
    _equal(
      eligibility.checkProgramCourses(student, program, _catalog).single.status,
      EligibilityStatus.eligibleAfterCurrentTerm,
    );
  });

  test('missing and special grades require review rather than satisfy prerequisites', () {
    for (final grade in [null, 'P', 'LB', 'W', '']) {
      final student = _student([_attempt('CSC 233', grade)]);
      _equal(
        completion.evaluate(student, 'CSC 233', minimumGrade: 'C'),
        CourseCompletionStatus.needsReview,
      );
      _equal(
        eligibility
            .checkCourse(student, _catalog.last, program: program)
            .status,
        EligibilityStatus.blocked,
      );
    }
  });

  test(
    'unknown target grade is held for review rather than automatically retaken',
    () {
      final student = _student([_attempt('CSC 233', 'LB')]);
      final result = eligibility
          .checkProgramCourses(student, program, _catalog)
          .singleWhere((result) => result.course.code == 'CSC 233');
      _equal(result.status, EligibilityStatus.blocked);
      _equal(
        result.reason,
        'Previous grade needs review before recommending a retake.',
      );
    },
  );

  test('grade and course-code whitespace are normalized', () {
    final student = _student([_attempt(' csc   233 ', ' c ')]);
    _equal(
      audit.auditProgram(student, program).first.status,
      RequirementStatus.completed,
    );
    _equal(
      eligibility.checkProgramCourses(student, program, _catalog).single.status,
      EligibilityStatus.eligible,
    );
  });

  test(
    'failed support course cannot satisfy a requirement with no minimum grade',
    () {
      final support = _program([
        const DegreeRequirement(
          id: 'PHYS 234',
          title: 'Physics II',
          category: 'Support',
          type: RequirementType.requiredCourse,
          creditsRequired: 3,
          courseCodes: ['PHYS 234'],
        ),
      ]);
      _equal(
        audit
            .auditProgram(_student([_attempt('PHYS 234', 'F')]), support)
            .single
            .status,
        RequirementStatus.remaining,
      );
    },
  );

  test(
    'one-of requirement prefers a passing option over an in-progress option',
    () {
      final options = _program([
        const DegreeRequirement(
          id: 'LANG',
          title: 'Language',
          category: 'General Education',
          type: RequirementType.oneOfCourses,
          creditsRequired: 3,
          courseCodes: ['AR 233', 'SP 233'],
          minimumGrade: 'C',
        ),
      ]);
      final student = _student([
        _attempt('AR 233', null, status: CourseStatus.inProgress),
        _attempt('SP 233', 'B'),
      ]);
      _equal(
        audit.auditProgram(student, options).single.status,
        RequirementStatus.completed,
      );
      _equal(
        audit
            .auditProgram(_student([_attempt('SP 233', 'F')]), options)
            .single
            .status,
        RequirementStatus.remaining,
      );
    },
  );

  test('credit-hour audit counts each passing course once and excludes failed attempts', () {
    final hours = _program([
      const DegreeRequirement(
        id: 'ENGLISH',
        title: 'English',
        category: 'General Education',
        type: RequirementType.creditHours,
        creditsRequired: 9,
        courseCodes: ['ENG 131', 'ENG 132', 'ENG 237'],
      ),
    ]);
    final student = _student([
      _attempt('ENG 131', 'A'),
      _attempt('ENG 131', 'B'),
      _attempt('ENG 131', null, status: CourseStatus.inProgress),
      _attempt('ENG 132', 'F'),
      _attempt('ENG 237', null, status: CourseStatus.inProgress),
    ]);
    final item = audit.auditProgram(student, hours).single;
    _equal(item.completedCredits, 3.0);
    _equal(item.inProgressCredits, 3.0);
    _equal(item.status, RequirementStatus.remaining);
  });

  test('AND/OR prerequisite groups retain their semantics', () {
    const course = Course(
      code: 'CSC 436',
      title: 'Operating Systems',
      credits: 3,
      category: 'Major',
      prerequisiteGroups: [
        ['CSC 233', 'CE 231'],
        ['CSC 337'],
      ],
    );
    _equal(
      eligibility
          .checkCourse(
            _student([_attempt('CE 231', 'B'), _attempt('CSC 337', 'A')]),
            course,
            program: program,
          )
          .status,
      EligibilityStatus.eligible,
    );
    _equal(
      eligibility
          .checkCourse(
            _student([_attempt('CE 231', 'B')]),
            course,
            program: program,
          )
          .status,
      EligibilityStatus.blocked,
    );
  });

  test('permission and standing checks remain enforced', () {
    const permission = Course(
      code: 'CSC 237',
      title: 'Java',
      credits: 3,
      category: 'Major',
      prerequisiteGroups: [
        ['CSC 135'],
      ],
      allowsInstructorPermission: true,
    );
    _equal(
      eligibility.checkCourse(_student([]), permission).status,
      EligibilityStatus.requiresPermission,
    );
    const standing = Course(
      code: 'CSC 430',
      title: 'Research',
      credits: 3,
      category: 'Major',
      minimumClassStanding: 'Senior',
    );
    _equal(
      eligibility.checkCourse(testStudent, standing).status,
      EligibilityStatus.blocked,
    );
  });

  test('priority reasons identify a retake', () {
    final ranked = CoursePriorityService().rankCourses(
      _student([_attempt('CSC 233', 'D')]),
      program,
      _catalog,
    );
    final retake = ranked.singleWhere(
      (result) => result.course.code == 'CSC 233',
    );
    _equal(retake.reasons.any((reason) => reason.startsWith('Retake')), true);
  });

  test('scheduler rejects zero-seat, closed, cancelled and full sections', () {
    const plan = SemesterPlan(
      items: [
        SemesterPlanItem(
          type: SemesterPlanItemType.course,
          title: 'Data Structures',
          category: 'Major',
          credits: 3,
          courseCode: 'CSC 233',
          reason: 'Required',
        ),
      ],
      totalCredits: 3,
      maxCredits: 15,
    );
    for (final section in [
      _section(seats: 0),
      _section(seats: -1),
      _section(seats: 0, status: 'Open'),
      _section(status: 'Closed'),
      _section(status: 'Cancelled'),
      _section(status: 'Full'),
    ]) {
      final schedule = ScheduleGenerationService().generateSchedule(
        plan: plan,
        sections: [section],
        instructors: [],
        preferences: _preferences,
      );
      _equal(schedule.scheduled.length, 0);
      _equal(schedule.unscheduled.length, 1);
    }
    final schedule = ScheduleGenerationService().generateSchedule(
      plan: plan,
      sections: [_section(seats: 0), _section(seats: 4, start: 800)],
      instructors: [],
      preferences: _preferences,
    );
    _equal(schedule.scheduled.single.section.startMinutes, 800);
  });

  test('existing sample student keeps expected eligibility and credit cap', () {
    final results = eligibility.checkProgramCourses(
      testStudent,
      benedictComputerScience2024,
      computerScienceCourseCatalog,
    );
    _equal(
      results.singleWhere((result) => result.course.code == 'CSC 431').status,
      EligibilityStatus.eligibleAfterCurrentTerm,
    );
    _equal(
      results.singleWhere((result) => result.course.code == 'CSC 338').status,
      EligibilityStatus.eligible,
    );
    _equal(
      results.singleWhere((result) => result.course.code == 'CSC 430').status,
      EligibilityStatus.blocked,
    );
    final plan = SemesterPlanService().generatePlan(
      student: testStudent,
      program: benedictComputerScience2024,
      catalog: computerScienceCourseCatalog,
      maxCredits: 15,
    );
    _equal(plan.totalCredits <= 15, true);
  });
}
