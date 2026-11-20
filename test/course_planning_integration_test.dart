import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/data/program_registry.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/main.dart';
import 'package:tiger_path/screens/course_check_screen.dart';
import 'package:tiger_path/services/course_eligibility_service.dart';
import 'package:tiger_path/services/mock_auth_service.dart';
import 'package:tiger_path/services/preferences_service.dart';
import 'package:tiger_path/services/student_record_service.dart';
import 'package:tiger_path/widgets/transcript_entry_dialog.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pumpAndSettle();
}

Future<void> chooseCourse(
  WidgetTester tester,
  String query,
  String label, {
  bool submit = false,
}) async {
  final field = find.descendant(
    of: find.byType(DropdownMenu<String>),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.enterText(field, query);
  await tester.pumpAndSettle();
  if (submit) {
    await tester.testTextInput.receiveAction(TextInputAction.search);
  } else {
    await tester.tap(
      find.widgetWithText(MenuItemButton, label).hitTestable().first,
    );
  }
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

void main() {
  const session = MockStudentSession(mockStudentEmail);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    selectDemoStudent(mockStudentEmail);
    PreferencesService.useProfile(session.profileId);
  });
  tearDown(() => selectDemoStudent(null));

  testWidgets(
    'search checks actual program rules and keeps requirements closed',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 740);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const MaterialApp(home: CourseCheckScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
      expect(
        find.text('Choose a course to check it against your record.'),
        findsOneWidget,
      );
      await chooseCourse(
        tester,
        'Data Structures',
        'CSC 233 · Data Structures & Algorithms I',
      );
      expect(find.text('Not eligible yet'), findsOneWidget);
      expect(
        find.text('CSC 135 · Introduction to Programming').hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ExpansionTile>(find.byType(ExpansionTile))
            .initiallyExpanded,
        isFalse,
      );
      await chooseCourse(
        tester,
        'CSC135',
        'CSC 135 · Introduction to Programming',
        submit: true,
      );
      expect(find.text('Pass current courses first'), findsOneWidget);
      expect(find.textContaining('must first pass CSC 132'), findsOneWidget);
      await chooseCourse(
        tester,
        'CSC430',
        'CSC 430 · Senior Research and Professional Experience',
      );
      expect(find.text('Not eligible yet'), findsOneWidget);
      expect(find.text('Requires Senior standing.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'course result entry is explicit, updates eligibility, and persists only in its profile',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: const CourseCheckScreen(initialCourseCode: 'CSC 233'),
          builder: (context, child) => MockSessionScope(
            session: session,
            onSignOut: () async {},
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = activeStudent;
      final resultButton = find.text('Record or edit result');
      await tester.ensureVisible(resultButton);
      await tester.tap(resultButton);
      await settle(tester);
      final entry = tester.widget<TranscriptEntryDialog>(
        find.byType(TranscriptEntryDialog),
      );
      expect(entry.attempt, isNull);
      expect(entry.initialCourseCode, 'CSC 233');
      expect(
        tester
            .widget<DropdownButton<String>>(
              find
                  .descendant(
                    of: find.byType(TranscriptEntryDialog),
                    matching: find.byType(DropdownButton<String>),
                  )
                  .first,
            )
            .value,
        '',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(activeStudent, same(before));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await chooseCourse(
        tester,
        'CSC132',
        'CSC 132 · Introduction to Computing and Programming Logic',
      );
      await tester.ensureVisible(resultButton);
      await tester.tap(resultButton);
      await settle(tester);
      final current = tester.widget<TranscriptEntryDialog>(
        find.byType(TranscriptEntryDialog),
      );
      expect(current.attempt?.courseCode, 'CSC 132');
      expect(current.attempt?.grade, isNull);
      await tester.tap(find.byType(DropdownButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('B').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save course'));
      await settle(tester);
      expect(activeStudent.earnedCredits, 9);
      expect(activeStudent.inProgressCredits, 13);
      expect(
        activeStudent.courses
            .where((c) => c.courseCode == 'CSC 132')
            .single
            .grade,
        'B',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Fall 2026 · Grade B'), findsOneWidget);
      await chooseCourse(
        tester,
        'CSC135',
        'CSC 135 · Introduction to Programming',
      );
      expect(find.text('Prerequisites met'), findsOneWidget);
      final saved = await StudentRecordService().load(
        session.profileId,
        fictionalStudent,
      );
      final course = catalogFor(saved).firstWhere((c) => c.code == 'CSC 135');
      expect(
        CourseEligibilityService().checkCourse(saved, course).status,
        EligibilityStatus.eligible,
      );
      expect(
        await StudentRecordService().load('another-profile', fictionalStudent),
        same(fictionalStudent),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('planning tools are accessible from the mobile Plan tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'mock_student_session_v1': mockStudentEmail,
    });
    rootBundle.clear();
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final path = const StringCodec().decodeMessage(message)!;
        return ByteData.sublistView(
          File('build/unit_test_assets/$path').readAsBytesSync(),
        );
      },
    );
    addTearDown(() {
      rootBundle.clear();
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const TigerPathAdvisorApp());
    await settle(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Plan'));
    await settle(tester);
    expect(find.text('Schedule Builder'), findsOneWidget);
    await tester.tap(find.text('Check prerequisites'));
    await settle(tester);
    expect(find.byType(CourseCheckScreen), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('Graduation pathway'));
    await settle(tester);
    expect(find.text('Graduation pathway'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
