import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/data/program_registry.dart';
import 'package:tiger_path/models/course.dart';
import 'package:tiger_path/models/degree_program.dart';
import 'package:tiger_path/models/student.dart';
import 'package:tiger_path/models/student_course.dart';
import 'package:tiger_path/services/course_eligibility_service.dart';
import 'package:tiger_path/services/advisor_context_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';

Student student(List<StudentCourse> attempts) => Student(
  name: 'Fixture',
  institution: 'Test',
  major: 'Computer Science',
  catalogYear: '2026',
  classification: 'Senior',
  gpa: 3,
  earnedCredits: 60,
  inProgressCredits: 0,
  requiredCredits: 120,
  courses: attempts,
);
StudentCourse attempt(
  String code,
  String? grade, {
  bool transfer = false,
  CourseStatus status = CourseStatus.completed,
}) => StudentCourse(
  courseCode: code,
  grade: grade,
  term: 'Fall 2026',
  status: status,
  isTransfer: transfer,
);
DegreeProgram policy(String? minimum) => DegreeProgram(
  institution: 'Test',
  name: 'Test',
  degreeType: 'BS',
  catalogYear: '2026',
  totalCreditsRequired: 6,
  majorCreditsRequired: 6,
  requirements: [
    DegreeRequirement(
      id: 'P',
      title: 'Prerequisite',
      category: 'Major',
      type: RequirementType.requiredCourse,
      courseCodes: ['P'],
      creditsRequired: 3,
      minimumGrade: minimum,
    ),
    const DegreeRequirement(
      id: 'N',
      title: 'Next',
      category: 'Major',
      type: RequirementType.requiredCourse,
      courseCodes: ['N'],
      creditsRequired: 3,
    ),
  ],
);
Course next({String? minimum}) => Course(
  code: 'N',
  title: 'Next',
  credits: 3,
  category: 'Major',
  prerequisiteGroups: const [
    ['P'],
  ],
  minimumPrerequisiteGrades: {if (minimum != null) 'P': minimum},
);

