import '../models/course.dart';
import '../models/degree_program.dart';
import '../models/student.dart';
import '../models/student_course.dart';
import 'course_eligibility_service.dart';
import 'degree_audit_service.dart';

class CoursePriorityResult {
  final Course course;
  final CourseEligibilityResult eligibility;
  final int score;
  final List<String> reasons;
  final List<String> unlocks;
  final String? requirementId;
  final double? requirementCreditsRemaining;

  const CoursePriorityResult({
    required this.course,
    required this.eligibility,
    required this.score,
    required this.reasons,
    required this.unlocks,
    this.requirementId,
    this.requirementCreditsRemaining,
  });
}

class CoursePriorityService {
  final CourseEligibilityService _eligibilityService =
      CourseEligibilityService();

  List<CoursePriorityResult> rankCourses(
    Student student,
    DegreeProgram program,
    List<Course> catalog,
  ) {
    final eligibilityResults = _eligibilityService.checkProgramCourses(
      student,
      program,
      catalog,
    );

    final completedCodes = student.courses
        .where((course) => course.status == CourseStatus.completed)
        .map((course) => course.courseCode)
        .toSet();

    final inProgressCodes = student.courses
        .where((course) => course.status == CourseStatus.inProgress)
        .map((course) => course.courseCode)
        .toSet();

    final audit = DegreeAuditService().auditProgram(student, program);
    final results = <CoursePriorityResult>[];

    for (final eligibility in eligibilityResults) {
      final course = eligibility.course;

      var score = 20;

      final reasons = <String>['Contributes to your ${program.name} degree'];

      switch (eligibility.status) {
        case EligibilityStatus.eligible:
          score += 40;
          reasons.add('Prerequisites are already completed');
          break;

        case EligibilityStatus.eligibleAfterCurrentTerm:
          score += 25;
          reasons.add('Can become available after your current semester');
          break;

        case EligibilityStatus.requiresPermission:
          score += 10;
          reasons.add('May be available with instructor permission');
          break;

        case EligibilityStatus.blocked:
          reasons.add('Currently blocked by prerequisites or class standing');
          break;
      }

      final freshman = student.classification.toLowerCase() == 'freshman';
      final level =
          int.tryParse(
            RegExp(r'\d{3}').firstMatch(course.code)?.group(0) ?? '999',
          ) ??
          999;
      if (freshman && level < 200) {
        score += 70;
        reasons.add('Builds your first-year foundation');
      }
      if (freshman && course.code == 'ENG 132') score += 45;
      if (freshman && course.code == 'AA 111') score += 40;
      if (freshman && level >= 300) score -= 80;

      final unlocks = _findCoursesUnlockedBy(
        course.code,
        catalog,
        completedCodes,
        inProgressCodes,
      );

      if (unlocks.isNotEmpty) {
        score += unlocks.length * 10;

        reasons.add('Helps unlock ${unlocks.join(', ')}');
      }

      final requirements = audit.where(
        (a) =>
            a.status == RequirementStatus.remaining &&
            a.requirement.courseCodes.contains(course.code),
      );
      final requirement = requirements.isEmpty ? null : requirements.first;
      results.add(
        CoursePriorityResult(
          course: course,
          eligibility: eligibility,
          score: score,
          reasons: reasons,
          unlocks: unlocks,
          requirementId: requirement?.requirement.id,
          requirementCreditsRemaining: requirement == null
              ? null
              : requirement.requirement.creditsRequired -
                    requirement.completedCredits -
                    requirement.inProgressCredits,
        ),
      );
    }

    results.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.course.code.compareTo(b.course.code);
    });

    return results;
  }

  List<String> _findCoursesUnlockedBy(
    String courseCode,
    List<Course> catalog,
    Set<String> completedCodes,
    Set<String> inProgressCodes,
  ) {
    final unlockedCourses = <String>[];

    for (final course in catalog) {
      if (completedCodes.contains(course.code) ||
          inProgressCodes.contains(course.code) ||
          course.code == courseCode) {
        continue;
      }

      final dependsOnCourse = course.prerequisiteGroups.any(
        (group) => group.contains(courseCode),
      );

      if (dependsOnCourse) {
        unlockedCourses.add(course.code);
      }
    }

    return unlockedCourses;
  }
}
