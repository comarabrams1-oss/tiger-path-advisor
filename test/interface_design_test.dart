import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/themes/app_theme.dart';
import 'package:tiger_path/services/theme_service.dart';
import 'package:tiger_path/screens/theme_settings_screen.dart';

void main() {
  test('design changes geometry without changing selected palette', () {
    for (final preset in AppThemePreset.values) {
      final classic = AppThemes.build(preset);
      for (final design in [AppDesign.soft, AppDesign.sharp]) {
        final styled = AppThemes.build(
          preset,
          custom: CustomThemeSettings(design: design),
        );
        expect(styled.colorScheme, classic.colorScheme);
        final shape = styled.cardTheme.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(design.radius));
        expect(styled.extension<AppDesignTokens>()!.design, design);
      }
    }
  });
  testWidgets('design selection saves and survives palette changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    ThemeSettings? applied;
    await tester.pumpWidget(
      MaterialApp(
        home: ThemeSettingsScreen(
          currentPreset: AppThemePreset.benedict,
          currentCustomTheme: const CustomThemeSettings(),
          onThemeChanged: (settings) => applied = settings,
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Sharp'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Sharp'));
    await tester.pumpAndSettle();
    expect(applied!.customTheme.design, AppDesign.sharp);
    expect((await ThemeService.load()).customTheme.design, AppDesign.sharp);
    await ThemeService.savePreset(AppThemePreset.midnightPurple);
    expect((await ThemeService.load()).customTheme.design, AppDesign.sharp);
    expect((await ThemeService.load()).preset, AppThemePreset.midnightPurple);
  });
}
