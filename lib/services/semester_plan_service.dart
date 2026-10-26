import '../models/course.dart';
import '../models/degree_program.dart';
import '../models/student.dart';
import '../models/student_course.dart';
import '../models/course_section.dart';
import 'course_eligibility_service.dart';
import 'course_priority_service.dart';
import 'degree_audit_service.dart';

enum SemesterPlanItemType { course, requirementSlot }

class SemesterPlanItem {
  final SemesterPlanItemType type;
  final String title;
  final String category;
  final double credits;
  final String? courseCode;
  final String reason;
  final bool projectedEligibility;
  final CoursePriorityResult? priority;

  const SemesterPlanItem({
    required this.type,
    required this.title,
    required this.category,
    required this.credits,
    required this.reason,
    this.courseCode,
    this.projectedEligibility = false,
    this.priority,
  });
}

class SemesterPlan {
  final List<SemesterPlanItem> items;
  final double totalCredits;
  final int maxCredits;
  final List<SemesterPlanItem> reviewItems;

  const SemesterPlan({
    required this.items,
    required this.totalCredits,
    required this.maxCredits,
    this.reviewItems = const [],
  });

  double get remainingCreditCapacity {
    return maxCredits - totalCredits;
  }
}

class SemesterPlanService {
  final CoursePriorityService _priorityService = CoursePriorityService();

  final DegreeAuditService _auditService = DegreeAuditService();

  SemesterPlan generatePlan({
    required Student student,
    required DegreeProgram program,
    required List<Course> catalog,
    required int maxCredits,
    List<CourseSection>? sections,
  }) {
    final items = <SemesterPlanItem>[];
    final reviewItems = <SemesterPlanItem>[];
    var totalCredits = 0.0;
    final audit = _auditService.auditProgram(student, program);
    final used = student.courses
        .where(
          (c) =>
              c.status == CourseStatus.completed ||
              c.status == CourseStatus.inProgress,
        )
        .map((c) => c.courseCode)
        .toSet();
    final plannedPerRequirement = <String, double>{};
    final freshman = student.classification.toLowerCase() == 'freshman';
    final ranked = _priorityService.rankCourses(student, program, catalog);
    for (final result in ranked) {
      if (![
        EligibilityStatus.eligible,
        EligibilityStatus.eligibleAfterCurrentTerm,
      ].contains(result.eligibility.status)) {
        continue;
      }
      final course = result.course;
      if (used.contains(course.code) ||
          totalCredits + course.credits > maxCredits) {
        continue;
      }
      final requirements = audit
          .where(
            (a) =>
                a.status == RequirementStatus.remaining &&
                a.requirement.courseCodes.contains(course.code),
          )
          .toList();
      if (requirements.isEmpty) continue;
      final requirement = requirements.first;
      final remaining =
          requirement.requirement.creditsRequired -
          requirement.completedCredits -
          requirement.inProgressCredits -
          (plannedPerRequirement[requirement.requirement.id] ?? 0);
      if (remaining <= 0 || course.credits > remaining) continue;
      // First-year planning favors the foundation sequence; eligibility is
      // still determined by the same prerequisite service for every student.
      final level =
          int.tryParse(
            RegExp(r'\d{3}').firstMatch(course.code)?.group(0) ?? '999',
          ) ??
          999;
      if (freshman && level >= 300) continue;
      if (sections != null &&
          !sections.any(
            (s) => s.courseCode == course.code && s.isOpen && s.hasOpenSeats,
          )) {
        continue;
      }
      final item = SemesterPlanItem(
        type: SemesterPlanItemType.course,
        title: course.title,
        category: course.category,
        courseCode: course.code,
        credits: course.credits,
        reason:
            '${result.reasons.join('. ')}. Counts toward ${requirement.requirement.title}.',
        projectedEligibility:
            result.eligibility.status ==
            EligibilityStatus.eligibleAfterCurrentTerm,
        priority: result,
      );
      items.add(item);
      totalCredits += course.credits;
      used.add(course.code);
      plannedPerRequirement[requirement.requirement.id] =
          (plannedPerRequirement[requirement.requirement.id] ?? 0) +
          course.credits;
    }
    // Unverified choices remain visible without consuming a semester's credits.
    for (final item in audit.where(
      (a) =>
          a.status == RequirementStatus.remaining &&
          ![
            RequirementType.totalCredits,
            RequirementType.minimumGpa,
          ].contains(a.requirement.type),
    )) {
      final remaining =
          item.requirement.creditsRequired -
          item.completedCredits -
          item.inProgressCredits -
          (plannedPerRequirement[item.requirement.id] ?? 0);
      if (remaining <= 0) continue;
      reviewItems.add(
        SemesterPlanItem(
          type: SemesterPlanItemType.requirementSlot,
          title: item.requirement.title,
          category: item.requirement.category,
          courseCode:
              item.requirement.type == RequirementType.requiredCourse &&
                  item.requirement.courseCodes.isNotEmpty
              ? item.requirement.courseCodes.first
              : null,
          credits: remaining,
          reason: 'Still outstanding; not included in this semester. Confirm prerequisites, placement, approved options and availability with your advisor.',
        ),
      );
    }
    return SemesterPlan(
      items: items,
      totalCredits: totalCredits,
      maxCredits: maxCredits,
      reviewItems: reviewItems,
    );
  }
}
