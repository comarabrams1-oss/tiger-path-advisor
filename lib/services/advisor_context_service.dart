import '../models/course.dart';
import '../models/course_section.dart';
import '../models/degree_program.dart';
import '../models/student.dart';
import 'course_priority_service.dart';
import 'degree_audit_service.dart';

/// A minimal explanation context. No student name, grades, GPA, transcript,
/// portal HTML, or session fields are included.
class AdvisorContextService {
  Map<String, Object?> build({
    required Student student,
    required DegreeProgram program,
    required List<Course> catalog,
    required List<CourseSection> sections,
    required String term,
  }) {
    final audit = DegreeAuditService().auditProgram(student, program);
    final ranked = CoursePriorityService().rankCourses(
      student,
      program,
      catalog,
    );
    return {
      'program': program.name,
      'catalogYear': program.catalogYear,
      'classification': student.classification,
      'term': term,
      'requirements': [
        for (final item in audit)
          {
            'id': item.requirement.id,
            'title': item.requirement.title,
            'status': item.status.name,
            'completedCredits': item.completedCredits,
            'inProgressCredits': item.inProgressCredits,
            'courseCodes': item.requirement.courseCodes,
            'creditsRequired': item.requirement.creditsRequired,
            'type': item.requirement.type.name,
            'note': item.requirement.note,
          },
      ],
      'recommendations': [
        for (final result in ranked)
          {
            'courseCode': result.course.code,
            'title': result.course.title,
            'eligibility': result.eligibility.status.name,
            'missingPrerequisites': result.eligibility.missingPrerequisites,
            'eligibilityReason': result.eligibility.reason,
            'reasons': result.reasons,
            'unlocks': result.unlocks,
            'openSections': sections
                .where(
                  (section) =>
                      section.term == term &&
                      section.courseCode == result.course.code &&
                      section.isOpen &&
                      section.hasOpenSeats,
                )
                .length,
          },
      ],
      'dataNotice':
          'Imported offerings are a snapshot. In-progress prerequisites '
          'are conditional on successful completion. The AI explains the '
          'computed results and cannot change eligibility or degree rules.',
    };
  }
}
