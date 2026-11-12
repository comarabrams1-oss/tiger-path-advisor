import '../models/course_section.dart';
import '../models/instructor.dart';
import '../models/schedule_preferences.dart';
import 'course_eligibility_service.dart';
import 'course_priority_service.dart';
import 'schedule_generation_service.dart';
import 'semester_plan_service.dart';

class ScheduleRecovery {
  final SemesterPlan plan;
  final List<SemesterPlanItem> deferred;
  const ScheduleRecovery(this.plan, this.deferred);
}

/// Moves courses between terms, never substitutes one degree requirement for another.
class ScheduleRecoveryService {
  ScheduleRecovery recover({
    required SemesterPlan plan,
    required List<CoursePriorityResult> candidates,
    required List<String> requestedCourses,
    required List<CourseSection> sections,
    required List<Instructor> instructors,
    required SchedulePreferences preferences,
    Map<String, String> preferredSections = const {},
  }) {
    if (requestedCourses.isEmpty) return ScheduleRecovery(plan, const []);
    final search = ScheduleSectionSearch(
      sections: sections,
      instructors: instructors,
      preferences: preferences,
      preferredSections: preferredSections,
    );
    final initial = search.buildSchedule(plan);
    final items = initial.scheduled.map((item) => item.planItem).toList();
    final codes = items.map((item) => item.courseCode).toSet();
    final eligible = {
      for (final result in candidates)
        if (result.eligibility.status == EligibilityStatus.eligible ||
            result.eligibility.status ==
                EligibilityStatus.eligibleAfterCurrentTerm)
          result.course.code: result,
    };

    for (final requested in requestedCourses.toSet()) {
      final bundle = <SemesterPlanItem>[];
      final visited = <String>{};
      bool collect(String code) {
        if (codes.contains(code) || !visited.add(code)) return true;
        final candidate = eligible[code];
        if (candidate == null) return false;
        for (final companion in candidate.eligibility.requiredCompanions) {
          if (!collect(companion)) return false;
        }
        bundle.add(
          SemesterPlanItem(
            type: SemesterPlanItemType.course,
            title: candidate.course.title,
            category: candidate.course.category,
            credits: candidate.course.credits,
            courseCode: code,
            reason: 'Another remaining degree course moved into this term after schedule recovery.',
            projectedEligibility:
                candidate.eligibility.status ==
                EligibilityStatus.eligibleAfterCurrentTerm,
            priority: candidate,
          ),
        );
        return true;
      }

      if (!collect(requested) || bundle.isEmpty) continue;
      final trialItems = [...items, ...bundle];
      final withinRequirements = bundle.every((item) {
        final id = item.priority?.requirementId;
        final limit = item.priority?.requirementCreditsRemaining;
        return id == null ||
            limit == null ||
            trialItems
                    .where((item) => item.priority?.requirementId == id)
                    .fold<double>(0, (sum, item) => sum + item.credits) <=
                limit;
      });
      if (!withinRequirements ||
          !search.canFitAll(trialItems, maxCredits: plan.maxCredits)) {
        continue;
      }
      items.addAll(bundle);
      codes.addAll(bundle.map((item) => item.courseCode));
    }
    if (items.length == initial.scheduled.length) {
      return ScheduleRecovery(plan, const []);
    }
    return ScheduleRecovery(
      SemesterPlan(
        items: items,
        totalCredits: items.fold<double>(0, (sum, item) => sum + item.credits),
        maxCredits: plan.maxCredits,
        reviewItems: plan.reviewItems,
      ),
      initial.unscheduled
          .where(
            (item) =>
                !codes.contains(item.planItem.courseCode) ||
                item.planItem.courseCode == null,
          )
          .map((item) => item.planItem)
          .toList(),
    );
  }
}
