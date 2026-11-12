import 'dart:math' as math;

import '../models/course_section.dart';
import '../models/instructor.dart';
import '../models/schedule_preferences.dart';
import 'course_eligibility_service.dart';
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
  GeneratedSchedule generateSchedule({
    required SemesterPlan plan,
    required List<CourseSection> sections,
    required List<Instructor> instructors,
    required SchedulePreferences preferences,
    Map<String, String> preferredSections = const {},
  }) => ScheduleSectionSearch(
    sections: sections,
    instructors: instructors,
    preferences: preferences,
    preferredSections: preferredSections,
  ).buildSchedule(plan);
}

/// Reuse ranked sections and clash checks across the planner's trial schedules.
class ScheduleSectionSearch {
  final List<Instructor> instructors;
  final SchedulePreferences preferences;
  final Map<String, String> preferredSections;
  final _matchingService = ScheduleMatchingService();
  final _offered = <String>{};
  final _open = <String, List<CourseSection>>{};
  final _ranked = <String, List<SectionMatch>>{};
  final _timings = <CourseSection, _SectionTiming>{};
  final _clashes = <(CourseSection, CourseSection), bool>{};

  ScheduleSectionSearch({
    required List<CourseSection> sections,
    required this.instructors,
    required this.preferences,
    this.preferredSections = const {},
  }) {
    for (final section in sections) {
      _offered.add(section.courseCode);
      if (section.isOpen && section.hasOpenSeats) {
        (_open[section.courseCode] ??= []).add(section);
      }
    }
  }

  bool hasOpenCourse(String code) => _open.containsKey(code);

  bool canFitAll(List<SemesterPlanItem> items, {required int maxCredits}) {
    final choices = _choices(items);
    return choices.length == items.length &&
        _assign(
              choices,
              math.max(0, math.min(maxCredits, preferences.maxCredits)),
              allowPartial: false,
            ) !=
            null;
  }

  GeneratedSchedule buildSchedule(SemesterPlan plan) {
    final creditLimit = math.max(
      0,
      math.min(plan.maxCredits, preferences.maxCredits),
    );
    final scheduled = _assign(
      _choices(plan.items),
      creditLimit,
      allowPartial: true,
    )!;
    final selectedCodes = scheduled.map((i) => i.section.courseCode).toSet();
    final credits = scheduled.fold<double>(
      0,
      (sum, i) => sum + i.planItem.credits,
    );
    final seen = <String>{};
    final unscheduled = <UnscheduledPlanItem>[];
    for (final item in plan.items) {
      final code = item.courseCode;
      final duplicate = code != null && !seen.add(code);
      if (!duplicate && selectedCodes.contains(code)) continue;
      unscheduled.add(
        UnscheduledPlanItem(
          planItem: item,
          reason: duplicate
              ? 'This course already appears in the draft.'
              : _unscheduledReason(item, selectedCodes, credits, creditLimit),
        ),
      );
    }
    scheduled.sort((a, b) {
      final time = _timing(a.section).firstStart
          .compareTo(_timing(b.section).firstStart);
      return time != 0
          ? time
          : a.section.fullCourseCode.compareTo(b.section.fullCourseCode);
    });
    return GeneratedSchedule(scheduled: scheduled, unscheduled: unscheduled);
  }

  List<_CourseChoices> _choices(List<SemesterPlanItem> items) {
    final seen = <String>{};
    final result = <_CourseChoices>[];
    for (final item in items) {
      final code = item.courseCode;
      if (code == null ||
          !seen.add(code) ||
          !_isEligible(item) ||
          !hasOpenCourse(code)) {
        continue;
      }
      final options = _ranked.putIfAbsent(
        code,
        () => _matchingService.rankSections(
          sections: _open[code]!,
          instructors: instructors,
          preferences: preferences,
        ),
      );
      result.add(_CourseChoices(item, code, options));
    }
    // Place the courses with the fewest available sections first.
    result.sort((a, b) {
      final count = a.sections.length.compareTo(b.sections.length);
      return count != 0 ? count : a.code.compareTo(b.code);
    });
    return result;
  }

