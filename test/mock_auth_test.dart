import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/main.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/services/mock_auth_service.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
  });
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'mock auth accepts only student domain and persists only when selected',
    () async {
      final auth = MockAuthService();
      expect(
        MockAuthService.isStudentEmail('student@my.benedict.edu.evil.test'),
        isFalse,
      );
      expect(MockAuthService.isStudentEmail('student@benedict.edu'), isFalse);
      expect(MockAuthService.isStudentEmail('student@gmail.com'), isFalse);
      expect(MockAuthService.isStudentEmail('a..b@my.benedict.edu'), isFalse);
      final session = await auth.signIn(
        ' Demo.Student@MY.BENEDICT.EDU ',
        remember: true,
      );
      expect(session.email, 'demo.student@my.benedict.edu');
      expect((await auth.restore())?.profileId, session.profileId);
      expect(
        (await auth.signIn('other@my.benedict.edu', remember: false)).profileId,
        isNot(session.profileId),
      );
      expect(await auth.restore(), isNull);
      await auth.signIn('demo.student@my.benedict.edu', remember: true);
      await auth.signOut();
      expect(await auth.restore(), isNull);
    },
  );
  testWidgets('mock email sign-in gates Home and sign-out returns to login', (
    tester,
  ) async {
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
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TigerPathAdvisorApp());
    await settle(tester);
    expect(find.text('Sign in'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'student@gmail.com');
    await tester.tap(find.text('Continue to Tiger Path'));
    await settle(tester);
    expect(
      find.text('Use your @my.benedict.edu student email.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextFormField),
      'demo.student@my.benedict.edu',
    );
    await tester.tap(find.text('Continue to Tiger Path'));
    await settle(tester);
    expect(find.text('demo.student@my.benedict.edu'), findsOneWidget);
    expect(find.text('Tiger Path Advisor'), findsWidgets);
    expect(activeStudent, same(fictionalStudent));
    await tester.tap(find.text('Plan'));
    await settle(tester);
    expect(find.text('Schedule Builder'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    expect(find.text('Tiger Path Advisor'), findsWidgets);
    await tester.tap(find.text('Sign out'));
    await settle(tester);
    expect(find.text('Sign in'), findsOneWidget);
    expect(await MockAuthService().restore(), isNull);
    expect(activeStudent, same(testStudent));
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Use fictional test student'));
    await tester.tap(find.text('Use fictional test student'));
    await settle(tester);
    expect(activeStudent, same(fictionalStudent));
    expect(find.text(mockStudentEmail), findsOneWidget);
    await tester.tap(find.text('Degree'));
    await settle(tester);
    expect(find.text('Degree Progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Home'));
    await settle(tester);
    await tester.tap(find.text('Sign out'));
    await settle(tester);
    expect(activeStudent, same(testStudent));
  });
}
