class Course {
  final String code;
  final String title;
  final double credits;
  final String category;
  final List<List<String>> prerequisiteGroups;
  final bool allowsInstructorPermission;
  final String? minimumClassStanding;
  final Map<String, String> minimumPrerequisiteGrades;
  final bool allowsPlacementExemption;
  final bool requiresPassingPrerequisites;
  final List<String> corequisiteCodes;
  final bool requiresAdvisorApproval;

  const Course({
    required this.code,
    required this.title,
    required this.credits,
    required this.category,
    this.prerequisiteGroups = const [],
    this.allowsInstructorPermission = false,
    this.minimumClassStanding,
    this.minimumPrerequisiteGrades = const {},
    this.allowsPlacementExemption = false,
    this.requiresPassingPrerequisites = false,
    this.corequisiteCodes = const [],
    this.requiresAdvisorApproval = false,
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
      'minimumPrerequisiteGrades': minimumPrerequisiteGrades,
      'allowsPlacementExemption': allowsPlacementExemption,
      'requiresPassingPrerequisites': requiresPassingPrerequisites,
      'corequisiteCodes': corequisiteCodes,
      'requiresAdvisorApproval': requiresAdvisorApproval,
    };
  }
}
