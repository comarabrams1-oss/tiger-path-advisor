import '../models/degree_program.dart';
import '../models/student.dart';
import 'degree_audit_service.dart';

class GraduationRecommendation {
  final String title;
  final String category;
  final String message;
  final List<String> courseCodes;

  const GraduationRecommendation({
    required this.title,
    required this.category,
    required this.message,
    this.courseCodes = const [],
  });
}

class GraduationRecommendationService {
  final DegreeAuditService _auditService =
      DegreeAuditService();

  List<GraduationRecommendation> getRecommendations(
    Student student,
    DegreeProgram program,
  ) {
    final audit = _auditService.auditProgram(
      student,
      program,
    );

    final recommendations =
        <GraduationRecommendation>[];

    for (final item in audit) {
      if (item.status == RequirementStatus.completed) {
        continue;
      }

      if (item.status == RequirementStatus.inProgress) {
        recommendations.add(
          GraduationRecommendation(
            title: item.requirement.title,
            category: item.requirement.category,
            message:
                'This requirement is currently in progress.',
            courseCodes: item.requirement.courseCodes,
          ),
        );

        continue;
      }

      switch (item.requirement.type) {
        case RequirementType.requiredCourse:
          recommendations.add(
            GraduationRecommendation(
              title: item.requirement.title,
              category: item.requirement.category,
              message:
                  'This course is still required for your degree.',
              courseCodes:
                  item.requirement.courseCodes,
            ),
          );
          break;

        case RequirementType.oneOfCourses:
          recommendations.add(
            GraduationRecommendation(
              title: item.requirement.title,
              category: item.requirement.category,
              message:
                  'Complete one of the approved courses for this requirement.',
              courseCodes:
                  item.requirement.courseCodes,
            ),
          );
          break;

        case RequirementType.creditHours:
          final remainingCredits =
              item.requirement.creditsRequired -
                  item.completedCredits;

          recommendations.add(
            GraduationRecommendation(
              title: item.requirement.title,
              category: item.requirement.category,
              message:
                  '${remainingCredits.toInt()} more credits are needed for this requirement.',
              courseCodes:
                  item.requirement.courseCodes,
            ),
          );
          break;

        case RequirementType.elective:
          recommendations.add(
            GraduationRecommendation(
              title: item.requirement.title,
              category: item.requirement.category,
              message:
                  '${item.requirement.creditsRequired.toInt()} elective credits are still required.',
            ),
          );
          break;

        case RequirementType.totalCredits:
          final remaining =
              item.requirement.creditsRequired -
                  student.earnedCredits;

          recommendations.add(
            GraduationRecommendation(
              title: item.requirement.title,
              category: item.requirement.category,
              message:
                  '${remaining.toInt()} additional earned credits are needed to reach graduation.',
            ),
          );
          break;

        case RequirementType.minimumGpa:
          recommendations.add(
            GraduationRecommendation(
              title: item.requirement.title,
              category: item.requirement.category,
              message:
                  'The minimum GPA requirement has not yet been satisfied.',
            ),
          );
          break;
      }
    }

    return recommendations;
  }
}