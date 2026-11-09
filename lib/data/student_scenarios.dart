import '../models/student.dart';
import '../models/student_course.dart';
import 'additional_programs.dart';
import 'cs_course_catalog.dart';

const sophomoreEmail = 'demo.sophomore@my.benedict.edu';
const juniorEmail = 'demo.junior@my.benedict.edu';
const seniorEmail = 'demo.senior@my.benedict.edu';
final _credits = {
  for (final c in [...computerScienceCourseCatalog, ...extendedStemCatalog])
    c.code: c.credits,
  'AR 130': 3.0,
  'MATH 138': 3.0,
  'MATH 134': 3.0,
};
Student _student(
  String name,
  String major,
  String standing,
  int total,
  List<(String, List<String>)> terms,
  List<String> current, {
  Map<String, double> confirmed = const {},
}) {
  final completed = <StudentCourse>[];
  double earned = 0, points = 0;
  for (final term in terms) {
    for (final code in term.$2) {
      final credit = _credits[code]!;
      final grade = completed.length % 3 == 0 ? 'B' : 'A';
      completed.add(
        StudentCourse(
          courseCode: code,
          grade: grade,
          term: term.$1,
          status: CourseStatus.completed,
        ),
      );
      earned += credit;
      points += credit * (grade == 'A' ? 4 : 3);
    }
  }
  return Student(
    name: '$name (Demo)',
    institution: 'Benedict College',
    major: major,
    catalogYear: '2025–2026',
    classification: standing,
    gpa: double.parse((points / earned).toStringAsFixed(2)),
    earnedCredits: earned,
    inProgressCredits: current.fold<double>(
      0,
      (sum, code) => sum + _credits[code]!,
    ),
    requiredCredits: total.toDouble(),
    confirmedRequirementCredits: confirmed,
    courses: [
      ...completed,
      for (final code in current)
        StudentCourse(
          courseCode: code,
          term: 'Fall 2026',
          status: CourseStatus.inProgress,
        ),
    ],
  );
}

final sophomoreStudent = _student(
  'Casey Brooks',
  'Electrical Engineering',
  'Sophomore',
  123,
  [
    ('Summer 2025 (dual enrollment)', ['MATH 138']),
    (
      'Fall 2025',
      ['ENG 131', 'MATH 143', 'CSC 132', 'ENGR 130', 'HIST 130', 'AA 111'],
    ),
    ('Spring 2026', ['ENG 132', 'MATH 144', 'CSC 135', 'MUS 130']),
  ],
  [
    'CE 211L',
    'CE 231',
    'EE 211L',
    'EE 231',
    'MATH 237',
    'PHYS 213L',
    'PHYS 233',
    'AA 211',
  ],
);
final juniorStudent = _student(
  'Morgan Lee',
  'Computer Science',
  'Junior',
  120,
  [
    ('Summer 2024 (dual enrollment)', ['AR 130', 'MATH 134']),
    (
      'Fall 2024',
      ['ENG 131', 'MATH 143', 'CSC 132', 'CSC 133', 'HIST 130', 'AA 111'],
    ),
    ('Spring 2025', ['ENG 132', 'MATH 144', 'CSC 135', 'CSC 138', 'AR 233']),
    (
      'Fall 2025',
      ['ENG 237', 'MATH 237', 'CSC 139', 'CSC 232', 'CSC 233', 'AA 211'],
    ),
    ('Spring 2026', ['MATH 230', 'CSC 234', 'CSC 235', 'PHIL 330', 'ART 130']),
  ],
  ['CSC 334', 'CSC 336', 'CSC 339', 'CSC 238', 'PHYS 233', 'PHYS 213L'],
);
final seniorStudent = _student(
  'Riley Chen',
  'Physics',
  'Senior',
  120,
  [
    ('Summer 2023 (transfer credit)', ['AR 130', 'MATH 134']),
    ('Fall 2023', ['ENG 131', 'MATH 143', 'CSC 132', 'ENGR 130', 'AA 111']),
    ('Spring 2024', ['ENG 132', 'MATH 144', 'CSC 135', 'ENGR 132', 'ART 130']),
    (
      'Fall 2024',
      [
        'CHEM 117L',
        'CHEM 137',
        'CSC 138',
        'MATH 237',
        'PHYS 213L',
        'PHYS 233',
        'AA 211',
      ],
    ),
    (
      'Spring 2025',
      [
        'CHEM 118L',
        'CHEM 138',
        'ENG 237',
        'HIST 130',
        'MATH 238',
        'PHYS 214L',
        'PHYS 234',
      ],
    ),
    ('Fall 2025', ['AR 233', 'MATH 236', 'PHYS 332', 'PHYS 336']),
    (
      'Spring 2026',
      ['MATH 241', 'PHIL 330', 'PHYS 331', 'PHYS 333', 'PHYS 334'],
    ),
  ],
  ['MATH 230', 'PHYS 431', 'PHYS 435', 'PHYS 338'],
  confirmed: {'PHYS_ELECTIVES': 3},
);
final additionalStudentScenarios = <String, Student>{
  sophomoreEmail: sophomoreStudent,
  juniorEmail: juniorStudent,
  seniorEmail: seniorStudent,
};
