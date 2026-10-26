import '../models/course.dart';

/// Verified descriptions/prerequisites: Benedict 2025–26 catalogue,
/// pp. 84, 178–179, 183, 191, 200, 278–279. Placement overrides are not assumed.
const foundationCourseCatalog = <Course>[
  Course(
    code: 'AA 111',
    title: 'The College Experience',
    credits: 1,
    category: 'General Education',
  ),
  Course(
    code: 'AA 211',
    title: 'Professional Pathways Development',
    credits: 1,
    category: 'General Education',
  ),
  Course(
    code: 'ENG 131',
    title: 'Analysis and Argumentation',
    credits: 3,
    category: 'General Education',
  ),
  Course(
    code: 'ENG 132',
    title: 'Information Literacy and Research',
    credits: 3,
    category: 'General Education',
    prerequisiteGroups: [
      ['ENG 131'],
    ],
    minimumPrerequisiteGrades: {'ENG 131': 'C'},
  ),
  Course(
    code: 'ENG 237',
    title: 'Oral Communication',
    credits: 3,
    category: 'General Education',
  ),
  Course(
    code: 'ART 130',
    title: 'Foundations: Art Appreciation',
    credits: 3,
    category: 'General Education',
  ),
  Course(
    code: 'MUS 130',
    title: 'Foundations: Music Appreciation',
    credits: 3,
    category: 'General Education',
  ),
  Course(
    code: 'MATH 143',
    title: 'Calculus I',
    credits: 4,
    category: 'General Education',
    prerequisiteGroups: [
      ['MATH 140'],
    ],
  ),
  Course(
    code: 'MATH 144',
    title: 'Calculus II',
    credits: 4,
    category: 'General Education',
    prerequisiteGroups: [
      ['MATH 143'],
    ],
  ),
  Course(
    code: 'AR 233',
    title: 'Intermediate Arabic',
    credits: 3,
    category: 'General Education',
    prerequisiteGroups: [
      ['AR 130'],
    ],
  ),
  Course(
    code: 'FS 233',
    title: 'Intermediate French',
    credits: 3,
    category: 'General Education',
    prerequisiteGroups: [
      ['FS 130'],
    ],
  ),
  Course(
    code: 'SP 233',
    title: 'Intermediate Spanish',
    credits: 3,
    category: 'General Education',
    prerequisiteGroups: [
      ['SP 130'],
    ],
  ),
];
