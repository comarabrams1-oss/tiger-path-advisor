import '../models/course.dart';
import '../models/degree_program.dart';
import '../models/student.dart';
import 'course_eligibility_service.dart';
import 'course_priority_service.dart';
import 'degree_audit_service.dart';

enum SemesterPlanItemType {
  course,
  requirementSlot,
}

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

  const SemesterPlan({
    required this.items,
    required this.totalCredits,
    required this.maxCredits,
  });

  double get remainingCreditCapacity {
    return maxCredits - totalCredits;
  }
}

class SemesterPlanService {
  final CoursePriorityService _priorityService =
      CoursePriorityService();

  final DegreeAuditService _auditService =
      DegreeAuditService();

  SemesterPlan generatePlan({
    required Student student,
    required DegreeProgram program,
    required List<Course> catalog,
    required int maxCredits,
  }) {
    final items = <SemesterPlanItem>[];
    double totalCredits = 0;

    final audit = _auditService.auditProgram(
      student,
      program,
    );

    final catalogCodes =
        catalog.map((course) => course.code).toSet();

    bool canAdd(double credits) {
      return totalCredits + credits <= maxCredits;
    }

    void addItem(SemesterPlanItem item) {
      if (!canAdd(item.credits)) {
        return;
      }

      items.add(item);
      totalCredits += item.credits;
    }

    final remainingGeneralEducation = audit.where(
      (item) =>
          item.status == RequirementStatus.remaining &&
          item.requirement.category ==
              'General Education',
    );

    for (final auditItem in remainingGeneralEducation) {
      final requirement = auditItem.requirement;

      if (requirement.type ==
          RequirementType.creditHours) {
        final remainingCredits =
            requirement.creditsRequired -
                auditItem.completedCredits;

        if (remainingCredits <= 0) {
          continue;
        }

        addItem(
          SemesterPlanItem(
            type: SemesterPlanItemType.requirementSlot,
            title: requirement.title,
            category: requirement.category,
            credits: remainingCredits,
            reason:
                'Reserve space for an approved course that satisfies this remaining General Education requirement.',
          ),
        );
      }

      if (requirement.type ==
          RequirementType.oneOfCourses) {
        addItem(
          SemesterPlanItem(
            type: SemesterPlanItemType.requirementSlot,
            title: requirement.title,
            category: requirement.category,
            credits: requirement.creditsRequired,
            reason:
                'Complete one approved option: ${requirement.courseCodes.join(' or ')}.',
          ),
        );
      }
    }

    final remainingSupportCourses = audit.where(
      (item) =>
          item.status == RequirementStatus.remaining &&
          item.requirement.category == 'Support' &&
          item.requirement.type ==
              RequirementType.requiredCourse,
    );

    for (final auditItem in remainingSupportCourses) {
      final requirement = auditItem.requirement;

      if (requirement.courseCodes.isEmpty) {
        continue;
      }

      final code = requirement.courseCodes.first;

      if (catalogCodes.contains(code)) {
        continue;
      }

      addItem(
        SemesterPlanItem(
          type: SemesterPlanItemType.requirementSlot,
          title: requirement.title,
          category: requirement.category,
          courseCode: code,
          credits: requirement.creditsRequired,
          reason:
              'This specific support course is still required. Course eligibility and semester availability still need to be verified.',
        ),
      );
    }

    final rankedCourses = _priorityService.rankCourses(
      student,
      program,
      catalog,
    );

    for (final result in rankedCourses) {
      final status = result.eligibility.status;

      final usable =
          status == EligibilityStatus.eligible ||
          status ==
              EligibilityStatus.eligibleAfterCurrentTerm;

      if (!usable) {
        continue;
      }

      if (!canAdd(result.course.credits)) {
        continue;
      }

      addItem(
        SemesterPlanItem(
          type: SemesterPlanItemType.course,
          title: result.course.title,
          category: result.course.category,
          courseCode: result.course.code,
          credits: result.course.credits,
          priority: result,
          projectedEligibility:
              status ==
              EligibilityStatus.eligibleAfterCurrentTerm,
          reason: result.reasons.join('. '),
        ),
      );
    }

    final remainingMajorElectives = audit.where(
      (item) =>
          item.status == RequirementStatus.remaining &&
          item.requirement.category == 'Major' &&
          item.requirement.type ==
              RequirementType.elective,
    );

    for (final auditItem in remainingMajorElectives) {
      final requirement = auditItem.requirement;

      addItem(
        SemesterPlanItem(
          type: SemesterPlanItemType.requirementSlot,
          title: requirement.title,
          category: requirement.category,
          credits: requirement.creditsRequired,
          reason:
              'Reserve space for an approved Computer Science elective.',
        ),
      );
    }

    final remainingOtherElectives = audit.where(
      (item) =>
          item.status == RequirementStatus.remaining &&
          item.requirement.category == 'Electives',
    );

    for (final auditItem in remainingOtherElectives) {
      final requirement = auditItem.requirement;

      addItem(
        SemesterPlanItem(
          type: SemesterPlanItemType.requirementSlot,
          title: requirement.title,
          category: requirement.category,
          credits: requirement.creditsRequired,
          reason:
              'Reserve space for coursework that satisfies this elective requirement.',
        ),
      );
    }

    return SemesterPlan(
      items: items,
      totalCredits: totalCredits,
      maxCredits: maxCredits,
    );
  }
}