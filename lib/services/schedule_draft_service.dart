import '../models/schedule_preferences.dart';
import 'preferences_service.dart';
import 'semester_plan_service.dart';
import 'schedule_generation_service.dart';
import 'schedule_edit_context_service.dart';

class ScheduleDraft {
  final SemesterPlan plan;
  final GeneratedSchedule schedule;
  final SchedulePreferences preferences;
  final Map<String, String> sectionPreferences;
  final List<String> excludedCourses;
  final List<String> excludedSections;
  const ScheduleDraft({
    required this.plan,
    required this.schedule,
    required this.preferences,
    this.sectionPreferences = const {},
    this.excludedCourses = const [],
    this.excludedSections = const [],
  });
  Map<String, Object?> get explanationContext => {
    'term': '2026-2027 - Spring',
    'preferences': preferences.toJson(),
    'scheduledCredits': schedule.scheduledCredits,
    'selected': [
      for (final i in schedule.scheduled)
        ScheduleEditContextService.sectionDetails(i.section),
    ],
    'unresolved': [
      for (final i in schedule.unscheduled)
        {'courseCode': i.planItem.courseCode, 'reason': i.reason},
    ],
    'notice': 'This is the current in-session draft. An edit request opens this draft through the Update current schedule button; text alone never changes it.',
  };
}

/// Shared by the advisor and timetable within this browser session, per profile.
class ScheduleDraftService {
  static final _drafts = <String, ScheduleDraft>{};
  static ScheduleDraft? get current => _drafts[PreferencesService.profileId];
  static void save(ScheduleDraft draft) =>
      _drafts[PreferencesService.profileId] = draft;
  static bool isEditRequest(String text) {
    final value = text.toLowerCase();
    if (RegExp(r'\b(change|switch) (my |the )?(major|program|classification)\b')
        .hasMatch(value)) {
      return false;
    }
    final edit = RegExp(
      r"\b(change|switch|replace|remove|swap|move|avoid)\b|\bi (want|would like|prefer)\b|\bi'd like\b|\bcan you (put|add|get|give|make)\b",
    ).hasMatch(value);
    final schedule = RegExp(
      r'\b(schedule|class|classes|course|courses|section|physics|professor|prof|dr)\b|\b[a-z]{2,5}\s*\d{3}\b|\d\s*(am|pm)\b',
    ).hasMatch(value);
    return edit && schedule;
  }
}