  List<ScheduledCourseSection>? _assign(
    List<_CourseChoices> courses,
    int maxCredits, {
    required bool allowPartial,
  }) {
    final availableCodes = courses.map((course) => course.code).toSet();
    final selected = <ScheduledCourseSection>[];
    final skipped = <String>{};
    final remainingCredits = List<double>.filled(courses.length + 1, 0);
    final remainingScore = List<int>.filled(courses.length + 1, 0);
    for (var index = courses.length - 1; index >= 0; index--) {
      final course = courses[index];
      remainingCredits[index] =
          remainingCredits[index + 1] + course.item.credits;
      if (allowPartial) {
        final gapLimit = preferences.minimizeGaps ? 4 : 0;
        remainingScore[index] =
            remainingScore[index + 1] +
            course.sections.fold(
              0,
              (best, option) => math.max(best, _score(option) + gapLimit),
            );
      }
    }
    List<ScheduledCourseSection>? best;
    var bestCredits = -1.0;
    var bestScore = 0;

    bool visit(int index, double credits, int score) {
      final upperCredits = math.min(
        maxCredits.toDouble(),
        credits + remainingCredits[index],
      );
      final upperCount = selected.length + courses.length - index;
      final bestCount = best?.length ?? 0;
      if (upperCredits < bestCredits ||
          (upperCredits == bestCredits && upperCount < bestCount) ||
          (upperCredits == bestCredits &&
              upperCount == bestCount &&
              score + remainingScore[index] <= bestScore)) {
        return false;
      }
      if (index == courses.length) {
        best = List.of(selected);
        bestCredits = credits;
        bestScore = score;
        return !allowPartial;
      }

      final course = courses[index];
      final needed = _companions(course.item);
      final nextCredits = credits + course.item.credits;
      if (nextCredits <= maxCredits &&
          needed.every(availableCodes.contains) &&
          !needed.any(skipped.contains)) {
        final matches = <ScheduledCourseSection>[];
        for (final match in course.sections) {
          if (selected.any(
            (existing) => _conflicts(match.section, existing.section),
          )) {
            continue;
          }
          final gap = allowPartial && preferences.minimizeGaps
              ? _gapScore(match.section, selected)
              : 0;
          matches.add(
            ScheduledCourseSection(
              planItem: course.item,
              section: match.section,
              instructor: match.instructor,
              preferenceScore: _score(match) + gap,
              matchReasons: [
                ...match.reasons,
                if (gap >= 3)
                  'Fits closely with your existing classes'
                else if (gap > 0)
                  'Helps reduce gaps between classes',
              ],
            ),
          );
        }
        matches.sort((a, b) {
          final score = b.preferenceScore.compareTo(a.preferenceScore);
          if (score != 0) return score;
          final start = _timing(a.section).firstStart
              .compareTo(_timing(b.section).firstStart);
          return start != 0
              ? start
              : a.section.sectionNumber.compareTo(b.section.sectionNumber);
        });
        for (final match in matches) {
          selected.add(match);
          final complete = visit(
            index + 1,
            nextCredits,
            score + match.preferenceScore,
          );
          selected.removeLast();
          if (complete) return true;
        }
      }

      if (allowPartial &&
          !selected.any(
            (item) => _companions(item.planItem).contains(course.code),
          )) {
        skipped.add(course.code);
        visit(index + 1, credits, score);
        skipped.remove(course.code);
      }
      return false;
    }

    if (!allowPartial && remainingCredits.first > maxCredits) return null;
    visit(0, 0, 0);
    return best;
  }

  int _score(SectionMatch match) {
    final section = match.section;
    final preferred =
        preferredSections[section.courseCode] == section.sectionNumber;
    return match.score + (preferred ? 1000 : 0);
  }

  static List<String> _companions(SemesterPlanItem item) =>
      item.priority?.eligibility.requiredCompanions ?? const [];

  static bool _isEligible(SemesterPlanItem item) {
    final status = item.priority?.eligibility.status;
    return item.type == SemesterPlanItemType.course &&
        status != EligibilityStatus.blocked &&
        status != EligibilityStatus.requiresPermission;
  }