void main() {
  final check = CourseEligibilityService();
  final cs = programMappings['Computer Science']!;
  final catalog = catalogMappings['Computer Science']!;
  final csc334 = catalog.singleWhere((c) => c.code == 'CSC 334');

  test('focused advisor eligibility uses the same program fallback', () {
    final context = AdvisorContextService().build(
      student: student([attempt('CSC 233', 'D')]),
      program: cs,
      catalog: catalog,
      sections: const [],
      term: 'Spring 2027',
      question: 'Can I take CSC 334?',
    );
    final focused = (context['focusedCourses'] as List).single as Map;
    expect((focused['eligibility'] as Map)['status'], 'blocked');
  });

  test(
    'AND/OR groups and corequisite-only completion retain their semantics',
    () {
      const alternative = Course(
        code: 'N',
        title: 'Next',
        credits: 3,
        category: 'Major',
        prerequisiteGroups: [
          ['P', 'ALT'],
          ['Q'],
        ],
      );
      expect(
        check
            .checkCourse(
              student([attempt('P', 'D'), attempt('Q', 'A')]),
              alternative,
              program: policy('C'),
            )
            .status,
        EligibilityStatus.blocked,
      );
      expect(
        check
            .checkCourse(
              student([attempt('ALT', 'D'), attempt('Q', 'A')]),
              alternative,
              program: policy('C'),
            )
            .status,
        EligibilityStatus.eligible,
      );
      expect(
        check
            .checkCourse(
              student([attempt('P', 'C')]),
              alternative,
              program: policy('C'),
            )
            .status,
        EligibilityStatus.blocked,
      );
      const lab = Course(
        code: 'LAB',
        title: 'Lab',
        credits: 1,
        category: 'Major',
        corequisiteCodes: ['P'],
      );
      expect(
        check
            .checkCourse(
              student([attempt('P', 'D')]),
              lab,
              program: policy('C'),
            )
            .requiredCompanions
            .isEmpty,
        isTrue,
      );
    },
  );

  test(
    'CSC 233 D blocks CSC 334 in program recommendations and semester plan',
    () {
      final profile = student([
        attempt('CSC 233', 'D'),
        attempt('CSC 135', 'A'),
      ]);
      final results = check.checkProgramCourses(profile, cs, catalog);
      expect(
        results.singleWhere((r) => r.course.code == 'CSC 334').status,
        EligibilityStatus.blocked,
      );
      expect(results.any((r) => r.course.code == 'CSC 233'), isTrue);
      final plan = SemesterPlanService().generatePlan(
        student: profile,
        program: cs,
        catalog: catalog,
        maxCredits: 18,
      );
      expect(plan.items.any((i) => i.courseCode == 'CSC 334'), isFalse);
    },
  );

  test(
    'C and qualifying repeats allow CSC 334 regardless of attempt order',
    () {
      for (final attempts in [
        [attempt('CSC 233', 'C')],
        [attempt('CSC 233', 'D'), attempt('CSC 233', 'C')],
        [attempt('CSC 233', 'C'), attempt('CSC 233', 'F')],
      ]) {
        expect(
          check.checkCourse(student(attempts), csc334, program: cs).status,
          EligibilityStatus.eligible,
        );
      }
    },
  );

  test(
    'current retake remains conditional and accepted transfer CR remains valid',
    () {
      final current = student([
        attempt('CSC 233', 'D'),
        attempt('CSC 233', null, status: CourseStatus.inProgress),
      ]);
      expect(
        check.checkCourse(current, csc334, program: cs).status,
        EligibilityStatus.eligibleAfterCurrentTerm,
      );
      expect(
        check
            .checkCourse(
              student([attempt('CSC 233', 'CR', transfer: true)]),
              csc334,
              program: cs,
            )
            .status,
        EligibilityStatus.eligible,
      );
      expect(
        check
            .checkCourse(
              student([attempt('CSC 233', 'CR')]),
              csc334,
              program: cs,
            )
            .status,
        EligibilityStatus.blocked,
      );
      expect(
        check
            .checkCourse(
              student([attempt('P', 'CR', transfer: true)]),
              next(minimum: 'B'),
              program: policy('C'),
            )
            .status,
        EligibilityStatus.blocked,
      );
    },
  );

  test(
    'explicit prerequisite thresholds override program completion thresholds',
    () {
      expect(
        check
            .checkCourse(
              student([attempt('P', 'D')]),
              next(minimum: 'D'),
              program: policy('C'),
            )
            .status,
        EligibilityStatus.eligible,
      );
      expect(
        check
            .checkCourse(
              student([attempt('P', 'C')]),
              next(minimum: 'B'),
              program: policy('C'),
            )
            .status,
        EligibilityStatus.blocked,
      );
      expect(
        check
            .checkCourse(
              student([attempt('P', 'B')]),
              next(minimum: 'B'),
              program: policy('C'),
            )
            .status,
        EligibilityStatus.eligible,
      );
    },
  );

  test('fallback follows each configured grade, never a blanket C', () {
    expect(
      check
          .checkCourse(
            student([attempt('P', 'D')]),
            next(),
            program: policy('D'),
          )
          .status,
      EligibilityStatus.eligible,
    );
    expect(
      check
          .checkCourse(
            student([attempt('P', 'C')]),
            next(),
            program: policy('B'),
          )
          .status,
      EligibilityStatus.blocked,
    );
    expect(
      check
          .checkCourse(
            student([attempt('P', 'B')]),
            next(),
            program: policy('B'),
          )
          .status,
      EligibilityStatus.eligible,
    );
    expect(
      check
          .checkCourse(
            student([attempt('P', 'D')]),
            next(),
            program: policy(null),
          )
          .status,
      EligibilityStatus.eligible,
    );
    expect(
      check.checkCourse(student([attempt('P', 'D')]), next()).status,
      EligibilityStatus.eligible,
    );
  });

  test(
    'configured C fallback applies across all mapped prerequisite chains',
    () {
      final covered = <String, int>{};
      for (final entry in programMappings.entries) {
        final program = entry.value;
        for (final course in catalogMappings[entry.key]!) {
          if (course.requiresAdvisorApproval) continue;
          for (final group in course.prerequisiteGroups.where(
            (g) => g.length == 1,
          )) {
            final code = group.single;
            if (course.minimumPrerequisiteGrades.containsKey(code)) continue;
            if (!program.requirements.any(
              (r) =>
                  r.type == RequirementType.requiredCourse &&
                  r.courseCodes.contains(code) &&
                  r.minimumGrade == 'C',
            ))
              continue;
            List<StudentCourse> record(String grade) => [
              for (final other in course.prerequisiteGroups)
                if (!other.contains(code)) attempt(other.first, 'A'),
              attempt(code, grade),
            ];
            final why = '${entry.key}: $code -> ${course.code}';
            expect(
              check
                  .checkCourse(student(record('D')), course, program: program)
                  .status,
              course.allowsInstructorPermission
                  ? EligibilityStatus.requiresPermission
                  : EligibilityStatus.blocked,
              reason: why,
            );
            expect(
              check
                  .checkCourse(student(record('C')), course, program: program)
                  .status,
              EligibilityStatus.eligible,
              reason: why,
            );
            covered.update(entry.key, (n) => n + 1, ifAbsent: () => 1);
          }
        }
      }
      expect(covered.keys, containsAll(programMappings.keys));
      expect(
        covered.values.fold(0, (sum, count) => sum + count),
        greaterThan(20),
      );
    },
  );
}
