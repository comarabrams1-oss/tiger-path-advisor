import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/screens/theme_settings_screen.dart';
import 'package:tiger_path/themes/app_theme.dart';

void main() {
  const custom = CustomThemeSettings(
    darkMode: true,
    primaryColor: Color(0xFF800080),
    accentColor: Color(0xFF008000),
  );
  testWidgets(
    'preview uses applied colors and control styles, independent of outer theme',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.build(AppThemePreset.light),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ThemeStudioPreview(
                preset: AppThemePreset.custom,
                custom: custom,
                title: 'Custom preview',
              ),
            ),
          ),
        ),
      );
      final expected = AppThemes.build(AppThemePreset.custom, custom: custom);
      final progress = find.byType(LinearProgressIndicator);
      final actual = Theme.of(tester.element(progress));
      expect(actual.colorScheme, expected.colorScheme);
      expect(actual.scaffoldBackgroundColor, expected.scaffoldBackgroundColor);
      expect(
        actual.progressIndicatorTheme.color,
        expected.colorScheme.secondary,
      );
      expect(
        actual.chipTheme.selectedColor,
        expected.colorScheme.secondaryContainer,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('preview-accent-action')),
      );
      expect(
        button.style!.backgroundColor!.resolve({}),
        expected.colorScheme.secondary,
      );
      expect(
        button.style!.foregroundColor!.resolve({}),
        expected.colorScheme.onSecondary,
      );
    },
  );
  testWidgets('preview follows preset until custom editor changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ThemeSettingsScreen(
          currentPreset: AppThemePreset.goldBlack,
          currentCustomTheme: custom,
          onThemeChanged: (_) {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byType(ThemeStudioPreview),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ThemeStudioPreview>(find.byType(ThemeStudioPreview)).preset,
      AppThemePreset.goldBlack,
    );
    await tester.scrollUntilVisible(
      find.byType(Switch),
      -300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(ThemeStudioPreview),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final preview = tester.widget<ThemeStudioPreview>(
      find.byType(ThemeStudioPreview),
    );
    expect(preview.preset, AppThemePreset.custom);
    expect(preview.custom.darkMode, isFalse);
    expect(preview.title, contains('not applied'));
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
