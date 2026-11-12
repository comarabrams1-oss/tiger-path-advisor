import '../models/course.dart';
import '../models/degree_program.dart';
import '../models/student.dart';
import '../models/student_course.dart';
import 'degree_audit_service.dart';

enum EligibilityStatus {
  eligible,
  eligibleAfterCurrentTerm,
  requiresPermission,
  blocked,
}

class CourseEligibilityResult {
  final Course course;
  final EligibilityStatus status;
  final List<String> missingPrerequisites;
  final String? reason;
  final List<String> requiredCompanions;

  const CourseEligibilityResult({
    required this.course,
    required this.status,
    this.missingPrerequisites = const [],
    this.reason,
    this.requiredCompanions = const [],
  });
}

class CourseEligibilityService {
  List<CourseEligibilityResult> checkProgramCourses(
    Student student,
    DegreeProgram program,
    List<Course> catalog,
  ) {
    final audit = DegreeAuditService().auditProgram(student, program);
    final inProgressCodes = student.courses
        .where((course) => course.status == CourseStatus.inProgress)
        .map((course) => course.courseCode)
        .toSet();

    final remainingCourses = catalog.where(
      (course) =>
          !inProgressCodes.contains(course.code) &&
          audit.any((item) => item.needsCourse(student, course.code)),
    );

    return remainingCourses
        .map((course) => checkCourse(student, course))
        .toList();
  }

  CourseEligibilityResult checkCourse(Student student, Course course) {
    final completedCodes = student.courses
        .where(
          (attempt) =>
              attempt.meetsMinimumGrade(
                course.minimumPrerequisiteGrades[attempt.courseCode],
              ) &&
              (!course.requiresPassingPrerequisites ||
                  RegExp(r'^[ABCD][+-]?$')
                      .hasMatch(attempt.normalizedGrade ?? '')),
        )
        .map((attempt) => attempt.courseCode)
        .toSet();

    final inProgressCodes = student.courses
        .where(
          (studentCourse) => studentCourse.status == CourseStatus.inProgress,
        )
        .map((studentCourse) => studentCourse.courseCode)
        .toSet();

    if (!_meetsClassStanding(
      student.classification,
      course.minimumClassStanding,
    )) {
      return CourseEligibilityResult(
        course: course,
        status: EligibilityStatus.blocked,
        reason: 'Requires ${course.minimumClassStanding} standing.',
      );
    }

    if (course.requiresAdvisorApproval) {
      return CourseEligibilityResult(
        course: course,
        status: EligibilityStatus.requiresPermission,
        reason: 'Graduating-senior/design clearance must be verified by your advisor before this course is planned.',
      );
    }
    final requiredCompanions = course.corequisiteCodes
        .where(
          (code) =>
              !completedCodes.contains(code) && !inProgressCodes.contains(code),
        )
        .toList();
    final currentCorequisites = course.corequisiteCodes
        .where(
          (code) =>
              !completedCodes.contains(code) && inProgressCodes.contains(code),
        )
        .toList();
    final companionNote = requiredCompanions.isEmpty
        ? ''
        : ' Must take together with ${requiredCompanions.join(', ')}.';
    final placementVerified = student.verifiedPlacementCourses.contains(
      course.code,
    );
    final failedElementary =
        course.allowsPlacementExemption &&
        course.prerequisiteGroups.any(
          (group) =>
              !group.any(completedCodes.contains) &&
              student.courses.any(
                (attempt) =>
                    group.contains(attempt.courseCode) &&
                    attempt.normalizedGrade == 'F',
              ),
        );
    if (course.allowsPlacementExemption &&
        !failedElementary &&
        currentCorequisites.isEmpty &&
        placementVerified) {
      return CourseEligibilityResult(
        course: course,
        status: EligibilityStatus.eligible,
        reason:
            'Verified college placement exemption for ${course.code}.$companionNote',
        requiredCompanions: requiredCompanions,
      );
    }
    final missing = <String>[];
    var dependsOnCurrentCourse = currentCorequisites.isNotEmpty;

    for (final group in course.prerequisiteGroups) {
      final completedRequirement = group.any(completedCodes.contains);

      if (completedRequirement) {
        continue;
      }

      final inProgressRequirement = group.any(inProgressCodes.contains);

      if (inProgressRequirement) {
        dependsOnCurrentCourse = true;
        continue;
      }

      missing.add(group.join(' OR '));
    }

    if (missing.isNotEmpty) {
      if (course.allowsInstructorPermission) {
        return CourseEligibilityResult(
          course: course,
          status: EligibilityStatus.requiresPermission,
          missingPrerequisites: missing,
          reason: 'Missing prerequisite requirements, but instructor permission may be allowed.',
        );
      }

      return CourseEligibilityResult(
        course: course,
        status: EligibilityStatus.blocked,
        missingPrerequisites: missing,
        reason: failedElementary
            ? 'Elementary language must be passed before taking this course.'
            : 'Prerequisites have not been completed.',
      );
    }

    if (dependsOnCurrentCourse) {
      return CourseEligibilityResult(
        course: course,
        status: EligibilityStatus.eligibleAfterCurrentTerm,
        reason:
            'For next term only: must first pass ${[...course.prerequisiteGroups.where((g) => !g.any(completedCodes.contains)).map((g) => g.join(' or ')), ...currentCorequisites].join(' and ')}${course.allowsPlacementExemption && !placementVerified ? '. No placement exemption is recorded' : ''}.$companionNote',
        requiredCompanions: requiredCompanions,
      );
    }

    return CourseEligibilityResult(
      course: course,
      status: EligibilityStatus.eligible,
      reason: 'Prerequisites completed.$companionNote',
      requiredCompanions: requiredCompanions,
    );
  }

  bool _meetsClassStanding(String currentStanding, String? requiredStanding) {
    if (requiredStanding == null) {
      return true;
    }

    final standings = {'Freshman': 1, 'Sophomore': 2, 'Junior': 3, 'Senior': 4};

    final current = standings[currentStanding];
    final required = standings[requiredStanding];

    if (current == null || required == null) {
      return false;
    }

    return current >= required;
  }
}
