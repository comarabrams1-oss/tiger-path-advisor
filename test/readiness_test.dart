import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/screens/readiness_screen.dart';
import 'package:tiger_path/services/interview_practice_service.dart';
import 'package:tiger_path/services/readiness_progress_service.dart';

void main() {
  testWidgets(
    'Readiness keeps Kamya’s order and saves only the latest feedback by profile',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final questions = await tester.runAsync(
        InterviewPracticeService.loadQuestions,
      );
      expect(questions?.map((question) => question.text), [
        'Tell me about yourself.',
        'Why do you want this job?',
        'What is one of your strengths?',
        'What is one weakness you are working on?',
        'Why should we hire you?',
        'Describe a time you led a team.',
      ]);
      const answer = 'I study engineering and built a robot with my class.';
      const feedback = InterviewFeedback(
        relevance: 4,
        specificity: 3,
        clarity: 5,
        strength: 'You gave a relevant example.',
        nextStep: 'Explain which part of the robot you built.',
      );
      var attempts = 0;
      final service = InterviewPracticeService(
        client: MockClient((request) async {
          expect(jsonDecode(request.body), {
            'mode': 'interview',
            'questionId': 'introduction',
            'answer': answer,
          });
          expect(request.headers.containsKey('x-goog-api-key'), isFalse);
          if (++attempts == 1) {
            return http.Response('{"code":"PROVIDER_BUSY"}', 503);
          }
          return http.Response(jsonEncode(feedback.toJson()), 200);
        }),
      );
      addTearDown(service.dispose);
      Future<void> open(String profile) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ReadinessScreen(
              key: ValueKey(profile),
              profileId: profile,
              interviewService: service,
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> scrollTo(Finder finder) => tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );

      await open('one');
      expect(find.text('Tell me about yourself.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), answer);
      await tester.pump();
      await tap(find.text('Rate answer'));
      expect(attempts, 1);
      expect(
        find.text('Gemini is busy. Try again in a moment.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        answer,
      );
      await tap(find.text('Rate answer'));
      expect(find.text('Relevance 4/5'), findsOneWidget);
      expect(find.text(feedback.nextStep), findsOneWidget);
      expect(find.text('1 of 6 questions reviewed'), findsOneWidget);
      await scrollTo(find.text('Prepare a résumé'));
      await tap(find.text('Prepare a résumé'));
      expect(find.text('1 of 5 milestones complete'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await open('two');
      expect(find.text('Tell me about yourself.'), findsOneWidget);
      expect(find.text('0 of 6 questions reviewed'), findsOneWidget);
      await scrollTo(find.text('Prepare a résumé'));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Prepare a résumé'),
            )
            .value,
        isFalse,
      );
      await open('one');
      expect(find.text('Why do you want this job?'), findsOneWidget);
      await tap(find.byTooltip('Previous question'));
      expect(find.text('Clarity 5/5'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences
            .getKeys()
            .where((key) => key.startsWith('readiness'))
            .any((key) => preferences.get(key).toString().contains(answer)),
        isFalse,
      );
      expect(
        (await const ReadinessProgressService('one').loadFeedback(questions!))
            .keys,
        ['introduction'],
      );
    },
  );
}
