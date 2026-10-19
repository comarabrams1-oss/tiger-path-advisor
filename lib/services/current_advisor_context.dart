import '../data/cs_course_catalog.dart';
import '../data/cs_program.dart';
import '../data/test_student.dart';
import 'academic_advisor_context.dart';
import 'preferences_service.dart';
import 'semester_plan_service.dart';

AcademicAdvisorContext currentAdvisorContext({SemesterPlan? plan}) {
  final semesterPlan =
      plan ??
      SemesterPlanService().generatePlan(
        student: testStudent,
        program: benedictComputerScience2024,
        catalog: computerScienceCourseCatalog,
        maxCredits: PreferencesService.preferences?.maxCredits ?? 15,
      );
  return AcademicAdvisorContext.build(
    student: testStudent,
    program: benedictComputerScience2024,
    catalog: computerScienceCourseCatalog,
    plan: semesterPlan,
  );
}
