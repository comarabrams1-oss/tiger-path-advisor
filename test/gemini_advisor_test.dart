import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/academic_advisor_screen.dart';
import '../lib/services/academic_advisor_context.dart';
import '../lib/services/current_advisor_context.dart';
import '../lib/services/gemini_advisor_service.dart';

void main() {
  test(
    'context includes required classes, eligibility and unresolved slots',
    () {
      final context = currentAdvisorContext();
      final json = context.toJson();
      expect(
        context.requirements.any(
          (item) => item.courseCodes.contains('CSC 437'),
        ),
        isTrue,
      );
      expect(
        context.requirements.any((item) => item.status == 'inProgress'),
        isTrue,
      );
      expect(
        context.requirements.any((item) => item.type == 'elective'),
        isTrue,
      );
      expect(
        context.courses.any(
          (item) =>
              item['code'] == 'CSC 430' && item['eligibility'] == 'blocked',
        ),
        isTrue,
      );
      expect(
        json['limitations'],
        contains(
          'Free-elective completion currently comes from a prototype audit shortcut.',
        ),
      );
    },
  );

  test('automatic context omits personal identity and transcript grades', () {
    final payload = currentAdvisorContext().promptFor('What comes next?');
    expect(payload, isNot(contains('Comar')));
    expect(payload, isNot(contains('"gpa"')));
    expect(payload, isNot(contains('"grade"')));
    expect(payload, isNot(contains('"name"')));
    expect(payload, isNot(contains('3.66')));
    expect((jsonDecode(payload) as Map)['studentQuestion'], 'What comes next?');
  });

  test('Gemini receives current context and the trimmed question', () async {
    String? sent;
    final service = GeminiAdvisorService(
      generate: (prompt) async {
        sent = prompt;
        return '  Check your remaining CSC requirements.  ';
      },
    );
    final result = await service.answer(currentAdvisorContext(), ' Classes? ');
    expect(result, 'Check your remaining CSC requirements.');
    expect((jsonDecode(sent!) as Map)['studentQuestion'], 'Classes?');
    expect(sent, contains('conditionalOnPassingCurrentCourses'));
  });

  test('empty and oversized questions never invoke Gemini', () async {
    var calls = 0;
    final service = GeminiAdvisorService(
      generate: (_) async {
        calls++;
        return 'answer';
      },
    );
    for (final question in ['', ' ', List.filled(1001, 'x').join()]) {
      await expectLater(
        service.answer(currentAdvisorContext(), question),
        throwsA(isA<AdvisorException>()),
      );
    }
    expect(calls, 0);
  });

  test(
    'empty answers and transport errors become safe user messages',
    () async {
      for (final generate in <Future<String?> Function(String)>[
        (_) async => null,
        (_) async => ' ',
        (_) async => throw StateError('sensitive internal diagnostic'),
      ]) {
        try {
          await GeminiAdvisorService(generate: generate)
              .answer(currentAdvisorContext(), 'Classes?');
          fail('Expected an advisor error');
        } on AdvisorException catch (error) {
          expect(error.message, isNot(contains('sensitive')));
        }
      }
    },
  );

  test('slow requests time out', () async {
    final service = GeminiAdvisorService(
      generate: (_) => Completer<String?>().future,
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      service.answer(currentAdvisorContext(), 'Classes?'),
      throwsA(
        isA<AdvisorException>().having(
          (error) => error.message,
          'message',
          contains('too long'),
        ),
      ),
    );
  });

  test('missing configuration does not attempt a model request', () async {
    await expectLater(
      GeminiAdvisorService().answer(currentAdvisorContext(), 'Classes?'),
      throwsA(
        isA<AdvisorException>().having(
          (error) => error.message,
          'message',
          contains('not connected'),
        ),
      ),
    );
  });

  testWidgets('remaining classes work offline and sharing requires consent', (
    tester,
  ) async {
    final advisor = _FakeAdvisor();
    await tester.pumpWidget(
      MaterialApp(
        home: AcademicAdvisorScreen(
          academicContext: currentAdvisorContext(),
          advisor: advisor,
        ),
      ),
    );
    expect(find.text('AI Academic Advisor'), findsOneWidget);
    expect(find.textContaining('Still needed:'), findsOneWidget);
    expect(advisor.calls, 0);
    final ask = find.widgetWithText(FilledButton, 'Ask Gemini');
    await tester.ensureVisible(ask);
    expect(tester.widget<FilledButton>(ask).onPressed, isNull);
    final consent = find.byType(CheckboxListTile);
    await tester.scrollUntilVisible(consent, 400);
    await tester.tap(consent);
    await tester.pump();
    await tester.ensureVisible(ask);
    await tester.tap(ask);
    await tester.pumpAndSettle();
    expect(advisor.calls, 1);
    expect(find.text('Your course explanation.'), findsOneWidget);
  });

  testWidgets('failed request can be retried without changing the plan', (
    tester,
  ) async {
    final advisor = _FakeAdvisor()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: AcademicAdvisorScreen(
          academicContext: currentAdvisorContext(),
          advisor: advisor,
        ),
      ),
    );
    final consent = find.byType(CheckboxListTile);
    await tester.scrollUntilVisible(consent, 400);
    await tester.tap(consent);
    await tester.pump();
    final ask = find.widgetWithText(FilledButton, 'Ask Gemini');
    await tester.ensureVisible(ask);
    await tester.tap(ask);
    await tester.pumpAndSettle();
    expect(find.text('Try again.'), findsOneWidget);
    advisor.fail = false;
    await tester.ensureVisible(ask);
    await tester.tap(ask);
    await tester.pumpAndSettle();
    expect(advisor.calls, 2);
    expect(find.text('Your course explanation.'), findsOneWidget);
  });
}

class _FakeAdvisor implements AcademicAdvisor {
  var calls = 0;
  var fail = false;

  @override
  Future<String> answer(AcademicAdvisorContext context, String question) async {
    calls++;
    if (fail) throw const AdvisorException('Try again.');
    return 'Your course explanation.';
  }
}
