import '../data/course_descriptions.dart';
import '../models/course.dart';
import '../models/course_section.dart';
import '../models/degree_program.dart';
import '../data/program_registry.dart';
import 'program_check_service.dart';
import '../models/student.dart';
import 'course_eligibility_service.dart';
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
    Iterable<String> earlierMessages = const [],
    bool sectionsAvailable = true,
  }) {
    final audit = DegreeAuditService().auditProgram(student, program);
    final ranked = CoursePriorityService().rankCourses(
      student,
      program,
      catalog,
    );
    final termSections = sections.where((s) => s.term == term).toList();
    final query = question.toLowerCase();
    final catalogByCode = {for (final course in catalog) course.code: course};
    final titles = {
      for (final entry in courseDescriptions.entries) entry.key: entry.value.$1,
      for (final course in catalog) course.code: course.title,
      for (final section in termSections)
        if (section.courseName case final String title)
          section.courseCode: title,
    };
    final aliases = <String, Set<String>>{};
    void addTitle(String code, String title) {
      final normalized = _normalizeTitle(title);
      if (normalized.length >= 6) {
        (aliases[normalized] ??= {}).add(code);
      }
    }

    for (final entry in titles.entries) {
      addTitle(entry.key, entry.value);
    }
    for (final entry in courseDescriptions.entries) {
      addTitle(entry.key, entry.value.$1);
    }
    for (final course in catalog) {
      addTitle(course.code, course.title);
    }
    addTitle('CSC 338', 'Intro to AI');
    addTitle('CSC 338', 'Artificial Intelligence');
    addTitle('PHYS 232', 'Physics II');
    addTitle('PHYS 234', 'Physics II');

    var requestedCodes = _courseMatches(question, aliases);
    if (requestedCodes.isEmpty && _isCourseFollowUp(query)) {
      for (final previous in earlierMessages) {
        final matches = _courseMatches(previous, aliases);
        if (matches.isNotEmpty) {
          if (matches.length <= 3) requestedCodes = matches;
          break;
        }
      }
    }
    final eligibility = CourseEligibilityService();
    final openSectionCounts = <String, int>{};
    for (final section in termSections) {
      if (section.isOpen && section.hasOpenSeats) {
        openSectionCounts.update(
          section.courseCode,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
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
      return recommendedCodes.contains(section.courseCode) ? 2 : 3;
    }

    termSections.sort((a, b) {
      final order = relevance(a).compareTo(relevance(b));
      return order != 0 ? order : a.fullCourseCode.compareTo(b.fullCourseCode);
    });
    final details = termSections.take(40).toList();
    return {
      'program': program.name,
      'catalogYear': program.catalogYear,
      if (programMappings.containsKey(program.name))
        'programMappingReview': [
          ...ProgramCheckService.check(program.name).errors,
          ...ProgramCheckService.check(program.name).review,
        ],
      'programLibrary': 'Programs of study is available from Home and Degree Progress. Reference pages alone do not verify a program mapping.',
      'classification': student.classification,
      'term': term,
      'offeringsAvailable': sectionsAvailable,
      if (requestedCodes.isNotEmpty)
        'focusedCourses': [
          for (final code in requestedCodes.take(6))
            {
              'courseCode': code,
              'title': courseDescriptions[code]?.$1 ?? titles[code],
              if (courseDescriptions[code] case final description?) ...{
                'description': description.$3,
                'source':
                    'Benedict College Catalogue 2025–2026, p. ${description.$2}',
              },
              if (catalogByCode[code] case final course?) ...{
                'credits': course.credits,
                'prerequisiteGroups': course.prerequisiteGroups,
                'corequisites': course.corequisiteCodes,
                'eligibility': _eligibilityDetails(
                  eligibility.checkCourse(student, course),
                ),
              },
              if (sectionsAvailable) ...{
                'offered': termSections.any(
                  (section) => section.courseCode == code,
                ),
                'openSections': openSectionCounts[code] ?? 0,
              },
            },
        ],
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
            'note': ?item.requirement.note,
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
            if (result.unlocks.isNotEmpty) 'unlocks': result.unlocks,
            if (sectionsAvailable)
              'openSections': openSectionCounts[result.course.code] ?? 0,
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
            'asynchronous': section.isAsynchronous,
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
        'notice': 'Up to 40 sections, prioritizing the requested course or instructor. Omitted sections and empty fields do not establish availability.',
      },
      'dataNotice':
          'Imported offerings are a snapshot. In-progress prerequisites '
          'are conditional on successful completion. The AI explains the '
          'computed results and cannot change eligibility or degree rules.'
          '${program.name == 'Computer Engineering' ? ' Computer Engineering courses, support requirements and lab corequisites are mapped from the supplied catalogue. A lab must be scheduled with its required lecture unless that lecture was passed or will be passed this term. MATH 139/140 equivalency, graduating-senior design clearance and explicit permissions still require verification.' : ''}',
    };
  }

  static String _normalizeTitle(String text) => text
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'\bintroduction\b'), 'intro')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  static bool _isCourseFollowUp(String text) => RegExp(
    r'\b(it|that|this|those|them|they|the (class|course)|what about)\b',
  ).hasMatch(text);

  static Set<String> _courseMatches(
    String text,
    Map<String, Set<String>> aliases,
  ) {
    final codes =
        RegExp(r'\b([a-z]{2,6})[\s-]*(\d{3}[a-z]{0,2})\b', caseSensitive: false)
            .allMatches(text)
            .where(
              (match) => !const {
                'can',
                'for',
                'the',
                'need',
                'take',
                'about',
              }.contains(match[1]!.toLowerCase()),
            )
            .map((match) => '${match[1]} ${match[2]}'.toUpperCase())
            .toSet();
    final query = ' ${_normalizeTitle(text)} ';
    final matches = <(int, int, String)>[];
    for (final title in aliases.keys) {
      final start = query.indexOf(' $title ');
      if (start >= 0) matches.add((start, start + title.length + 1, title));
    }
    // For "Principles of Physics II Lab", ignore the lecture title inside it.
    matches.sort((a, b) => b.$3.length.compareTo(a.$3.length));
    final selected = <(int, int, String)>[];
    for (final match in matches) {
      if (!selected.any(
        (other) => match.$1 < other.$2 && other.$1 < match.$2,
      )) {
        selected.add(match);
      }
    }
    selected.sort((a, b) => a.$1.compareTo(b.$1));
    final byTitle = {for (final match in selected) ...aliases[match.$3]!};
    return codes.isEmpty
        ? byTitle
        : {
            ...codes,
            if (RegExp(
              r'\b(and|versus|vs|compare|difference)\b',
              caseSensitive: false,
            ).hasMatch(text))
              ...byTitle,
          };
  }

  static Map<String, Object?> _eligibilityDetails(
    CourseEligibilityResult result,
  ) => {
    'status': result.status.name,
    'reason': result.reason,
    'missingPrerequisites': result.missingPrerequisites,
    'requiredCompanions': result.requiredCompanions,
  };

  static String? courseOverview(
    String question,
    Map<String, Object?> context, {
    bool includeMixedQuestions = false,
  }) {
    final query = _normalizeTitle(question);
    final courses =
        (context['focusedCourses'] as List?)?.cast<Map<String, Object?>>() ??
        [];
    final codeOnly = RegExp(r'^[a-z]{2,6} ?\d{3}[a-z]{0,2}$').hasMatch(query);
    final descriptionQuestion = RegExp(
      r'\b(whats|what (is|s|are|does|do|will|topics)|what [^?.]{1,100} is about|tell me (more )?about|describe|explain|i want to know)\b',
    ).hasMatch(query);
    final otherQuestion = RegExp(
      r'\b(teach\w*|instructors?|professors?|time|seats?|sections?|offered|available|prerequisites?|eligible|can i|should i|counts?|credits?|requirements?|difference|compare|schedule|replace|swap|switch|change|hard|easy|workload|textbook|exams?|assignments?|grading|how many|when|where)\b',
    ).hasMatch(query);
    final asksAboutContent = RegExp(
      r'\b(about|cover\w*|learn\w*|topics|like)\b',
    ).hasMatch(query);
    if ((otherQuestion && !(includeMixedQuestions && asksAboutContent)) ||
        !(codeOnly ||
            (descriptionQuestion &&
                (courses.isNotEmpty ||
                    asksAboutContent && _isCourseFollowUp(query))))) {
      return null;
    }
    if (courses.isEmpty) {
      return 'Which course do you mean? Send the course code or full title.';
    }
    if (courses.length > 1 &&
        _courseMatches(question, const {}).isEmpty &&
        !RegExp(r'\b(and|both|compare|difference|versus|vs)\b')
            .hasMatch(query)) {
      final options = courses.map(
        (course) => '**${course['courseCode']}** · ${course['title']}',
      );
      return 'Which course do you mean?\n\n${options.map((option) => '- $option').join('\n')}';
    }
    return courses
        .map((course) {
          final code = course['courseCode'];
          final title = course['title'];
          final name = title == null ? '$code' : '$code · $title';
          final description = course['description'];
          if (description == null) {
            return '**$name**\n\nI don’t have a verified description for this course. Check Benedict’s catalogue or the course syllabus for details.';
          }
          return '**$name**\n\n$description\n\n${course['source']}.';
        })
        .join('\n\n');
  }
}
