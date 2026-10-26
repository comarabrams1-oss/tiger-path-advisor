import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/main.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/themes/app_theme.dart';
import 'package:tiger_path/widgets/workspace_shell.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final design in AppDesign.values) {
    testWidgets(
      '${design.name} navigation survives resizing and keyboard changes',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'mock_student_session_v1': mockStudentEmail,
          'interface_design': design.name,
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
          tester.binding.defaultBinaryMessenger.setMockMessageHandler(
            'flutter/assets',
            null,
          );
          selectDemoStudent(null);
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 740);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(const TigerPathAdvisorApp());
        await settle(tester);
        expect(activeStudent, same(fictionalStudent));
        for (final label in [
          'Courses',
          'Degree',
          'Plan',
          'Advisor',
          'Style',
          'Home',
        ]) {
          await tester.tap(find.widgetWithText(NavigationDestination, label));
          await settle(tester);
          expect(
            tester
                .widget<WorkspaceShell>(find.byType(WorkspaceShell))
                .selectedIndex,
            WorkspaceShell.labels.indexOf(label),
          );
          expect(tester.takeException(), isNull, reason: '$label at 360px');
        }
        await tester.tap(find.widgetWithText(NavigationDestination, 'Advisor'));
        await settle(tester);
        final navigator = tester.state(find.byType(Navigator).first);
        tester.view.viewInsets = FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(Navigator).first), same(navigator));
        expect(find.byType(NavigationBar), findsNothing);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        for (final size in [
          const Size(1280, 900),
          const Size(844, 390),
          const Size(360, 740),
        ]) {
          tester.view.physicalSize = size;
          await settle(tester);
          await tester.tap(find.text('Plan').last);
          await settle(tester);
          expect(find.text('Schedule Builder'), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'Plan after resize to $size',
          );
        }
      },
    );
  }
}
