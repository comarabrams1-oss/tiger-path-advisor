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
    String question = '',
  }) {
    final audit = DegreeAuditService().auditProgram(student, program);
    final ranked = CoursePriorityService().rankCourses(
      student,
      program,
      catalog,
    );
    final termSections = sections.where((s) => s.term == term).toList();
    final query = question.toLowerCase();
    final requestedCodes = RegExp(r'\b([a-z]{2,5})\s*(\d{3}[a-z]?)\b')
        .allMatches(query)
        .map((m) => '${m[1]} ${m[2]}'.toUpperCase())
        .toSet();
    final recommendedCodes = ranked.map((r) => r.course.code).toSet();
    int relevance(CourseSection section) {
      if (requestedCodes.contains(section.courseCode)) {
        return 0;
      }
      if (section.allInstructorNames.any(
        (name) => name
            .toLowerCase()
            .split(RegExp(r'\W+'))
            .any(
              (part) =>
                  part.length >= 4 &&
                  RegExp('\\b${RegExp.escape(part)}\\b').hasMatch(query),
            ),
      )) {
        return 1;
      }
      if (section.courseName != null &&
          query.contains(section.courseName!.toLowerCase())) {
        return 2;
      }
      return recommendedCodes.contains(section.courseCode) ? 3 : 4;
    }

    termSections.sort((a, b) {
      final order = relevance(a).compareTo(relevance(b));
      return order != 0 ? order : a.fullCourseCode.compareTo(b.fullCourseCode);
    });
    final details = termSections.take(40).toList();
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
            if (result.course.corequisiteCodes.isNotEmpty)
              'corequisites': result.course.corequisiteCodes,
            if (result.eligibility.requiredCompanions.isNotEmpty)
              'requiredCompanions': result.eligibility.requiredCompanions,
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
      'offeredCourseCodes':
          termSections.map((s) => s.courseCode).toSet().toList()..sort(),
      'sectionDetails': [
        for (final section in details)
          {
            'courseCode': section.courseCode,
            'title': section.courseName,
            'section': section.sectionNumber,
            'instructors': section.allInstructorNames,
            'schedule': section.scheduleDisplay,
            'location': section.location,
            'delivery': section.deliveryMethod,
            'credits': section.credits,
            'openSeats': section.openSeats,
            'capacity': section.capacity,
            'status': section.status,
            'beginDate': section.beginDate,
            'endDate': section.endDate,
          },
      ],
      'sectionCoverage': {
        'included': details.length,
        'total': termSections.length,
        'notice': 'Details are limited to 40 sections, prioritizing course codes and instructor names in the latest question, then degree recommendations. Missing details do not mean a course is unavailable. Ask for a specific course code for more details. Empty instructors or null times/seats mean unknown, not confirmed availability.',
      },
      'dataNotice':
          'Imported offerings are a snapshot. In-progress prerequisites '
          'are conditional on successful completion. The AI explains the '
          'computed results and cannot change eligibility or degree rules.'
          '${program.name == 'Computer Engineering' ? ' Computer Engineering courses, support requirements and lab corequisites are mapped from the supplied catalogue. A lab must be scheduled with its required lecture unless that lecture was passed or will be passed this term. MATH 139/140 equivalency, graduating-senior design clearance and explicit permissions still require verification.' : ''}',
    };
  }
}
