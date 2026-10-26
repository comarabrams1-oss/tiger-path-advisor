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
  for (final scenario in [
    (
      preset: AppThemePreset.benedict,
      size: const Size(1440, 1200),
      platform: TargetPlatform.macOS,
    ),
    (
      preset: AppThemePreset.goldBlack,
      size: const Size(1440, 1200),
      platform: TargetPlatform.macOS,
    ),
    (
      preset: AppThemePreset.custom,
      size: const Size(1440, 1200),
      platform: TargetPlatform.macOS,
    ),
    (
      preset: AppThemePreset.benedict,
      size: const Size(390, 844),
      platform: TargetPlatform.iOS,
    ),
    (
      preset: AppThemePreset.goldBlack,
      size: const Size(412, 915),
      platform: TargetPlatform.android,
    ),
  ]) {
    final preset = scenario.preset;
    testWidgets(
      'Main flows render in ${preset.name} on ${scenario.platform.name}',
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
          tester.binding.defaultBinaryMessenger.setMockMessageHandler(
            'flutter/assets',
            null,
          );
          rootBundle.clear();
        });
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = scenario.size;
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
          AiAdvisorScreen(),
          const SchedulePreferencesScreen(),
        ]) {
          await tester.pumpWidget(
            MaterialApp(theme: AppThemes.build(preset), home: screen),
          );
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          });
          await tester.pumpAndSettle();
          if (screen is HomeScreen) {
            await tester.scrollUntilVisible(
              find.text('Your academic workspace'),
              400,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView).first,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
          }
          expect(
            tester.takeException(),
            isNull,
            reason: screen.runtimeType.toString(),
          );
        }
        await tester.scrollUntilVisible(
          find.text('Find courses for my semester'),
          400,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.text('Find courses for my semester'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Find courses for my semester'));
        await tester.pumpAndSettle();
        expect(find.text('Junior semester plan'), findsOneWidget);
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
        await tester.ensureVisible(find.text('Generate Class Schedule'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Generate Class Schedule'));
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        expect(find.text('Your Semester Schedule'), findsOneWidget);
        expect(find.textContaining('Demo sections in use'), findsNothing);
        await tester.scrollUntilVisible(
          find.textContaining('Imported Spring 2027 snapshot'),
          400,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          find.textContaining('Imported Spring 2027 snapshot'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Build with Tiger Path'),
          -400,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Update schedule'), findsOneWidget);
      },
      variant: TargetPlatformVariant({scenario.platform}),
    );
  }
}
