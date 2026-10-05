enum CourseStatus {
  completed,
  inProgress,
}

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

  Map<String, dynamic> toJson() {
    return {
      'courseCode': courseCode,
      'grade': grade,
      'term': term,
      'status': status.name,
    };
  }
}