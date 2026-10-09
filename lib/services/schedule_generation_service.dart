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

  const UnscheduledPlanItem({required this.planItem, required this.reason});
}

class GeneratedSchedule {
  final List<ScheduledCourseSection> scheduled;
  final List<UnscheduledPlanItem> unscheduled;

  const GeneratedSchedule({required this.scheduled, required this.unscheduled});

  double get scheduledCredits {
    return scheduled.fold(0, (total, item) => total + item.planItem.credits);
  }
}

class ScheduleGenerationService {
  final ScheduleMatchingService _matchingService = ScheduleMatchingService();

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
            reason: 'An approved course still needs to be selected for this requirement.',
          ),
        );

        continue;
      }

      final courseSections = sections
          .where((section) => section.courseCode == courseCode)
          .toList();

      if (courseSections.isEmpty) {
        unscheduled.add(
          UnscheduledPlanItem(
            planItem: planItem,
            reason:
                'No section information is currently available for $courseCode.',
          ),
        );

        continue;
      }

      final usableSections = courseSections.where(_isUsableSection).toList();

      if (usableSections.isEmpty) {
        unscheduled.add(
          UnscheduledPlanItem(
            planItem: planItem,
            reason:
                'All known sections for $courseCode are closed, cancelled, or full.',
          ),
        );

        continue;
      }

      final rankedSections = _matchingService.rankSections(
        sections: usableSections,
        instructors: instructors,
        preferences: preferences,
      );

      SectionMatch? bestMatch;
      int? bestScore;
      List<String>? bestReasons;

      for (final match in rankedSections) {
        if (_conflictsWithSchedule(match.section, scheduled)) {
          continue;
        }

        var score = match.score;
        final reasons = List<String>.from(match.reasons);

        if (preferences.minimizeGaps && scheduled.isNotEmpty) {
          final gapScore = _gapScore(match.section, scheduled);

          score += gapScore;

          if (gapScore >= 3) {
            reasons.add('Fits closely with your existing classes');
          } else if (gapScore > 0) {
            reasons.add('Helps reduce gaps between classes');
          }
        }

        if (bestMatch == null || bestScore == null || score > bestScore) {
          bestMatch = match;
          bestScore = score;
          bestReasons = reasons;
        }
      }

      if (bestMatch == null) {
        unscheduled.add(
          UnscheduledPlanItem(
            planItem: planItem,
            reason: 'Open sections are available, but they conflict with classes already selected.',
          ),
        );

        continue;
      }

      scheduled.add(
        ScheduledCourseSection(
          planItem: planItem,
          section: bestMatch.section,
          instructor: bestMatch.instructor,
          preferenceScore: bestScore ?? bestMatch.score,
          matchReasons: bestReasons ?? bestMatch.reasons,
        ),
      );
    }

    scheduled.sort(
      (a, b) => _earliestStart(a.section).compareTo(_earliestStart(b.section)),
    );

    return GeneratedSchedule(scheduled: scheduled, unscheduled: unscheduled);
  }

  bool _isUsableSection(CourseSection section) {
    return section.isOpen && section.hasOpenSeats;
  }

  bool _conflictsWithSchedule(
    CourseSection candidate,
    List<ScheduledCourseSection> scheduled,
  ) {
    for (final existing in scheduled) {
      if (_sectionsConflict(candidate, existing.section)) {
        return true;
      }
    }

    return false;
  }

  bool _sectionsConflict(CourseSection first, CourseSection second) {
    final sharedDay = first.days.any(second.days.contains);

    if (!sharedDay) {
      return false;
    }

    return first.startMinutes < second.endMinutes &&
        first.endMinutes > second.startMinutes;
  }

  int _gapScore(
    CourseSection candidate,
    List<ScheduledCourseSection> scheduled,
  ) {
    int bestScore = 0;

    for (final existing in scheduled) {
      final sharedDay = candidate.days.any(existing.section.days.contains);

      if (!sharedDay) {
        continue;
      }

      final gap = _minutesBetween(candidate, existing.section);

      if (gap == null) {
        continue;
      }

      if (gap <= 15) {
        bestScore = bestScore < 4 ? 4 : bestScore;
      } else if (gap <= 30) {
        bestScore = bestScore < 3 ? 3 : bestScore;
      } else if (gap <= 60) {
        bestScore = bestScore < 2 ? 2 : bestScore;
      } else if (gap <= 90) {
        bestScore = bestScore < 1 ? 1 : bestScore;
      }
    }

    return bestScore;
  }

  int? _minutesBetween(CourseSection first, CourseSection second) {
    if (_sectionsConflict(first, second)) {
      return null;
    }

    if (first.endMinutes <= second.startMinutes) {
      return second.startMinutes - first.endMinutes;
    }

    if (second.endMinutes <= first.startMinutes) {
      return first.startMinutes - second.endMinutes;
    }

    return null;
  }

  int _earliestStart(CourseSection section) {
    return section.startMinutes;
  }
}
