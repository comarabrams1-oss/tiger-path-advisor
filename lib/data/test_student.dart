import '../models/student.dart';
import '../models/student_course.dart';

const Student testStudent = Student(
  name: 'Comar Abrams Jr',
  institution: 'Benedict College',
  major: 'Computer Science',
  catalogYear: '2024',
  classification: 'Junior',
  gpa: 3.66,
  earnedCredits: 73,
  inProgressCredits: 16,
  requiredCredits: 120,
  confirmedRequirementCredits: {'FREE_ELECTIVES': 6},
  courses: [
    StudentCourse(
      courseCode: 'AA 111',
      grade: 'A',
      term: 'Fall 2024',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'CSC 132',
      grade: 'A',
      term: 'Fall 2024',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'CSC 133',
      grade: 'A',
      term: 'Fall 2024',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'ENG 131',
      grade: 'A',
      term: 'Fall 2024',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'HIST 130',
      grade: 'A',
      term: 'Fall 2024',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'MATH 108',
      grade: 'LB',
      term: 'Fall 2024',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'MATH 138',
      grade: 'B',
      term: 'Fall 2024',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'CSC 135',
      grade: 'A',
      term: 'Spring 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'CSC 139',
      grade: 'A',
      term: 'Spring 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'CSC 234',
      grade: 'A',
      term: 'Spring 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'ENG 132',
      grade: 'A',
      term: 'Spring 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'MATH 139',
      grade: 'A',
      term: 'Spring 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'MUS 130',
      grade: 'A',
      term: 'Spring 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'MATH 143',
      grade: 'C',
      term: 'Summer 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'AA 211',
      grade: 'A',
      term: 'Fall 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'CSC 138',
      grade: 'A',
      term: 'Fall 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'CSC 232',
      grade: 'A',
      term: 'Fall 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'CSC 337',
      grade: 'A',
      term: 'Fall 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'ENG 237',
      grade: 'A',
      term: 'Fall 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'MATH 144',
      grade: 'C',
      term: 'Fall 2025',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'AR 130',
      grade: 'A',
      term: 'Spring 2026',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'CSC 233',
      grade: 'A',
      term: 'Spring 2026',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'CSC 235',
      grade: 'A',
      term: 'Spring 2026',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'MATH 230',
      grade: 'A',
      term: 'Spring 2026',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'MATH 236',
      grade: 'A',
      term: 'Spring 2026',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'MATH 336',
      grade: 'C',
      term: 'Spring 2026',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'AR 233',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'CSC 334',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'CSC 336',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'CSC 339',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'PHYS 213L',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'PHYS 233',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
  ],
);

/// The selected local demo record. This prototype has one active session.
Student activeStudent = testStudent;

const mockStudentEmail = 'demo.student@my.benedict.edu';
// Fictional first-year students with limited pre-college dual-enrollment credit.
// Each has a full 16-credit current semester; no current course has a final grade.
const fictionalStudent = Student(
  name: 'Jordan Taylor (Demo)',
  institution: 'Benedict College',
  major: 'Computer Science',
  catalogYear: '2024',
  classification: 'Freshman',
  gpa: 3.5,
  earnedCredits: 6,
  inProgressCredits: 16,
  requiredCredits: 120,
  courses: [
    StudentCourse(
      courseCode: 'ENG 131',
      grade: 'A',
      term: 'Spring 2026 (dual enrollment)',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'HIST 130',
      grade: 'B',
      term: 'Spring 2026 (dual enrollment)',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'CSC 132',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'CSC 133',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'ENG 132',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'MATH 138',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'AA 111',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'AR 130',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
  ],
);

const engineeringStudentEmail = 'demo.engineering@my.benedict.edu';
const engineeringStudent = Student(
  name: 'Alex Morgan (Engineering Demo)',
  institution: 'Benedict College',
  major: 'Computer Engineering',
  catalogYear: '2025–2026',
  classification: 'Freshman',
  gpa: 3.33,
  earnedCredits: 9,
  inProgressCredits: 16,
  requiredCredits: 125,
  courses: [
    StudentCourse(
      courseCode: 'ENG 131',
      grade: 'B',
      term: 'Spring 2026 (dual enrollment)',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'HIST 130',
      grade: 'A',
      term: 'Spring 2026 (dual enrollment)',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'MATH 138',
      grade: 'B',
      term: 'Spring 2026 (dual enrollment)',
      status: CourseStatus.completed,
    ),
    StudentCourse(
      courseCode: 'CSC 132',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'MATH 139',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'ENGR 130',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'ENG 132',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'AA 111',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
    StudentCourse(
      courseCode: 'AR 130',
      term: 'Fall 2026',
      status: CourseStatus.inProgress,
    ),
  ],
);

void selectDemoStudent(String? email) {
  activeStudent = switch (email) {
    mockStudentEmail => fictionalStudent,
    engineeringStudentEmail => engineeringStudent,
    _ => testStudent,
  };
}
