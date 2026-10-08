import '../models/course.dart';
import '../models/degree_program.dart';
import '../models/student.dart';
import '../models/student_course.dart';
import 'course_completion_service.dart';

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
  final CourseCompletionService _completion = CourseCompletionService();
  List<CourseEligibilityResult> checkProgramCourses(
    Student student,
    DegreeProgram program,
    List<Course> catalog,
  ) {
    final requiredCourseCodes = program.requirements
        .where(
          (requirement) => requirement.type == RequirementType.requiredCourse,
        )
        .expand((requirement) => requirement.courseCodes)
        .toSet();

    final completedCodes = _completion.satisfiedCodes(student, program);

    final inProgressCodes = student.courses
        .where((course) => course.status == CourseStatus.inProgress)
        .map((course) => _completion.normalizeCode(course.courseCode))
        .toSet();

    final remainingCourses = catalog.where(
      (course) =>
          requiredCourseCodes.any(
            (code) =>
                _completion.normalizeCode(code) ==
                _completion.normalizeCode(course.code),
          ) &&
          !completedCodes.contains(_completion.normalizeCode(course.code)) &&
          !inProgressCodes.contains(_completion.normalizeCode(course.code)),
    );

    return remainingCourses
        .map((course) => checkCourse(student, course, program: program))
        .toList();
  }

  CourseEligibilityResult checkCourse(
    Student student,
    Course course, {
    DegreeProgram? program,
  }) {
    CourseCompletionStatus statusFor(String code) => _completion.evaluate(
      student,
      code,
      minimumGrade: program == null
          ? null
          : _completion.minimumGradeForCourse(program, code),
    );

    if (statusFor(course.code) == CourseCompletionStatus.needsReview) {
      return CourseEligibilityResult(
        course: course,
        status: EligibilityStatus.blocked,
        reason: 'Previous grade needs review before recommending a retake.',
      );
    }

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
        (code) => statusFor(code) == CourseCompletionStatus.satisfied,
      );

      if (completedRequirement) {
        continue;
      }

      final inProgressRequirement = group.any(
        (code) => statusFor(code) == CourseCompletionStatus.inProgress,
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
          reason: 'Missing prerequisite requirements, but instructor permission may be allowed.',
        );
      }

      return CourseEligibilityResult(
        course: course,
        status: EligibilityStatus.blocked,
        missingPrerequisites: missing,
        reason: 'Prerequisites need a qualifying passing grade. Unknown grades need review.',
      );
    }

    if (dependsOnCurrentCourse) {
      return CourseEligibilityResult(
        course: course,
        status: EligibilityStatus.eligibleAfterCurrentTerm,
        reason: 'Eligible if the current prerequisite course is completed successfully.',
      );
    }

    return CourseEligibilityResult(
      course: course,
      status: EligibilityStatus.eligible,
      reason:
          statusFor(course.code) != CourseCompletionStatus.satisfied &&
              student.courses.any(
                (attempt) =>
                    _completion.normalizeCode(attempt.courseCode) ==
                        _completion.normalizeCode(course.code) &&
                    attempt.status == CourseStatus.completed,
              )
          ? 'Retake or grade review needed: this course has no qualifying completed attempt.'
          : 'Prerequisites completed.',
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
