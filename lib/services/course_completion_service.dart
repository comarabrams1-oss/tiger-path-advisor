import '../models/degree_program.dart';
import '../models/student.dart';
import '../models/student_course.dart';

enum CourseCompletionStatus { satisfied, inProgress, unmet, needsReview }

class CourseCompletionService {
  static const _gradeValues = {
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

  String normalizeCode(String code) =>
      code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  bool meetsMinimumGrade(String? grade, String? minimumGrade) {
    final value = _gradeValues[grade?.trim().toUpperCase()];
    final minimum = minimumGrade == null
        ? 1
        : _gradeValues[minimumGrade.trim().toUpperCase()];
    return value != null && minimum != null && value > 0 && value >= minimum;
  }

  String? minimumGradeForCourse(DegreeProgram program, String code) {
    String? minimum;
    for (final requirement in program.requirements) {
      if (requirement.type != RequirementType.requiredCourse ||
          !requirement.courseCodes.any(
            (candidate) => normalizeCode(candidate) == normalizeCode(code),
          )) {
        continue;
      }
      final grade = requirement.minimumGrade?.trim().toUpperCase();
      if (grade == null) continue;
      if (!_gradeValues.containsKey(grade)) return grade;
      if (minimum == null ||
          _gradeValues[grade]! > (_gradeValues[minimum] ?? 0)) {
        minimum = grade;
      }
    }
    return minimum;
  }

  CourseCompletionStatus evaluate(
    Student student,
    String code, {
    String? minimumGrade,
  }) {
    final attempts = student.courses.where(
      (attempt) => normalizeCode(attempt.courseCode) == normalizeCode(code),
    );
    if (attempts.any(
      (attempt) =>
          attempt.status == CourseStatus.completed &&
          meetsMinimumGrade(attempt.grade, minimumGrade),
    )) {
      return CourseCompletionStatus.satisfied;
    }
    if (attempts.any((attempt) => attempt.status == CourseStatus.inProgress)) {
      return CourseCompletionStatus.inProgress;
    }
    if (attempts.any(
      (attempt) =>
          attempt.status == CourseStatus.completed &&
          (!_gradeValues.containsKey(attempt.grade?.trim().toUpperCase()) ||
              (minimumGrade != null &&
                  !_gradeValues.containsKey(
                    minimumGrade.trim().toUpperCase(),
                  ))),
    )) {
      return CourseCompletionStatus.needsReview;
    }
    return CourseCompletionStatus.unmet;
  }

  Set<String> satisfiedCodes(Student student, DegreeProgram program) {
    return student.courses
        .map((attempt) => normalizeCode(attempt.courseCode))
        .where(
          (code) =>
              evaluate(
                student,
                code,
                minimumGrade: minimumGradeForCourse(program, code),
              ) ==
              CourseCompletionStatus.satisfied,
        )
        .toSet();
  }
}
