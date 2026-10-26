import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/services/schedule_change_history_service.dart';
import 'package:tiger_path/services/schedule_generation_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';
import 'package:tiger_path/widgets/info_tip.dart';

const prefs = SchedulePreferences(
  preferredTime: 'No Preference',
  preferredDays: [],
  avoidedDays: [],
  preferredProfessors: [],
  maxCredits: 15,
  avoidEarlyClasses: false,
  avoidLateClasses: false,
  minimizeGaps: true,
);
ScheduledCourseSection course(
  String code, {
  String section = '01',
  int start = 600,
}) => ScheduledCourseSection(
  planItem: SemesterPlanItem(
    type: SemesterPlanItemType.course,
    title: code,
    courseCode: code,
    category: 'Major',
    credits: 3,
    reason: '',
  ),
  section: CourseSection(
    courseCode: code,
    sectionNumber: section,
    instructorId: '',
    instructorName: 'Test teacher',
    term: 'Spring 2027',
    days: ['Monday'],
    startMinutes: start,
    endMinutes: start + 50,
    location: 'Room 1',
    deliveryMethod: '',
  ),
  instructor: null,
  preferenceScore: 0,
  matchReasons: [],
);
GeneratedSchedule schedule(List<ScheduledCourseSection> items) =>
    GeneratedSchedule(scheduled: items, unscheduled: []);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'diffs actual course additions, removals, sections and no-op results',
    () {
      final before = schedule([course('CSC 135'), course('ENG 237')]);
      final after = schedule([
        course('CSC 135', section: '02', start: 660),
        course('MATH 236'),
      ]);
      final changes = ScheduleChangeEntry.compare(before, after, prefs, prefs);
      expect(changes.any((s) => s.startsWith('Removed ENG 237')), isTrue);
      expect(changes.any((s) => s.startsWith('Added MATH 236')), isTrue);
      expect(
        changes.any(
          (s) =>
              s.startsWith('CSC 135:') &&
              s.contains('section 01') &&
              s.contains('section 02') &&
              s.contains('11:00 AM'),
        ),
        isTrue,
      );
      expect(
        ScheduleChangeEntry.compare(before, before, prefs, prefs),
        isEmpty,
      );
    },
  );
  test('history survives service reload, is profile isolated, bounded and includes no-ops', () async {
    SharedPreferences.setMockInitialValues({});
    const a = ScheduleChangeHistoryService('student-a'),
        b = ScheduleChangeHistoryService('student-b');
    final entries = List.generate(
      25,
      (i) => ScheduleChangeEntry(
        time: DateTime(2026, 10, 26, 12, i),
        term: 'Spring 2027',
        request: 'Request $i',
        changes: i == 0 ? [] : ['Added CSC 135.'],
        result: '3 credits',
      ),
    );
    await a.save(entries);
    final restored = await const ScheduleChangeHistoryService('student-a')
        .load();
    expect(restored.length, 20);
    expect(restored.first.request, 'Request 0');
    expect(restored.first.changes, isEmpty);
    expect(restored[1].changes, ['Added CSC 135.']);
    expect(await b.load(), isEmpty);
  });
  testWidgets('info icons reveal supporting copy on tap and hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoTip(
            label: 'Schedule help',
            message: 'Supporting explanation',
          ),
        ),
      ),
    );
    expect(find.text('Supporting explanation'), findsNothing);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('Supporting explanation'), findsOneWidget);
    await tester.tapAt(const Offset(400, 400));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 400));
    await mouse.moveTo(tester.getCenter(find.byType(IconButton)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Supporting explanation'), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpAndSettle();
  });
}
