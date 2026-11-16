enum CourseStatus { completed, inProgress }

class StudentCourse {
  final String courseCode;
  final String? grade;
  final String term;
  final CourseStatus status;
  final double? creditHours;
  final bool isTransfer;
  final String? approvedElectiveId;

  const StudentCourse({
    required this.courseCode,
    required this.term,
    required this.status,
    this.grade,
    this.creditHours,
    this.isTransfer = false,
    this.approvedElectiveId,
  });

  String? get normalizedGrade => grade?.trim().toUpperCase();
  bool get transfer =>
      isTransfer ||
      RegExp(
        r'\b(transfer|dual enrollment)\b',
        caseSensitive: false,
      ).hasMatch(term);

  static const gradePoints = {'A': 4.0, 'B': 3.0, 'C': 2.0, 'D': 1.0, 'F': 0.0};
  static const recordGrades = [
    'A',
    'B',
    'C',
    'D',
    'F',
    'CR',
    'I',
    'WC',
    'WU',
    'WS',
    'WA',
    'AU',
  ];

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
      'WC',
      'WU',
      'WS',
      'WA',
    }.contains(grade)) {
      return false;
    }
    if (minimum == null) return true;
    if (transfer && grade == 'CR') {
      return const ['C', 'C-', 'D+', 'D', 'D-'].contains(minimum);
    }
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
      'creditHours': ?creditHours,
      if (isTransfer) 'isTransfer': true,
      'approvedElectiveId': ?approvedElectiveId,
    };
  }
}
