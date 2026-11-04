import 'dart:convert';

import '../models/course_section.dart';
import '../models/schedule_preferences.dart';
import 'course_priority_service.dart';
import 'schedule_generation_service.dart';

class ScheduleEditContextService {
  static String sectionKey(String code, String section) => '$code|$section';
  static Map<String, Object?> sectionDetails(CourseSection section) => {
    'key': sectionKey(section.courseCode, section.sectionNumber),
    'courseCode': section.courseCode,
    'section': section.sectionNumber,
    'instructors': section.allInstructorNames,
    'schedule': section.scheduleDisplay,
    'location': section.location,
    'delivery': section.deliveryMethod,
    'asynchronous': section.isAsynchronous,
    'days': section.days,
    'start': section.startTime,
    'end': section.endTime,
    'meetings': [for (final meeting in section.meetings) meeting.displayText],
    'open': section.isOpen && section.hasOpenSeats,
    'openSeats': section.openSeats,
  };
  static Map<String, Object?> build({
    required String program,
    required String classification,
    required String term,
    required GeneratedSchedule schedule,
    required SchedulePreferences preferences,
    required List<CoursePriorityResult> candidates,
    required List<CourseSection> available,
    String question = '',
    List<String> excludedCourses = const [],
    List<String> excludedSections = const [],
    Map<String, String> sectionPreferences = const {},
  }) {
    final selected = schedule.scheduled
        .map((s) => sectionKey(s.section.courseCode, s.section.sectionNumber))
        .toSet();
    final words = question
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 3)
        .toSet();
    int relevance(CourseSection s) {
      final names = s.allInstructorNames.join(' ').toLowerCase();
      if (words.any(names.contains)) return 0;
      if (selected.contains(sectionKey(s.courseCode, s.sectionNumber))) {
        return 1;
      }
      if (question
          .toUpperCase()
          .replaceAll(' ', '')
          .contains(s.courseCode.replaceAll(' ', ''))) {
        return 2;
      }
      return 3;
    }

    final sorted = [...available]
      ..sort((a, b) {
        final r = relevance(a).compareTo(relevance(b));
        return r != 0 ? r : a.fullCourseCode.compareTo(b.fullCourseCode);
      });
    final context = <String, Object?>{
      'program': program,
      'classification': classification,
      'term': term,
      'scheduledCredits': schedule.scheduledCredits,
      'creditGap': preferences.maxCredits - schedule.scheduledCredits,
      'preferences': preferences.toJson(),
      'excludedCourses': excludedCourses,
      'excludedSections': excludedSections,
      'sectionPreferences': sectionPreferences,
      'selected': [
        for (final i in schedule.scheduled) sectionDetails(i.section),
      ],
      'alternatives': [
        for (final c in candidates)
          {
            'courseCode': c.course.code,
            'credits': c.course.credits,
            'eligibility': c.eligibility.status.name,
            'reason': c.reasons,
            'requiredCompanions': c.eligibility.requiredCompanions,
          },
      ],
      'unresolved': [
        for (final i in schedule.unscheduled)
          {'courseCode': i.planItem.courseCode, 'reason': i.reason},
      ],
      'choices': <Map<String, Object?>>[],
    };
    final choices = context['choices'] as List<Map<String, Object?>>;
    for (final section in sorted) {
      if (choices.length >= 100) break;
      choices.add(sectionDetails(section));
      if (utf8.encode(jsonEncode(context)).length > 58000) choices.removeLast();
    }
    context['choiceCoverage'] = {
      'included': choices.length,
      'total': available.length,
      'notice': 'Requested instructors and selected sections are prioritized. Omitted choices are not proof of no offering.',
    };
    return context;
  }
}
