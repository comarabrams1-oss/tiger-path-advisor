import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/models/student_course.dart';

void main() {
  final fall = (jsonDecode(
    File('assets/data/course_sections_fall_2026.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  double credits(String code) =>
      (fall.firstWhere((s) => s['courseCode'] == code)['credits'] as num)
          .toDouble();
  for (final student in [fictionalStudent, engineeringStudent]) {
    test(
      '${student.name} has a full-time record with consistent credits and GPA',
      () {
        final current = student.courses
            .where((c) => c.status == CourseStatus.inProgress)
            .toList();
        final completed = student.courses
            .where((c) => c.status == CourseStatus.completed)
            .toList();
        expect(current.length, 6);
        expect(
          current.every((c) => c.term == 'Fall 2026' && c.grade == null),
          isTrue,
        );
        expect(
          current.fold<double>(0, (sum, c) => sum + credits(c.courseCode)),
          16,
        );
        expect(student.inProgressCredits, 16);
        expect(
          completed.every((c) => c.term.contains('dual enrollment')),
          isTrue,
        );
        expect(
          completed.fold<double>(0, (sum, c) => sum + credits(c.courseCode)),
          student.earnedCredits,
        );
        const points = {'A': 4.0, 'B': 3.0};
        final gradePoints = completed.fold<double>(
          0,
          (sum, c) => sum + credits(c.courseCode) * points[c.grade]!,
        );
        expect(student.gpa, closeTo(gradePoints / student.earnedCredits, .005));
        expect(
          student.courses.map((c) => c.courseCode).toSet().length,
          student.courses.length,
        );
        expect(student.confirmedRequirementCredits, isEmpty);
        expect(student.classification, 'Freshman');
      },
    );
  }
}
