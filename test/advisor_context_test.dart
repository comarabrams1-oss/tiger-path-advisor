import 'dart:convert';
import 'dart:io';

import 'package:tiger_path/models/course_section.dart';

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
  test('question-specific offering context carries teachers and all meeting blocks within request budget', () {
    final sections =
        (jsonDecode(
              File('assets/data/course_sections_spring_2027.json')
                  .readAsStringSync(),
            ) as List)
            .map(
              (json) => CourseSection.fromJson(Map<String, dynamic>.from(json)),
            )
            .toList();
    final target = sections.firstWhere((s) => s.allInstructorNames.isNotEmpty);
    final context = AdvisorContextService().build(
      student: fictionalStudent,
      program: benedictComputerScience2024,
      catalog: computerScienceCourseCatalog,
      sections: sections,
      term: CourseSectionRepository.spring2027Term,
      question: 'Who teaches ${target.courseCode} and when?',
    );
    final details = context['sectionDetails'] as List;
    expect(details.length, 40);
    final actual = details.firstWhere(
      (d) =>
          d['courseCode'] == target.courseCode &&
          d['section'] == target.sectionNumber,
    );
    expect(actual['instructors'], target.allInstructorNames);
    expect(actual['schedule'], target.scheduleDisplay);
    expect(actual['openSeats'], target.openSeats);
    expect(context['classification'], 'Freshman');
    expect(utf8.encode(jsonEncode(context)).length, lessThan(40000));
    expect(jsonEncode(context), isNot(contains(fictionalStudent.name)));
  });
}
