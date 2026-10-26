import '../models/degree_program.dart';

DegreeRequirement requiredCourse(
  String code,
  String title,
  double credits,
  String category, {
  String? minimumGrade,
}) {
  return DegreeRequirement(
    id: code,
    title: title,
    category: category,
    type: RequirementType.requiredCourse,
    creditsRequired: credits,
    courseCodes: [code],
    minimumGrade: minimumGrade,
  );
}

final benedictComputerScience2024 = DegreeProgram(
  institution: 'Benedict College',
  name: 'Computer Science',
  degreeType: 'B.S.',
  catalogYear: '2024',
  totalCreditsRequired: 120,
  majorCreditsRequired: 69,
  requirements: [
    DegreeRequirement(
      id: 'GENED_ENGLISH',
      title: 'English',
      category: 'General Education',
      type: RequirementType.creditHours,
      creditsRequired: 9,
      courseCodes: [
        'ENG 131',
        'ENG 132',
        'ENG 237',
      ],
    ),

    // One 9-credit Global & Intercultural category, tracked as three
    // mandatory 3-credit components. Catalogue 2025-2026, pp. 102-103,
    // 183 and 286; applied to this profile following the student's confirmation.
    DegreeRequirement(
      id: 'GENED_GLOBAL_HISTORY',
      title: 'Global & Intercultural: African American History',
      category: 'General Education',
      type: RequirementType.requiredCourse,
      creditsRequired: 3,
      courseCodes: ['HIST 130'],
      note: 'Mandatory history component of the 9-credit Global & Intercultural category.',
    ),
    DegreeRequirement(
      id: 'GENED_GLOBAL',
      title: 'Global & Intercultural: Cultural/Social Science Elective',
      category: 'General Education',
      type: RequirementType.oneOfCourses,
      creditsRequired: 3,
      courseCodes: [
        'ART 130', 'EC 130', 'ENG 231', 'ENG 232',
        'HIST 131', 'HIST 132', 'HIST 231', 'HIST 232',
        'MUS 130', 'PHIL 230', 'PHIL 235', 'POLS 230',
        'POLS 233', 'POLS 234', 'PSY 230', 'REL 130',
        'SOC 230', 'SOC 232A', 'SOC 239', 'THE 230', 'HON 230', 'HON 233',
      ],
      note: 'One approved 3-credit elective within the 9-credit category. '
          'HIST 130 is reserved for the mandatory history component and is not counted again here. '
          'The listed HIST options are the 100/200-level courses identified in the catalogue.',
    ),
    DegreeRequirement(
      id: 'GENED_LANGUAGE',
      title: 'Global & Intercultural: Foreign Language',
      category: 'General Education',
      type: RequirementType.oneOfCourses,
      creditsRequired: 3,
      courseCodes: ['AR 233', 'FS 233', 'SP 233'],
      note: 'Mandatory intermediate-language component of the same 9-credit category, not 3 additional credits.',
    ),

    DegreeRequirement(
      id: 'GENED_MATH',
      title: 'Mathematics',
      category: 'General Education',
      type: RequirementType.creditHours,
      creditsRequired: 8,
      courseCodes: [
        'MATH 143',
        'MATH 144',
      ],
    ),

    DegreeRequirement(
      id: 'GENED_SCIENCE',
      title: 'Natural Science',
      category: 'General Education',
      type: RequirementType.creditHours,
      creditsRequired: 4,
      courseCodes: [
        'PHYS 233',
        'PHYS 213L',
      ],
    ),

    DegreeRequirement(
      id: 'GENED_SEMINARS',
      title: 'Seminars',
      category: 'General Education',
      type: RequirementType.creditHours,
      creditsRequired: 2,
      courseCodes: [
        'AA 111',
        'AA 211',
      ],
    ),

    requiredCourse(
      'CSC 132',
      'Introduction to Computing and Programming Concepts',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 133',
      'Digital Logic',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 135',
      'Introduction to Programming',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 138',
      'Object-Oriented Programming',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 139',
      'Web Development',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 232',
      'Foundations of App Development',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 233',
      'Data Structures & Algorithms I',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 234',
      'Theory of Computation',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 235',
      'Fundamentals of App Development',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 237',
      'Java Programming',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 238',
      'Introduction to Computer Security',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 334',
      'Data Structures & Algorithms II',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 336',
      'Advanced Concepts in App Development',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 337',
      'Computer Organization and Architecture',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 338',
      'Artificial Intelligence',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 339',
      'Data Communication and Networking',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 430',
      'Senior Research and Professional Experience',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 431',
      'Programming Languages',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 434',
      'Database Management',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 435',
      'Software Engineering Principles',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 436',
      'Operating Systems',
      3,
      'Major',
      minimumGrade: 'C',
    ),
    requiredCourse(
      'CSC 437',
      'Senior Capstone',
      3,
      'Major',
      minimumGrade: 'C',
    ),

    DegreeRequirement(
      id: 'CSC_ELECTIVE',
      title: 'Computer Science Elective',
      category: 'Major',
      type: RequirementType.elective,
      creditsRequired: 3,
      minimumGrade: 'C',
    ),

    requiredCourse(
      'MATH 230',
      'Linear Algebra',
      3,
      'Support',
    ),
    requiredCourse(
      'MATH 236',
      'Probability and Statistics',
      3,
      'Support',
    ),
    requiredCourse(
      'MATH 336',
      'Discrete Mathematics',
      3,
      'Support',
    ),
    requiredCourse(
      'PHYS 214L',
      'Principles of Physics II Lab',
      1,
      'Support',
    ),
    requiredCourse(
      'PHYS 234',
      'Principles of Physics II',
      3,
      'Support',
    ),

    DegreeRequirement(
      id: 'FREE_ELECTIVES',
      title: 'Free Electives',
      category: 'Electives',
      type: RequirementType.elective,
      creditsRequired: 6,
      note:
          'Elective credit must be confirmed in the individual student audit.',
    ),

    DegreeRequirement(
      id: 'TOTAL_CREDITS',
      title: '120 Total Credit Hours',
      category: 'Graduation',
      type: RequirementType.totalCredits,
      creditsRequired: 120,
    ),

    DegreeRequirement(
      id: 'MINIMUM_GPA',
      title: 'Minimum Cumulative GPA',
      category: 'Graduation',
      type: RequirementType.minimumGpa,
      minimumGpa: 2.0,
    ),
  ],
);