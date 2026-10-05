import '../models/course_section.dart';
import '../models/instructor.dart';
import '../models/schedule_preferences.dart';
import 'schedule_matching_service.dart';
import 'semester_plan_service.dart';

class ScheduledCourseSection {
  final SemesterPlanItem planItem;
  final CourseSection section;
  final Instructor? instructor;
  final int preferenceScore;
  final List<String> matchReasons;

  const ScheduledCourseSection({
    required this.planItem,
    required this.section,
    required this.instructor,
    required this.preferenceScore,
    required this.matchReasons,
  });
}

class UnscheduledPlanItem {
  final SemesterPlanItem planItem;
  final String reason;

  const UnscheduledPlanItem({
    required this.planItem,
    required this.reason,
  });
}

class GeneratedSchedule {
  final List<ScheduledCourseSection> scheduled;
  final List<UnscheduledPlanItem> unscheduled;

  const GeneratedSchedule({
    required this.scheduled,
    required this.unscheduled,
  });

  double get scheduledCredits {
    return scheduled.fold(
      0,
      (total, item) => total + item.planItem.credits,
    );
  }
}

class ScheduleGenerationService {
  final ScheduleMatchingService _matchingService =
      ScheduleMatchingService();

  GeneratedSchedule generateSchedule({
    required SemesterPlan plan,
    required List<CourseSection> sections,
    required List<Instructor> instructors,
    required SchedulePreferences preferences,
  }) {
    final scheduled = <ScheduledCourseSection>[];
    final unscheduled = <UnscheduledPlanItem>[];

    for (final planItem in plan.items) {
      final courseCode = planItem.courseCode;

      if (courseCode == null) {
        unscheduled.add(
          UnscheduledPlanItem(
            planItem: planItem,
            reason:
                'TigerPath still needs an approved course selection for this requirement.',
          ),
        );

        continue;
      }

      final availableSections = sections
          .where(
            (section) =>
                section.courseCode == courseCode,
          )
          .toList();

      if (availableSections.isEmpty) {
        unscheduled.add(
          UnscheduledPlanItem(
            planItem: planItem,
            reason:
                'No section data is currently available for $courseCode.',
          ),
        );

        continue;
      }

      final rankedSections =
          _matchingService.rankSections(
        sections: availableSections,
        instructors: instructors,
        preferences: preferences,
      );

      SectionMatch? selectedMatch;

      for (final match in rankedSections) {
        if (!_conflictsWithSchedule(
          match.section,
          scheduled,
        )) {
          selectedMatch = match;
          break;
        }
      }

      if (selectedMatch == null) {
        unscheduled.add(
          UnscheduledPlanItem(
            planItem: planItem,
            reason:
                'Available sections conflict with classes already selected.',
          ),
        );

        continue;
      }

      scheduled.add(
        ScheduledCourseSection(
          planItem: planItem,
          section: selectedMatch.section,
          instructor: selectedMatch.instructor,
          preferenceScore: selectedMatch.score,
          matchReasons: selectedMatch.reasons,
        ),
      );
    }

    scheduled.sort(
      (a, b) => _earliestStart(a.section)
          .compareTo(_earliestStart(b.section)),
    );

    return GeneratedSchedule(
      scheduled: scheduled,
      unscheduled: unscheduled,
    );
  }

  bool _conflictsWithSchedule(
    CourseSection candidate,
    List<ScheduledCourseSection> scheduled,
  ) {
    for (final existing in scheduled) {
      if (_sectionsConflict(
        candidate,
        existing.section,
      )) {
        return true;
      }
    }

    return false;
  }

  bool _sectionsConflict(
    CourseSection first,
    CourseSection second,
  ) {
    final sharedDay = first.days.any(
      second.days.contains,
    );

    if (!sharedDay) {
      return false;
    }

    return first.startMinutes < second.endMinutes &&
        first.endMinutes > second.startMinutes;
  }

  int _earliestStart(
    CourseSection section,
  ) {
    return section.startMinutes;
  }
}