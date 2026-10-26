import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tiger_path/screens/generated_schedule_screen.dart';
import 'package:tiger_path/services/schedule_assistant_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';

void main() {
  testWidgets(
    'schedule request updates the builder in place and rejects invented sections',
    (tester) async {
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
      tester.view.physicalSize = const Size(1100, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var invalid = false;
      final assistant = ScheduleAssistantService(
        client: MockClient((request) async {
          final data = jsonDecode(request.body);
          expect(data['mode'], 'schedule');
          final prefs = Map<String, dynamic>.from(
            data['context']['schedule']['preferences'] as Map,
          );
          prefs['avoidEarlyClasses'] = true;
          return http.Response(
            jsonEncode({
              'summary': 'Updated',
              'preferences': prefs,
              'sectionChoices': invalid
                  ? [
                      {'courseCode': 'CSC 237', 'section': 'invented'},
                    ]
                  : [],
              'courseChoices': ['CSC 237'],
              'advisorReview': true,
            }),
            200,
          );
        }),
      );
      addTearDown(assistant.dispose);
      const plan = SemesterPlan(
        items: [
          SemesterPlanItem(
            type: SemesterPlanItemType.course,
            title: 'Java',
            category: 'Major',
            credits: 3,
            reason: '',
            courseCode: 'CSC 237',
          ),
        ],
        totalCredits: 3,
        maxCredits: 15,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GeneratedScheduleScreen(plan: plan, assistant: assistant),
        ),
      );
      Future<void> settle() async {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
      }

      await settle();
      await tester.enterText(find.byType(TextField), 'Prefer later starts');
      await tester.tap(find.text('Update schedule'));
      await settle();
      expect(find.byType(GeneratedScheduleScreen), findsOneWidget);
      expect(find.textContaining('Draft rebuilt:'), findsOneWidget);
      expect(find.textContaining('favor starts from 10 AM'), findsOneWidget);
      expect(
        find.textContaining('Advisor review recommended:'),
        findsOneWidget,
      );
      invalid = true;
      await tester.enterText(find.byType(TextField), 'Use another section');
      await tester.tap(find.text('Update schedule'));
      await settle();
      expect(find.textContaining('Your schedule is unchanged'), findsOneWidget);
      expect(find.textContaining('favor starts from 10 AM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
