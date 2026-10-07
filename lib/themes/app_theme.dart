import 'package:flutter/material.dart';

const benedictPurple = Color(0xFF3A0B5C);
const benedictDarkPurple = Color(0xFF26063E);
const benedictGold = Color(0xFFFFD22E);

enum AppThemePreset {
  benedict,
  light,
  dark,
  midnightPurple,
  goldBlack,
  highContrast,
  custom,
}

extension AppThemePresetInfo on AppThemePreset {
  String get displayName {
    switch (this) {
      case AppThemePreset.benedict:
        return 'Benedict';
      case AppThemePreset.light:
        return 'Light';
      case AppThemePreset.dark:
        return 'Dark';
      case AppThemePreset.midnightPurple:
        return 'Midnight Purple';
      case AppThemePreset.goldBlack:
        return 'Gold & Black';
      case AppThemePreset.highContrast:
        return 'High Contrast';
      case AppThemePreset.custom:
        return 'My Theme';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemePreset.benedict:
        return Icons.school_outlined;
      case AppThemePreset.light:
        return Icons.light_mode_outlined;
      case AppThemePreset.dark:
        return Icons.dark_mode_outlined;
      case AppThemePreset.midnightPurple:
        return Icons.nights_stay_outlined;
      case AppThemePreset.goldBlack:
        return Icons.workspace_premium_outlined;
      case AppThemePreset.highContrast:
        return Icons.contrast_outlined;
      case AppThemePreset.custom:
        return Icons.palette_outlined;
    }
  }
}

class CustomThemeSettings {
  final bool darkMode;
  final Color primaryColor;
  final Color accentColor;

  const CustomThemeSettings({
    this.darkMode = false,
    this.primaryColor = benedictPurple,
    this.accentColor = benedictGold,
  });

  CustomThemeSettings copyWith({
    bool? darkMode,
    Color? primaryColor,
    Color? accentColor,
  }) {
    return CustomThemeSettings(
      darkMode: darkMode ?? this.darkMode,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}

class AppThemes {
  static ThemeData build(
    AppThemePreset preset, {
    CustomThemeSettings custom = const CustomThemeSettings(),
  }) {
    switch (preset) {
      case AppThemePreset.benedict:
        return _benedictTheme();

      case AppThemePreset.light:
        return _lightTheme();

      case AppThemePreset.dark:
        return _darkTheme();

      case AppThemePreset.midnightPurple:
        return _midnightPurpleTheme();

      case AppThemePreset.goldBlack:
        return _goldBlackTheme();

      case AppThemePreset.highContrast:
        return _highContrastTheme();

      case AppThemePreset.custom:
        return _customTheme(custom);
    }
  }

  static ThemeData _benedictTheme() {
    const background = Color(0xFFF7F4FA);
    const surface = Colors.white;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: benedictPurple,
          brightness: Brightness.light,
        ).copyWith(
          primary: benedictPurple,
          onPrimary: Colors.white,
          secondary: benedictGold,
          onSecondary: Colors.black,
          surface: surface,
          onSurface: const Color(0xFF211B25),
        );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: background,
      cardColor: surface,
      appBarColor: benedictPurple,
      appBarForeground: Colors.white,
      navigationColor: surface,
    );
  }

