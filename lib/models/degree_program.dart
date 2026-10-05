enum RequirementType {
  requiredCourse,
  oneOfCourses,
  creditHours,
  elective,
  totalCredits,
  minimumGpa,
}

class DegreeRequirement {
  final String id;
  final String title;
  final String category;
  final RequirementType type;
  final double creditsRequired;
  final List<String> courseCodes;
  final String? minimumGrade;
  final double? minimumGpa;
  final String? note;

  const DegreeRequirement({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    this.creditsRequired = 0,
    this.courseCodes = const [],
    this.minimumGrade,
    this.minimumGpa,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'type': type.name,
      'creditsRequired': creditsRequired,
      'courseCodes': courseCodes,
      'minimumGrade': minimumGrade,
      'minimumGpa': minimumGpa,
      'note': note,
    };
  }
}

class DegreeProgram {
  final String institution;
  final String name;
  final String degreeType;
  final String catalogYear;
  final double totalCreditsRequired;
  final double majorCreditsRequired;
  final List<DegreeRequirement> requirements;

  const DegreeProgram({
    required this.institution,
    required this.name,
    required this.degreeType,
    required this.catalogYear,
    required this.totalCreditsRequired,
    required this.majorCreditsRequired,
    required this.requirements,
  });

  Map<String, dynamic> toJson() {
    return {
      'institution': institution,
      'name': name,
      'degreeType': degreeType,
      'catalogYear': catalogYear,
      'totalCreditsRequired': totalCreditsRequired,
      'majorCreditsRequired': majorCreditsRequired,
      'requirements':
          requirements.map((requirement) => requirement.toJson()).toList(),
    };
  }
}