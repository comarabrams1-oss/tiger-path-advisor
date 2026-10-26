import '../models/course.dart';
import '../models/degree_program.dart';
import '../models/student.dart';
import 'cs_program.dart';
import 'cs_course_catalog.dart';
import 'engineering_program.dart';
import 'test_student.dart';

DegreeProgram programFor(Student student) => switch (student.major) {
  'Computer Science' => benedictComputerScience2024,
  'Computer Engineering' => computerEngineeringProgram,
  _ => throw StateError('This major has no verified program mapping.'),
};
List<Course> catalogFor(Student student) => switch (student.major) {
  'Computer Science' => computerScienceCourseCatalog,
  'Computer Engineering' => computerEngineeringCatalog,
  _ => throw StateError('This major has no verified course mapping.'),
};
DegreeProgram get activeProgram => programFor(activeStudent);
List<Course> get activeCatalog => catalogFor(activeStudent);
const engineeringPreviewNotice =
    'Computer Engineering uses the 125-credit catalogue program, including support courses and lecture/lab corequisites. Confirm placement, the MATH 139/140 discrepancy, required permissions and graduating-senior design clearance with your advisor.';
