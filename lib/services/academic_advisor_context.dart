import 'dart:convert';

import '../models/course.dart';
import '../models/degree_program.dart';
import '../models/student.dart';
import 'course_eligibility_service.dart';
import 'degree_audit_service.dart';
import 'semester_plan_service.dart';

class AdvisorRequirement {
  final String title;
  final String category;
  final String status;
  final String type;
  final List<String> courseCodes;
  final double remainingCredits;
  final String? note;

  const AdvisorRequirement({
    required this.title,
    required this.category,
    required this.status,
    required this.type,
    required this.courseCodes,
    required this.remainingCredits,
    this.note,
  });

  Map<String, Object?> toJson() => {
    'title': title,
    'category': category,
    'status': status,
    'type': type,
    'approvedCourseOptions': courseCodes,
    'remainingCreditsExcludingInProgress': remainingCredits,
    if (note != null) 'note': note,
  };
}

class AcademicAdvisorContext {
  final List<AdvisorRequirement> requirements;
  final List<Map<String, Object?>> courses;
  final Map<String, Object?> plan;

  const AcademicAdvisorContext({
    required this.requirements,
    required this.courses,
    required this.plan,
  });

  factory AcademicAdvisorContext.build({
    required Student student,
    required DegreeProgram program,
    required List<Course> catalog,
    required SemesterPlan plan,
  }) {
    final audit = DegreeAuditService().auditProgram(student, program);
    final eligibility = CourseEligibilityService().checkProgramCourses(
      student,
      program,
      catalog,
    );
    return AcademicAdvisorContext(
      requirements: List.unmodifiable(
        audit
            .where(
              (item) =>
                  item.status != RequirementStatus.completed &&
                  item.requirement.category != 'Graduation',
            )
            .map(
              (item) => AdvisorRequirement(
                title: item.requirement.title,
                category: item.requirement.category,
                status: item.status.name,
                type: item.requirement.type.name,
                courseCodes: List.unmodifiable(item.requirement.courseCodes),
                remainingCredits:
                    (item.requirement.creditsRequired -
                            item.completedCredits -
                            item.inProgressCredits)
                        .clamp(0, item.requirement.creditsRequired)
                        .toDouble(),
                note: item.requirement.note,
              ),
            ),
      ),
      courses: List.unmodifiable(
        eligibility.map(
          (result) => {
            'code': result.course.code,
            'title': result.course.title,
            'credits': result.course.credits,
            'eligibility': result.status.name,
            'missingPrerequisites': List<String>.from(
              result.missingPrerequisites,
            ),
            'reason': result.reason,
          },
        ),
      ),
      plan: {
        'totalCredits': plan.totalCredits,
        'maxCredits': plan.maxCredits,
        'items': plan.items
            .map(
              (item) => {
                'code': item.courseCode,
                'title': item.title,
                'type': item.type.name,
                'credits': item.credits,
                'conditionalOnPassingCurrentCourses': item.projectedEligibility,
                'reason': item.reason,
              },
            )
            .toList(),
      },
    );
  }

  Map<String, Object?> toJson() => {
    'requirementsNotYetCompleted': requirements
        .map((item) => item.toJson())
        .toList(),
    'checkedCourseEligibility': courses,
    'suggestedSemesterPlan': plan,
    'limitations': [
      'Only the configured Benedict Computer Science 2024 program is supported.',
      'Course offering, open seats and registration are not verified by this academic plan.',
      'The catalog does not cover every general education or support course.',
      'Free-elective completion currently comes from a prototype audit shortcut.',
      'Unknown grades and incomplete approved-option lists need advisor review.',
    ],
  };

  String promptFor(String question) =>
      jsonEncode({'academicData': toJson(), 'studentQuestion': question});
}
