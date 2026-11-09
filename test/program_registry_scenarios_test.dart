import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/data/program_registry.dart';
import 'package:tiger_path/models/student_course.dart';
import 'package:tiger_path/services/program_check_service.dart';
import 'package:tiger_path/services/degree_audit_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';
import 'package:tiger_path/models/course_section.dart';

void main() {
  test('every registered program is checked automatically', () {
    for (final check in ProgramCheckService.checkAll()) {
      expect(
        check.errors,
        isEmpty,
        reason: '${check.major}: ${check.errors.join('; ')}',
      );
    }
  });
  test(
    'four class years have two CS and two STEM students with full-time records',
    () {
      final students = [
        fictionalStudent,
        sophomoreStudent,
        juniorStudent,
        seniorStudent,
      ];
      expect(students.map((s) => s.classification).toSet(), {
        'Freshman',
        'Sophomore',
        'Junior',
        'Senior',
      });
      expect(students.where((s) => s.major == 'Computer Science').length, 2);
      expect(students.map((s) => s.major).toSet(), {
        'Computer Science',
        'Electrical Engineering',
        'Physics',
      });
      for (final student in students) {
        final catalog = catalogFor(student), program = programFor(student);
        expect(student.inProgressCredits, inInclusiveRange(12, 18));
        expect(student.requiredCredits, program.totalCreditsRequired);
        expect(
          student.courses.map((c) => c.courseCode).toSet().length,
          student.courses.length,
        );
        expect(
          student.courses
              .where((c) => c.status == CourseStatus.inProgress)
              .every((c) => c.grade == null),
          isTrue,
        );
        expect(DegreeAuditService().auditProgram(student, program), isNotEmpty);
        final sections =
            (jsonDecode(
                  File('assets/data/course_sections_spring_2027.json')
                      .readAsStringSync(),
                ) as List)
                .map(
                  (j) => CourseSection.fromJson(Map<String, dynamic>.from(j)),
                )
                .toList();
        final plan = SemesterPlanService().generatePlan(
          student: student,
          program: program,
          catalog: catalog,
          maxCredits: 15,
          sections: sections,
        );
        expect(plan.totalCredits, lessThanOrEqualTo(15));
      }
      expect(sophomoreStudent.earnedCredits, inInclusiveRange(30, 59));
      expect(juniorStudent.earnedCredits, inInclusiveRange(60, 89));
      expect(seniorStudent.earnedCredits, greaterThanOrEqualTo(90));
    },
  );
  test('all source library entries have original pages and valid continuation files', () {
    final entries = jsonDecode(
      File('assets/programs/index.json').readAsStringSync(),
    ) as List;
    expect(entries.length, 40);
    for (final e in entries) {
      expect(File(e['image']).existsSync(), isTrue);
      expect((e['text'] as String).contains('PROGRAM OF STUDY'), isTrue);
      if (e['continuationPage'] != null) {
        expect(
          File('assets/programs/page-${e['continuationPage']}.jpg')
              .existsSync(),
          isTrue,
        );
      }
    }
  });
}
