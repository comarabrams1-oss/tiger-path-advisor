import '../models/degree_program.dart';
import '../models/student.dart';
import '../models/student_course.dart';

enum RequirementStatus {
  completed,
  inProgress,
  remaining,
}

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
}

class DegreeAuditService {
  List<DegreeAuditItem> auditProgram(
    Student student,
    DegreeProgram program,
  ) {
    return program.requirements
        .map(
          (requirement) =>
              _auditRequirement(student, requirement),
        )
        .toList();
  }

  DegreeAuditItem _auditRequirement(
    Student student,
    DegreeRequirement requirement,
  ) {
    switch (requirement.type) {
      case RequirementType.requiredCourse:
        return _auditRequiredCourse(
          student,
          requirement,
        );

      case RequirementType.oneOfCourses:
        return _auditOneOfCourses(
          student,
          requirement,
        );

      case RequirementType.creditHours:
        return _auditCreditHours(
          student,
          requirement,
        );

      case RequirementType.totalCredits:
        return DegreeAuditItem(
          requirement: requirement,
          status: student.earnedCredits >=
                  requirement.creditsRequired
              ? RequirementStatus.completed
              : student.earnedCredits +
                          student.inProgressCredits >=
                      requirement.creditsRequired
                  ? RequirementStatus.inProgress
                  : RequirementStatus.remaining,
          completedCredits: student.earnedCredits,
          inProgressCredits:
              student.inProgressCredits,
        );

      case RequirementType.minimumGpa:
        final minimum = requirement.minimumGpa ?? 0;

        return DegreeAuditItem(
          requirement: requirement,
          status: student.gpa >= minimum
              ? RequirementStatus.completed
              : RequirementStatus.remaining,
        );

      case RequirementType.elective:
        return DegreeAuditItem(
          requirement: requirement,
          status: requirement.id == 'FREE_ELECTIVES'
              ? RequirementStatus.completed
              : RequirementStatus.remaining,
        );
    }
  }

  DegreeAuditItem _auditRequiredCourse(
    Student student,
    DegreeRequirement requirement,
  ) {
    for (final studentCourse in student.courses) {
      if (!requirement.courseCodes
          .contains(studentCourse.courseCode)) {
        continue;
      }

      if (studentCourse.status == CourseStatus.completed &&
          _meetsMinimumGrade(
            studentCourse.grade,
            requirement.minimumGrade,
          )) {
        return DegreeAuditItem(
          requirement: requirement,
          status: RequirementStatus.completed,
          completedCredits:
              requirement.creditsRequired,
        );
      }

      if (studentCourse.status ==
          CourseStatus.inProgress) {
        return DegreeAuditItem(
          requirement: requirement,
          status: RequirementStatus.inProgress,
          inProgressCredits:
              requirement.creditsRequired,
        );
      }
    }

    return DegreeAuditItem(
      requirement: requirement,
      status: RequirementStatus.remaining,
    );
  }

  DegreeAuditItem _auditOneOfCourses(
    Student student,
    DegreeRequirement requirement,
  ) {
    for (final studentCourse in student.courses) {
      if (!requirement.courseCodes
          .contains(studentCourse.courseCode)) {
        continue;
      }

      if (studentCourse.status == CourseStatus.completed) {
        return DegreeAuditItem(
          requirement: requirement,
          status: RequirementStatus.completed,
          completedCredits:
              requirement.creditsRequired,
        );
      }

      if (studentCourse.status ==
          CourseStatus.inProgress) {
        return DegreeAuditItem(
          requirement: requirement,
          status: RequirementStatus.inProgress,
          inProgressCredits:
              requirement.creditsRequired,
        );
      }
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
    double completed = 0;
    double inProgress = 0;

    for (final course in student.courses) {
      if (!requirement.courseCodes.contains(course.courseCode)) {
        continue;
      }

      final credits = _creditsForCourse(
        course.courseCode,
      );

      if (course.status == CourseStatus.completed) {
        completed += credits;
      } else if (course.status ==
          CourseStatus.inProgress) {
        inProgress += credits;
      }
    }

    if (completed >= requirement.creditsRequired) {
      return DegreeAuditItem(
        requirement: requirement,
        status: RequirementStatus.completed,
        completedCredits: completed,
        inProgressCredits: inProgress,
      );
    }

    if (completed + inProgress >=
        requirement.creditsRequired) {
      return DegreeAuditItem(
        requirement: requirement,
        status: RequirementStatus.inProgress,
        completedCredits: completed,
        inProgressCredits: inProgress,
      );
    }

    return DegreeAuditItem(
      requirement: requirement,
      status: RequirementStatus.remaining,
      completedCredits: completed,
      inProgressCredits: inProgress,
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

  bool _meetsMinimumGrade(
    String? grade,
    String? minimumGrade,
  ) {
    if (minimumGrade == null) {
      return true;
    }

    if (grade == null) {
      return false;
    }

    final gradeValues = {
      'A+': 12,
      'A': 11,
      'A-': 10,
      'B+': 9,
      'B': 8,
      'B-': 7,
      'C+': 6,
      'C': 5,
      'C-': 4,
      'D+': 3,
      'D': 2,
      'D-': 1,
      'F': 0,
    };

    final studentGrade =
        gradeValues[grade.toUpperCase()];
    final requiredGrade =
        gradeValues[minimumGrade.toUpperCase()];

    if (studentGrade == null ||
        requiredGrade == null) {
      return false;
    }

    return studentGrade >= requiredGrade;
  }

  List<DegreeAuditItem> completedRequirements(
    Student student,
    DegreeProgram program,
  ) {
    return auditProgram(student, program)
        .where(
          (item) =>
              item.status ==
              RequirementStatus.completed,
        )
        .toList();
  }

  List<DegreeAuditItem> inProgressRequirements(
    Student student,
    DegreeProgram program,
  ) {
    return auditProgram(student, program)
        .where(
          (item) =>
              item.status ==
              RequirementStatus.inProgress,
        )
        .toList();
  }

  List<DegreeAuditItem> remainingRequirements(
    Student student,
    DegreeProgram program,
  ) {
    return auditProgram(student, program)
        .where(
          (item) =>
              item.status ==
              RequirementStatus.remaining,
        )
        .toList();
  }
}