import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/data/cs_program.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/data/cs_course_catalog.dart';
import 'package:tiger_path/models/student.dart';
import 'package:tiger_path/models/student_course.dart';
import 'package:tiger_path/services/degree_audit_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';
import 'package:tiger_path/services/advisor_context_service.dart';

Student withCourses(List<StudentCourse> courses) => Student(
  name: testStudent.name,
  institution: testStudent.institution,
  major: testStudent.major,
  catalogYear: testStudent.catalogYear,
  classification: testStudent.classification,
  gpa: testStudent.gpa,
  earnedCredits: testStudent.earnedCredits,
  inProgressCredits: testStudent.inProgressCredits,
  requiredCredits: testStudent.requiredCredits,
  courses: courses,
);
List<DegreeAuditItem> global(Student student) => DegreeAuditService()
    .auditProgram(student, benedictComputerScience2024)
    .where(
      (a) => [
        'GENED_GLOBAL_HISTORY',
        'GENED_GLOBAL',
        'GENED_LANGUAGE',
      ].contains(a.requirement.id),
    )
    .toList();
void main() {
  test(
    'history and music completed; Arabic supplies final in-progress component',
    () {
      final audit = global(testStudent);
      expect(audit, hasLength(3));
      expect(
        audit.fold<double>(0, (n, a) => n + a.requirement.creditsRequired),
        9,
      );
      expect(audit.fold<double>(0, (n, a) => n + a.completedCredits), 6);
      expect(audit.fold<double>(0, (n, a) => n + a.inProgressCredits), 3);
      expect(
        audit.where((a) => a.status == RequirementStatus.remaining),
        isEmpty,
      );
      expect(
        audit.singleWhere((a) => a.requirement.id == 'GENED_LANGUAGE').status,
        RequirementStatus.inProgress,
      );
      final plan = SemesterPlanService().generatePlan(
        student: testStudent,
        program: benedictComputerScience2024,
        catalog: computerScienceCourseCatalog,
        maxCredits: 18,
      );
      expect(
        plan.items.where(
          (item) => item.title.startsWith('Global & Intercultural'),
        ),
        isEmpty,
      );
      final context = AdvisorContextService().build(
        student: testStudent,
        program: benedictComputerScience2024,
        catalog: computerScienceCourseCatalog,
        sections: [],
        term: '2026-2027 - Spring',
      );
      expect(
        (context['requirements'] as List).singleWhere(
          (r) => r['id'] == 'GENED_LANGUAGE',
        )['inProgressCredits'],
        3,
      );
    },
  );
  test('passing Arabic completes exactly nine credits', () {
    final courses = testStudent.courses
        .map(
          (c) => c.courseCode == 'AR 233'
              ? const StudentCourse(
                  courseCode: 'AR 233',
                  grade: 'A',
                  term: 'Fall 2026',
                  status: CourseStatus.completed,
                )
              : c,
        )
        .toList();
    final audit = global(withCourses(courses));
    expect(audit.every((a) => a.status == RequirementStatus.completed), isTrue);
    expect(audit.fold<double>(0, (n, a) => n + a.completedCredits), 9);
  });
  test('history cannot also supply elective; extra electives cannot replace language', () {
    final audit = global(
      withCourses([
        const StudentCourse(
          courseCode: 'HIST 130',
          grade: 'A',
          term: 'Fall 2024',
          status: CourseStatus.completed,
        ),
      ]),
    );
    expect(
      audit.singleWhere((a) => a.requirement.id == 'GENED_GLOBAL').status,
      RequirementStatus.remaining,
    );
    expect(
      audit.singleWhere((a) => a.requirement.id == 'GENED_LANGUAGE').status,
      RequirementStatus.remaining,
    );
    final noLanguage = global(
      withCourses(
        testStudent.courses.where((c) => c.courseCode != 'AR 233').toList(),
      ),
    );
    expect(
      noLanguage
          .singleWhere((a) => a.requirement.id == 'GENED_LANGUAGE')
          .status,
      RequirementStatus.remaining,
    );
    expect(
      noLanguage.singleWhere((a) => a.requirement.id == 'GENED_GLOBAL').status,
      RequirementStatus.completed,
    );
  });
}
