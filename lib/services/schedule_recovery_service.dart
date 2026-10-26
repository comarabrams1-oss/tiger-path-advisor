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
    final generator = ScheduleGenerationService();
    final initial = generator.generateSchedule(
      plan: plan,
      sections: sections,
      instructors: instructors,
      preferences: preferences,
      preferredSections: preferredSections,
    );
    final items = initial.scheduled.map((item) => item.planItem).toList();
    final codes = items.map((item) => item.courseCode).toSet();
    var credits = items.fold<double>(0, (sum, item) => sum + item.credits);
    for (final code in requestedCourses.toSet()) {
      final matches = candidates.where(
        (candidate) =>
            candidate.course.code == code &&
            [
              EligibilityStatus.eligible,
              EligibilityStatus.eligibleAfterCurrentTerm,
            ].contains(candidate.eligibility.status),
      );
      if (matches.isEmpty || codes.contains(code)) continue;
      final candidate = matches.first;
      final requirementId = candidate.requirementId;
      if (requirementId != null &&
          candidate.requirementCreditsRemaining != null) {
        final allocated = items
            .where((i) => i.priority?.requirementId == requirementId)
            .fold<double>(0, (sum, i) => sum + i.credits);
        if (allocated + candidate.course.credits >
            candidate.requirementCreditsRemaining!) {
          continue;
        }
      }
      if (credits + candidate.course.credits > preferences.maxCredits) continue;
      final item = SemesterPlanItem(
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
      );
      final trial = SemesterPlan(
        items: [...items, item],
        totalCredits: credits + item.credits,
        maxCredits: preferences.maxCredits,
      );
      final result = generator.generateSchedule(
        plan: trial,
        sections: sections,
        instructors: instructors,
        preferences: preferences,
        preferredSections: preferredSections,
      );
      if (result.unscheduled.isNotEmpty) continue;
      items.add(item);
      codes.add(code);
      credits += item.credits;
    }
    if (items.length == initial.scheduled.length) {
      return ScheduleRecovery(plan, const []);
    }
    return ScheduleRecovery(
      SemesterPlan(
        items: items,
        totalCredits: credits,
        maxCredits: preferences.maxCredits,
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
