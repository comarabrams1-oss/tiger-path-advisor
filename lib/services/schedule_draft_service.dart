import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/program_registry.dart';
import '../data/test_instructors.dart';
import '../data/test_student.dart';
import '../models/course_section.dart';
import '../models/student.dart';
import 'course_priority_service.dart';
import 'course_section_repository.dart';
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
  final List<SemesterPlanItem> deferred;
  final bool advisorReview;

  const ScheduleDraft({
    required this.plan,
    required this.schedule,
    required this.preferences,
    this.sectionPreferences = const {},
    this.excludedCourses = const [],
    this.excludedSections = const [],
    this.deferred = const [],
    this.advisorReview = false,
  });
  Map<String, Object?> get explanationContext => {
    'term': CourseSectionRepository.spring2027Term,
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
    'notice': 'This is the current schedule draft. An edit request opens this draft through the Update current schedule button; text alone never changes it.',
  };
}

/// Keeps the latest draft per profile and restores it from this device.
class ScheduleDraftService {
  static const _term = CourseSectionRepository.spring2027Term;
  static final _drafts = <String, ScheduleDraft>{};
  static final _revision = ValueNotifier(0);

  static ScheduleDraft? get current => _drafts[PreferencesService.profileId];
  static ValueListenable<int> get revision => _revision;

  static String _key(String profile) => 'schedule_draft_v1_$profile';

  static Future<bool> save(ScheduleDraft draft) async {
    final profile = PreferencesService.profileId;
    _drafts[profile] = draft;
    _revision.value++;
    try {
      final plan = draft.plan;
      final encoded = jsonEncode({
        'term': _term,
        'recordRevision': _recordRevision(activeStudent),
        'plan': {
          'items': plan.items.map(_encodeItem).toList(),
          'totalCredits': plan.totalCredits,
          'maxCredits': plan.maxCredits,
          'reviewItems': plan.reviewItems.map(_encodeItem).toList(),
          'shortfallReason': plan.shortfallReason,
        },
        'preferences': draft.preferences.toJson(),
        'sectionPreferences': draft.sectionPreferences,
        'excludedCourses': draft.excludedCourses,
        'excludedSections': draft.excludedSections,
        'deferred': draft.deferred.map(_encodeItem).toList(),
        'advisorReview': draft.advisorReview,
      });
      return await (await SharedPreferences.getInstance()).setString(
        _key(profile),
        encoded,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> restore() async {
    final profile = PreferencesService.profileId;
    if (current != null) return;
    final student = activeStudent;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _key(profile),
      );
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['term'] != _term ||
          data['recordRevision'] != _recordRevision(student)) {
        return;
      }

      final priorities = {
        for (final item in CoursePriorityService().rankCourses(
          student,
          programFor(student),
          catalogFor(student),
        ))
          item.course.code: item,
      };
      List<SemesterPlanItem> decodeItems(List<dynamic> items) => [
        for (final item in items.cast<Map<String, dynamic>>())
          SemesterPlanItem(
            type: SemesterPlanItemType.values.byName(item['type'] as String),
            title: item['title'] as String,
            category: item['category'] as String,
            credits: (item['credits'] as num).toDouble(),
            courseCode: item['courseCode'] as String?,
            reason: item['reason'] as String,
            projectedEligibility: item['projectedEligibility'] as bool,
            priority: item['hasPriority'] == true
                ? priorities[item['courseCode']]
                : null,
          ),
      ];
      final savedPlan = data['plan'] as Map<String, dynamic>;
      final plan = SemesterPlan(
        items: decodeItems(savedPlan['items'] as List),
        totalCredits: (savedPlan['totalCredits'] as num).toDouble(),
        maxCredits: savedPlan['maxCredits'] as int,
        reviewItems: decodeItems(savedPlan['reviewItems'] as List),
        shortfallReason: savedPlan['shortfallReason'] as String?,
      );
      final preferences = SchedulePreferences.fromJson(
        data['preferences'] as Map<String, dynamic>,
      );
      final pins = Map<String, String>.from(data['sectionPreferences'] as Map);
      final excludedCourses = List<String>.from(
        data['excludedCourses'] as List,
      );
      final excludedSections = List<String>.from(
        data['excludedSections'] as List,
      );
      final deferred = decodeItems(data['deferred'] as List);
      final advisorReview = data['advisorReview'] as bool;
      final sections = await CourseSectionRepository.loadForTerm(_term);
      if (sections.isEmpty ||
          profile != PreferencesService.profileId ||
          current != null) {
        return;
      }
      final schedule = ScheduleGenerationService().generateSchedule(
        plan: plan,
        sections: permittedSections(
          sections,
          excludedCourses: excludedCourses,
          excludedSections: excludedSections,
          sectionPreferences: pins,
        ),
        instructors: testInstructors,
        preferences: preferences,
        preferredSections: pins,
      );
      _drafts[profile] = ScheduleDraft(
        plan: plan,
        schedule: schedule,
        preferences: preferences,
        sectionPreferences: pins,
        excludedCourses: excludedCourses,
        excludedSections: excludedSections,
        deferred: deferred,
        advisorReview: advisorReview,
      );
      if (!PreferencesService.hasPreferences) {
        PreferencesService.savePreferences(preferences);
      }
      _revision.value++;
    } catch (_) {
      // The planner can still open when local storage or offerings fail to load.
    }
  }

  static List<CourseSection> permittedSections(
    List<CourseSection> sections, {
    required List<String> excludedCourses,
    required List<String> excludedSections,
    required Map<String, String> sectionPreferences,
  }) => sections.where((section) {
    final code = section.courseCode;
    final pin = sectionPreferences[code];
    return !excludedCourses.contains(code) &&
        !excludedSections.contains(
          ScheduleEditContextService.sectionKey(code, section.sectionNumber),
        ) &&
        (pin == null || pin == section.sectionNumber);
  }).toList();

  static Map<String, Object?> _encodeItem(SemesterPlanItem item) => {
    'type': item.type.name,
    'title': item.title,
    'category': item.category,
    'credits': item.credits,
    'courseCode': item.courseCode,
    'reason': item.reason,
    'projectedEligibility': item.projectedEligibility,
    'hasPriority': item.priority != null,
  };

  // Invalidate drafts after a record change without storing a second transcript.
  static int _recordRevision(Student student) => jsonEncode(student.toJson())
      .codeUnits
      .fold<int>(0, (revision, unit) => (revision * 31 + unit) & 0x7fffffff);

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
