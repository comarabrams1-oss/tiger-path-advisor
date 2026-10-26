import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/themes/app_theme.dart';

void main() {
  test('requested custom hues remain readable on light and dark surfaces', () {
    for (final dark in [true, false]) {
      final theme = AppThemes.build(
        AppThemePreset.custom,
        custom: CustomThemeSettings(
          darkMode: dark,
          primaryColor: dark
              ? const Color(0xFF800080)
              : const Color(0xFFFFFFAA),
          accentColor: const Color(0xFF008000),
        ),
      );
      final surface = theme.colorScheme.surface.computeLuminance();
      for (final color in [
        theme.colorScheme.primary,
        theme.colorScheme.secondary,
      ]) {
        final luminance = color.computeLuminance();
        expect(
          (math.max(luminance, surface) + 0.05) /
              (math.min(luminance, surface) + 0.05),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });
}
