import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/data/cs_program.dart';
import 'package:tiger_path/data/cs_course_catalog.dart';
import 'package:tiger_path/services/advisor_context_service.dart';
import 'package:tiger_path/services/course_priority_service.dart';
import 'package:tiger_path/services/course_section_repository.dart';

void main() {
  test('AI context preserves computed eligibility and excludes identity', () {
    final context = AdvisorContextService().build(
      student: testStudent,
      program: benedictComputerScience2024,
      catalog: computerScienceCourseCatalog,
      sections: [],
      term: CourseSectionRepository.spring2027Term,
    );
    final encoded = jsonEncode(context);
    expect(encoded.contains(testStudent.name), isFalse);
    expect(context['classification'], testStudent.classification);
    expect(context.containsKey('gpa'), isFalse);
    expect(context.containsKey('courses'), isFalse);
    final ranked = CoursePriorityService().rankCourses(
      testStudent,
      benedictComputerScience2024,
      computerScienceCourseCatalog,
    );
    final recommendations = context['recommendations'] as List;
    expect(recommendations.length, ranked.length);
    for (var i = 0; i < ranked.length; i++) {
      expect(
        recommendations[i]['eligibility'],
        ranked[i].eligibility.status.name,
      );
      expect(
        recommendations[i]['missingPrerequisites'],
        ranked[i].eligibility.missingPrerequisites,
      );
      expect(recommendations[i]['openSections'], 0);
    }
  });
}
