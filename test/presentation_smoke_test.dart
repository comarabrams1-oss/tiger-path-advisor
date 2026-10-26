import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/main.dart';
import 'package:tiger_path/screens/transcript_screen.dart';
import 'package:tiger_path/screens/ai_advisor_screen.dart';
import 'package:tiger_path/screens/degree_progress_screen.dart';
import 'package:tiger_path/screens/course_recommendations_screen.dart';
import 'package:tiger_path/screens/schedule_preferences_screen.dart';
import 'package:tiger_path/themes/app_theme.dart';

void main() {
  for (final preset in [
    AppThemePreset.benedict,
    AppThemePreset.goldBlack,
    AppThemePreset.custom,
  ]) {
    testWidgets('Main flows render in ${preset.name}', (tester) async {
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
        rootBundle.clear();
      });
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final screen in <Widget>[
        HomeScreen(
          currentPreset: preset,
          currentCustomTheme: const CustomThemeSettings(),
          onThemeChanged: (_) {},
        ),
        const TranscriptScreen(),
        const DegreeProgressScreen(),
        const CourseRecommendationsScreen(),
        const AiAdvisorScreen(),
        const SchedulePreferencesScreen(),
      ]) {
        await tester.pumpWidget(
          MaterialApp(theme: AppThemes.build(preset), home: screen),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.scrollUntilVisible(
        find.text('Generate Semester Plan'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Generate Semester Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Recommended Semester Plan'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Generate Class Schedule'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Generate Class Schedule'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text('Your Semester Schedule'), findsOneWidget);
      expect(find.textContaining('demonstration Spring'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('Using real Tiger Portal section data'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.textContaining('Using real Tiger Portal section data'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
