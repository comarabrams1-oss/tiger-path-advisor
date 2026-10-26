import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/screens/ai_advisor_screen.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/models/student.dart';
import 'package:tiger_path/models/student_course.dart';
import 'package:tiger_path/services/ai_advisor_service.dart';
import 'package:tiger_path/services/advisor_app_actions.dart';
import 'package:tiger_path/services/advisor_history_service.dart';
import 'package:tiger_path/services/theme_service.dart';
import 'package:tiger_path/themes/app_theme.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('chat restores and theme action needs a tap', (tester) async {
    SharedPreferences.setMockInitialValues({});
    rootBundle.clear();
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    ThemeSettings? applied;
    List? latestChanges;
    final service = AiAdvisorService(
      client: MockClient((request) async {
        final data = jsonDecode(request.body) as Map;
        expect(data['context']['classification'], 'Junior');
        expect(data['context'].containsKey('progressChanges'), isTrue);
        latestChanges = data['context']['progressChanges'] as List;
        if ((data['messages'] as List).last['text'].contains('teal')) {
          return http.Response(
            jsonEncode({
              'answer': 'Tap to apply teal and orange.',
              'actions': [
                {
                  'type': 'customTheme',
                  'target': 'custom',
                  'primaryHex': '#008080',
                  'accentHex': '#FF8800',
                  'darkMode': true,
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'answer': 'Tap to apply Gold & Black.',
            'actions': [
              {'type': 'changeTheme', 'target': 'goldBlack'},
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(service.dispose);
    Widget app(String key, {Student student = testStudent}) => MaterialApp(
      builder: (context, child) => AdvisorAppActions(
        onThemeChanged: (value) => applied = value,
        child: child!,
      ),
      home: AiAdvisorScreen(
        key: ValueKey(key),
        service: service,
        student: student,
      ),
    );
    await tester.pumpWidget(app('first'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Change to Gold & Black');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(applied, isNull);
    final action = find.widgetWithText(FilledButton, 'Apply Gold & Black');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await settle(tester);
    expect(applied?.preset, AppThemePreset.goldBlack);
    expect((await ThemeService.load()).preset, AppThemePreset.goldBlack);
    expect(
      (await const AdvisorHistoryService().load()).single.messages,
      hasLength(2),
    );
    await tester.pumpWidget(app('reopen'));
    await settle(tester);
    expect(find.text('Change to Gold & Black'), findsOneWidget);
    expect(find.text('Conversation saved on this browser'), findsOneWidget);
    final updated = Student(
      name: testStudent.name,
      institution: testStudent.institution,
      major: testStudent.major,
      catalogYear: testStudent.catalogYear,
      classification: testStudent.classification,
      gpa: testStudent.gpa,
      earnedCredits: testStudent.earnedCredits + 3,
      inProgressCredits: testStudent.inProgressCredits,
      requiredCredits: testStudent.requiredCredits,
      courses: [
        ...testStudent.courses,
        const StudentCourse(
          courseCode: 'CSC 237',
          grade: 'A',
          term: '2026-2027 - Fall',
          status: CourseStatus.completed,
        ),
      ],
    );
    await tester.pumpWidget(app('updated', student: updated));
    await settle(tester);
    await tester.enterText(
      find.byType(TextField),
      'What changed in my progress?',
    );
    await tester.tap(find.byTooltip('Send question'));
    await settle(tester);
    expect(latestChanges, isNotEmpty);
    expect(
      latestChanges!.any((change) => change['current'] == 'completed'),
      isTrue,
    );
    await tester.enterText(
      find.byType(TextField),
      'Use teal and orange with a dark background',
    );
    await tester.tap(find.byTooltip('Send question'));
    await settle(tester);
    final customButton = find.widgetWithText(
      FilledButton,
      'Apply custom colors',
    );
    await tester.ensureVisible(customButton);
    await tester.tap(customButton);
    await settle(tester);
    final theme = await ThemeService.load();
    expect(theme.preset, AppThemePreset.custom);
    expect(theme.customTheme.primaryColor, const Color(0xFF008080));
    expect(theme.customTheme.accentColor, const Color(0xFFFF8800));
    expect(theme.customTheme.darkMode, isTrue);
    final saved = (await const AdvisorHistoryService().load())
        .first
        .messages
        .last
        .actions
        .single;
    expect(saved.primaryHex, '#008080');
    await tester.enterText(find.byType(TextField), 'A question');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.text('Thinking with your latest plan'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      contains('\n'),
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
  });
}
