import '../models/course.dart';
import '../models/degree_program.dart';
import 'cs_program.dart';
import 'cs_course_catalog.dart';
import 'engineering_program.dart';

// Catalogue 2025–26: program tables pp. 275 and 293; descriptions pp.
// 232, 260, 273–274, 279, 289–290, 294. Preserve source discrepancies.
Course _course(
  String code,
  String title,
  double credits, {
  List<List<String>> prerequisites = const [],
  List<String> corequisites = const [],
  String? standing,
  bool clearance = false,
}) => Course(
  code: code,
  title: title,
  credits: credits,
  category: 'Support',
  prerequisiteGroups: prerequisites,
  corequisiteCodes: corequisites,
  minimumClassStanding: standing,
  requiresAdvisorApproval: clearance,
  requiresPassingPrerequisites: true,
);

final extendedStemCatalog = <Course>[
  ...computerEngineeringCatalog,
  ...computerScienceCourseCatalog.where(
    (course) => !computerEngineeringCatalog.any((c) => c.code == course.code),
  ),
  _course('ENGR 132', 'Engineering Graphics and Design', 3),
  _course(
    'MATH 238',
    'Differential Equations II',
    3,
    prerequisites: [
      ['MATH 237'],
    ],
  ),
  _course(
    'MATH 241',
    'Calculus III',
    4,
    prerequisites: [
      ['MATH 144'],
    ],
  ),
  _course(
    'PHIL 330',
    'Critical Thinking and Logic',
    3,
    prerequisites: [
      ['MATH 134'],
    ],
  ),
  _course('CHEM 137', 'Principles of Chemistry I', 3),
  _course(
    'CHEM 117L',
    'Principles of Chemistry I Lab',
    1,
    corequisites: ['CHEM 137'],
  ),
  _course(
    'CHEM 138',
    'Principles of Chemistry II',
    3,
    prerequisites: [
      ['CHEM 137'],
    ],
  ),
  _course(
    'CHEM 118L',
    'Principles of Chemistry II Lab',
    1,
    prerequisites: [
      ['CHEM 117L'],
    ],
    corequisites: ['CHEM 138'],
  ),
  _course(
    'PHYS 331',
    'Statics',
    3,
    prerequisites: [
      ['MATH 143'],
    ],
  ),
  _course(
    'PHYS 332',
    'Dynamics',
    3,
    prerequisites: [
      ['MATH 143'],
    ],
  ),
  _course(
    'PHYS 333',
    'Principles of Physics III',
    3,
    prerequisites: [
      ['PHYS 234'],
    ],
  ),
  _course(
    'PHYS 334',
    'Thermal Physics',
    3,
    prerequisites: [
      ['PHYS 233'],
    ],
  ),
  _course(
    'PHYS 336',
    'Electricity and Magnetism',
    3,
    prerequisites: [
      ['PHYS 234'],
    ],
  ),
  _course(
    'PHYS 338',
    'Modern Electronics',
    3,
    prerequisites: [
      ['PHYS 234'],
    ],
  ),
  _course(
    'PHYS 431',
    'Modern Physics I',
    3,
    prerequisites: [
      ['PHYS 333'],
    ],
  ),
  _course(
    'PHYS 432',
    'Modern Physics II',
    3,
    prerequisites: [
      ['PHYS 431'],
    ],
  ),
  _course(
    'PHYS 434',
    'Advanced Modern Physics Laboratory',
    3,
    prerequisites: [
      ['PHYS 431'],
    ],
  ),
  _course(
    'PHYS 435',
    'Optics',
    3,
    prerequisites: [
      ['PHYS 234'],
    ],
  ),
  _course(
    'PHYS 436',
    'Introduction to Quantum Mechanics',
    3,
    prerequisites: [
      ['PHYS 431'],
    ],
  ),
  // PHYS 244 is the printed prerequisite. Do not silently substitute PHYS 234.
  _course(
    'EE 333',
    'Electromagnetics',
    3,
    prerequisites: [
      ['PHYS 244'],
    ],
    corequisites: ['MATH 241'],
  ),
  _course(
    'EE 433',
    'Electric Energy and Power Systems',
    3,
    prerequisites: [
      ['EE 333'],
    ],
  ),
  _course(
    'EE 434',
    'Control Systems',
    3,
    prerequisites: [
      ['EE 330'],
    ],
  ),
  _course(
    'EE 427',
    'Senior Design Project I',
    2,
    standing: 'Senior',
    clearance: true,
  ),
  _course(
    'EE 428',
    'Senior Design Project II',
    2,
    prerequisites: [
      ['EE 427'],
    ],
  ),
];

final _byCode = {for (final c in extendedStemCatalog) c.code: c};
DegreeRequirement _required(
  String code, {
  String? category,
  bool minC = false,
}) {
  final c = _byCode[code]!;
  return requiredCourse(
    code,
    c.title,
    c.credits,
    category ?? 'Support',
    minimumGrade: minC ? 'C' : null,
  );
}

