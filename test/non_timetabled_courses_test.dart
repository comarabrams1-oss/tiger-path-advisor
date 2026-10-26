import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/services/schedule_generation_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';
import 'package:tiger_path/widgets/non_timetabled_courses.dart';

ScheduledCourseSection item(CourseSection s) => ScheduledCourseSection(
  planItem: SemesterPlanItem(
    type: SemesterPlanItemType.course,
    courseCode: s.courseCode,
    title: 'Music Appreciation',
    category: 'General Education',
    credits: 3,
    reason: '',
  ),
  section: s,
  instructor: null,
  preferenceScore: 0,
  matchReasons: [],
);
void main() {
  final sections =
      (jsonDecode(
            File('assets/data/course_sections_spring_2027.json')
                .readAsStringSync(),
          ) as List)
          .map((j) => CourseSection.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  test('real MUS 130 sections are async; online and TBA alone are not', () {
    final music = sections.where((s) => s.courseCode == 'MUS 130');
    expect(music.length, 2);
    for (final s in music) {
      expect(s.isAsynchronous, isTrue);
      expect(s.hasWeeklyMeeting, isFalse);
    }
    final unknown = CourseSection.fromJson({
      ...music.first.toJson(),
      'rawSchedule': 'TBA',
      'location': '',
      'meetings': [],
    });
    expect(unknown.isAsynchronous, isFalse);
    final timed = CourseSection.fromJson({
      ...music.first.toJson(),
      'days': ['Monday'],
      'startMinutes': 600,
      'endMinutes': 650,
    });
    expect(timed.hasWeeklyMeeting, isTrue);
    expect(timed.isAsynchronous, isFalse);
  });
  testWidgets(
    'async classes stay visible on phones with credits, instructor and no invented slot',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final music = sections.firstWhere((s) => s.courseCode == 'MUS 130');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NonTimetabledCourses(courses: [item(music)]),
            ),
          ),
        ),
      );
      expect(find.text('MUS 130'), findsOneWidget);
      expect(find.text('Asynchronous'), findsOneWidget);
      expect(find.textContaining('3 credits · Section'), findsOneWidget);
      expect(find.text(music.instructorDisplay), findsOneWidget);
      expect(find.textContaining('No fixed meeting time'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
