import 'student_course.dart';

class Student {
  final String name;
  final String institution;
  final String major;
  final String catalogYear;
  final String classification;
  final double gpa;
  final double earnedCredits;
  final double inProgressCredits;
  final double requiredCredits;
  final List<StudentCourse> courses;

  const Student({
    required this.name,
    required this.institution,
    required this.major,
    required this.catalogYear,
    required this.classification,
    required this.gpa,
    required this.earnedCredits,
    required this.inProgressCredits,
    required this.requiredCredits,
    required this.courses,
  });

  double get remainingCredits =>
      requiredCredits - earnedCredits;

  double get progressPercentage =>
      (earnedCredits / requiredCredits) * 100;

  String get degreeLabel =>
      major == 'Computer Science' ? 'B.S.' : '';

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'institution': institution,
      'major': major,
      'catalogYear': catalogYear,
      'classification': classification,
      'gpa': gpa,
      'earnedCredits': earnedCredits,
      'inProgressCredits': inProgressCredits,
      'requiredCredits': requiredCredits,
      'courses': courses.map((course) => course.toJson()).toList(),
    };
  }
}