DegreeRequirement _choice(
  String id,
  String title,
  List<String> codes, {
  String category = 'General Education',
  bool minC = false,
}) => DegreeRequirement(
  id: id,
  title: title,
  category: category,
  type: RequirementType.oneOfCourses,
  creditsRequired: 3,
  courseCodes: codes,
  minimumGrade: minC ? 'C' : null,
);
List<DegreeRequirement> _graduation(int credits) => [
  DegreeRequirement(
    id: 'TOTAL_CREDITS',
    title: '$credits Total Credit Hours',
    category: 'Graduation',
    type: RequirementType.totalCredits,
    creditsRequired: credits.toDouble(),
  ),
  const DegreeRequirement(
    id: 'MINIMUM_GPA',
    title: 'Minimum Cumulative GPA',
    category: 'Graduation',
    type: RequirementType.minimumGpa,
    minimumGpa: 2,
  ),
];
final _global = benedictComputerScience2024.requirements.firstWhere(
  (r) => r.id == 'GENED_GLOBAL',
);
final _language = benedictComputerScience2024.requirements.firstWhere(
  (r) => r.id == 'GENED_LANGUAGE',
);
final electricalEngineeringProgram = DegreeProgram(
  institution: 'Benedict College',
  name: 'Electrical Engineering',
  degreeType: 'B.S.',
  catalogYear: '2025–2026',
  totalCreditsRequired: 123,
  majorCreditsRequired: 66,
  requirements: [
    for (final code in [
      'ENG 131',
      'ENG 132',
      'ENG 237',
      'HIST 130',
      'AA 111',
      'AA 211',
    ])
      _required(code, category: 'General Education'),
    _required('MATH 143', category: 'General Education', minC: true),
    _required('MATH 144', category: 'General Education'),
    _global,
    _language,
    for (final code in [
      'CSC 132',
      'CSC 135',
      'MATH 237',
      'MATH 336',
      'MATH 236',
      'MATH 230',
      'MATH 241',
      'PHYS 213L',
      'PHYS 233',
      'PHYS 214L',
      'PHYS 234',
      'PHYS 332',
    ])
      _required(code),
    for (final code in [
      'ENGR 130',
      'CE 211L',
      'CE 231',
      'EE 211L',
      'EE 231',
      'EE 212L',
      'EE 232',
      'EE 213L',
      'EE 233',
      'CE 332',
      'EE 332',
      'EE 314L',
      'EE 334',
      'EE 330',
      'EE 333',
      'EE 427',
      'EE 433',
      'ENGR 331',
      'EE 428',
      'EE 431',
      'EE 434',
      'ENGR 321',
    ])
      _required(code, category: 'Major', minC: true),
    _choice(
      'EE_ALGORITHMS',
      'Data Structures and Algorithms I or Algorithm Design I',
      ['CSC 233', 'CSC 136'],
      category: 'Support',
    ),
    _choice('EE_ARCHITECTURE', 'Computer Organization or Assembly Language', [
      'CSC 337',
      'CSC 231',
    ], category: 'Support'),
    _choice(
      'EE_ELECTIVE',
      'Electrical Engineering Major Elective',
      ['EE 435', 'CSC 338', 'EE 436', 'CE 436', 'CE 437'],
      category: 'Major',
      minC: true,
    ),
    ..._graduation(123),
  ],
);
final physicsProgram = DegreeProgram(
  institution: 'Benedict College',
  name: 'Physics',
  degreeType: 'B.S.',
  catalogYear: '2025–2026',
  totalCreditsRequired: 120,
  majorCreditsRequired: 41,
  requirements: [
    for (final code in [
      'ENG 131',
      'ENG 132',
      'ENG 237',
      'HIST 130',
      'AA 111',
      'AA 211',
    ])
      _required(code, category: 'General Education'),
    _global,
    _language,
    for (final code in [
      'MATH 143',
      'MATH 144',
      'CSC 132',
      'ENGR 130',
      'CSC 135',
      'ENGR 132',
      'CHEM 117L',
      'CHEM 137',
      'CSC 138',
      'MATH 237',
      'CHEM 118L',
      'CHEM 138',
      'MATH 238',
      'MATH 236',
      'MATH 241',
      'PHIL 330',
      'MATH 230',
    ])
      _required(code),
    for (final code in [
      'PHYS 213L',
      'PHYS 233',
      'PHYS 214L',
      'PHYS 234',
      'PHYS 332',
      'PHYS 336',
      'PHYS 331',
      'PHYS 333',
      'PHYS 334',
      'PHYS 431',
      'PHYS 435',
      'PHYS 338',
      'PHYS 432',
      'PHYS 434',
      'PHYS 436',
    ])
      _required(code, category: 'Major', minC: true),
    const DegreeRequirement(
      id: 'PHYS_ELECTIVES',
      title: 'Advisor-approved Electives',
      category: 'Electives',
      type: RequirementType.elective,
      creditsRequired: 9,
      note: 'Elective credit is recorded only when explicitly confirmed; do not infer approval from AI.',
    ),
    ..._graduation(120),
  ],
);
