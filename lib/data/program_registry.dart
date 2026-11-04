import '../models/course.dart';
import '../models/degree_program.dart';
import '../models/student.dart';
import 'cs_program.dart';
import 'cs_course_catalog.dart';
import 'engineering_program.dart';
import 'test_student.dart';
import 'additional_programs.dart';

/// Every registered mapping is exercised by the catalogue checks, not a per-page switch.
final programMappings = <String, DegreeProgram>{
  'Computer Science': benedictComputerScience2024,
  'Computer Engineering': computerEngineeringProgram,
  'Electrical Engineering': electricalEngineeringProgram,
  'Physics': physicsProgram,
};
final catalogMappings = <String, List<Course>>{
  'Computer Science': [
    ...computerScienceCourseCatalog,
    ...extendedStemCatalog.where(
      (course) =>
          !computerScienceCourseCatalog.any((c) => c.code == course.code),
    ),
  ],
  'Computer Engineering': computerEngineeringCatalog,
  'Electrical Engineering': extendedStemCatalog,
  'Physics': extendedStemCatalog,
};
DegreeProgram programFor(Student student) =>
    programMappings[student.major] ??
    (throw StateError('This major has no verified program mapping.'));
List<Course> catalogFor(Student student) =>
    catalogMappings[student.major] ??
    (throw StateError('This major has no verified course mapping.'));
DegreeProgram get activeProgram => programFor(activeStudent);
List<Course> get activeCatalog => catalogFor(activeStudent);
const engineeringPreviewNotice =
    'Computer Engineering uses the 125-credit catalogue program, including support courses and lecture/lab corequisites. Confirm placement, the MATH 139/140 discrepancy, required permissions and graduating-senior design clearance with your advisor.';
