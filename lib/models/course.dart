class Course {
  final String code;
  final String title;
  final double credits;
  final String category;
  final List<List<String>> prerequisiteGroups;
  final bool allowsInstructorPermission;
  final String? minimumClassStanding;

  const Course({
    required this.code,
    required this.title,
    required this.credits,
    required this.category,
    this.prerequisiteGroups = const [],
    this.allowsInstructorPermission = false,
    this.minimumClassStanding,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'title': title,
      'credits': credits,
      'category': category,
      'prerequisiteGroups': prerequisiteGroups,
      'allowsInstructorPermission': allowsInstructorPermission,
      'minimumClassStanding': minimumClassStanding,
    };
  }
}