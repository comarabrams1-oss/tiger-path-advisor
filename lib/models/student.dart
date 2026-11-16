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

  /// Credits explicitly confirmed by an academic audit, never inferred by AI.
  final Map<String, double> confirmedRequirementCredits;
  final Set<String> verifiedPlacementCourses;
  final bool hasLocalRecord;
  final bool hasCalculatedGpa;

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
    this.confirmedRequirementCredits = const {},
    this.verifiedPlacementCourses = const {},
    this.hasLocalRecord = false,
    this.hasCalculatedGpa = true,
  });

  double get remainingCredits =>
      (requiredCredits - earnedCredits).clamp(0.0, double.infinity);

  double get progressPercentage => (earnedCredits / requiredCredits) * 100;

  String get degreeLabel =>
      [
        'Computer Science',
        'Computer Engineering',
        'Electrical Engineering',
        'Physics',
      ].contains(major)
      ? 'B.S.'
      : '';

  Student copyWith({
    List<StudentCourse>? courses,
    double? earnedCredits,
    double? inProgressCredits,
    double? gpa,
    String? classification,
    Map<String, double>? confirmedRequirementCredits,
    bool? hasLocalRecord,
    bool? hasCalculatedGpa,
  }) => Student(
    name: name,
    institution: institution,
    major: major,
    catalogYear: catalogYear,
    classification: classification ?? this.classification,
    gpa: gpa ?? this.gpa,
    earnedCredits: earnedCredits ?? this.earnedCredits,
    inProgressCredits: inProgressCredits ?? this.inProgressCredits,
    requiredCredits: requiredCredits,
    courses: courses ?? this.courses,
    confirmedRequirementCredits:
        confirmedRequirementCredits ?? this.confirmedRequirementCredits,
    verifiedPlacementCourses: verifiedPlacementCourses,
    hasLocalRecord: hasLocalRecord ?? this.hasLocalRecord,
    hasCalculatedGpa: hasCalculatedGpa ?? this.hasCalculatedGpa,
  );

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
      'confirmedRequirementCredits': confirmedRequirementCredits,
      'verifiedPlacementCourses': verifiedPlacementCourses.toList(),
      if (!hasCalculatedGpa) 'hasCalculatedGpa': false,
    };
  }
}
