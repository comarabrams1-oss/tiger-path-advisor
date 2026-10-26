import '../models/course.dart';
import '../models/degree_program.dart';
import 'cs_course_catalog.dart';
import 'cs_program.dart';

/// Benedict College 2025–26 catalogue, program table p. 292.
final computerEngineeringProgram = DegreeProgram(
  institution: 'Benedict College',
  name: 'Computer Engineering',
  degreeType: 'B.S.',
  catalogYear: '2025–2026',
  totalCreditsRequired: 125,
  majorCreditsRequired: 77,
  requirements: [
    ...benedictComputerScience2024.requirements.where(
      (r) => r.category == 'General Education' && r.id != 'GENED_SCIENCE',
    ),
    for (final row in _major)
      requiredCourse(
        row.$1,
        row.$2,
        row.$3,
        'Major',
        minimumGrade: row.$4 ? 'C' : null,
      ),
    for (final row in _support)
      requiredCourse(row.$1, row.$2, row.$3, 'Support'),
    const DegreeRequirement(
      id: 'CE_ELECTIVE',
      title: 'Computer Engineering Major Elective',
      category: 'Major',
      type: RequirementType.oneOfCourses,
      creditsRequired: 3,
      courseCodes: ['EE 435', 'CSC 338', 'EE 436'],
      minimumGrade: 'C',
      note: 'Choose one listed engineering major elective; prerequisite verification is required.',
    ),
    const DegreeRequirement(
      id: 'TOTAL_CREDITS',
      title: '125 Total Credit Hours',
      category: 'Graduation',
      type: RequirementType.totalCredits,
      creditsRequired: 125,
    ),
    const DegreeRequirement(
      id: 'MINIMUM_GPA',
      title: 'Minimum Cumulative GPA',
      category: 'Graduation',
      type: RequirementType.minimumGpa,
      minimumGpa: 2,
    ),
  ],
);
const _major = <(String, String, double, bool)>[
  ('CSC 132', 'Introduction to Computing and Programming Logic', 3, true),
  ('ENGR 130', 'Introduction to Engineering', 3, true),
  ('CSC 135', 'Introduction to Programming', 3, true),
  ('CE 211L', 'Digital Circuits Lab', 1, true),
  ('CE 231', 'Digital Circuits', 3, true),
  ('EE 211L', 'Circuits I Lab', 1, true),
  ('EE 231', 'Circuits I', 3, true),
  ('CSC 233', 'Data Structures and Algorithms I', 3, true),
  ('EE 212L', 'Circuits II Lab', 1, true),
  ('EE 232', 'Circuits II', 3, true),
  ('EE 213L', 'Electronics I Lab', 1, true),
  ('EE 233', 'Electronics I', 3, true),
  ('CE 332', 'Embedded Systems', 3, true),
  ('CSC 339', 'Data Communication and Networking', 3, true),
  ('CSC 334', 'Data Structures and Algorithms II', 3, true),
  ('CSC 337', 'Computer Organization and Architecture', 3, true),
  ('EE 314L', 'Electronics II Lab', 1, true),
  ('EE 334', 'Electronics II', 3, true),
  ('EE 330', 'Systems and Signals', 3, true),
  ('ENGR 321', 'Engineering Professional Development', 2, true),
  ('CE 427', 'Senior Design Project I', 2, true),
  ('CE 436', 'VLSI Design', 3, true),
  ('CE 437', 'Computer Network Hardware', 3, false),
  ('CSC 435', 'Software Engineering Principles', 3, true),
  ('ENGR 331', 'Engineering Economics', 3, true),
  ('CE 428', 'Senior Design Project II', 2, true),
  ('CSC 436', 'Operating Systems', 3, true),
  ('EE 332', 'Digital Signal Processing', 3, true),
  ('EE 431', 'Communication Systems', 3, true),
];
const _support = <(String, String, double)>[
  ('MATH 237', 'Differential Equations I', 3),
  ('MATH 230', 'Linear Algebra', 3),
  ('MATH 236', 'Probability and Statistics', 3),
  ('MATH 336', 'Discrete Mathematics', 3),
  ('PHYS 213L', 'Principles of Physics I Lab', 1),
  ('PHYS 233', 'Principles of Physics I', 3),
  ('PHYS 214L', 'Principles of Physics II Lab', 1),
  ('PHYS 234', 'Principles of Physics II', 3),
];

/// Scheduling coverage is deliberately limited to verified prerequisite rules.
/// Labs are kept in the audit/review list until corequisite pairing is supported.
final computerEngineeringCatalog = <Course>[
  ...computerScienceCourseCatalog.where(
    (c) => computerEngineeringProgram.requirements.any(
      (r) => r.courseCodes.contains(c.code),
    ),
  ),
  const Course(
    code: 'ENGR 130',
    title: 'Introduction to Engineering',
    credits: 3,
    category: 'Major',
  ),
  const Course(
    code: 'CE 231',
    title: 'Digital Circuits',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['MATH 138'],
    ],
  ),
  const Course(
    code: 'EE 231',
    title: 'Circuits I',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['MATH 143'],
    ],
  ),
  const Course(
    code: 'EE 232',
    title: 'Circuits II',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['EE 231'],
    ],
  ),
  const Course(
    code: 'EE 233',
    title: 'Electronics I',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['MATH 143'],
      ['EE 231'],
    ],
  ),
];
