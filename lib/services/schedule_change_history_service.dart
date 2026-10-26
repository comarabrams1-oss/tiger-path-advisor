import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_preferences.dart';
import 'schedule_generation_service.dart';

class ScheduleChangeEntry {
  final DateTime time;
  final String term;
  final String request;
  final List<String> changes;
  final String result;
  const ScheduleChangeEntry({
    required this.time,
    required this.term,
    required this.request,
    required this.changes,
    required this.result,
  });

  List<String> get highlights => changes.map((line) {
    if (line.startsWith('Added ') || line.startsWith('Removed ')) {
      return '${line.split(' (').first}.';
    }
    final sections = RegExp(r'^(.+?): section (\S+).* → section (\S+)')
        .firstMatch(line);
    if (sections != null) {
      return sections[2] == sections[3]
          ? '${sections[1]}: meeting or instructor details changed.'
          : '${sections[1]}: section ${sections[2]} → ${sections[3]}.';
    }
    return line;
  }).toList();

  Map<String, dynamic> toJson() => {
    'time': time.toUtc().toIso8601String(),
    'term': term,
    'request': request,
    'changes': changes,
    'result': result,
  };
  factory ScheduleChangeEntry.fromJson(Map<String, dynamic> json) =>
      ScheduleChangeEntry(
        time: DateTime.parse(json['time'] as String).toLocal(),
        term: json['term'] as String,
        request: json['request'] as String,
        changes: List<String>.from(json['changes'] as List),
        result: json['result'] as String,
      );

  static List<String> compare(
    GeneratedSchedule before,
    GeneratedSchedule after,
    SchedulePreferences oldPrefs,
    SchedulePreferences newPrefs,
  ) {
    final changes = <String>[];
    final old = {for (final i in before.scheduled) i.section.courseCode: i};
    final next = {for (final i in after.scheduled) i.section.courseCode: i};
    String details(ScheduledCourseSection i) =>
        'section ${i.section.sectionNumber} · ${i.section.scheduleDisplay} · ${i.section.instructorDisplay}';
    for (final code in old.keys.where((c) => !next.containsKey(c))) {
      changes.add('Removed $code (${details(old[code]!)}).');
    }
    for (final code in next.keys) {
      if (!old.containsKey(code)) {
        changes.add('Added $code (${details(next[code]!)}).');
      } else if (details(old[code]!) != details(next[code]!)) {
        changes.add('$code: ${details(old[code]!)} → ${details(next[code]!)}.');
      }
    }
    if (before.scheduledCredits != after.scheduledCredits) {
      changes.add(
        'Scheduled credits: ${before.scheduledCredits.toInt()} → ${after.scheduledCredits.toInt()}.',
      );
    }
    if (before.unscheduled.length != after.unscheduled.length) {
      changes.add(
        'Unresolved items: ${before.unscheduled.length} → ${after.unscheduled.length}.',
      );
    }
    final oldUnresolved = {
      for (final i in before.unscheduled)
        i.planItem.courseCode ?? i.planItem.title: i.reason,
    };
    final newUnresolved = {
      for (final i in after.unscheduled)
        i.planItem.courseCode ?? i.planItem.title: i.reason,
    };
    for (final code in oldUnresolved.keys.where(
      (c) => !newUnresolved.containsKey(c),
    )) {
      changes.add('No longer unresolved: $code.');
    }
    for (final code in newUnresolved.keys) {
      if (oldUnresolved[code] != newUnresolved[code]) {
        changes.add('Unresolved $code: ${newUnresolved[code]}');
      }
    }
    final labels = {
      'maxCredits': 'Credit target',
      'preferredTime': 'Preferred time',
      'preferredDays': 'Preferred days',
      'avoidedDays': 'Days to avoid',
      'preferredProfessors': 'Preferred professors',
      'avoidEarlyClasses': 'Prefer starts from 10 AM',
      'avoidLateClasses': 'Prefer finishes by 5 PM',
      'minimizeGaps': 'Minimize gaps',
    };
    String value(dynamic v) => v is List
        ? (v.isEmpty ? 'Any' : v.join(', '))
        : v is bool
        ? (v ? 'On' : 'Off')
        : '$v';
    final a = oldPrefs.toJson(), b = newPrefs.toJson();
    for (final key in labels.keys) {
      if (jsonEncode(a[key]) != jsonEncode(b[key])) {
        changes.add('${labels[key]}: ${value(a[key])} → ${value(b[key])}.');
      }
    }
    return changes;
  }
}

/// Local-only change history, isolated by mock student profile, newest first.
/// This records updates; it does not restore a timetable or register courses.
class ScheduleChangeHistoryService {
  final String profileId;
  const ScheduleChangeHistoryService(this.profileId);
  String get _key => 'schedule_changes_v1_$profileId';
  Future<List<ScheduleChangeEntry>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .take(20)
        .map(
          (e) =>
              ScheduleChangeEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> save(List<ScheduleChangeEntry> entries) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(entries.take(20).map((e) => e.toJson()).toList()),
    );
    if (!ok) throw StateError('Schedule history could not be saved');
  }
}
