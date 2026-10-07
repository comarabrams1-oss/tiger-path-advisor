import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../themes/app_theme.dart';

class ThemeSettings {
  final AppThemePreset preset;
  final CustomThemeSettings customTheme;

  const ThemeSettings({
    required this.preset,
    required this.customTheme,
  });
}

class ThemeService {
  static const String _presetKey =
      'theme_preset';

  static const String _customDarkModeKey =
      'custom_theme_dark_mode';

  static const String _customPrimaryColorKey =
      'custom_theme_primary_color';

  static const String _customAccentColorKey =
      'custom_theme_accent_color';

  static Future<ThemeSettings> load() async {
    final preferences =
        await SharedPreferences.getInstance();

    final presetName =
        preferences.getString(_presetKey);

    final preset = AppThemePreset.values.firstWhere(
      (theme) => theme.name == presetName,
      orElse: () => AppThemePreset.benedict,
    );

    final darkMode =
        preferences.getBool(
          _customDarkModeKey,
        ) ??
        false;

    final primaryValue =
        preferences.getInt(
          _customPrimaryColorKey,
        );

    final accentValue =
        preferences.getInt(
          _customAccentColorKey,
        );

    final customTheme = CustomThemeSettings(
      darkMode: darkMode,
      primaryColor: primaryValue == null
          ? benedictPurple
          : Color(primaryValue),
      accentColor: accentValue == null
          ? benedictGold
          : Color(accentValue),
    );

    return ThemeSettings(
      preset: preset,
      customTheme: customTheme,
    );
  }

  static Future<void> savePreset(
    AppThemePreset preset,
  ) async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setString(
      _presetKey,
      preset.name,
    );
  }

  static Future<void> saveCustomTheme(
    CustomThemeSettings settings,
  ) async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setBool(
      _customDarkModeKey,
      settings.darkMode,
    );

    await preferences.setInt(
      _customPrimaryColorKey,
      settings.primaryColor.toARGB32(),
    );

    await preferences.setInt(
      _customAccentColorKey,
      settings.accentColor.toARGB32(),
    );

    await preferences.setString(
      _presetKey,
      AppThemePreset.custom.name,
    );
  }

  static Future<void> save({
    required AppThemePreset preset,
    required CustomThemeSettings customTheme,
  }) async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setString(
      _presetKey,
      preset.name,
    );

    await preferences.setBool(
      _customDarkModeKey,
      customTheme.darkMode,
    );

    await preferences.setInt(
      _customPrimaryColorKey,
      customTheme.primaryColor.toARGB32(),
    );

    await preferences.setInt(
      _customAccentColorKey,
      customTheme.accentColor.toARGB32(),
    );
  }

  static Future<void> reset() async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.remove(_presetKey);
    await preferences.remove(
      _customDarkModeKey,
    );
    await preferences.remove(
      _customPrimaryColorKey,
    );
    await preferences.remove(
      _customAccentColorKey,
    );
  }
}