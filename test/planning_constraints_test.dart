import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/data/foundation_course_catalog.dart';
import 'package:tiger_path/data/program_registry.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/models/course.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/models/degree_program.dart';
import 'package:tiger_path/models/student.dart';
import 'package:tiger_path/models/student_course.dart';
import 'package:tiger_path/services/course_eligibility_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';

Student student({
  List<StudentCourse> courses = const [],
  Set<String> placement = const {},
}) => Student(
  name: 'Test',
  institution: 'Benedict College',
  major: 'Computer Science',
  catalogYear: '2024',
  classification: 'Sophomore',
  gpa: 3,
  earnedCredits: 30,
  inProgressCredits: 0,
  requiredCredits: 120,
  courses: courses,
  verifiedPlacementCourses: placement,
);
DegreeProgram program(List<DegreeRequirement> requirements) => DegreeProgram(
  institution: 'Test',
  name: 'Test',
  degreeType: 'B.S.',
  catalogYear: '2024',
  totalCreditsRequired: 120,
  majorCreditsRequired: 60,
  requirements: requirements,
);
DegreeRequirement required(String code, double credits) => DegreeRequirement(
  id: code,
  title: code,
  category: 'Major',
  type: RequirementType.requiredCourse,
  courseCodes: [code],
  creditsRequired: credits,
);
Course course(String code, double credits) =>
    Course(code: code, title: code, category: 'Major', credits: credits);
CourseSection section(String code, int start) => CourseSection(
  courseCode: code,
  sectionNumber: '01',
  instructorId: '',
  term: 'test',
  days: ['Monday'],
  startMinutes: start,
  endMinutes: start + 50,
  location: '',
  deliveryMethod: '',
  openSeats: 10,
);

void main() {
  test('intermediate Arabic requires passing elementary or verified placement, never an invented exemption', () {
    final arabic = foundationCourseCatalog.firstWhere(
      (c) => c.code == 'AR 233',
    );
    final check = CourseEligibilityService();
    StudentCourse elementary(CourseStatus status, [String? grade]) =>
        StudentCourse(
          courseCode: 'AR 130',
          term: 'Fall 2026',
          status: status,
          grade: grade,
        );
    expect(
      check.checkCourse(student(), arabic).status,
      EligibilityStatus.blocked,
    );
    final conditional = check.checkCourse(
      student(courses: [elementary(CourseStatus.inProgress)]),
      arabic,
    );
    expect(conditional.status, EligibilityStatus.eligibleAfterCurrentTerm);
    expect(conditional.reason, contains('must first pass AR 130'));
    expect(conditional.reason, contains('No placement exemption'));
    expect(
      check
          .checkCourse(
            student(courses: [elementary(CourseStatus.completed, 'B')]),
            arabic,
          )
          .status,
      EligibilityStatus.eligible,
    );
    expect(
      check
          .checkCourse(
            student(courses: [elementary(CourseStatus.completed, 'F')]),
            arabic,
          )
          .status,
      EligibilityStatus.blocked,
    );
    expect(
      check.checkCourse(student(placement: {'AR 233'}), arabic).status,
      EligibilityStatus.eligible,
    );
    expect(
      check
          .checkCourse(
            student(
              courses: [elementary(CourseStatus.completed, 'F')],
              placement: {'AR 233'},
            ),
            arabic,
          )
          .status,
      EligibilityStatus.blocked,
    );
    expect(fictionalStudent.verifiedPlacementCourses, isEmpty);
    expect(engineeringStudent.verifiedPlacementCourses, isEmpty);
  });
  test('credit fitting can skip a four-credit choice to place two three-credit requirements', () {
    final plan = SemesterPlanService().generatePlan(
      student: student(),
      program: program([required('A', 4), required('B', 3), required('C', 3)]),
      catalog: [course('A', 4), course('B', 3), course('C', 3)],
      maxCredits: 6,
    );
    expect(plan.totalCredits, 6);
    expect(plan.items.map((i) => i.courseCode), ['B', 'C']);
  });
  test('course combinations replace a conflicting elective with another approved option', () {
    final plan = SemesterPlanService().generatePlan(
      student: student(),
      program: program([
        const DegreeRequirement(
          id: 'elective',
          title: 'Approved elective',
          category: 'General Education',
          type: RequirementType.oneOfCourses,
          courseCodes: ['A', 'C'],
          creditsRequired: 3,
        ),
        required('B', 3),
      ]),
      catalog: [course('A', 3), course('B', 3), course('C', 3)],
      maxCredits: 6,
      sections: [section('A', 540), section('B', 540), section('C', 660)],
    );
    expect(plan.totalCredits, 6);
    expect(plan.items.map((i) => i.courseCode).toSet(), {'B', 'C'});
  });
  test('real profiles report an honest gap when verified offerings cannot reach the limit', () {
    final sections =
        (jsonDecode(
              File('assets/data/course_sections_spring_2027.json')
                  .readAsStringSync(),
            ) as List)
            .map((j) => CourseSection.fromJson(Map<String, dynamic>.from(j)))
            .toList();
    for (final profile in [fictionalStudent, engineeringStudent]) {
      final plan = SemesterPlanService().generatePlan(
        student: profile,
        program: programFor(profile),
        catalog: catalogFor(profile),
        maxCredits: 18,
        sections: sections,
      );
      expect(plan.totalCredits, lessThanOrEqualTo(18));
      expect(
        plan.items.every(
          (i) => !profile.courses.any((c) => c.courseCode == i.courseCode),
        ),
        isTrue,
      );
      if (plan.totalCredits < 18) {
        expect(plan.shortfallReason, contains('limit is not a guarantee'));
      }
      if (profile.major == 'Computer Science') expect(plan.totalCredits, 18);
      if (profile.major == 'Computer Engineering') {
        expect(
          plan.reviewItems.where((i) => i.title == 'Mathematics').single.reason,
          contains('MATH 140'),
        );
      }
    }
  });
}