  String _unscheduledReason(
    SemesterPlanItem item,
    Set<String> selected,
    double credits,
    int creditLimit,
  ) {
    final code = item.courseCode;
    if (code == null || item.type == SemesterPlanItemType.requirementSlot) {
      return 'An approved course still needs to be selected for this requirement.';
    }
    if (!_isEligible(item)) {
      return 'This course needs prerequisite or advisor approval review.';
    }
    if (!_offered.contains(code)) {
      return 'No section information is currently available for $code.';
    }
    if (!hasOpenCourse(code)) {
      return 'All known sections for $code are closed, cancelled, or full.';
    }
    final missing = _companions(item).where((code) => !selected.contains(code));
    if (missing.isNotEmpty) {
      return 'Required lecture/co-enrollment could not be scheduled: ${missing.join(', ')}.';
    }
    if (credits + item.credits > creditLimit) {
      return 'Adding $code would exceed the $creditLimit-credit limit.';
    }
    return 'Open sections are available, but they conflict with classes already selected.';
  }

  _SectionTiming _timing(CourseSection section) =>
      _timings.putIfAbsent(section, () => _SectionTiming(section));

  bool _conflicts(CourseSection a, CourseSection b) {
    final cached = _clashes[(a, b)] ?? _clashes[(b, a)];
    if (cached != null) return cached;
    final first = _timing(a);
    final second = _timing(b);
    final clash = first.meetings.any(
      (x) => second.meetings.any(
        (y) =>
            x.startMinutes! < y.endMinutes! &&
            x.endMinutes! > y.startMinutes! &&
            _sharesMeetingDay(x, first, y, second),
      ),
    );
    _clashes[(a, b)] = clash;
    return clash;
  }

  int _gapScore(CourseSection section, List<ScheduledCourseSection> selected) {
    final first = _timing(section);
    var best = 0;
    for (final existing in selected) {
      final second = _timing(existing.section);
      for (final x in first.meetings) {
        for (final y in second.meetings) {
          if (!_sharesMeetingDay(x, first, y, second)) continue;
          final gap = math.max(
            y.startMinutes! - x.endMinutes!,
            x.startMinutes! - y.endMinutes!,
          );
          if (gap < 0) continue;
          final score = switch (gap) {
            <= 15 => 4,
            <= 30 => 3,
            <= 60 => 2,
            <= 90 => 1,
            _ => 0,
          };
          best = math.max(best, score);
        }
      }
    }
    return best;
  }

  static bool _sharesMeetingDay(
    CourseMeeting first,
    _SectionTiming a,
    CourseMeeting second,
    _SectionTiming b,
  ) {
    final aStart = a.start, aEnd = a.end, bStart = b.start, bEnd = b.end;
    if (aStart == null ||
        aEnd == null ||
        bStart == null ||
        bEnd == null ||
        aStart.isAfter(aEnd) ||
        bStart.isAfter(bEnd)) {
      return first.days.any(second.days.contains);
    }

    final start = aStart.isAfter(bStart) ? aStart : bStart;
    final end = aEnd.isBefore(bEnd) ? aEnd : bEnd;
    final lastOffset = end.difference(start).inDays;
    if (lastOffset < 0) return false;
    const weekdays = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };
    return first.days.any((day) {
      if (!second.days.contains(day)) return false;
      final weekday = weekdays[day];
      return weekday == null || (weekday - start.weekday + 7) % 7 <= lastOffset;
    });
  }
}

class _CourseChoices {
  final SemesterPlanItem item;
  final String code;
  final List<SectionMatch> sections;
  const _CourseChoices(this.item, this.code, this.sections);
}

class _SectionTiming {
  final List<CourseMeeting> meetings;
  final DateTime? start;
  final DateTime? end;
  _SectionTiming(CourseSection section)
    : meetings = section.weeklyMeetings,
      start = section.beginsOn,
      end = section.endsOn;

  int get firstStart => meetings.fold(
    24 * 60,
    (earliest, meeting) => math.min(earliest, meeting.startMinutes!),
  );
}
