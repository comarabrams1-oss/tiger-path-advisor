import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tiger_path/services/ai_advisor_service.dart';

void main() {
  test('advisor sends context to proxy and parses answer', () async {
    final service = AiAdvisorService(
      endpoint: Uri.parse('https://example.com/advisor'),
      client: MockClient((request) async {
        expect(request.body, contains('Junior'));
        expect(request.headers.containsKey('x-goog-api-key'), isFalse);
        return http.Response(
          '{"answer":"CSC 434 is in your imported offerings."}',
          200,
        );
      }),
    );
    expect(
      await service.ask(
        [const AdvisorMessage('user', 'What next?')],
        {'classification': 'Junior'},
      ),
      contains('CSC 434'),
    );
    service.dispose();
  });
  test('advisor sanitizes upstream errors', () async {
    for (final status in [429, 503, 502]) {
      final service = AiAdvisorService(
        client: MockClient(
          (_) async => http.Response('private upstream detail', status),
        ),
      );
      await expectLater(
        service.ask([const AdvisorMessage('user', 'What next?')], {}),
        throwsA(isA<AdvisorException>()),
      );
      service.dispose();
    }
  });
  test('advisor distinguishes invalid action and timeout from quota', () async {
    for (final entry in {
      'INVALID_ACTION': 'invalid response or app action',
      'TIMEOUT': 'too long',
      'QUOTA': 'quota reached',
    }.entries) {
      final service = AiAdvisorService(
        client: MockClient(
          (_) async => http.Response('{"code":"${entry.key}"}', 502),
        ),
      );
      await expectLater(
        service.ask([const AdvisorMessage('user', 'Test')], {}),
        throwsA(
          isA<AdvisorException>().having(
            (e) => e.message,
            'message',
            contains(entry.value),
          ),
        ),
      );
      service.dispose();
    }
  });
  test('offering context trims older exchanges without dropping the latest question', () async {
    final service = AiAdvisorService(
      client: MockClient((request) async {
        expect(utf8.encode(request.body).length, lessThanOrEqualTo(64000));
        final messages = (jsonDecode(request.body) as Map)['messages'] as List;
        expect(messages.last['text'], 'Who teaches CSC 135?');
        expect(messages.first['role'], 'user');
        expect(messages.length.isOdd, isTrue);
        expect(messages.length, lessThan(11));
        return http.Response('{"answer":"Test response"}', 200);
      }),
    );
    await service.ask(
      [
        for (var i = 0; i < 10; i++)
          AdvisorMessage(i.isEven ? 'user' : 'assistant', 'x' * 4000),
        const AdvisorMessage('user', 'Who teaches CSC 135?'),
      ],
      {'sectionDetails': 'x' * 35000},
    );
    service.dispose();
  });
}
