import '../models/degree_program.dart';
import '../models/student.dart';
import '../models/student_course.dart';

enum RequirementStatus { completed, inProgress, remaining }

class DegreeAuditItem {
  final DegreeRequirement requirement;
  final RequirementStatus status;
  final double completedCredits;
  final double inProgressCredits;

  const DegreeAuditItem({
    required this.requirement,
    required this.status,
    this.completedCredits = 0,
    this.inProgressCredits = 0,
  });

  bool needsCourse(Student student, String code) =>
      status == RequirementStatus.remaining &&
      (requirement.type == RequirementType.requiredCourse ||
          requirement.type == RequirementType.oneOfCourses ||
          requirement.type == RequirementType.creditHours) &&
      requirement.courseCodes.contains(code) &&
      !student.courses.any(
        (course) =>
            course.courseCode == code &&
            course.meetsMinimumGrade(requirement.minimumGrade),
      );
}

class DegreeAuditService {
  List<DegreeAuditItem> auditProgram(Student student, DegreeProgram program) {
    return program.requirements
        .map((requirement) => _auditRequirement(student, requirement))
        .toList();
  }

  DegreeAuditItem _auditRequirement(
    Student student,
    DegreeRequirement requirement,
  ) {
    switch (requirement.type) {
      case RequirementType.requiredCourse:
      case RequirementType.oneOfCourses:
        return _auditCourseChoice(student, requirement);

      case RequirementType.creditHours:
        return _auditCreditHours(student, requirement);

      case RequirementType.totalCredits:
        return DegreeAuditItem(
          requirement: requirement,
          status: student.earnedCredits >= requirement.creditsRequired
              ? RequirementStatus.completed
              : student.earnedCredits + student.inProgressCredits >=
                    requirement.creditsRequired
              ? RequirementStatus.inProgress
              : RequirementStatus.remaining,
          completedCredits: student.earnedCredits,
          inProgressCredits: student.inProgressCredits,
        );

      case RequirementType.minimumGpa:
        final minimum = requirement.minimumGpa ?? 0;

        return DegreeAuditItem(
          requirement: requirement,
          status: student.hasCalculatedGpa && student.gpa >= minimum
              ? RequirementStatus.completed
              : RequirementStatus.remaining,
        );

      case RequirementType.elective:
        final approved = <String, double>{};
        for (final course in student.courses) {
          if (course.approvedElectiveId != requirement.id ||
              !course.meetsMinimumGrade(requirement.minimumGrade)) {
            continue;
          }
          final hours = course.creditHours ?? 0;
          if (hours > (approved[course.courseCode] ?? 0)) {
            approved[course.courseCode] = hours;
          }
        }
        final credits =
            (student.confirmedRequirementCredits[requirement.id] ?? 0) +
            approved.values.fold(0.0, (sum, hours) => sum + hours);
        return DegreeAuditItem(
          requirement: requirement,
          status: credits >= requirement.creditsRequired
              ? RequirementStatus.completed
              : RequirementStatus.remaining,
          completedCredits: credits
              .clamp(0, requirement.creditsRequired)
              .toDouble(),
        );
    }
  }

  DegreeAuditItem _auditCourseChoice(
    Student student,
    DegreeRequirement requirement,
  ) {
    final matching = student.courses.where(
      (course) => requirement.courseCodes.contains(course.courseCode),
    );
    if (matching.any(
      (course) => course.meetsMinimumGrade(requirement.minimumGrade),
    )) {
      return DegreeAuditItem(
        requirement: requirement,
        status: RequirementStatus.completed,
        completedCredits: requirement.creditsRequired,
      );
    }
    if (matching.any((course) => course.status == CourseStatus.inProgress)) {
      return DegreeAuditItem(
        requirement: requirement,
        status: RequirementStatus.inProgress,
        inProgressCredits: requirement.creditsRequired,
      );
    }
    return DegreeAuditItem(
      requirement: requirement,
      status: RequirementStatus.remaining,
    );
  }

  DegreeAuditItem _auditCreditHours(
    Student student,
    DegreeRequirement requirement,
  ) {
    final completed = <String, double>{};
    final inProgress = <String, double>{};
    for (final course in student.courses) {
      if (!requirement.courseCodes.contains(course.courseCode)) continue;
      final hours = course.creditHours ?? _creditsForCourse(course.courseCode);
      if (course.meetsMinimumGrade(requirement.minimumGrade)) {
        if (hours > (completed[course.courseCode] ?? 0)) {
          completed[course.courseCode] = hours;
        }
      } else if (course.status == CourseStatus.inProgress &&
          hours > (inProgress[course.courseCode] ?? 0)) {
        inProgress[course.courseCode] = hours;
      }
    }
    final completedHours = completed.values.fold<double>(
      0,
      (sum, hours) => sum + hours,
    );
    final inProgressHours = inProgress.entries
        .where((entry) => !completed.containsKey(entry.key))
        .fold<double>(0, (sum, entry) => sum + entry.value);

    if (completedHours >= requirement.creditsRequired) {
      return DegreeAuditItem(
        requirement: requirement,
        status: RequirementStatus.completed,
        completedCredits: completedHours,
        inProgressCredits: inProgressHours,
      );
    }

    if (completedHours + inProgressHours >= requirement.creditsRequired) {
      return DegreeAuditItem(
        requirement: requirement,
        status: RequirementStatus.inProgress,
        completedCredits: completedHours,
        inProgressCredits: inProgressHours,
      );
    }

    return DegreeAuditItem(
      requirement: requirement,
      status: RequirementStatus.remaining,
      completedCredits: completedHours,
      inProgressCredits: inProgressHours,
    );
  }

  double _creditsForCourse(String code) {
    const credits = {
      'ENG 131': 3.0,
      'ENG 132': 3.0,
      'ENG 237': 3.0,
      'HIST 130': 3.0,
      'MUS 130': 3.0,
      'AR 233': 3.0,
      'FS 233': 3.0,
      'SP 233': 3.0,
      'MATH 143': 4.0,
      'MATH 144': 4.0,
      'PHYS 233': 3.0,
      'PHYS 213L': 1.0,
      'AA 111': 1.0,
      'AA 211': 1.0,
    };

    return credits[code] ?? 0;
  }

  List<DegreeAuditItem> completedRequirements(
    Student student,
    DegreeProgram program,
  ) {
    return auditProgram(
      student,
      program,
    ).where((item) => item.status == RequirementStatus.completed).toList();
  }

  List<DegreeAuditItem> inProgressRequirements(
    Student student,
    DegreeProgram program,
  ) {
    return auditProgram(
      student,
      program,
    ).where((item) => item.status == RequirementStatus.inProgress).toList();
  }

  List<DegreeAuditItem> remainingRequirements(
    Student student,
    DegreeProgram program,
  ) {
    return auditProgram(
      student,
      program,
    ).where((item) => item.status == RequirementStatus.remaining).toList();
  }
}
