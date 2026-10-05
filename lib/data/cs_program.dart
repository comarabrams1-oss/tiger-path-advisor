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

    DegreeRequirement(
      id: 'GENED_GLOBAL',
      title: 'Global & Intercultural Learning',
      category: 'General Education',
      type: RequirementType.creditHours,
      creditsRequired: 9,
      courseCodes: [
        'HIST 130',
        'MUS 130',
      ],
      note:
          'Additional approved Global & Intercultural course options still need to be added.',
    ),

    DegreeRequirement(
      id: 'GENED_LANGUAGE',
      title: 'Foreign Language',
      category: 'General Education',
      type: RequirementType.oneOfCourses,
      creditsRequired: 3,
      courseCodes: [
        'AR 233',
        'FS 233',
        'SP 233',
      ],
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
          'Your current audit shows this requirement as already met.',
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