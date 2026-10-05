import '../models/course.dart';
import '../models/degree_program.dart';
import '../models/student.dart';
import '../models/student_course.dart';

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

  const CourseEligibilityResult({
    required this.course,
    required this.status,
    this.missingPrerequisites = const [],
    this.reason,
  });
}

class CourseEligibilityService {
  List<CourseEligibilityResult> checkProgramCourses(
    Student student,
    DegreeProgram program,
    List<Course> catalog,
  ) {
    final requiredCourseCodes = program.requirements
        .where(
          (requirement) =>
              requirement.type == RequirementType.requiredCourse,
        )
        .expand((requirement) => requirement.courseCodes)
        .toSet();

    final completedCodes = student.courses
        .where(
          (course) => course.status == CourseStatus.completed,
        )
        .map((course) => course.courseCode)
        .toSet();

    final inProgressCodes = student.courses
        .where(
          (course) => course.status == CourseStatus.inProgress,
        )
        .map((course) => course.courseCode)
        .toSet();

    final remainingCourses = catalog.where(
      (course) =>
          requiredCourseCodes.contains(course.code) &&
          !completedCodes.contains(course.code) &&
          !inProgressCodes.contains(course.code),
    );

    return remainingCourses
        .map(
          (course) => checkCourse(
            student,
            course,
          ),
        )
        .toList();
  }

  CourseEligibilityResult checkCourse(
    Student student,
    Course course,
  ) {
    final completedCodes = student.courses
        .where(
          (studentCourse) =>
              studentCourse.status == CourseStatus.completed,
        )
        .map((studentCourse) => studentCourse.courseCode)
        .toSet();

    final inProgressCodes = student.courses
        .where(
          (studentCourse) =>
              studentCourse.status == CourseStatus.inProgress,
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

    final missing = <String>[];
    var dependsOnCurrentCourse = false;

    for (final group in course.prerequisiteGroups) {
      final completedRequirement = group.any(
        completedCodes.contains,
      );

      if (completedRequirement) {
        continue;
      }

      final inProgressRequirement = group.any(
        inProgressCodes.contains,
      );

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
          reason:
              'Missing prerequisite requirements, but instructor permission may be allowed.',
        );
      }

      return CourseEligibilityResult(
        course: course,
        status: EligibilityStatus.blocked,
        missingPrerequisites: missing,
        reason: 'Prerequisites have not been completed.',
      );
    }

    if (dependsOnCurrentCourse) {
      return CourseEligibilityResult(
        course: course,
        status: EligibilityStatus.eligibleAfterCurrentTerm,
        reason:
            'Eligible if the current prerequisite course is completed successfully.',
      );
    }

    return CourseEligibilityResult(
      course: course,
      status: EligibilityStatus.eligible,
      reason: 'Prerequisites completed.',
    );
  }

  bool _meetsClassStanding(
    String currentStanding,
    String? requiredStanding,
  ) {
    if (requiredStanding == null) {
      return true;
    }

    final standings = {
      'Freshman': 1,
      'Sophomore': 2,
      'Junior': 3,
      'Senior': 4,
    };

    final current = standings[currentStanding];
    final required = standings[requiredStanding];

    if (current == null || required == null) {
      return false;
    }

    return current >= required;
  }
}