  static ThemeData _lightTheme() {
    const background = Color(0xFFF4F5F7);
    const surface = Colors.white;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: benedictPurple,
          brightness: Brightness.light,
        ).copyWith(
          primary: benedictPurple,
          onPrimary: Colors.white,
          secondary: benedictGold,
          onSecondary: Colors.black,
          surface: surface,
          onSurface: const Color(0xFF1C1B1F),
        );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: background,
      cardColor: surface,
      appBarColor: surface,
      appBarForeground: benedictDarkPurple,
      navigationColor: surface,
    );
  }

  static ThemeData _darkTheme() {
    const background = Color(0xFF100D13);
    const surface = Color(0xFF1B1720);
    const card = Color(0xFF211A28);
    const primary = Color(0xFFD4A6F0);
    const primaryContainer = Color(0xFF4D2265);
    const mutedSurface = Color(0xFF2A2230);

    const scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: Color(0xFF2B073E),
      primaryContainer: primaryContainer,
      onPrimaryContainer: Color(0xFFF5DFFF),
      secondary: benedictGold,
      onSecondary: Colors.black,
      surface: surface,
      onSurface: Color(0xFFF5EFF7),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: background,
      cardColor: card,
      appBarColor: const Color(0xFF17111B),
      appBarForeground: const Color(0xFFF8F3FA),
      navigationColor: surface,
      dividerColor: const Color(0xFF403647),
      inputFillColor: mutedSurface,
    );
  }

  static ThemeData _midnightPurpleTheme() {
    const background = Color(0xFF090510);
    const surface = Color(0xFF160D20);
    const card = Color(0xFF1D102A);
    const primary = Color(0xFFB875E7);
    const accent = Color(0xFF8F7CFF);

    const scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: Color(0xFF240037),
      primaryContainer: Color(0xFF41215A),
      onPrimaryContainer: Color(0xFFF4DBFF),
      secondary: accent,
      onSecondary: Color(0xFF100A2C),
      surface: surface,
      onSurface: Color(0xFFF7EEFC),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: background,
      cardColor: card,
      appBarColor: const Color(0xFF12091B),
      appBarForeground: Colors.white,
      navigationColor: surface,
      dividerColor: const Color(0xFF3E304A),
      inputFillColor: const Color(0xFF251630),
    );
  }

  static ThemeData _goldBlackTheme() {
    const background = Color(0xFF0B0B0B);
    const surface = Color(0xFF171717);
    const card = Color(0xFF202020);

    const scheme = ColorScheme.dark(
      primary: benedictGold,
      onPrimary: Colors.black,
      primaryContainer: Color(0xFF4C3C00),
      onPrimaryContainer: Color(0xFFFFE996),
      secondary: Color(0xFFFFE082),
      onSecondary: Colors.black,
      surface: surface,
      onSurface: Color(0xFFF7F3E8),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: background,
      cardColor: card,
      appBarColor: const Color(0xFF111111),
      appBarForeground: benedictGold,
      navigationColor: surface,
      dividerColor: const Color(0xFF3D3D3D),
      inputFillColor: const Color(0xFF282828),
    );
  }

  static ThemeData _highContrastTheme() {
    const scheme = ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      primaryContainer: Color(0xFF333333),
      onPrimaryContainer: Colors.white,
      secondary: Color(0xFFFFFF00),
      onSecondary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
      error: Color(0xFFFF6B6B),
      onError: Colors.black,
    );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: Colors.black,
      cardColor: const Color(0xFF111111),
      appBarColor: Colors.black,
      appBarForeground: Colors.white,
      navigationColor: Colors.black,
      dividerColor: Colors.white,
      inputFillColor: const Color(0xFF191919),
      highContrast: true,
    );
  }

  static ThemeData _customTheme(CustomThemeSettings settings) {
    final brightness = settings.darkMode ? Brightness.dark : Brightness.light;

    final dark = settings.darkMode;

    final background = dark ? const Color(0xFF101014) : const Color(0xFFF6F6F8);

    final surface = dark ? const Color(0xFF1B1B20) : Colors.white;

    final card = dark ? const Color(0xFF232329) : Colors.white;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: settings.primaryColor,
          brightness: brightness,
        ).copyWith(
          primary: settings.primaryColor,
          onPrimary: _foregroundFor(settings.primaryColor),
          secondary: settings.accentColor,
          surface: surface,
          onSecondary:
              ThemeData.estimateBrightnessForColor(settings.accentColor) ==
                  Brightness.dark
              ? Colors.white
              : Colors.black,
        );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: background,
      cardColor: card,
      appBarColor: dark ? const Color(0xFF17171C) : settings.primaryColor,
      appBarForeground: dark
          ? Colors.white
          : _foregroundFor(settings.primaryColor),
      navigationColor: surface,
      dividerColor: dark ? const Color(0xFF404047) : const Color(0xFFE0E0E5),
      inputFillColor: dark ? const Color(0xFF29292F) : const Color(0xFFF0F0F3),
    );
  }

  static ThemeData _baseTheme({
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color appBarColor,
    required Color appBarForeground,
    required Color navigationColor,
    Color? dividerColor,
    Color? inputFillColor,
    bool highContrast = false,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      dividerColor: dividerColor,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarColor,
        foregroundColor: appBarForeground,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: highContrast
              ? const BorderSide(color: Colors.white, width: 1.5)
              : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            inputFillColor ??
            scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: highContrast
              ? const BorderSide(color: Colors.white)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.primary.withValues(alpha: 0.08),
        selectedColor: scheme.primary.withValues(alpha: 0.20),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navigationColor,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }

  static Color _foregroundFor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}
