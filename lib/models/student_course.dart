enum CourseStatus { completed, inProgress }

class StudentCourse {
  final String courseCode;
  final String? grade;
  final String term;
  final CourseStatus status;

  const StudentCourse({
    required this.courseCode,
    required this.term,
    required this.status,
    this.grade,
  });

  String? get normalizedGrade => grade?.trim().toUpperCase();

  bool meetsMinimumGrade(String? minimum) {
    if (status != CourseStatus.completed) return false;
    final grade = normalizedGrade;
    // The transcript may contain a final result that earned no credit.
    if (const {
      'F',
      'W',
      'WF',
      'WP',
      'I',
      'U',
      'NP',
      'NC',
      'AU',
    }.contains(grade)) {
      return false;
    }
    if (minimum == null) return true;
    const grades = [
      'F',
      'D-',
      'D',
      'D+',
      'C-',
      'C',
      'C+',
      'B-',
      'B',
      'B+',
      'A-',
      'A',
      'A+',
    ];
    final required = grades.indexOf(minimum.trim().toUpperCase());
    return required >= 0 && grades.indexOf(grade ?? '') >= required;
  }

  Map<String, dynamic> toJson() {
    return {
      'courseCode': courseCode,
      'grade': grade,
      'term': term,
      'status': status.name,
    };
  }
}
